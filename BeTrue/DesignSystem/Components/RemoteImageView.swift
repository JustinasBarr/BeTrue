import SwiftUI
import UIKit

/// A remote image decoded at its shown pixel size. The cache is read synchronously in `body`, so a reused
/// cell shows its image on the first frame; only a download or decode fades in.
struct RemoteImageView: View {
    let url: URL
    /// In points; decides the decoded pixel size.
    let pointSize: CGSize
    var placeholder = Palette.fill

    @Environment(\.imageLoader) private var imageLoader
    @Environment(\.displayScale) private var displayScale
    @State private var loaded: LoadedImage?

    private struct LoadedImage {
        let request: ImageRequest
        let image: UIImage
    }

    var body: some View {
        let request = ImageRequest(url: url, pointSize: pointSize, displayScale: displayScale)
        let image = loaded?.request == request
            ? loaded?.image
            : imageLoader.cachedImage(for: url, maxPixelSize: request.maxPixelSize)
        placeholder
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .transition(.opacity)
                }
            }
            .clipped()
            .task(id: request) { await load(request) }
            // Lazy stacks keep every built tile's state; letting go keeps a long scroll from holding every image.
            .onDisappear { loaded = nil }
    }

    private func load(_ request: ImageRequest) async {
        guard request.maxPixelSize > 0, loaded?.request != request else { return }
        if let cached = imageLoader.cachedImage(for: request.url, maxPixelSize: request.maxPixelSize) {
            // Already on screen from the synchronous read; keep it even if the cache evicts it later.
            loaded = LoadedImage(request: request, image: cached)
            return
        }
        guard let image = await imageLoader.image(for: request.url, maxPixelSize: request.maxPixelSize),
              !Task.isCancelled else { return }
        withAnimation(Motion.imageFade) {
            loaded = LoadedImage(request: request, image: image)
        }
    }
}
