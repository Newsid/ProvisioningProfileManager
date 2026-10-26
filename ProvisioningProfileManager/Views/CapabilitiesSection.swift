import SwiftUI

struct CapabilitiesSection: View {
    let entitlements: [String: PlistValue]

    var body: some View {
        let classification = CapabilityCatalog.classify(entitlements)

        Section("Capabilities (\(classification.capabilities.count))") {
            if classification.capabilities.isEmpty {
                Text("No additional capabilities.")
                    .foregroundStyle(.secondary)
            }
            ForEach(classification.capabilities) { capability in
                VStack(alignment: .leading, spacing: 4) {
                    Label(capability.name, systemImage: capability.symbol)
                        .scaledFont(.headline)
                    ForEach(capability.entries) { entry in
                        EntitlementValueView(entry: entry)
                    }
                }
                .padding(.vertical, 2)
            }
        }

        Section("Entitlements") {
            ForEach(classification.base) { entry in
                EntitlementValueView(entry: entry)
            }
            if !classification.other.isEmpty {
                DisclosureGroup("Other entitlements (\(classification.other.count))") {
                    ForEach(classification.other) { entry in
                        EntitlementValueView(entry: entry)
                    }
                }
            }
        }
    }
}

private struct EntitlementValueView: View {
    let entry: CapabilityGroup.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(entry.key)
                .scaledFont(.caption)
                .foregroundStyle(.secondary)
            Text(entry.value.displayString)
                .scaledFont(.callout, design: .monospaced)
                .textSelection(.enabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
