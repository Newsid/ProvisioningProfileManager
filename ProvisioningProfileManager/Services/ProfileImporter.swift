import Foundation

enum ProfileImporter {
    struct Result: Equatable, Sendable {
        var importedIDs: [String] = []
        var importedNames: [String] = []
        var alreadyInstalled: [String] = []
        var failures: [String] = []

        var hasIssues: Bool { !alreadyInstalled.isEmpty || !failures.isEmpty }
    }

    /// Copies valid profiles into `destination` as `<UUID>.<extension>`, the naming Xcode uses.
    /// Folders are searched recursively for profile files.
    static func importProfiles(
        from urls: [URL],
        into destination: URL = ProfileLocator.importDirectory,
        existingIDs: Set<String>
    ) -> Result {
        var result = Result()
        var knownIDs = existingIDs

        for url in expand(urls) {
            let fileName = url.lastPathComponent
            guard ProfileLocator.fileExtensions.contains(url.pathExtension.lowercased()) else {
                result.failures.append("\(fileName): not a provisioning profile")
                continue
            }
            let profile = ProfileParser.parse(fileAt: url)
            if let error = profile.parseError {
                result.failures.append("\(fileName): \(error)")
                continue
            }
            guard !profile.uuid.isEmpty else {
                result.failures.append("\(fileName): the profile has no UUID")
                continue
            }
            let target = destination.appending(path: "\(profile.uuid).\(url.pathExtension.lowercased())")
            if knownIDs.contains(profile.uuid) || FileManager.default.fileExists(atPath: target.path) {
                result.alreadyInstalled.append(profile.name)
                continue
            }
            do {
                try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
                try FileManager.default.copyItem(at: url, to: target)
                knownIDs.insert(profile.uuid)
                result.importedIDs.append(profile.uuid)
                result.importedNames.append(profile.name)
            } catch {
                result.failures.append("\(fileName): \(error.localizedDescription)")
            }
        }
        return result
    }

    static func expand(_ urls: [URL]) -> [URL] {
        urls.flatMap { url -> [URL] in
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue else {
                return [url]
            }
            let enumerator = FileManager.default.enumerator(
                at: url, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles, .skipsPackageDescendants]
            )
            return (enumerator?.allObjects as? [URL] ?? [])
                .filter { ProfileLocator.fileExtensions.contains($0.pathExtension.lowercased()) }
                .sorted { $0.path < $1.path }
        }
    }
}
