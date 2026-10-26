import SwiftUI

struct ProfileRowView: View {
    let profile: ProvisioningProfile

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            TypeIcon(type: profile.type)
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline) {
                    Text(profile.name)
                        .scaledFont(.headline)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 8)
                    TypeBadge(type: profile.type)
                }
                Text(profile.bundleID.isEmpty ? "—" : profile.bundleID)
                    .scaledFont(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                HStack(spacing: 8) {
                    if let date = profile.expirationDate {
                        Text("Expires \(date.formatted(date: .abbreviated, time: .omitted))")
                            .scaledFont(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    ExpirationBadges(profile: profile)
                }
            }
        }
        .padding(.vertical, 3)
    }
}
