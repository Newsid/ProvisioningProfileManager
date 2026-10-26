import Foundation

enum ExpirationStatus: Int, Comparable, Sendable {
    case valid
    case expiringSoon
    case expired

    static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    /// A missing date is treated as valid (unknown expiration).
    static func evaluate(_ date: Date?, now: Date, warningDays: Int) -> ExpirationStatus {
        guard let date else { return .valid }
        if date <= now { return .expired }
        if date <= now.addingTimeInterval(Double(warningDays) * 86_400) { return .expiringSoon }
        return .valid
    }

    static func daysRemaining(until date: Date, now: Date) -> Int {
        max(0, Int((date.timeIntervalSince(now) / 86_400).rounded(.down)))
    }
}

/// State of the certificates of a profile that are installed on this Mac.
enum CertificateStatus: Equatable, Sendable {
    case valid
    case expiringSoon
    case expired
    /// None of the profile's certificates is installed (with its private key) in the keychain.
    case missing

    var isUsable: Bool { self == .valid || self == .expiringSoon }
}

/// Team profiles embed every member's certificate, so only the certificates installed in the
/// keychain (those you can sign with) are taken into account, using the best one.
struct CertificateSummary: Equatable, Sendable {
    /// Certificates embedded in the profile.
    var total = 0
    /// Certificates installed in the keychain together with their private key.
    var installed = 0
    var status: CertificateStatus = .missing
    /// Latest expiration among the installed certificates.
    var expiration: Date?
    /// Names of your valid keychain certificates that the profile doesn't include.
    var validCertificatesNotInProfile: [String] = []
}

enum ProfileHealth: Equatable, Sendable {
    case ok
    case expiringSoon
    case invalid(reason: String)

    var isInvalid: Bool {
        if case .invalid = self { return true }
        return false
    }
}
