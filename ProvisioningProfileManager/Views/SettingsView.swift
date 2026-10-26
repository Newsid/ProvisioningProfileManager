import SwiftUI

struct SettingsView: View {
    @Environment(ProfileStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Form {
            Section("Expiration") {
                Stepper(value: $store.warningDays, in: 1...365) {
                    LabeledContent("Warn before expiration", value: "\(store.warningDays) days")
                }
                Text("Profiles and certificates that expire within this many days are marked as expiring soon.")
                    .scaledFont(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("List") {
                Picker("Sort by", selection: $store.sortField) {
                    ForEach(SortField.allCases) { Text($0.title).tag($0) }
                }
                Picker("Order", selection: $store.sortAscending) {
                    Text("Ascending").tag(true)
                    Text("Descending").tag(false)
                }
                Toggle("Group by bundle ID", isOn: $store.groupByBundleID)
            }
            Section("Folders") {
                ForEach(ProfileLocator.directories, id: \.self) { url in
                    Text(url.path)
                        .scaledFont(.caption)
                        .textSelection(.enabled)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
        .fixedSize(horizontal: false, vertical: true)
    }
}
