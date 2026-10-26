import Foundation
@testable import ProvisioningProfileManager

let referenceNow = Date(timeIntervalSince1970: 1_800_000_000)

func days(_ count: Double) -> Date {
    referenceNow.addingTimeInterval(count * 86_400)
}

func makeCertificate(name: String = "Apple Development: Test", expires: Date?, installed: Bool = true) -> CertificateInfo {
    CertificateInfo(
        commonName: name,
        serialNumber: "01",
        sha1: UUID().uuidString,
        notBefore: days(-365),
        notAfter: expires,
        hasPrivateKey: installed
    )
}

extension CertificateInfo {
    func withSHA1(_ sha1: String) -> CertificateInfo {
        CertificateInfo(commonName: commonName, serialNumber: serialNumber, sha1: sha1,
                        notBefore: notBefore, notAfter: notAfter, hasPrivateKey: hasPrivateKey)
    }
}

func makeProfile(
    name: String,
    bundleID: String = "com.example.app",
    type: ProfileType = .development,
    expires: Date? = days(200),
    certificates: [CertificateInfo]? = nil,
    parseError: String? = nil
) -> ProvisioningProfile {
    var profile = ProvisioningProfile(
        id: UUID().uuidString,
        fileURLs: [URL(fileURLWithPath: "/tmp/\(name).mobileprovision")],
        name: name
    )
    profile.bundleID = bundleID
    profile.type = type
    profile.expirationDate = expires
    profile.certificates = certificates ?? [makeCertificate(expires: days(300))]
    profile.parseError = parseError
    return profile
}
