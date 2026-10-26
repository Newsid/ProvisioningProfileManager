import Foundation

enum ProfileLocator {
    static let fileExtensions: Set<String> = ["mobileprovision", "provisionprofile"]

    /// Xcode 16+ folder first, then the legacy one.
    static var directories: [URL] {
        let library = FileManager.default.homeDirectoryForCurrentUser.appending(path: "Library", directoryHint: .isDirectory)
        return [
            library.appending(path: "Developer/Xcode/UserData/Provisioning Profiles", directoryHint: .isDirectory),
            library.appending(path: "MobileDevice/Provisioning Profiles", directoryHint: .isDirectory),
        ]
    }

    /// Where imported profiles are copied (the folder current Xcode versions read).
    static var importDirectory: URL { directories[0] }

    static var existingDirectories: [URL] {
        directories.filter { FileManager.default.fileExists(atPath: $0.path) }
    }

    static func profileFiles(in directories: [URL] = existingDirectories) -> [URL] {
        directories.flatMap { directory -> [URL] in
            let contents = (try? FileManager.default.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.fileSizeKey],
                options: [.skipsHiddenFiles]
            )) ?? []
            return contents.filter { fileExtensions.contains($0.pathExtension.lowercased()) }
        }
    }
}
