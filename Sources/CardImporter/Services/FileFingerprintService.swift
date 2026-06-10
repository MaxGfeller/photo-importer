import CryptoKit
import Foundation

struct FileFingerprintService {
    static let version = "sample-v1"
    static let sampleSize = 256 * 1024

    func fingerprint(for url: URL, byteCount knownByteCount: Int64? = nil) throws -> String {
        let byteCount = try knownByteCount ?? fileSize(for: url)
        let handle = try FileHandle(forReadingFrom: url)
        defer {
            try? handle.close()
        }

        var hasher = SHA256()
        hasher.update(data: Data("\(Self.version)|\(byteCount)|\(Self.sampleSize)|".utf8))

        for offset in sampleOffsets(byteCount: byteCount) {
            try handle.seek(toOffset: UInt64(offset))
            let data = try handle.read(upToCount: Self.sampleSize) ?? Data()
            hasher.update(data: Data("\(offset):\(data.count)|".utf8))
            hasher.update(data: data)
        }

        let digest = hasher.finalize().map { String(format: "%02x", $0) }.joined()
        return "\(Self.version):\(digest)"
    }

    private func sampleOffsets(byteCount: Int64) -> [Int64] {
        guard byteCount > Int64(Self.sampleSize) else {
            return [0]
        }

        let lastOffset = max(0, byteCount - Int64(Self.sampleSize))
        let middleOffset = max(0, (byteCount / 2) - Int64(Self.sampleSize / 2))
        return Array(Set([0, middleOffset, lastOffset])).sorted()
    }

    private func fileSize(for url: URL) throws -> Int64 {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .totalFileAllocatedSizeKey])
        return Int64(values.fileSize ?? values.totalFileAllocatedSize ?? 0)
    }
}
