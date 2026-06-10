import Foundation

enum BookmarkStore {
    private static let sourceKey = "sourceBookmark"
    private static let destinationKey = "destinationBookmark"

    static func saveSource(_ url: URL) {
        save(url, key: sourceKey)
    }

    static func saveDestination(_ url: URL) {
        save(url, key: destinationKey)
    }

    static func resolveSource() -> URL? {
        resolve(key: sourceKey)
    }

    static func resolveDestination() -> URL? {
        resolve(key: destinationKey)
    }

    static func withSecurityScopedAccess<T>(to url: URL, _ work: () throws -> T) rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try work()
    }

    static func withSecurityScopedAccess<T>(to url: URL, _ work: () async throws -> T) async rethrows -> T {
        let didStart = url.startAccessingSecurityScopedResource()
        defer {
            if didStart {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try await work()
    }

    private static func save(_ url: URL, key: String) {
        do {
            let data = try url.bookmarkData(options: [.withSecurityScope], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            UserDefaults.standard.set(url.path, forKey: "\(key).path")
        }
    }

    private static func resolve(key: String) -> URL? {
        if let data = UserDefaults.standard.data(forKey: key) {
            var isStale = false
            if let url = try? URL(resolvingBookmarkData: data, options: [.withSecurityScope], relativeTo: nil, bookmarkDataIsStale: &isStale) {
                if isStale {
                    save(url, key: key)
                }
                return url
            }
        }

        if let path = UserDefaults.standard.string(forKey: "\(key).path") {
            return URL(fileURLWithPath: path)
        }

        return nil
    }
}
