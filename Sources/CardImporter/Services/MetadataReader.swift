import Foundation
import ImageIO

enum MetadataReader {
    static func captureDate(for url: URL, mediaKind: MediaKind) -> Date? {
        guard mediaKind == .image || mediaKind == .rawImage else {
            return nil
        }

        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] else {
            return nil
        }

        if let exif = properties[kCGImagePropertyExifDictionary] as? [CFString: Any],
           let original = exif[kCGImagePropertyExifDateTimeOriginal] as? String,
           let date = exifDateFormatter.date(from: original) {
            return date
        }

        if let tiff = properties[kCGImagePropertyTIFFDictionary] as? [CFString: Any],
           let dateString = tiff[kCGImagePropertyTIFFDateTime] as? String,
           let date = exifDateFormatter.date(from: dateString) {
            return date
        }

        return nil
    }

    private static let exifDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        return formatter
    }()
}
