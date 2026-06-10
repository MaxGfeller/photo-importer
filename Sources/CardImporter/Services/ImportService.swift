import Foundation

struct ImportService {
    private let fingerprintService = FileFingerprintService()
    private let pathBuilder = DestinationPathBuilder()

    func importItem(_ item: MediaItem, destinationRoot: URL, ledger: ImportLedger) async throws -> ImportRecord {
        let sourceFingerprint = try fingerprintService.fingerprint(for: item.url, byteCount: item.byteCount)
        let target = try pathBuilder.availableDestinationURL(for: item, destinationRoot: destinationRoot)
        let targetDirectory = target.url.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: targetDirectory, withIntermediateDirectories: true)

        let tempURL = targetDirectory.appendingPathComponent(".\(target.url.lastPathComponent).tmp-\(UUID().uuidString)")
        var didCreateTemporaryCopy = false

        do {
            try FileManager.default.copyItem(at: item.url, to: tempURL)
            didCreateTemporaryCopy = true
            let copiedFingerprint = try fingerprintService.fingerprint(for: tempURL, byteCount: item.byteCount)

            guard sourceFingerprint == copiedFingerprint else {
                throw AppError.copyVerificationFailed(filename: item.filename)
            }

            if FileManager.default.fileExists(atPath: target.url.path) {
                throw CocoaError(.fileWriteFileExists)
            }
            try FileManager.default.moveItem(at: tempURL, to: target.url)
            didCreateTemporaryCopy = false

            let now = Date()
            let destinationVolumeUUID = try? destinationRoot.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
            let record = ImportRecord(
                id: nil,
                contentHash: sourceFingerprint,
                byteCount: item.byteCount,
                originalFilename: item.filename,
                sourceVolumeUUID: item.sourceVolumeUUID,
                sourceRelativePath: item.relativePath,
                captureDate: item.captureDate,
                mediaKind: item.mediaKind,
                destinationRootPath: destinationRoot.path,
                destinationPath: target.relativePath,
                destinationAbsolutePath: target.url.path,
                destinationVolumeUUID: destinationVolumeUUID,
                importedAt: now,
                verifiedAt: now
            )

            try await ledger.insert(record)
            return record
        } catch {
            // Only clean up the hidden temporary copy created by this import attempt.
            if didCreateTemporaryCopy, FileManager.default.fileExists(atPath: tempURL.path) {
                try? FileManager.default.removeItem(at: tempURL)
            }
            throw error
        }
    }
}
