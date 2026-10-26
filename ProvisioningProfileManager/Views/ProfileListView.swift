import SwiftUI

struct ProfileListView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        let visible = store.visibleProfiles

        VStack(spacing: 0) {
            ListHeader(title: title, subtitle: subtitle)
            if store.sidebarSelection == .expiredOrInvalid && !visible.isEmpty {
                ExpiredBanner(count: visible.count)
            }
            content(visible)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        // Still sets the window title (Window menu, Mission Control); the toolbar copy is
        // removed because the title is shown in the list header instead.
        .navigationTitle(title)
        .hidingToolbarTitle()
        .toolbar { toolbar }
    }

    @ViewBuilder
    private func content(_ visible: [ProvisioningProfile]) -> some View {
        @Bindable var store = store

        Group {
            if store.isLoading && store.profiles.isEmpty {
                ProgressView("Loading profiles…")
            } else if visible.isEmpty {
                emptyState
            } else {
                List(selection: $store.selection) {
                    if store.groupByBundleID {
                        ForEach(store.groupedProfiles) { group in
                            Section {
                                if !store.isCollapsed(group) {
                                    rows(group.profiles)
                                }
                            } header: {
                                GroupHeader(group: group)
                            }
                        }
                    } else {
                        rows(visible)
                    }
                }
                .listStyle(.inset(alternatesRowBackgrounds: true))
                .contextMenu(forSelectionType: ProvisioningProfile.ID.self) { ids in
                    contextMenu(for: ids)
                }
                .onDeleteCommand { store.requestDelete(ids: store.selection) }
            }
        }
    }

    private var title: String { (store.sidebarSelection ?? .all).title }

    private var subtitle: String {
        "\(store.visibleProfiles.count) of \(store.profiles.count) profiles"
    }

    private func rows(_ profiles: [ProvisioningProfile]) -> some View {
        ForEach(profiles) { profile in
            ProfileRowView(profile: profile)
                .tag(profile.id)
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if !store.searchText.isEmpty {
            ContentUnavailableView.search(text: store.searchText)
        } else if store.sidebarSelection == .expiredOrInvalid {
            ContentUnavailableView(
                "All Clean",
                systemImage: "checkmark.seal",
                description: Text("No expired or invalid provisioning profiles.")
            )
        } else {
            ContentUnavailableView {
                Label("No Profiles", systemImage: "doc.questionmark")
            } description: {
                Text("No provisioning profiles found in\n~/Library/Developer/Xcode/UserData/Provisioning Profiles\n\nDrop profiles here or import them.")
            } actions: {
                Button("Import Profiles…") { store.isImporting = true }
            }
        }
    }

    @ViewBuilder
    private func contextMenu(for ids: Set<ProvisioningProfile.ID>) -> some View {
        if !ids.isEmpty {
            let profiles = store.profiles.filter { ids.contains($0.id) }
            Button("Show in Finder") { store.revealInFinder(ids) }
            Button(ids.count == 1 ? "Export…" : "Export \(ids.count) Profiles…") { store.exportProfiles(ids: ids) }
            if profiles.count == 1, let profile = profiles.first {
                Button("Copy UUID") { store.copyToPasteboard(profile.uuid) }
                    .disabled(profile.uuid.isEmpty)
                Button("Copy Bundle ID") { store.copyToPasteboard(profile.bundleID) }
                    .disabled(profile.bundleID.isEmpty)
            }
            Divider()
            Button(ids.count == 1 ? "Move to Trash…" : "Move \(ids.count) Profiles to Trash…", role: .destructive) {
                store.requestDelete(ids: ids)
            }
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // One item laid out by hand: as separate items macOS 26 regroups them into its own
        // shared glass capsules (merging the sections and reordering them).
        if #available(macOS 26, *) {
            ToolbarItem(placement: .navigation) { toolbarBar }
                .sharedBackgroundVisibility(.hidden)
        } else {
            ToolbarItem(placement: .navigation) { toolbarBar }
        }
    }

    private var toolbarBar: some View {
        @Bindable var store = store

        return HStack(spacing: 8) {
            ToolbarSearchField(text: $store.searchText, scope: $store.searchScope)
                .frame(width: 220)
                .padding(.horizontal, 6)
                .toolbarCapsule()

            HStack(spacing: 2) {
                // A button rather than a Toggle: the borderless style would hide the "on" state.
                Button {
                    store.groupByBundleID.toggle()
                } label: {
                    Label("Group by Bundle ID", systemImage: "square.stack.3d.up")
                }
                .background {
                    if store.groupByBundleID {
                        Capsule().fill(.quaternary)
                    }
                }
                .accessibilityAddTraits(store.groupByBundleID ? .isSelected : [])
                .help(store.groupByBundleID ? "Stop grouping by bundle ID" : "Group by bundle ID")

                Menu {
                    Picker("Sort By", selection: $store.sortField) {
                        ForEach(SortField.allCases) { Text($0.title).tag($0) }
                    }
                    .pickerStyle(.inline)
                    Picker("Order", selection: $store.sortAscending) {
                        Text("Ascending").tag(true)
                        Text("Descending").tag(false)
                    }
                    .pickerStyle(.inline)
                } label: {
                    Label("Sort", systemImage: "arrow.up.arrow.down")
                }
                .menuStyle(.button)
                .menuIndicator(.hidden)
                .fixedSize()
                .help("Sort by \(store.sortField.title.lowercased())")
            }
            .toolbarSection()

            HStack(spacing: 2) {
                Button {
                    store.isImporting = true
                } label: {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .help("Import provisioning profiles (or drop them on the window)")

                Button {
                    store.exportProfiles(ids: store.selection)
                } label: {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .disabled(store.selection.isEmpty)
                .help("Export selected profiles, named after the profile")

                Button {
                    store.requestDelete(ids: store.selection)
                } label: {
                    Label("Move to Trash", systemImage: "trash")
                }
                .disabled(store.selection.isEmpty)
                .help("Move selected profiles to Trash")

                Button {
                    store.reload()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .disabled(store.isLoading)
                .help("Reload profiles")
            }
            .toolbarSection()
        }
    }
}

private extension View {
    /// A group of icon buttons drawn as one capsule, like a toolbar item group.
    func toolbarSection() -> some View {
        labelStyle(ToolbarIconLabelStyle())
            .buttonStyle(ToolbarIconButtonStyle())
            .padding(.horizontal, 4)
            .toolbarCapsule()
    }

    /// The capsule behind each toolbar section: Liquid Glass on macOS 26, a plain fill before.
    @ViewBuilder
    func toolbarCapsule() -> some View {
        if #available(macOS 26, *) {
            frame(height: 36)
                .glassEffect(.regular, in: .capsule)
        } else {
            frame(height: 28)
                .background(.quaternary, in: Capsule())
        }
    }
}

/// Drawn by SwiftUI (unlike `.borderless`, which AppKit draws at its own symbol size) so the
/// label style controls the icon size; dims while pressed.
private struct ToolbarIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
    }
}

