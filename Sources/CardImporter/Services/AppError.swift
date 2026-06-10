import Foundation

enum AppError: LocalizedError {
    case missingSource
    case missingDestination
    case sqlite(String)
    case copyVerificationFailed(filename: String)
    case unsupportedMedia(URL)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .missingSource:
            "Choose an SD card or source folder first."
        case .missingDestination:
            "Choose a destination folder first."
        case .sqlite(let message):
            "Ledger error: \(message)"
        case .copyVerificationFailed(let filename):
            "Verification failed after copying \(filename). The destination copy was not recorded."
        case .unsupportedMedia(let url):
            "\(url.lastPathComponent) is not a supported photo or video file."
        case .cancelled:
            "The operation was cancelled."
        }
    }
}
