import Foundation

struct ImportProgress: Equatable {
    var currentFilename: String?
    var completedCount: Int = 0
    var totalCount: Int = 0
    var currentMessage: String?

    var fractionCompleted: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }
}