/// Toolbar-sized icon with a full-size hit area; the title stays available as the accessibility label.
private struct ToolbarIconLabelStyle: LabelStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.icon
            .font(.system(size: 13))
            .imageScale(.large)
            .foregroundStyle(isEnabled ? .primary : .tertiary)
            .frame(width: 34, height: 28)
            .contentShape(Rectangle())
    }
}

private struct GroupHeader: View {
    @Environment(ProfileStore.self) private var store
    let group: ProfileGroup

    var body: some View {
        Button {
            withAnimation(.snappy) { store.toggleCollapsed(group) }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .rotationEffect(.degrees(store.isCollapsed(group) ? 0 : 90))
                    .scaledFont(.caption, weight: .bold)
                    .foregroundStyle(.secondary)
                Text(group.title)
                    .scaledFont(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                Text("\(group.profiles.count)")
                    .scaledFont(.caption, monospacedDigit: true)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 1)
                    .background(.quaternary, in: Capsule())
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct ListHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .scaledFont(.headline)
            Text(subtitle)
                .scaledFont(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .lineLimit(1)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }
}

private extension View {
    /// The title moved into `ListHeader`; macOS 14 has no API to drop it from the toolbar.
    @ViewBuilder
    func hidingToolbarTitle() -> some View {
        if #available(macOS 15, *) {
            toolbar(removing: .title)
        } else {
            self
        }
    }
}

private struct ExpiredBanner: View {
    @Environment(ProfileStore.self) private var store
    let count: Int

    var body: some View {
        HStack {
            Label("\(count) expired or invalid profile\(count == 1 ? "" : "s")", systemImage: "exclamationmark.octagon.fill")
                .foregroundStyle(.red)
            Spacer()
            Button("Move All to Trash…", role: .destructive) {
                store.requestDeleteAllExpiredOrInvalid()
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.red.opacity(0.08))
        .overlay(alignment: .bottom) { Divider() }
    }
}
