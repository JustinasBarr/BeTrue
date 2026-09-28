import SwiftUI

/// The floating dark and light switch. Slides away while content scrolls down and springs back.
struct AppearanceToggleView: View {
    private enum Constants {
        static let glyphTurn = 90.0
        static let hiddenGlyphScale: CGFloat = 0.6
    }

    let isDark: Bool
    let isHidden: Bool
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        FloatingRoundButtonView(action: action) {
            ZStack {
                Image(systemName: isDark ? "moon.fill" : "sun.max.fill")
                    .font(Typography.headline)
                    .id(isDark)
                    .transition(glyphTransition)
            }
            .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: isDark)
        }
        .accessibilityLabel("Appearance")
        .accessibilityValue(isDark ? "Dark" : "Light")
        .accessibilityIdentifier("appearanceToggle")
        .floatingHidden(isHidden)
    }

    private var glyphTransition: AnyTransition {
        guard !reduceMotion else { return .opacity }
        return .asymmetric(
            insertion: .modifier(active: GlyphTurn(angle: -Constants.glyphTurn, scale: Constants.hiddenGlyphScale),
                                 identity: GlyphTurn(angle: 0, scale: 1)),
            removal: .modifier(active: GlyphTurn(angle: Constants.glyphTurn, scale: Constants.hiddenGlyphScale),
                               identity: GlyphTurn(angle: 0, scale: 1)))
    }
}

private struct GlyphTurn: ViewModifier {
    let angle: Double
    let scale: CGFloat

    func body(content: Content) -> some View {
        content
            .rotationEffect(.degrees(angle))
            .scaleEffect(scale)
            .opacity(scale < 1 ? 0 : 1)
    }
}
