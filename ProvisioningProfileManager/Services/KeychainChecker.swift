import Foundation
import Security

enum KeychainChecker {
    /// SHA-1 fingerprints of the certificates of every signing identity in the keychain.
    static func identityFingerprints() -> Set<String> {
        Set(identityCertificates().map(\.sha1))
    }

    /// Certificates of every signing identity (certificate + private key) in the keychain.
    static func identityCertificates() -> [CertificateInfo] {
        let query: [String: Any] = [
            kSecClass as String: kSecClassIdentity,
            kSecMatchLimit as String: kSecMatchLimitAll,
            kSecReturnRef as String: true,
        ]
        var result: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let items = result as? [AnyObject]
        else { return [] }

        var certificates: [String: CertificateInfo] = [:]
        for item in items where CFGetTypeID(item) == SecIdentityGetTypeID() {
            let identity = item as! SecIdentity
            var certificate: SecCertificate?
            guard SecIdentityCopyCertificate(identity, &certificate) == errSecSuccess,
                  let certificate,
                  var info = CertificateParser.parse(SecCertificateCopyData(certificate) as Data)
            else { continue }
            info.hasPrivateKey = true
            certificates[info.sha1] = info
        }
        return Array(certificates.values)
    }
}
