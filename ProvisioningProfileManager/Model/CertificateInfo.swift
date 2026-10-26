import Foundation

struct CertificateInfo: Identifiable, Hashable, Sendable {
    var id: String { sha1 }

    let commonName: String
    let serialNumber: String
    let sha1: String
    let notBefore: Date?
    let notAfter: Date?
    /// True when a matching signing identity (certificate + private key) is in the keychain.
    var hasPrivateKey = false

    func status(now: Date, warningDays: Int) -> ExpirationStatus {
        ExpirationStatus.evaluate(notAfter, now: now, warningDays: warningDays)
    }
}
