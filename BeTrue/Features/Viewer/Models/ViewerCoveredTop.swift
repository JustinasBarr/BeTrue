import SwiftUI

/// How far down the window a screen's pinned header covers its grid. A grid picture hands it to the viewer as it
/// opens, so the image flies beneath the header rather than over it.
///
/// A reference, so the screen can follow its header without redrawing every grid picture.
final class ViewerCoveredTop {
    var y: CGFloat = 0
}

extension EnvironmentValues {
    /// Set by a screen that pins a header over its grid; nil where nothing covers the grid.
    var viewerCoveredTop: ViewerCoveredTop? {
        get { self[ViewerCoveredTopKey.self] }
        set { self[ViewerCoveredTopKey.self] = newValue }
    }
}

private struct ViewerCoveredTopKey: EnvironmentKey {
    static var defaultValue: ViewerCoveredTop? { nil }
}
