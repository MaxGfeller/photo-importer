import Foundation

struct VolumeInfo: Identifiable, Hashable {
    let id: String
    let url: URL
    let name: String
    let uuid: String?
    let isRemovable: Bool
    let isEjectable: Bool
    let capacity: Int64?
    let availableCapacity: Int64?

    var canEject: Bool {
        isRemovable || isEjectable
    }
}
