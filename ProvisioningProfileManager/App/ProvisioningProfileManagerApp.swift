import SwiftUI

@main
struct ProvisioningProfileManagerApp: App {
    @State private var store = ProfileStore()

    var body: some Scene {
        Window("Provisioning Profiles", id: "main") {
            RootView()
                .environment(store)
                .environment(\.fontScale, store.fontScale)
                .frame(minWidth: 960, minHeight: 560)
        }
        .commands {
            CommandGroup(after: .newItem) {
                Button("Import Profiles…") { store.isImporting = true }
                    .keyboardShortcut("o")
                Button("Export…") { store.exportProfiles(ids: store.selection) }
                    .keyboardShortcut("e")
                    .disabled(store.selection.isEmpty)
                Divider()
                Button("Refresh") { store.reload() }
                    .keyboardShortcut("r")
                Button("Show in Finder") { store.revealInFinder(store.selection) }
                    .keyboardShortcut("r", modifiers: [.command, .shift])
                    .disabled(store.selection.isEmpty)
            }
            CommandGroup(after: .toolbar) {
                Divider()
                Button("Actual Size") { store.resetZoom() }
                    .keyboardShortcut("0")
                    .disabled(store.fontScale == 1)
                Button("Zoom In") { store.zoomIn() }
                    .keyboardShortcut("+")
                    .disabled(!store.canZoomIn)
                Button("Zoom Out") { store.zoomOut() }
                    .keyboardShortcut("-")
                    .disabled(!store.canZoomOut)
            }
        }

        Settings {
            SettingsView()
                .environment(store)
                .environment(\.fontScale, store.fontScale)
        }
    }
}
