import SwiftUI

/// Quiet blocks in the shape of the masonry grid, shown before the first page arrives.
struct SkeletonGridView: View {
    private enum Constants {
        static let aspectRatios = [0.75, 1.3, 0.8, 1.0, 0.67, 1.5, 0.9, 1.2, 0.7, 1.1, 0.8, 1.4]
        static let dimmedOpacity = 0.45
        static let pulse = Animation.easeInOut(duration: 1.1).repeatForever(autoreverses: true)
    }

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isDimmed = false

    private struct Block: Identifiable {
        let id: Int
        let aspectRatio: Double
    }

    var body: some View {
        MasonryGridView(items: blocks, aspectRatio: \.aspectRatio) { block, width in
            Radius.tileShape
                .fill(Palette.fill)
                .frame(width: width, height: width / block.aspectRatio)
        }
        .opacity(isDimmed ? Constants.dimmedOpacity : 1)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(Constants.pulse) { isDimmed = true }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityIdentifier("skeletonGrid")
    }

    private var blocks: [Block] {
        Constants.aspectRatios.enumerated().map { Block(id: $0.offset, aspectRatio: $0.element) }
    }
}
