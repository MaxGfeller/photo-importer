import Foundation

enum ImportStatus: String, Codable, CaseIterable, Equatable {
    case pending
    case imported
    case importedMissing
    case conflict
    case importing
    case failed

    var label: String {
        switch self {
        case .pending: "New"
        case .imported: "Imported"
        case .importedMissing: "Missing"
        case .conflict: "Conflict"
        case .importing: "Importing"
        case .failed: "Failed"
        }
    }
}
