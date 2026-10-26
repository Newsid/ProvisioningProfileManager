import Foundation
import Testing
@testable import ProvisioningProfileManager

struct ProfileImporterTests {
    private let root: URL
    private let source: URL
    private let destination: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ImporterTests-\(UUID().uuidString)")
        source = root.appending(path: "source")
        destination = root.appending(path: "Provisioning Profiles")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
    }

    /// An unsigned XML plist is enough: the parser falls back to scanning for the plist.
    @discardableResult
    private func writeProfile(uuid: String, name: String, file: String, in folder: URL? = nil) throws -> URL {
        let folder = folder ?? source
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let dict: [String: Any] = [
            "Name": name,
            "UUID": uuid,
            "ExpirationDate": Date().addingTimeInterval(86_400 * 100),
            "Entitlements": ["application-identifier": "TEAM.com.example.\(name)", "get-task-allow": true],
        ]
        let url = folder.appending(path: file)
        try PropertyListSerialization.data(fromPropertyList: dict, format: .xml, options: 0).write(to: url)
        return url
    }

    @Test func copiesValidProfilesNamedByUUID() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let file = try writeProfile(uuid: "AAA-111", name: "one", file: "Downloaded Profile.mobileprovision")

        let result = ProfileImporter.importProfiles(from: [file], into: destination, existingIDs: [])

        #expect(result.importedIDs == ["AAA-111"])
        #expect(result.importedNames == ["one"])
        #expect(!result.hasIssues)
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "AAA-111.mobileprovision").path))
        #expect(FileManager.default.fileExists(atPath: file.path), "the source file is copied, not moved")
    }

    @Test func skipsAlreadyInstalledProfiles() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let installed = try writeProfile(uuid: "AAA-111", name: "installed", file: "a.mobileprovision")
        let duplicate = try writeProfile(uuid: "BBB-222", name: "dup", file: "b.mobileprovision")
        let duplicateCopy = try writeProfile(uuid: "BBB-222", name: "dup", file: "b copy.mobileprovision")

        let result = ProfileImporter.importProfiles(
            from: [installed, duplicate, duplicateCopy], into: destination, existingIDs: ["AAA-111"]
        )

        #expect(result.importedIDs == ["BBB-222"])
        #expect(result.alreadyInstalled == ["installed", "dup"])
    }

    @Test func reportsInvalidFiles() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let garbage = source.appending(path: "broken.mobileprovision")
        try Data("garbage".utf8).write(to: garbage)
        let wrongType = source.appending(path: "notes.txt")
        try Data("hello".utf8).write(to: wrongType)

        let result = ProfileImporter.importProfiles(from: [garbage, wrongType], into: destination, existingIDs: [])

        #expect(result.importedIDs.isEmpty)
        #expect(result.failures.count == 2)
        #expect(result.failures[1] == "notes.txt: not a provisioning profile")
        #expect(!FileManager.default.fileExists(atPath: destination.path), "nothing is created on failure")
    }

    @Test func importsProfilesInsideFolders() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let folder = source.appending(path: "profiles")
        try writeProfile(uuid: "CCC-333", name: "ios", file: "ios.mobileprovision", in: folder)
        try writeProfile(uuid: "DDD-444", name: "mac", file: "mac.provisionprofile", in: folder.appending(path: "nested"))
        try Data("x".utf8).write(to: folder.appending(path: "readme.txt"))

        let result = ProfileImporter.importProfiles(from: [folder], into: destination, existingIDs: [])

        #expect(Set(result.importedIDs) == ["CCC-333", "DDD-444"])
        #expect(result.failures.isEmpty)
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "DDD-444.provisionprofile").path))
    }
}
