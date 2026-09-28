import SwiftUI

extension View {
    /// Shrinks floating chrome toward its bottom edge as content scrolls, so the bottom stays in place.
    /// With Reduce Motion it keeps its full size.
    func scrollChromeBar(_ bar: ScrollChrome.Bar) -> some View {
        modifier(ScrollChromeBar(bar: bar))
    }

    /// Gives a pinned header an opaque ground and slides it up under the status bar while it is not shown.
    ///
    /// The status bar keeps its own ground, so the header disappears beneath it rather than off the screen,
    /// and content never shows above the header. The spring settles out of sight, beneath the status bar, so
    /// no sliver of the header lingers over the content. With Reduce Motion it fades.
    func scrollChromeHeader(isShown: Bool, spring: ChromeSpring) -> some View {
        modifier(ScrollChromeHeader(isShown: isShown, spring: spring))
    }
}

private struct ScrollChromeBar: ViewModifier {
    private enum Constants {
        /// The scale at full shrink.
        static let smallestScale = 0.78
    }

    let bar: ScrollChrome.Bar

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .scaleEffect(reduceMotion ? 1 : 1 - bar.shrink * (1 - Constants.smallestScale), anchor: .bottom)
            .animation(bar.spring.animation, value: bar.shrink)
    }
}

private struct ScrollChromeHeader: ViewModifier {
    private enum Constants {
        /// How far past the status bar's edge a hidden header goes. A spring covers its last few points slowly,
        /// so stopping exactly at the edge would leave a sliver of the header over the content for a moment;
        /// going this much further makes the header cross the edge at speed and settle out of sight.
        static let tuck: CGFloat = 8
    }

    let isShown: Bool
    let spring: ChromeSpring

    /// The header's own height: the distance it travels to reach the status bar.
    @State private var height: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { proxy in
                    let height = proxy.size.height
                    Color.clear
                        .onAppear { self.height = height }
                        .onChange(of: height) { self.height = $0 }
                }
            )
            .background(Palette.ground.ignoresSafeArea(edges: .top))
            .offset(y: isShown || reduceMotion ? 0 : -(height + Constants.tuck))
            .opacity(isShown || !reduceMotion ? 1 : 0)
            .allowsHitTesting(isShown)
            .accessibilityHidden(!isShown)
            .animation(Motion.respecting(reduceMotion: reduceMotion, spring.animation), value: isShown)
            // Outside the offset, so it stays over the status bar while the header moves beneath it.
            .overlay(alignment: .top) {
                Palette.ground
                    .frame(height: 0)
                    .ignoresSafeArea(edges: .top)
                    .allowsHitTesting(false)
            }
    }
}
