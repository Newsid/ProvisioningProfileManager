import Foundation

enum ProfileDeleter {
    struct Failure: Sendable {
        let url: URL
        let message: String
    }

    /// Moves the files to the Trash so a deletion can be undone from Finder.
    static func trash(_ urls: [URL]) -> [Failure] {
        urls.compactMap { url in
            do {
                try FileManager.default.trashItem(at: url, resultingItemURL: nil)
                return nil
            } catch {
                return Failure(url: url, message: error.localizedDescription)
            }
        }
    }
}
