import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let provisioningProfiles: [UTType] = ProfileLocator.fileExtensions.sorted()
        .compactMap { UTType(filenameExtension: $0) }
}

/// File picker, drag & drop target and result alert for importing profiles.
private struct ProfileImportModifier: ViewModifier {
    @Environment(ProfileStore.self) private var store
    @State private var isDropTargeted = false

    func body(content: Content) -> some View {
        @Bindable var store = store

        content
            .fileImporter(
                isPresented: $store.isImporting,
                allowedContentTypes: UTType.provisioningProfiles + [.folder],
                allowsMultipleSelection: true
            ) { result in
                if case .success(let urls) = result { store.importProfiles(from: urls) }
            }
            .dropDestination(for: URL.self) { urls, _ in
                let fileURLs = urls.filter(\.isFileURL)
                store.importProfiles(from: fileURLs)
                return !fileURLs.isEmpty
            } isTargeted: { targeted in
                withAnimation(.easeOut(duration: 0.15)) { isDropTargeted = targeted }
            }
            .overlay {
                if isDropTargeted { DropOverlay() }
            }
            .alert(
                alertTitle,
                isPresented: Binding(
                    get: { store.importResult != nil },
                    set: { if !$0 { store.importResult = nil } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMessage)
            }
    }

    private var alertTitle: String {
        let imported = store.importResult?.importedIDs.count ?? 0
        return imported == 0
            ? "No profiles imported"
            : "Imported \(imported) profile\(imported == 1 ? "" : "s")"
    }

    private var alertMessage: String {
        guard let result = store.importResult else { return "" }
        var sections: [String] = []
        if !result.alreadyInstalled.isEmpty {
            sections.append("Already installed:\n" + list(result.alreadyInstalled))
        }
        if !result.failures.isEmpty {
            sections.append("Could not import:\n" + list(result.failures))
        }
        return sections.joined(separator: "\n\n")
    }

    private func list(_ items: [String], limit: Int = 8) -> String {
        var lines = items.prefix(limit).map { "• \($0)" }
        if items.count > limit { lines.append("…and \(items.count - limit) more") }
        return lines.joined(separator: "\n")
    }
}

private struct DropOverlay: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.accentColor.opacity(0.10))
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 3, dash: [10, 6]))
            VStack(spacing: 10) {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 48, weight: .semibold))
                Text("Drop to Import Provisioning Profiles")
                    .scaledFont(.title3, weight: .semibold)
                Text(".mobileprovision and .provisionprofile files, or folders containing them")
                    .scaledFont(.callout)
                    .foregroundStyle(.secondary)
            }
            .foregroundStyle(Color.accentColor)
            .padding(24)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        }
        .padding(8)
        .allowsHitTesting(false)
    }
}

extension View {
    func profileImport() -> some View {
        modifier(ProfileImportModifier())
    }
}
