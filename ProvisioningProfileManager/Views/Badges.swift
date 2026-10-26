import SwiftUI

extension ProfileType {
    var color: Color {
        switch self {
        case .development: .blue
        case .adHoc: .purple
        case .appStore: .green
        case .enterprise: .brown
        case .developerID: .teal
        case .unknown: .gray
        }
    }
}

extension ExpirationStatus {
    var color: Color {
        switch self {
        case .valid: .green
        case .expiringSoon: .orange
        case .expired: .red
        }
    }
}

struct TypeBadge: View {
    let type: ProfileType

    var body: some View {
        Label(type.title, systemImage: type.symbol)
            .scaledFont(.caption, weight: .semibold)
            .labelStyle(.titleAndIcon)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(type.color)
            .background(type.color.opacity(0.15), in: Capsule())
            .accessibilityLabel("\(type.title) profile")
    }
}

struct TypeIcon: View {
    @Environment(\.fontScale) private var fontScale
    let type: ProfileType
    var size: CGFloat = 28

    var body: some View {
        // Grows with the text zoom so it stays balanced against the row text.
        let size = size * fontScale
        return Image(systemName: type.symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(type.color.gradient, in: RoundedRectangle(cornerRadius: size * 0.25))
            .accessibilityHidden(true)
    }
}

extension CertificateStatus {
    var color: Color {
        switch self {
        case .valid: .green
        case .expiringSoon: .orange
        case .expired, .missing: .red
        }
    }

    var symbol: String {
        switch self {
        case .valid: "checkmark.seal.fill"
        case .expiringSoon: "exclamationmark.triangle.fill"
        case .expired: "xmark.seal.fill"
        case .missing: "key.slash"
        }
    }
}

/// Profile alerts are filled capsules with a calendar icon; certificate alerts are outlined
/// capsules with a seal (expired / expiring) or crossed-out key (missing) icon.
struct ExpirationBadge: View {
    enum Kind { case profile, certificate }

    let kind: Kind
    let color: Color
    let symbol: String
    let text: String

    init(profileStatus status: ExpirationStatus, text: String) {
        kind = .profile
        color = status.color
        symbol = status == .expired ? "calendar.badge.exclamationmark" : "calendar.badge.clock"
        self.text = text
    }

    init(certificateStatus status: CertificateStatus, text: String) {
        kind = .certificate
        color = status.color
        symbol = status.symbol
        self.text = text
    }

    var body: some View {
        Label(text, systemImage: symbol)
            .scaledFont(.caption, weight: .medium)
            .lineLimit(1)
            .padding(.horizontal, 7)
            .padding(.vertical, 2)
            .foregroundStyle(color)
            .background {
                switch kind {
                case .profile:
                    Capsule().fill(color.opacity(0.15))
                case .certificate:
                    Capsule().strokeBorder(color.opacity(0.8), style: StrokeStyle(lineWidth: 1, dash: [3, 2]))
                }
            }
    }
}

enum StatusText {
    static func relativeDays(_ days: Int) -> String {
        switch days {
        case 0: "today"
        case 1: "tomorrow"
        default: "in \(days) days"
        }
    }

    static func profile(_ profile: ProvisioningProfile, status: ExpirationStatus, now: Date) -> String? {
        switch status {
        case .valid: return nil
        case .expired: return "Profile expired"
        case .expiringSoon:
            guard let date = profile.expirationDate else { return nil }
            return "Profile expires \(relativeDays(ExpirationStatus.daysRemaining(until: date, now: now)))"
        }
    }

    static func certificates(_ summary: CertificateSummary, now: Date) -> String? {
        switch summary.status {
        case .valid:
            return nil
        case .missing:
            return summary.validCertificatesNotInProfile.isEmpty
                ? "Certificate not installed"
                : "Installed certificate not in profile"
        case .expired:
            return "Certificate expired"
        case .expiringSoon:
            guard let date = summary.expiration else { return nil }
            return "Certificate expires \(relativeDays(ExpirationStatus.daysRemaining(until: date, now: now)))"
        }
    }

    static func certificateExplanation(_ summary: CertificateSummary) -> String {
        let regenerate = "Regenerate the profile (or let Xcode manage it) so that it includes your current certificate."
        switch summary.status {
        case .missing:
            if summary.total == 0 { return "The profile contains no certificates." }
            if !summary.validCertificatesNotInProfile.isEmpty {
                return "You have a valid certificate installed for \(Set(summary.validCertificatesNotInProfile).sorted().joined(separator: ", ")), but this profile was generated with a different one, so you can't sign with it on this Mac. \(regenerate)"
            }
            return "You don't have any certificate for this profile installed in your keychain (with its private key), so you can't sign with it on this Mac."
        case .expired:
            if !summary.validCertificatesNotInProfile.isEmpty {
                return "The certificate this profile uses has expired. You have a newer valid certificate installed, but the profile doesn't include it. \(regenerate)"
            }
            return "The certificate installed in your keychain for this profile has expired. Renew it in Xcode or the Apple Developer portal, then regenerate the profile."
        case .expiringSoon:
            return "The certificate installed in your keychain for this profile expires soon."
        case .valid:
            return "A valid certificate for this profile is installed in your keychain."
        }
    }
}

/// The profile and certificate badges for one profile.
struct ExpirationBadges: View {
    @Environment(ProfileStore.self) private var store
    let profile: ProvisioningProfile

    var body: some View {
        let now = Date()
        let profileStatus = profile.profileStatus(now: now, warningDays: store.warningDays)
        let certificates = profile.certificateSummary(now: now, warningDays: store.warningDays)

        HStack(spacing: 6) {
            if profile.parseError != nil {
                ExpirationBadge(profileStatus: .expired, text: "Unreadable")
            } else {
                if let text = StatusText.profile(profile, status: profileStatus, now: now) {
                    ExpirationBadge(profileStatus: profileStatus, text: text)
                        .help("Profile expiration: \(profile.expirationDate?.formatted(date: .long, time: .shortened) ?? "—")")
                }
                if let text = StatusText.certificates(certificates, now: now) {
                    ExpirationBadge(certificateStatus: certificates.status, text: text)
                        .help(certificateTooltip(certificates))
                }
            }
        }
    }

    private func certificateTooltip(_ summary: CertificateSummary) -> String {
        let installed = profile.installedCertificates
            .map { "\($0.commonName): expires \($0.notAfter?.formatted(date: .long, time: .omitted) ?? "—")" }
        return ([StatusText.certificateExplanation(summary)] + installed).joined(separator: "\n")
    }
}
