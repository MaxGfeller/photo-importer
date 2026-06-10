import Foundation

enum ImportFilter: String, CaseIterable, Identifiable {
    case all
    case new
    case imported
    case conflicts

    var id: String { rawValue }

    var label: String {
        switch self {
        case .all: "All"
        case .new: "New"
        case .imported: "Imported"
        case .conflicts: "Issues"
        }
    }
}
