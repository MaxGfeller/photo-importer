import Foundation

struct ImportRecord: Identifiable, Hashable {
    var id: Int64?
    let contentHash: String
    let byteCount: Int64
    let originalFilename: String
    let sourceVolumeUUID: String?
    let sourceRelativePath: String
    let captureDate: Date?
    let mediaKind: MediaKind
    let destinationRootPath: String?
    let destinationPath: String
    let destinationAbsolutePath: String?
    let destinationVolumeUUID: String?
    let importedAt: Date
    let verifiedAt: Date
}
