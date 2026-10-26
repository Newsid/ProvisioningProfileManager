import SwiftUI

struct SidebarView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store

        List(selection: $store.sidebarSelection) {
            Section {
                row(.all, symbol: "doc.on.doc", tint: .accentColor)
                row(.expiringSoon, symbol: "clock.badge.exclamationmark", tint: .orange)
                row(.expiredOrInvalid, symbol: "exclamationmark.octagon", tint: .red)
            } header: {
                header("Library")
            }
            Section {
                ForEach(ProfileType.allCases) { type in
                    if store.count(for: .type(type)) > 0 {
                        row(.type(type), symbol: type.symbol, tint: type.color)
                    }
                }
            } header: {
                header("Type")
            }
        }
        .listStyle(.sidebar)
    }

    // Fonts are set explicitly (and the count is a Text rather than `.badge`) because the
    // sidebar otherwise uses AppKit's fixed sidebar fonts, which ignore the text zoom.
    private func header(_ title: String) -> some View {
        Text(title).scaledFont(.subheadline, weight: .semibold)
    }

    private func row(_ item: SidebarItem, symbol: String, tint: Color) -> some View {
        let count = store.count(for: item)
        return HStack {
            Label {
                Text(item.title).scaledFont(.body)
            } icon: {
                // Not zoomed: the sidebar's icon column has a fixed width.
                Image(systemName: symbol).foregroundStyle(tint)
            }
            Spacer()
            // Like `.badge`, which hid zero counts.
            if count > 0 {
                Text("\(count)")
                    .scaledFont(.callout, monospacedDigit: true)
                    .foregroundStyle(.secondary)
            }
        }
        .tag(item)
    }
}
