import CryptoKit
import Foundation

extension Data {
    func hexString(separator: String = "") -> String {
        map { String(format: "%02X", $0) }.joined(separator: separator)
    }

    var sha1Hex: String {
        Insecure.SHA1.hash(data: self).map { String(format: "%02X", $0) }.joined()
    }
}
