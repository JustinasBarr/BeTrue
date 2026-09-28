import SwiftUI

/// Place at the very top of scroll content so `onScrollOffsetChange` can read its position.
///
/// iOS 16 has no scroll geometry API, so the offset is this marker's frame in the scroll view's
/// named coordinate space. It is handed up through the environment because iOS 16 never delivered
/// a preference from here.
struct ScrollOffsetMarkerView: View {
    let coordinateSpace: String

    @Environment(\.scrollOffsetHandler) private var onOffsetChange

    var body: some View {
        GeometryReader { proxy in
            let offset = proxy.frame(in: .named(coordinateSpace)).minY
            Color.clear
                .onAppear { onOffsetChange(offset) }
                .onChange(of: offset) { onOffsetChange($0) }
        }
        .frame(height: 0)
    }
}

extension View {
    /// Reports the content's offset every frame it moves: 0 at rest at the top, negative as it scrolls
    /// down, positive while pulled to refresh. Apply to the scroll view that contains a `ScrollOffsetMarkerView`.
    func onScrollOffsetChange(coordinateSpace: String, perform action: @escaping (CGFloat) -> Void) -> some View {
        self
            .coordinateSpace(name: coordinateSpace)
            .environment(\.scrollOffsetHandler, action)
    }
}

private extension EnvironmentValues {
    var scrollOffsetHandler: (CGFloat) -> Void {
        get { self[ScrollOffsetHandlerKey.self] }
        set { self[ScrollOffsetHandlerKey.self] = newValue }
    }
}

private struct ScrollOffsetHandlerKey: EnvironmentKey {
    static let defaultValue: (CGFloat) -> Void = { _ in }
}
