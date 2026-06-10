import SwiftUI

struct MediaGridItemView: View {
    let item: MediaItem
    let isSelected: Bool
    let showDestinationAction: Bool
    let toggleSelection: () -> Void
    let revealSource: () -> Void
    let revealDestination: () -> Void

    var body: some View {
        Button(action: toggleSelection) {
            VStack(alignment: .leading, spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    ThumbnailView(url: item.url)
                        .frame(maxWidth: .infinity)
                        .aspectRatio(4.0 / 3.0, contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.22), lineWidth: isSelected ? 3 : 1)
                        }

                    VStack(alignment: .trailing, spacing: 6) {
                        StatusBadge(status: item.status)

                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title2)
                                .foregroundStyle(.white, Color.accentColor)
                                .shadow(radius: 2)
                        }
                    }
                    .padding(8)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Image(systemName: item.mediaKind == .video ? "video.fill" : "photo.fill")
                            .foregroundStyle(.secondary)
                        Text(item.filename)
                            .font(.subheadline.weight(.medium))
                            .lineLimit(1)
                    }

                    HStack(spacing: 8) {
                        Text(ByteCountFormatting.string(from: item.byteCount))
                        if let captureDate = item.captureDate {
                            Text(AppDateFormatting.shortDateTime.string(from: captureDate))
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                    if let errorMessage = item.errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                    }
                }
            }
            .padding(9)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .contentShape(Rectangle())
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .disabled(!item.isSelectableForImport && item.status != .imported)
        .contextMenu {
            Button("Reveal Source in Finder", action: revealSource)

            if showDestinationAction {
                Button("Reveal Destination in Finder", action: revealDestination)
            }
        }
    }
}

private struct StatusBadge: View {
    let status: ImportStatus

    var body: some View {
        Text(status.label)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 4)
            .background(color, in: Capsule())
    }

    private var color: Color {
        switch status {
        case .pending:
            .blue
        case .imported:
            .green
        case .importedMissing:
            .orange
        case .conflict:
            .red
        case .importing:
            .purple
        case .failed:
            .red
        }
    }
}
