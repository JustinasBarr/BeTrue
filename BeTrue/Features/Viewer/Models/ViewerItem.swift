import CoreGraphics
import Foundation

/// Anything the full-screen viewer can show: a photo now, a video later.
struct ViewerItem: Identifiable, Hashable, Sendable {
    /// Unique across kinds, such as "photo-123", so a photo and a video never collide.
    let id: String
    let aspectRatio: Double
    /// Hex colour shown before the image arrives.
    let placeholderColor: String?
    /// The image already shown in the grid, displayed first so opening is instant.
    let previewURL: URL
    let fullImageURL: URL
    let title: String
    let creditName: String
    let creditURL: URL?
    let pageURL: URL
    let videoURL: URL?
}

/// The item the viewer shows and the grid picture it opened from.
struct ViewerPresentation {
    let item: ViewerItem
    /// Where the item's grid picture sits in the window, followed live, so the image flies back to wherever the grid
    /// has laid the picture out since opening.
    let source: ViewerSourceFrame
    /// How far down the window the screen's header covers the grid; nil where nothing does.
    let coveredTop: ViewerCoveredTop?
    /// True while the image flies back into the grid, before the viewer is removed.
    var isClosing = false
}

/// Where a grid picture sits in the window. A reference, so following the scroll never redraws the picture.
///
/// Not nested in the generic `ViewerTileView`: there, its deinit crashes the Release optimizer (Swift 6.3.3).
final class ViewerSourceFrame {
    var frame = CGRect.zero
}
