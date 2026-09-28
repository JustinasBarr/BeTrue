import SwiftUI

/// A floating capsule of tabs. Generic over the selection so it knows nothing about the app's tabs.
struct FloatingTabBarView<Selection: Hashable>: View {
    struct Item {
        let value: Selection
        let title: String
        let systemImage: String
        let identifier: String
    }

    private enum Constants {
        static var inset: CGFloat { 6 }
        static var itemHeight: CGFloat { 44 }
        static var itemPadding: CGFloat { 18 }
        static var iconSpacing: CGFloat { 8 }
        static var highlightID: String { "selectedTab" }
    }

    let items: [Item]
    let selection: Selection
    let onSelect: (Selection) -> Void

    @Namespace private var highlight
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            ForEach(items, id: \.value) { item in
                button(for: item)
            }
        }
        .padding(Constants.inset)
        .glassSurface(in: Capsule())
        .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.quick), value: selection)
    }

    private func button(for item: Item) -> some View {
        let isSelected = item.value == selection
        return Button {
            onSelect(item.value)
        } label: {
            HStack(spacing: Constants.iconSpacing) {
                Image(systemName: item.systemImage)
                    .accessibilityHidden(true)
                Text(item.title)
            }
            .font(Typography.callout.bold())
            .foregroundColor(isSelected ? Palette.ground : Palette.inkSecondary)
            .padding(.horizontal, Constants.itemPadding)
            .frame(minHeight: Constants.itemHeight)
            .background {
                if isSelected {
                    highlightCapsule
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityIdentifier(item.identifier)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private var highlightCapsule: some View {
        if reduceMotion {
            Capsule().fill(Palette.ink)
                .transition(.opacity)
        } else {
            // Slides from the old tab to the new one instead of blinking between them.
            Capsule().fill(Palette.ink)
                .matchedGeometryEffect(id: Constants.highlightID, in: highlight)
        }
    }
}

extension View {
    /// The floating bar sits straight on the content, with no system blur along the bottom edge on iOS 26.
    @ViewBuilder
    func hidesBottomScrollEdgeEffect() -> some View {
        if #available(iOS 26.0, *) {
            scrollEdgeEffectHidden(true, for: .bottom)
        } else {
            self
        }
    }
}
