import AppKit
import SwiftUI

struct ThumbnailView: View {
    let url: URL

    @State private var image: NSImage?

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Rectangle()
                    .fill(.quaternary)

                if let image {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .task(id: url) {
            image = await ThumbnailService.shared.thumbnail(for: url, size: CGSize(width: 420, height: 315))
        }
    }
}
