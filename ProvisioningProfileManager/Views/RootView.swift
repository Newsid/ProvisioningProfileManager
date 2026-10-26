import SwiftUI

struct RootView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 190, ideal: 220)
        } detail: {
            // List and detail share one split-view column so they get a single
            // toolbar spanning both, instead of a three-column split with one per column.
            VStack(spacing: 0) {
                Divider()
                ListDetailSplit()
            }
            .navigationSplitViewColumnWidth(min: 780, ideal: 1020)
        }
        .alert(
            "Some profiles could not be exported",
            isPresented: Binding(
                get: { !store.exportErrors.isEmpty },
                set: { if !$0 { store.exportErrors = [] } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.exportErrors.joined(separator: "\n"))
        }
        .scaledFont(.body)
        .deleteConfirmation()
        .profileImport()
    }
}

/// List and detail side by side with a draggable divider. Not `HSplitView`: that resets the
/// divider whenever the detail content changes (e.g. on selecting a profile).
private struct ListDetailSplit: View {
    private static let listMinWidth: CGFloat = 360
    private static let detailMinWidth: CGFloat = 420

    @AppStorage("listWidth") private var listWidth = 460.0
    @State private var dragStartWidth: Double?

    var body: some View {
        GeometryReader { geometry in
            let width = clampedWidth(listWidth, total: geometry.size.width)

            HStack(spacing: 0) {
                ProfileListView()
                    .frame(width: width)
                Divider()
                    .overlay {
                        // Wider invisible grab area centred on the 1pt line.
                        Color.clear
                            .frame(width: 8)
                            .contentShape(Rectangle())
                            .onHover { inside in
                                if inside { NSCursor.resizeLeftRight.push() } else { NSCursor.pop() }
                            }
                            .gesture(
                                DragGesture(minimumDistance: 0, coordinateSpace: .global)
                                    .onChanged { value in
                                        let start = dragStartWidth ?? width
                                        dragStartWidth = start
                                        listWidth = clampedWidth(start + value.translation.width, total: geometry.size.width)
                                    }
                                    .onEnded { _ in dragStartWidth = nil }
                            )
                    }
                DetailContainerView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(minWidth: Self.listMinWidth + Self.detailMinWidth)
    }

    private func clampedWidth(_ width: Double, total: CGFloat) -> CGFloat {
        let maxWidth = max(Self.listMinWidth, total - Self.detailMinWidth - 1)
        return min(max(CGFloat(width), Self.listMinWidth), maxWidth)
    }
}

private struct DetailContainerView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        let selected = store.selectedProfiles
        switch selected.count {
        case 0:
            ContentUnavailableView(
                "No Profile Selected",
                systemImage: "doc.text.magnifyingglass",
                description: Text("Select a provisioning profile to see its details.")
            )
        case 1:
            ProfileDetailView(profile: selected[0])
                .id(selected[0].id)
        default:
            MultiSelectionView(profiles: selected)
        }
    }
}
