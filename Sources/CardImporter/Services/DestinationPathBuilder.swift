import Foundation

struct DestinationPathBuilder {
    func preferredRelativePath(for item: MediaItem) -> String {
        item.filename
    }

    func availableDestinationURL(for item: MediaItem, destinationRoot: URL) throws -> (url: URL, relativePath: String) {
        let relativePath = item.destinationPath ?? preferredRelativePath(for: item)
        let preferredURL = PathUtilities.url(forRelativePath: relativePath, root: destinationRoot)

        if !FileManager.default.fileExists(atPath: preferredURL.path) {
            return (preferredURL, relativePath)
        }

        let directory = preferredURL.deletingLastPathComponent()
        let baseName = preferredURL.deletingPathExtension().lastPathComponent
        let pathExtension = preferredURL.pathExtension

        for index in 2...999 {
            let filename: String
            if pathExtension.isEmpty {
                filename = "\(baseName)-\(index)"
            } else {
                filename = "\(baseName)-\(index).\(pathExtension)"
            }

            let candidateURL = directory.appendingPathComponent(filename)
            if !FileManager.default.fileExists(atPath: candidateURL.path) {
                return (candidateURL, PathUtilities.relativePath(for: candidateURL, root: destinationRoot))
            }
        }

        throw CocoaError(.fileWriteFileExists)
    }
}
