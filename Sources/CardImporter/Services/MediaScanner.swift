import Foundation

struct MediaScanner {
    func scan(source: URL, excludedDirectoryNames: Set<String> = []) throws -> [MediaItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey,
            .isDirectoryKey,
            .fileSizeKey,
            .totalFileAllocatedSizeKey,
            .contentModificationDateKey,
            .creationDateKey,
            .typeIdentifierKey,
            .volumeUUIDStringKey
        ]

        guard let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return []
        }

        let sourceVolumeUUID = try? source.resourceValues(forKeys: [.volumeUUIDStringKey]).volumeUUIDString
        var items: [MediaItem] = []

        for case let url as URL in enumerator {
            let values = try url.resourceValues(forKeys: Set(keys))

            if values.isDirectory == true {
                if excludedDirectoryNames.contains(url.lastPathComponent) {
                    enumerator.skipDescendants()
                }
                continue
            }

            guard values.isRegularFile == true,
                  let kind = MediaTypeDetector.mediaKind(for: url, typeIdentifier: values.typeIdentifier) else {
                continue
            }

            let byteCount = Int64(values.fileSize ?? values.totalFileAllocatedSize ?? 0)
            let relativePath = PathUtilities.relativePath(for: url, root: source)
            let modificationDate = values.contentModificationDate
            let captureDate = MetadataReader.captureDate(for: url, mediaKind: kind) ?? values.creationDate ?? modificationDate
            let stableID = [
                sourceVolumeUUID ?? source.path,
                relativePath,
                String(byteCount),
                String(Int(modificationDate?.timeIntervalSince1970 ?? 0))
            ].joined(separator: "|")

            items.append(
                MediaItem(
                    id: stableID,
                    url: url,
                    relativePath: relativePath,
                    filename: url.lastPathComponent,
                    mediaKind: kind,
                    byteCount: byteCount,
                    modificationDate: modificationDate,
                    captureDate: captureDate,
                    sourceVolumeUUID: sourceVolumeUUID,
                    hash: nil,
                    status: .pending,
                    destinationPath: nil,
                    destinationAbsolutePath: nil,
                    errorMessage: nil
                )
            )
        }

        return items.sorted {
            let leftDate = $0.captureDate ?? $0.modificationDate ?? .distantPast
            let rightDate = $1.captureDate ?? $1.modificationDate ?? .distantPast

            if leftDate != rightDate {
                return leftDate < rightDate
            }
            return $0.relativePath.localizedStandardCompare($1.relativePath) == .orderedAscending
        }
    }
}
