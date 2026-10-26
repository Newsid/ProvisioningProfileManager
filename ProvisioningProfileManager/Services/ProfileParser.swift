import Foundation
import Security

enum ProfileParser {
    enum ParseError: LocalizedError {
        case unreadable(String)
        case noPlist
        case invalidPlist

        var errorDescription: String? {
            switch self {
            case .unreadable(let message): message
            case .noPlist: "No property list found in the file"
            case .invalidPlist: "The embedded property list is malformed"
            }
        }
    }

    /// Never throws: files that can't be decoded become invalid entries.
    static func parse(fileAt url: URL) -> ProvisioningProfile {
        let fileSize = Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)
        do {
            let data = try Data(contentsOf: url)
            let plistData = try extractPlist(from: data)
            return try profile(fromPlistData: plistData, url: url, fileSize: fileSize)
        } catch {
            return .invalid(url: url, fileSize: fileSize, error: error.localizedDescription)
        }
    }

    // MARK: - CMS envelope

    static func extractPlist(from data: Data) throws -> Data {
        if let decoded = decodeCMS(data) { return decoded }
        if let plist = scanForPlist(in: data) { return plist }
        throw ParseError.noPlist
    }

    /// Decodes the PKCS#7 (CMS) signed envelope and returns its content.
    static func decodeCMS(_ data: Data) -> Data? {
        var decoder: CMSDecoder?
        guard CMSDecoderCreate(&decoder) == errSecSuccess, let decoder else { return nil }
        let updateStatus = data.withUnsafeBytes { buffer -> OSStatus in
            guard let base = buffer.baseAddress else { return errSecParam }
            return CMSDecoderUpdateMessage(decoder, base, buffer.count)
        }
        guard updateStatus == errSecSuccess, CMSDecoderFinalizeMessage(decoder) == errSecSuccess else { return nil }
        var content: CFData?
        guard CMSDecoderCopyContent(decoder, &content) == errSecSuccess, let content else { return nil }
        return content as Data
    }

    /// Fallback: locate the XML plist embedded in the signed blob.
    static func scanForPlist(in data: Data) -> Data? {
        guard let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex)
        else { return nil }
        return data.subdata(in: start.lowerBound..<end.upperBound)
    }

    // MARK: - Plist mapping

    static func profile(fromPlistData plistData: Data, url: URL, fileSize: Int64) throws -> ProvisioningProfile {
        guard let dict = try PropertyListSerialization.propertyList(from: plistData, format: nil) as? [String: Any] else {
            throw ParseError.invalidPlist
        }
        let raw = String(data: plistData, encoding: .utf8)
            ?? (try? PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0))
                .flatMap { String(data: $0, encoding: .utf8) }
            ?? ""
        return profile(from: dict, url: url, fileSize: fileSize, rawPlist: raw)
    }

    static func profile(from dict: [String: Any], url: URL, fileSize: Int64, rawPlist: String) -> ProvisioningProfile {
        let entitlements = (dict["Entitlements"] as? [String: Any] ?? [:]).compactMapValues(PlistValue.init)
        let prefixes = dict["ApplicationIdentifierPrefix"] as? [String] ?? []
        let applicationIdentifier = entitlements["application-identifier"]?.stringValue
            ?? entitlements["com.apple.application-identifier"]?.stringValue
            ?? ""
        let certificates = (dict["DeveloperCertificates"] as? [Data] ?? []).compactMap(CertificateParser.parse)
        let devices = dict["ProvisionedDevices"] as? [String] ?? []
        let platforms = dict["Platform"] as? [String] ?? []
        let provisionsAllDevices = dict["ProvisionsAllDevices"] as? Bool ?? false
        let getTaskAllow = entitlements["get-task-allow"]?.boolValue
            ?? entitlements["com.apple.security.get-task-allow"]?.boolValue
            ?? false
        let uuid = dict["UUID"] as? String ?? ""

        return ProvisioningProfile(
            id: uuid.isEmpty ? url.path : uuid,
            fileURLs: [url],
            fileSize: fileSize,
            name: dict["Name"] as? String ?? url.deletingPathExtension().lastPathComponent,
            uuid: uuid,
            appIDName: dict["AppIDName"] as? String ?? "",
            bundleID: bundleID(fromApplicationIdentifier: applicationIdentifier, prefixes: prefixes),
            applicationIdentifier: applicationIdentifier,
            teamName: dict["TeamName"] as? String ?? "",
            teamIdentifiers: dict["TeamIdentifier"] as? [String] ?? [],
            platforms: platforms,
            creationDate: dict["CreationDate"] as? Date,
            expirationDate: dict["ExpirationDate"] as? Date,
            isXcodeManaged: dict["IsXcodeManaged"] as? Bool ?? false,
            version: dict["Version"] as? Int,
            timeToLive: dict["TimeToLive"] as? Int,
            provisionedDevices: devices,
            provisionsAllDevices: provisionsAllDevices,
            certificates: certificates,
            entitlements: entitlements,
            rawPlist: rawPlist,
            type: detectType(
                provisionsAllDevices: provisionsAllDevices,
                platforms: platforms,
                getTaskAllow: getTaskAllow,
                hasDevices: !devices.isEmpty,
                certificateNames: certificates.map(\.commonName)
            )
        )
    }

    /// `ABCDE12345.com.foo.bar` → `com.foo.bar`.
    static func bundleID(fromApplicationIdentifier identifier: String, prefixes: [String]) -> String {
        for prefix in prefixes where identifier.hasPrefix(prefix + ".") {
            return String(identifier.dropFirst(prefix.count + 1))
        }
        guard let dot = identifier.firstIndex(of: ".") else { return identifier }
        return String(identifier[identifier.index(after: dot)...])
    }

    static func detectType(
        provisionsAllDevices: Bool,
        platforms: [String],
        getTaskAllow: Bool,
        hasDevices: Bool,
        certificateNames: [String]
    ) -> ProfileType {
        let isMacOnly = !platforms.isEmpty && platforms.allSatisfy { $0 == "OSX" || $0 == "macOS" }
        if provisionsAllDevices { return isMacOnly ? .developerID : .enterprise }
        if getTaskAllow { return .development }
        if hasDevices {
            // macOS development profiles have devices but no get-task-allow.
            let developmentCertificate = certificateNames.contains {
                $0.contains("Development") || $0.contains("Developer:")
            }
            return developmentCertificate ? .development : .adHoc
        }
        return .appStore
    }
}
