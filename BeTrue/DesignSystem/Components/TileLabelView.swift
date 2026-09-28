import SwiftUI

/// A short label on a grid picture: one line on a soft blur, readable on any image while covering little of it.
struct TileLabelView<Content: View>: View {
    private enum Constants {
        static var horizontalPadding: CGFloat { 8 }
        static var verticalPadding: CGFloat { 4 }
        static var inset: CGFloat { 6 }
        /// The label sits on the image, so past this size it would hide the picture it describes.
        static var largestTextSize: DynamicTypeSize { .accessibility1 }
    }

    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .font(Typography.caption)
            .foregroundStyle(Palette.ink)
            .lineLimit(1)
            .padding(.horizontal, Constants.horizontalPadding)
            .padding(.vertical, Constants.verticalPadding)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(Constants.inset)
            .dynamicTypeSize(...Constants.largestTextSize)
    }
}
