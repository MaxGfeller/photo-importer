import AppKit
import Foundation
import QuickLookThumbnailing

final class ThumbnailService {
    static let shared = ThumbnailService()

    private let cache = NSCache<NSString, NSImage>()

    private init() {
        cache.countLimit = 700
    }

    func thumbnail(for url: URL, size: CGSize) async -> NSImage {
        let key = "\(url.path)|\(Int(size.width))x\(Int(size.height))" as NSString

        if let cached = cache.object(forKey: key) {
            return cached
        }

        let scale = NSScreen.main?.backingScaleFactor ?? 2
        let request = QLThumbnailGenerator.Request(
            fileAt: url,
            size: size,
            scale: scale,
            representationTypes: [.thumbnail, .icon]
        )

        do {
            let image = try await withCheckedThrowingContinuation { continuation in
                QLThumbnailGenerator.shared.generateBestRepresentation(for: request) { representation, error in
                    if let representation {
                        continuation.resume(returning: representation.nsImage)
                    } else if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume(returning: NSWorkspace.shared.icon(forFile: url.path))
                    }
                }
            }

            cache.setObject(image, forKey: key)
            return image
        } catch {
            let image = NSWorkspace.shared.icon(forFile: url.path)
            cache.setObject(image, forKey: key)
            return image
        }
    }
}
