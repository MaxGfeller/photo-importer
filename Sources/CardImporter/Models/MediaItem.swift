import Foundation

struct MediaItem: Identifiable, Hashable {
    let id: String
    let url: URL
    let relativePath: String
    let filename: String
    let mediaKind: MediaKind
    let byteCount: Int64
    let modificationDate: Date?
    let captureDate: Date?
    let sourceVolumeUUID: String?
    var hash: String?
    var status: ImportStatus
    var destinationPath: String?
    var errorMessage: String?

    var isSelectableForImport: Bool {
        status == .pending || status == .failed || status == .importedMissing || status == .conflict
    }
}
