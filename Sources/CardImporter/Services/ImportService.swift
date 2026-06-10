import Foundation

struct ImportService {
    private let hashService = FileHashService()
    private let pathBuilder = DestinationPathBuilder()

    func importItem(_ item: MediaItem, destinationRoot: URL, ledger: ImportLedger) async throws -> ImportRecord {
        let sourceHash = try hashService.sha256(for: item.url)
        let target = try pathBuilder.availableDestinationURL(for: item, destinationRoot: destinationRoot)
        let targetDirectory = target.url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let tempURL = targetDirectory.appendingPathComponent(".\(target.url.lastPathComponent).tmp-\(UUID().uuidString)")

        do {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try FileManager.default.removeItem(at: tempURL)
            }

            try FileManager.default.copyItem(at: item.url, to: tempURL)
            let copiedHash = try hashService.sha256(for: tempURL)

            guard sourceHash == copiedHash else {
                throw AppError.copyVerificationFailed(filename: item.filename)
            }

            if FileManager.default.fileExists(atPath: target.url.path) {
                try FileManager.default.removeItem(at: target.url)
            }
            try FileManager.default.moveItem(at: tempURL, to: target.url)

            let now = Date()
            let destinationVolumeUUID = try? destinationRoot.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
            let record = ImportRecord(
                id: nil,
                contentHash: sourceHash,
                byteCount: item.byteCount,
                originalFilename: item.filename,
                sourceVolumeUUID: item.sourceVolumeUUID,
                sourceRelativePath: item.relativePath,
                captureDate: item.captureDate,
                mediaKind: item.mediaKind,
                destinationPath: target.relativePath,
                destinationVolumeUUID: destinationVolumeUUID,
                importedAt: now,
                verifiedAt: now
            )

            try await ledger.insert(record)
            return record
        } catch {
            if FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            throw error
        }
    }
}
