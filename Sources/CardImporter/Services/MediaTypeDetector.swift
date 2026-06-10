import Foundation
import UniformTypeIdentifiers

enum MediaTypeDetector {
    static func mediaKind(for url: URL, typeIdentifier: String? = nil) -> MediaKind? {
        let type: UTType?

        if let typeIdentifier, let detected = UTType(typeIdentifier) {
            type = detected
        } else {
            type = UTType(filenameExtension: url.pathExtension.lowercased())
        }

        guard let type else {
            return fallbackKind(forExtension: url.pathExtension)
        }

        if type.conforms(to: .movie) || type.conforms(to: .video) {
            return .video
        }

        if type.conforms(to: .rawImage) {
            return .rawImage
        }

        if type.conforms(to: .image) {
            return .image
        }

        return fallbackKind(forExtension: url.pathExtension)
    }

    private static func fallbackKind(forExtension fileExtension: String) -> MediaKind? {
        switch fileExtension.lowercased() {
        case "jpg", "jpeg", "heic", "heif", "png", "tif", "tiff":
            .image
        case "cr2", "cr3", "nef", "nrw", "arw", "srf", "sr2", "raf", "rw2", "orf", "dng", "pef", "3fr", "fff", "iiq":
            .rawImage
        case "mov", "mp4", "m4v", "avi", "mts", "m2ts", "mpg", "mpeg":
            .video
        default:
            nil
        }
    }
}
