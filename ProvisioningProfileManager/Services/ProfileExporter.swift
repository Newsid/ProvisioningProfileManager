import Foundation

/// Copies installed profiles out of the profile folders, named after the profile instead of the
/// `<UUID>.<ext>` file name Xcode uses.
enum ProfileExporter {
    struct Result: Equatable, Sendable {
        var exportedURLs: [URL] = []
        var failures: [String] = []
    }

    struct ExportError: LocalizedError {
        let errorDescription: String?
    }

    /// Exports into `folder` as `<profile name>.<ext>`. Team profiles often share a name, so
    /// clashes (with each other or with files already in the folder) get " 2", " 3"… appended
    /// instead of overwriting anything.
    static func export(_ profiles: [ProvisioningProfile], into folder: URL) -> Result {
        var result = Result()
        var used = Set<String>()

        for profile in profiles {
            guard let source = profile.fileURLs.first else {
                result.failures.append("\(profile.name): the profile file is missing")
                continue
            }
            let base = fileName(for: profile)
            let ext = source.pathExtension
            var candidate = "\(base).\(ext)"
            var counter = 2
            // Lowercased because the default macOS file system is case-insensitive.
            while used.contains(candidate.lowercased())
                || FileManager.default.fileExists(atPath: folder.appending(path: candidate).path) {
                candidate = "\(base) \(counter).\(ext)"
                counter += 1
            }
            used.insert(candidate.lowercased())

            let target = folder.appending(path: candidate)
            do {
                try FileManager.default.copyItem(at: source, to: target)
                result.exportedURLs.append(target)
            } catch {
                result.failures.append("\(profile.name): \(error.localizedDescription)")
            }
        }
        return result
    }

    /// Copies one profile to an exact location chosen in a save panel, replacing an existing
    /// file there (the panel has already asked the user to confirm that).
    static func export(_ profile: ProvisioningProfile, to target: URL) throws {
        guard let source = profile.fileURLs.first else {
            throw ExportError(errorDescription: "The profile file is missing.")
        }
        if FileManager.default.fileExists(atPath: target.path) {
            try FileManager.default.removeItem(at: target)
        }
        try FileManager.default.copyItem(at: source, to: target)
    }

    /// The profile name made safe for a file name, or the UUID when the name is unusable.
    static func fileName(for profile: ProvisioningProfile) -> String {
        var name = profile.name
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        // A leading dot would make the exported file hidden in Finder.
        while name.hasPrefix(".") { name.removeFirst() }
        if !name.isEmpty { return name }
        return profile.uuid.isEmpty ? "Provisioning Profile" : profile.uuid
    }

    static func suggestedFileName(for profile: ProvisioningProfile) -> String {
        let ext = profile.fileURLs.first?.pathExtension ?? "mobileprovision"
        return "\(fileName(for: profile)).\(ext)"
    }
}
