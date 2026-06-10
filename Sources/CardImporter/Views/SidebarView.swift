import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: ImportSessionStore

    var body: some View {
        VStack(spacing: 0) {
            List(selection: selectedVolumeBinding) {
                Section("Source") {
                    ForEach(store.volumes) { volume in
                        VolumeRow(volume: volume)
                            .tag(volume.id)
                    }

                    Button {
                        store.chooseSourceFolder()
                    } label: {
                        Label("Choose Folder...", systemImage: "folder")
                    }

                    Button {
                        Task { await store.refreshVolumes() }
                    } label: {
                        Label("Refresh Volumes", systemImage: "arrow.clockwise")
                    }
                }

                Section("Destination") {
                    if let destinationURL = store.destinationURL {
                        LocationRow(
                            icon: "externaldrive",
                            title: destinationURL.lastPathComponent,
                            subtitle: destinationURL.path
                        )
                    }

                    Button {
                        store.chooseDestinationFolder()
                    } label: {
                        Label("Choose Destination...", systemImage: "folder.badge.gearshape")
                    }

                    Button {
                        Task { await store.indexExistingDestination() }
                    } label: {
                        Label("Index Existing Media", systemImage: "checklist.checked")
                    }
                    .disabled(store.destinationURL == nil || store.isIndexing || store.isImporting)
                }
            }
            .listStyle(.sidebar)

            VStack(alignment: .leading, spacing: 8) {
                if let sourceURL = store.sourceURL {
                    LocationRow(icon: "sdcard", title: sourceURL.lastPathComponent, subtitle: sourceURL.path)
                }

                Divider()

                Text(store.statusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                HStack {
                    Label("\(store.items.count)", systemImage: "photo.on.rectangle")
                    Spacer()
                    if let ledgerRecordCount = store.ledgerRecordCount {
                        Label("\(ledgerRecordCount)", systemImage: "checkmark.seal")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(12)
        }
    }

    private var selectedVolumeBinding: Binding<VolumeInfo.ID?> {
        Binding(
            get: { store.selectedVolumeID },
            set: { newValue in
                guard let newValue,
                      let volume = store.volumes.first(where: { $0.id == newValue }) else {
                    return
                }
                store.selectVolume(volume)
            }
        )
    }
}

private struct VolumeRow: View {
    let volume: VolumeInfo

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: volume.isRemovable || volume.isEjectable ? "sdcard" : "externaldrive")
                .foregroundStyle(volume.isRemovable || volume.isEjectable ? .green : .secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(volume.name)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if volume.isRemovable {
                        Text("Removable")
                    } else if volume.isEjectable {
                        Text("Ejectable")
                    } else {
                        Text("Volume")
                    }

                    if let availableCapacity = volume.availableCapacity {
                        Text(ByteCountFormatting.string(from: availableCapacity))
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }
        }
    }
}

private struct LocationRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .lineLimit(1)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
        }
    }
}
