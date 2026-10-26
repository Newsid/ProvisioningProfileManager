import Foundation

struct ProvisioningProfile: Identifiable, Hashable, Sendable {
    /// The profile UUID, or the file path for files that could not be parsed.
    let id: String
    /// The same UUID may be installed in more than one profiles folder.
    var fileURLs: [URL]
    var fileSize: Int64 = 0

    var name: String
    var uuid: String = ""
    var appIDName: String = ""
    /// Bundle identifier without the team prefix (may be a wildcard such as `com.foo.*`).
    var bundleID: String = ""
    var applicationIdentifier: String = ""
    var teamName: String = ""
    var teamIdentifiers: [String] = []
    var platforms: [String] = []
    var creationDate: Date?
    var expirationDate: Date?
    var isXcodeManaged = false
    var version: Int?
    var timeToLive: Int?
    var provisionedDevices: [String] = []
    var provisionsAllDevices = false
    var certificates: [CertificateInfo] = []
    /// Your valid signing certificates (same developer name as a certificate in the profile)
    /// that are installed in the keychain but not included in the profile.
    var keychainCertificatesNotInProfile: [CertificateInfo] = []
    var entitlements: [String: PlistValue] = [:]
    var rawPlist: String = ""
    var type: ProfileType = .unknown
    /// Set when the file could not be decoded.
    var parseError: String?

    static func invalid(url: URL, fileSize: Int64, error: String) -> ProvisioningProfile {
        ProvisioningProfile(
            id: url.path,
            fileURLs: [url],
            fileSize: fileSize,
            name: url.lastPathComponent,
            parseError: error
        )
    }
}

extension ProvisioningProfile {
    func profileStatus(now: Date, warningDays: Int) -> ExpirationStatus {
        ExpirationStatus.evaluate(expirationDate, now: now, warningDays: warningDays)
    }

    /// Certificates of this profile installed in the keychain with their private key.
    var installedCertificates: [CertificateInfo] { certificates.filter(\.hasPrivateKey) }

    /// Marks installed certificates and finds your valid certificates that the profile doesn't include.
    /// Certificates are related by their common name, e.g. "Apple Development: Jane Doe (ABCDE12345)".
    /// Certificates you don't have installed are never reported, whatever their expiration.
    mutating func linkKeychain(identities: [CertificateInfo], now: Date = Date()) {
        let fingerprints = Set(identities.map(\.sha1))
        for index in certificates.indices {
            certificates[index].hasPrivateKey = fingerprints.contains(certificates[index].sha1)
        }
        let profileFingerprints = Set(certificates.map(\.sha1))
        let profileNames = Set(certificates.map(\.commonName))
        keychainCertificatesNotInProfile = identities
            .filter { profileNames.contains($0.commonName) && !profileFingerprints.contains($0.sha1) }
            .filter { ($0.notAfter ?? .distantFuture) > now }
            .sorted { ($0.notAfter ?? .distantFuture) > ($1.notAfter ?? .distantFuture) }
    }

    func certificateSummary(now: Date, warningDays: Int) -> CertificateSummary {
        let installed = installedCertificates
        let newer = keychainCertificatesNotInProfile.filter { $0.status(now: now, warningDays: warningDays) != .expired }
        var summary = CertificateSummary(
            total: certificates.count,
            installed: installed.count,
            status: .missing,
            validCertificatesNotInProfile: newer.map(\.commonName)
        )
        guard let best = installed.max(by: { ($0.notAfter ?? .distantFuture) < ($1.notAfter ?? .distantFuture) }) else {
            return summary
        }
        summary.status = switch best.status(now: now, warningDays: warningDays) {
        case .valid: .valid
        case .expiringSoon: .expiringSoon
        case .expired: .expired
        }
        summary.expiration = best.notAfter
        return summary
    }

    func health(now: Date, warningDays: Int) -> ProfileHealth {
        if let parseError { return .invalid(reason: "Unreadable file: \(parseError)") }
        let status = profileStatus(now: now, warningDays: warningDays)
        if status == .expired { return .invalid(reason: "Profile expired") }
        let certificates = certificateSummary(now: now, warningDays: warningDays)
        switch certificates.status {
        case .missing:
            return .invalid(reason: certificates.validCertificatesNotInProfile.isEmpty
                ? "No installed certificate"
                : "Your installed certificate is not in this profile")
        case .expired: return .invalid(reason: "Installed certificate expired")
        case .expiringSoon: return .expiringSoon
        case .valid: return status == .expiringSoon ? .expiringSoon : .ok
        }
    }
}
