import SwiftUI

/// Shared animation curves, tuned to feel like Photos on iOS 16.
enum Motion {
    /// Opening and closing the full-screen viewer.
    static let hero = Animation.spring(response: 0.38, dampingFraction: 0.86)
    /// How long `hero` takes to come to rest, for work that must wait until the image has landed.
    static let heroSettleDuration: TimeInterval = 0.5
    /// How long the Reduce Motion fade in `respecting` takes.
    static let fadeDuration: TimeInterval = 0.2
    /// Small state changes: showing a banner, hiding a floating button.
    static let quick = Animation.spring(response: 0.3, dampingFraction: 0.9)
    /// An image replacing its placeholder.
    static let imageFade = Animation.easeOut(duration: 0.2)
    /// A dropdown opening from its field: a strong ease-out, so it answers the keystroke at once.
    static let dropdown = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.18)
    /// A control changing in place, such as a filter chip taking a choice: the same ease-out, a little longer and
    /// with no overshoot, so the chip and its neighbours glide to their new widths rather than bounce.
    static let controlChange = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.24)
    /// Work that finishes sooner than this shows no loading state, so a quick answer never flashes one.
    static let loadingDelay: TimeInterval = 0.15

    /// `animation`, or a short fade when the user has turned on Reduce Motion.
    static func respecting(reduceMotion: Bool, _ animation: Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: fadeDuration) : animation
    }
}
