import Foundation
import Security

enum CertificateParser {
    static func parse(_ der: Data) -> CertificateInfo? {
        guard let certificate = SecCertificateCreateWithData(nil, der as CFData) else { return nil }

        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)
        let name = (commonName as String?)
            ?? (SecCertificateCopySubjectSummary(certificate) as String?)
            ?? "Unknown certificate"

        let serial = (SecCertificateCopySerialNumberData(certificate, nil) as Data?)?.hexString(separator: ":") ?? ""

        let keys = [kSecOIDX509V1ValidityNotBefore, kSecOIDX509V1ValidityNotAfter] as CFArray
        let values = SecCertificateCopyValues(certificate, keys, nil) as? [String: Any]

        func date(for oid: CFString) -> Date? {
            guard let entry = values?[oid as String] as? [String: Any] else { return nil }
            switch entry[kSecPropertyKeyValue as String] {
            case let number as NSNumber: return Date(timeIntervalSinceReferenceDate: number.doubleValue)
            case let date as Date: return date
            default: return nil
            }
        }

        return CertificateInfo(
            commonName: name,
            serialNumber: serial,
            sha1: der.sha1Hex,
            notBefore: date(for: kSecOIDX509V1ValidityNotBefore),
            notAfter: date(for: kSecOIDX509V1ValidityNotAfter)
        )
    }
}
