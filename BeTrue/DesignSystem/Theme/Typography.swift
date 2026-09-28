import SwiftUI

/// Brand type: Helvetica Neue, bold for display. Every style scales with Dynamic Type.
enum Typography {
    /// The "BeTrue." wordmark in navigation.
    static let wordmark = Font.custom("HelveticaNeue-Bold", size: 28, relativeTo: .title)
    static let title = Font.custom("HelveticaNeue-Bold", size: 22, relativeTo: .title2)
    static let headline = Font.custom("HelveticaNeue-Bold", size: 17, relativeTo: .headline)
    static let body = Font.custom("HelveticaNeue", size: 17, relativeTo: .body)
    static let callout = Font.custom("HelveticaNeue-Medium", size: 15, relativeTo: .callout)
    static let caption = Font.custom("HelveticaNeue", size: 13, relativeTo: .caption)
}
