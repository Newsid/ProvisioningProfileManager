import Foundation

enum ProfileLoader {
    /// Parses every installed profile, merges duplicates by UUID and flags keychain identities.
    static func loadAll(directories: [URL] = ProfileLocator.existingDirectories) -> [ProvisioningProfile] {
        let identities = KeychainChecker.identityCertificates()
        var byID: [String: ProvisioningProfile] = [:]
        var order: [String] = []

        for url in ProfileLocator.profileFiles(in: directories) {
            var profile = ProfileParser.parse(fileAt: url)
            if var existing = byID[profile.id] {
                existing.fileURLs.append(url)
                byID[profile.id] = existing
                continue
            }
            profile.linkKeychain(identities: identities)
            byID[profile.id] = profile
            order.append(profile.id)
        }
        return order.compactMap { byID[$0] }
    }
}
