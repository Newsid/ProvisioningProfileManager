import Foundation
import Testing
@testable import ProvisioningProfileManager

struct ProfileParserTests {
    private let url = URL(fileURLWithPath: "/tmp/test.mobileprovision")

    private func plist(
        entitlements: [String: Any],
        devices: [String]? = nil,
        allDevices: Bool? = nil,
        platforms: [String] = ["iOS"]
    ) -> [String: Any] {
        var dict: [String: Any] = [
            "Name": "Test Profile",
            "UUID": "1234-ABCD",
            "AppIDName": "Test App",
            "TeamName": "Test Team",
            "TeamIdentifier": ["TEAM123456"],
            "ApplicationIdentifierPrefix": ["TEAM123456"],
            "Platform": platforms,
            "CreationDate": days(-10),
            "ExpirationDate": days(355),
            "Entitlements": entitlements,
        ]
        if let devices { dict["ProvisionedDevices"] = devices }
        if let allDevices { dict["ProvisionsAllDevices"] = allDevices }
        return dict
    }

    @Test func mapsBasicFields() {
        let dict = plist(entitlements: [
            "application-identifier": "TEAM123456.com.example.app",
            "get-task-allow": true,
            "aps-environment": "development",
        ], devices: ["udid-1", "udid-2"])
        let profile = ProfileParser.profile(from: dict, url: url, fileSize: 42, rawPlist: "")

        #expect(profile.id == "1234-ABCD")
        #expect(profile.name == "Test Profile")
        #expect(profile.bundleID == "com.example.app")
        #expect(profile.teamName == "Test Team")
        #expect(profile.provisionedDevices.count == 2)
        #expect(profile.expirationDate == days(355))
        #expect(profile.entitlements["aps-environment"] == .string("development"))
        #expect(profile.type == .development)
    }

    @Test func detectsAdHoc() {
        let dict = plist(entitlements: ["application-identifier": "TEAM123456.com.example.app", "get-task-allow": false],
                         devices: ["udid-1"])
        #expect(ProfileParser.profile(from: dict, url: url, fileSize: 0, rawPlist: "").type == .adHoc)
    }

    @Test func detectsAppStore() {
        let dict = plist(entitlements: ["application-identifier": "TEAM123456.com.example.app", "get-task-allow": false])
        #expect(ProfileParser.profile(from: dict, url: url, fileSize: 0, rawPlist: "").type == .appStore)
    }

    @Test func detectsEnterprise() {
        let dict = plist(entitlements: ["application-identifier": "TEAM123456.com.example.app", "get-task-allow": false],
                         allDevices: true)
        #expect(ProfileParser.profile(from: dict, url: url, fileSize: 0, rawPlist: "").type == .enterprise)
    }

    @Test func detectsDeveloperIDOnMac() {
        let dict = plist(entitlements: ["com.apple.application-identifier": "TEAM123456.com.example.mac"],
                         allDevices: true, platforms: ["OSX"])
        let profile = ProfileParser.profile(from: dict, url: url, fileSize: 0, rawPlist: "")
        #expect(profile.type == .developerID)
        #expect(profile.bundleID == "com.example.mac")
    }

    @Test func detectsMacDevelopmentFromCertificateName() {
        let type = ProfileParser.detectType(
            provisionsAllDevices: false, platforms: ["OSX"], getTaskAllow: false,
            hasDevices: true, certificateNames: ["Apple Development: Jane Doe (ABC)"]
        )
        #expect(type == .development)
    }

    @Test(arguments: [
        ("TEAM123456.com.example.app", ["TEAM123456"], "com.example.app"),
        ("TEAM123456.*", ["TEAM123456"], "*"),
        ("OTHER.com.example.app", ["TEAM123456"], "com.example.app"),
        ("noprefix", [String](), "noprefix"),
    ])
    func stripsTeamPrefix(identifier: String, prefixes: [String], expected: String) {
        #expect(ProfileParser.bundleID(fromApplicationIdentifier: identifier, prefixes: prefixes) == expected)
    }

    @Test func scansPlistOutOfSignedBlob() throws {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <plist version="1.0"><dict><key>Name</key><string>Embedded</string></dict></plist>
        """
        var blob = Data([0x30, 0x82, 0x01, 0x02, 0xFF])
        blob.append(Data(xml.utf8))
        blob.append(Data([0x00, 0xA0, 0x82]))

        let extracted = try #require(ProfileParser.scanForPlist(in: blob))
        let dict = try PropertyListSerialization.propertyList(from: extracted, format: nil) as? [String: Any]
        #expect(dict?["Name"] as? String == "Embedded")
    }

    @Test func garbageFileBecomesInvalidEntry() throws {
        let file = FileManager.default.temporaryDirectory.appending(path: "\(UUID().uuidString).mobileprovision")
        try Data("not a profile".utf8).write(to: file)
        defer { try? FileManager.default.removeItem(at: file) }

        let profile = ProfileParser.parse(fileAt: file)
        #expect(profile.parseError != nil)
        #expect(profile.id == file.path)
        #expect(profile.health(now: referenceNow, warningDays: 30).isInvalid)
    }

    @Test func plistValueDistinguishesBoolFromNumber() {
        #expect(PlistValue(NSNumber(value: true)) == .bool(true))
        #expect(PlistValue(NSNumber(value: 1)) == .integer(1))
        #expect(PlistValue(NSNumber(value: 1.5)) == .real(1.5))
    }

    @Test func classifiesCapabilities() {
        let result = CapabilityCatalog.classify([
            "application-identifier": .string("T.com.x"),
            "aps-environment": .string("production"),
            "com.apple.security.application-groups": .array([.string("group.x")]),
            "com.apple.developer.icloud-services": .array([.string("CloudKit")]),
            "com.apple.developer.icloud-container-identifiers": .array([.string("iCloud.x")]),
            "com.example.custom": .bool(true),
        ])
        #expect(result.capabilities.map(\.name) == ["App Groups", "iCloud", "Push Notifications"])
        #expect(result.capabilities.first { $0.name == "iCloud" }?.entries.count == 2)
        #expect(result.base.map(\.key) == ["application-identifier"])
        #expect(result.other.map(\.key) == ["com.example.custom"])
    }
}
