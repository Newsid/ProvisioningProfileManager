import Foundation
import Testing
@testable import ProvisioningProfileManager

struct ProfileExporterTests {
    private let root: URL
    private let source: URL
    private let destination: URL

    init() throws {
        root = FileManager.default.temporaryDirectory.appending(path: "ExporterTests-\(UUID().uuidString)")
        source = root.appending(path: "source")
        destination = root.appending(path: "export")
        try FileManager.default.createDirectory(at: source, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
    }

    /// A profile backed by a `<UUID>.<ext>` file, as installed by Xcode.
    private func installedProfile(name: String, uuid: String, ext: String = "mobileprovision") throws -> ProvisioningProfile {
        let url = source.appending(path: "\(uuid).\(ext)")
        try Data(uuid.utf8).write(to: url)
        var profile = makeProfile(name: name)
        profile.uuid = uuid
        profile.fileURLs = [url]
        return profile
    }

    private func exportedNames(_ result: ProfileExporter.Result) -> [String] {
        result.exportedURLs.map(\.lastPathComponent)
    }

    @Test func namesFilesAfterTheProfileKeepingTheExtension() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let ios = try installedProfile(name: "My App Dev", uuid: "AAA-111")
        let mac = try installedProfile(name: "Mac App", uuid: "BBB-222", ext: "provisionprofile")

        let result = ProfileExporter.export([ios, mac], into: destination)

        #expect(exportedNames(result) == ["My App Dev.mobileprovision", "Mac App.provisionprofile"])
        #expect(result.failures.isEmpty)
        let copied = try Data(contentsOf: destination.appending(path: "My App Dev.mobileprovision"))
        #expect(String(decoding: copied, as: UTF8.self) == "AAA-111")
    }

    @Test func numbersProfilesSharingANameInsteadOfOverwriting() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let first = try installedProfile(name: "Test Widget App", uuid: "AAA-111")
        let second = try installedProfile(name: "Test Widget App", uuid: "BBB-222")
        let third = try installedProfile(name: "test widget app", uuid: "CCC-333")

        let result = ProfileExporter.export([first, second, third], into: destination)

        #expect(exportedNames(result) == [
            "Test Widget App.mobileprovision",
            "Test Widget App 2.mobileprovision",
            "test widget app 3.mobileprovision",
        ])
    }

    @Test func neverOverwritesFilesAlreadyInTheFolder() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        let existing = destination.appending(path: "My App.mobileprovision")
        try Data("keep me".utf8).write(to: existing)
        let profile = try installedProfile(name: "My App", uuid: "AAA-111")

        let result = ProfileExporter.export([profile], into: destination)

        #expect(exportedNames(result) == ["My App 2.mobileprovision"])
        #expect(try String(contentsOf: existing, encoding: .utf8) == "keep me")
    }

    @Test func reportsProfilesWithoutAFile() throws {
        defer { try? FileManager.default.removeItem(at: root) }
        var profile = makeProfile(name: "Ghost")
        profile.fileURLs = []

        let result = ProfileExporter.export([profile], into: destination)

        #expect(result.exportedURLs.isEmpty)
        #expect(result.failures.count == 1)
    }

    @Test func makesProfileNamesSafeForFileNames() {
        var profile = makeProfile(name: "  .Team: iOS/Mac  ")
        profile.uuid = "AAA-111"
        #expect(ProfileExporter.fileName(for: profile) == "Team- iOS-Mac")

        profile.name = "  "
        #expect(ProfileExporter.fileName(for: profile) == "AAA-111")
    }
}
