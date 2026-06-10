import Foundation

enum PathUtilities {
    static func relativePath(for url: URL, root: URL) -> String {
        let rootPath = root.standardizedFileURL.path
        let filePath = url.standardizedFileURL.path

        guard filePath.hasPrefix(rootPath) else {
            return url.lastPathComponent
        }

        let start = filePath.index(filePath.startIndex, offsetBy: rootPath.count)
        var relative = String(filePath[start...])
        if relative.hasPrefix("/") {
            relative.removeFirst()
        }
        return relative.isEmpty ? url.lastPathComponent : relative
    }

    static func url(forRelativePath relativePath: String, root: URL) -> URL {
        relativePath
            .split(separator: "/")
            .reduce(root) { partialResult, component in
                partialResult.appendingPathComponent(String(component), isDirectory: false)
            }
    }
}
