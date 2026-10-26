import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class ProfileStore {
    private enum DefaultsKey {
        static let sortField = "sortField"
        static let sortAscending = "sortAscending"
        static let groupByBundleID = "groupByBundleID"
        static let warningDays = "warningDays"
        static let fontScale = "fontScale"
    }

    private(set) var profiles: [ProvisioningProfile] = []
    private(set) var isLoading = false
    private(set) var lastLoaded: Date?

    var sidebarSelection: SidebarItem? = .all
    var searchText = ""
    var searchScope: SearchScope = .name
    var selection: Set<ProvisioningProfile.ID> = []
    var collapsedGroups: Set<String> = []

    var sortField: SortField {
        didSet { defaults.set(sortField.rawValue, forKey: DefaultsKey.sortField) }
    }
    var sortAscending: Bool {
        didSet { defaults.set(sortAscending, forKey: DefaultsKey.sortAscending) }
    }
    var groupByBundleID: Bool {
        didSet { defaults.set(groupByBundleID, forKey: DefaultsKey.groupByBundleID) }
    }
    var warningDays: Int {
        didSet { defaults.set(warningDays, forKey: DefaultsKey.warningDays) }
    }
    /// Text zoom applied through `scaledFont`; always one of `fontScaleSteps`.
    var fontScale: CGFloat {
        didSet { defaults.set(Double(fontScale), forKey: DefaultsKey.fontScale) }
    }

    // Deletion flow
    private(set) var pendingDeletion: [ProvisioningProfile] = []
    var isConfirmingDeletion = false
    var deletionErrors: [String] = []

    // Import flow
    var isImporting = false
    var importResult: ProfileImporter.Result?

    // Export flow
    var exportErrors: [String] = []

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private var loadTask: Task<Void, Never>?
    @ObservationIgnored private var reloadDebounce: Task<Void, Never>?
    @ObservationIgnored private var watcher: FolderWatcher?

    init(defaults: UserDefaults = .standard, autoload: Bool = true) {
        self.defaults = defaults
        sortField = defaults.string(forKey: DefaultsKey.sortField).flatMap(SortField.init) ?? .name
        sortAscending = defaults.object(forKey: DefaultsKey.sortAscending) as? Bool ?? true
        groupByBundleID = defaults.bool(forKey: DefaultsKey.groupByBundleID)
        warningDays = defaults.object(forKey: DefaultsKey.warningDays) as? Int ?? 30
        let savedScale = (defaults.object(forKey: DefaultsKey.fontScale) as? Double).map { CGFloat($0) } ?? 1
        fontScale = Self.fontScaleSteps.min { abs($0 - savedScale) < abs($1 - savedScale) } ?? 1

        guard autoload else { return }
        reload()
        let watcher = FolderWatcher { [weak self] in self?.scheduleReload() }
        watcher.start(watching: ProfileLocator.existingDirectories)
        self.watcher = watcher
    }

    // MARK: - Text zoom

    static let fontScaleSteps: [CGFloat] = [0.8, 0.9, 1, 1.1, 1.25, 1.4, 1.6, 1.8, 2]

    var canZoomIn: Bool { fontScale < Self.fontScaleSteps.last! }
    var canZoomOut: Bool { fontScale > Self.fontScaleSteps.first! }

    func zoomIn() {
        if let next = Self.fontScaleSteps.first(where: { $0 > fontScale }) { fontScale = next }
    }

    func zoomOut() {
        if let previous = Self.fontScaleSteps.last(where: { $0 < fontScale }) { fontScale = previous }
    }

    func resetZoom() { fontScale = 1 }

    // MARK: - Loading

    func reload() {
        loadTask?.cancel()
        isLoading = true
        loadTask = Task {
            let loaded = await Task.detached(priority: .userInitiated) { ProfileLoader.loadAll() }.value
            guard !Task.isCancelled else { return }
            setProfiles(loaded)
            isLoading = false
        }
    }

    func setProfiles(_ newProfiles: [ProvisioningProfile]) {
        profiles = newProfiles
        lastLoaded = Date()
        let ids = Set(newProfiles.map(\.id))
        selection.formIntersection(ids)
    }

    /// Coalesces bursts of file-system events (Xcode often writes several files at once).
    private func scheduleReload() {
        reloadDebounce?.cancel()
        reloadDebounce = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            reload()
        }
    }

    // MARK: - Derived data

    var query: ProfileQuery {
        ProfileQuery(
            sidebar: sidebarSelection ?? .all,
            searchText: searchText,
            searchScope: searchScope,
            sortField: sortField,
            ascending: sortAscending,
            warningDays: warningDays,
            now: Date()
        )
    }

    var visibleProfiles: [ProvisioningProfile] { query.apply(to: profiles) }

    var groupedProfiles: [ProfileGroup] {
        let query = query
        return query.grouped(query.apply(to: profiles))
    }

    func count(for item: SidebarItem) -> Int { query.count(for: item, in: profiles) }

    var selectedProfiles: [ProvisioningProfile] {
        profiles.filter { selection.contains($0.id) }
    }

    func isCollapsed(_ group: ProfileGroup) -> Bool { collapsedGroups.contains(group.id) }

    func toggleCollapsed(_ group: ProfileGroup) {
        if collapsedGroups.contains(group.id) {
            collapsedGroups.remove(group.id)
        } else {
            collapsedGroups.insert(group.id)
        }
    }

    // MARK: - Deletion

    func requestDelete(ids: Set<ProvisioningProfile.ID>) {
        let targets = profiles.filter { ids.contains($0.id) }
        guard !targets.isEmpty else { return }
        pendingDeletion = targets.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        isConfirmingDeletion = true
    }

    func requestDeleteAllExpiredOrInvalid() {
        let query = query
        let ids = profiles.filter { query.includes($0, in: .expiredOrInvalid) }.map(\.id)
        requestDelete(ids: Set(ids))
    }

    func confirmDelete() {
        let targets = pendingDeletion
        pendingDeletion = []
        isConfirmingDeletion = false
        let failures = ProfileDeleter.trash(targets.flatMap(\.fileURLs))
        deletionErrors = failures.map { "\($0.url.lastPathComponent): \($0.message)" }
        selection.subtract(targets.map(\.id))
        reload()
    }

    func cancelDelete() {
        pendingDeletion = []
        isConfirmingDeletion = false
    }

    // MARK: - Import

    func importProfiles(from urls: [URL]) {
        guard !urls.isEmpty else { return }
        let existingIDs = Set(profiles.map(\.id))
        Task {
            let result = await Task.detached(priority: .userInitiated) {
                let accessed = urls.filter { $0.startAccessingSecurityScopedResource() }
                defer { accessed.forEach { $0.stopAccessingSecurityScopedResource() } }
                return ProfileImporter.importProfiles(from: urls, existingIDs: existingIDs)
            }.value

            if !result.importedIDs.isEmpty {
                // The import folder may not have existed when watching started.
                watcher?.start(watching: ProfileLocator.existingDirectories)
                sidebarSelection = .all
                searchText = ""
                selection = Set(result.importedIDs)
                reload()
            }
            // Successful imports are shown by selecting them; only report problems.
            if result.hasIssues { importResult = result }
        }
    }

    // MARK: - Export

    /// Asks where to save, then copies the profiles named after the profile, not the file.
    /// One profile gets a save panel (so it can be renamed); several get a folder picker.
    func exportProfiles(ids: Set<ProvisioningProfile.ID>) {
        let targets = profiles.filter { ids.contains($0.id) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        guard !targets.isEmpty else { return }

        if targets.count == 1, let profile = targets.first {
            let panel = NSSavePanel()
            panel.title = "Export Profile"
            panel.nameFieldStringValue = ProfileExporter.suggestedFileName(for: profile)
            guard panel.runModal() == .OK, let url = panel.url else { return }
            do {
                try ProfileExporter.export(profile, to: url)
                NSWorkspace.shared.activateFileViewerSelecting([url])
            } catch {
                exportErrors = ["\(profile.name): \(error.localizedDescription)"]
            }
        } else {
            let panel = NSOpenPanel()
            panel.title = "Export \(targets.count) Profiles"
            panel.prompt = "Export"
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.canCreateDirectories = true
            guard panel.runModal() == .OK, let folder = panel.url else { return }
            let result = ProfileExporter.export(targets, into: folder)
            if !result.exportedURLs.isEmpty {
                NSWorkspace.shared.activateFileViewerSelecting(result.exportedURLs)
            }
            exportErrors = result.failures
        }
    }

    // MARK: - Finder / pasteboard

    func revealInFinder(_ ids: Set<ProvisioningProfile.ID>) {
        let urls = profiles.filter { ids.contains($0.id) }.flatMap(\.fileURLs)
        guard !urls.isEmpty else { return }
        NSWorkspace.shared.activateFileViewerSelecting(urls)
    }

    func copyToPasteboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}
