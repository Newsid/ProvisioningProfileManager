import SwiftUI

struct MultiSelectionView: View {
    @Environment(ProfileStore.self) private var store
    let profiles: [ProvisioningProfile]

    private let maxListed = 12

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.doc.fill")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("\(profiles.count) Profiles Selected")
                .scaledFont(.title2, weight: .semibold)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(profiles.prefix(maxListed)) { profile in
                    HStack(spacing: 6) {
                        Image(systemName: profile.type.symbol)
                            .foregroundStyle(profile.type.color)
                            .frame(width: 16)
                        Text(profile.name).lineLimit(1)
                    }
                }
                if profiles.count > maxListed {
                    Text("…and \(profiles.count - maxListed) more")
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: 360, alignment: .leading)

            HStack {
                Button("Show in Finder") { store.revealInFinder(Set(profiles.map(\.id))) }
                Button("Move \(profiles.count) Profiles to Trash…", role: .destructive) {
                    store.requestDelete(ids: Set(profiles.map(\.id)))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
