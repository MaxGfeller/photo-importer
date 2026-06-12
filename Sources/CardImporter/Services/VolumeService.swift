import Foundation

struct VolumeService {
    func mountedVolumes() -> [VolumeInfo] {
        let keys: [URLResourceKey] = [
            .volumeNameKey,
            .volumeUUIDStringKey,
            .volumeIsRemovableKey,
            .volumeIsEjectableKey,
            .volumeTotalCapacityKey,
            .volumeAvailableCapacityKey
        ]

        let urls = FileManager.default.mountedVolumeURLs(
            includingResourceValuesForKeys: keys,
            options: [.skipHiddenVolumes]
        ) ?? []

        return urls.compactMap { url in
            do {
                let values = try url.resourceValues(forKeys: Set(keys))
                let uuid = values.volumeUUIDString
                let name = values.volumeName ?? url.lastPathComponent
                return VolumeInfo(
                    id: uuid ?? url.path,
                    url: url,
                    name: name,
                    uuid: uuid,
                    isRemovable: values.volumeIsRemovable ?? false,
                    isEjectable: values.volumeIsEjectable ?? false,
                    capacity: values.volumeTotalCapacity.map(Int64.init),
                    availableCapacity: values.volumeAvailableCapacity.map(Int64.init)
                )
            } catch {
                return nil
            }
        }
        .sorted { lhs, rhs in
            if lhs.isRemovable != rhs.isRemovable {
                return lhs.isRemovable && !rhs.isRemovable
            }
            if lhs.isEjectable != rhs.isEjectable {
                return lhs.isEjectable && !rhs.isEjectable
            }
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    func volume(containing url: URL, in volumes: [VolumeInfo]) -> VolumeInfo? {
        let path = url.standardizedFileURL.path

        return volumes
            .filter { volume in
                let volumePath = volume.url.standardizedFileURL.path
                return path == volumePath || path.hasPrefix("\(volumePath)/")
            }
            .max { lhs, rhs in
                lhs.url.path.count < rhs.url.path.count
            }
    }
}
