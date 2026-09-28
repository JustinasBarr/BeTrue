import AVFoundation
import Combine
import UIKit

/// Shows the grid's preview at once, then swaps in the full image, so opening never waits on the network.
final class ViewerViewModel: ObservableObject {
    @Published private(set) var image: UIImage?
    @Published private(set) var isShowingFullImage = false
    /// True once the video cannot load, most often because the connection dropped.
    @Published private(set) var didPlaybackFail = false
    let item: ViewerItem
    /// Made on open, so the video buffers while the still flies in.
    let player: AVPlayer?
    var isVideo: Bool { player != nil }
    private let imageLoader: any ImageLoading
    private let previewPixelSize: CGFloat
    private var subscriptions = Set<AnyCancellable>()

    init(item: ViewerItem, imageLoader: any ImageLoading,
         previewPixelSize: CGFloat = CGFloat(Photo.gridPixelWidth)) {
        self.item = item
        self.imageLoader = imageLoader
        self.previewPixelSize = previewPixelSize
        // The grid decoded the preview at its cell size, which the viewer cannot know, so any cached size will do.
        image = imageLoader.cachedImage(for: item.previewURL)
        player = item.videoURL.map { AVPlayer(url: $0) }
        player?.currentItem?.publisher(for: \.status)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] status in
                if status == .failed { self?.didPlaybackFail = true }
            }
            .store(in: &subscriptions)
    }

    /// Fetches the preview when the cache has dropped it, so the image never flies in as a bare colour.
    func loadPreviewIfNeeded() async {
        guard image == nil else { return }
        let preview = await imageLoader.image(for: item.previewURL, maxPixelSize: previewPixelSize)
        // The full image may have arrived first.
        guard image == nil else { return }
        image = preview
    }

    /// Swaps in the full image unless the caller was cancelled meanwhile, so it never lands mid-flight.
    func loadFullImage(maxPixelSize: CGFloat) async {
        guard !isShowingFullImage else { return }
        guard let fullImage = await imageLoader.image(for: item.fullImageURL, maxPixelSize: maxPixelSize),
              !Task.isCancelled else {
            return
        }
        image = fullImage
        isShowingFullImage = true
    }

    /// Starts muted: a viewer opened from a silent grid should never surprise anyone with sound.
    /// The player's own speaker control turns it on.
    func startPlayback() {
        player?.isMuted = true
        player?.play()
    }

    func pausePlayback() {
        player?.pause()
    }
}
