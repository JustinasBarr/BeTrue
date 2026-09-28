import CoreGraphics
import Foundation

/// An image at the pixel size it is shown at. Tiles and the grid's prefetcher build it the same way, so a
/// prefetched image is the very cache entry its tile reads.
nonisolated struct ImageRequest: Hashable, Sendable {
    let url: URL
    /// The longer side, in pixels.
    let maxPixelSize: CGFloat

    /// Rounded up, so a tile and its prefetch always agree on the size.
    init(url: URL, pointSize: CGSize, displayScale: CGFloat) {
        self.url = url
        maxPixelSize = (max(pointSize.width, pointSize.height) * displayScale).rounded(.up)
    }
}
