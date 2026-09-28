import SwiftUI

extension View {
    /// Slides floating chrome below the screen edge while content scrolls down. Fades only with Reduce Motion.
    func floatingHidden(_ isHidden: Bool) -> some View {
        modifier(FloatingHide(isHidden: isHidden))
    }
}

private struct FloatingHide: ViewModifier {
    private enum Constants {
        static let hiddenOffset: CGFloat = 120
    }

    let isHidden: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .offset(y: isHidden && !reduceMotion ? Constants.hiddenOffset : 0)
            .opacity(isHidden ? 0 : 1)
            .allowsHitTesting(!isHidden)
            .accessibilityHidden(isHidden)
            .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: isHidden)
    }
}
