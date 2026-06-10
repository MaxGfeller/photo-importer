import CryptoKit
import Foundation

struct FileHashService {
    func sha256(for url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()

        while true {
            let data = try handle.read(upToCount: 1_048_576)
            guard let data, !data.isEmpty else {
                break
            }
            hasher.update(data: data)
        }

        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }
}
