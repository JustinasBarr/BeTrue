import SwiftUI

/// A filter chip that opens a menu: "Any" first to clear the filter, then each value, the chosen one checked.
///
/// The chip shows the filter's name while nothing is chosen and the choice once one is, inverted like the
/// solid button, so the active filters read at a glance.
struct FilterMenuView<Value: Hashable & Sendable>: View {
    private enum Constants {
        static var height: CGFloat { 36 }
        /// Taps land within this much of the chip above and below it, making a 44 pt target of a 36 pt chip.
        static var hitInset: CGFloat { 4 }
        static var horizontalPadding: CGFloat { 12 }
        static var spacing: CGFloat { 6 }
        static var swatchSide: CGFloat { 12 }
        static var swatchOutlineWidth: CGFloat { 1 }
    }

    let title: String
    let anyTitle: String
    let options: [Value]
    let selection: Value?
    let optionTitle: (Value) -> String
    /// The chip's words for a choice, when shorter than the menu's.
    var chipTitle: ((Value) -> String)?
    var optionImage: ((Value) -> Image)?
    /// A colour dot on the chip, for a colour filter.
    var chipSwatch: Color?
    let onSelect: (Value?) -> Void

    @ScaledMetric(relativeTo: .callout) private var swatchSide = Constants.swatchSide

    var body: some View {
        // The chip is drawn outside the menu. A menu's label can keep the width it had when the menu opened, which
        // cut a longer choice short, and on iOS 26 it vanishes while the menu is open. The menu only takes the taps.
        chip
            .accessibilityHidden(true)
            .overlay { menu }
    }

    private var menu: some View {
        Menu {
            Picker(title, selection: Binding(get: { selection }, set: { onSelect($0) })) {
                Text(anyTitle)
                    .tag(Value?.none)
                ForEach(options, id: \.self) { option in
                    Label {
                        Text(optionTitle(option))
                    } icon: {
                        optionImage?(option)
                    }
                    .tag(Value?.some(option))
                }
            }
        } label: {
            Color.clear
                .contentShape(.interaction, Rectangle())
                // The menu grows out of this shape and shrinks back into it, so it is the capsule, not the hit area.
                .contentShape(.contextMenuPreview, ChipShape(verticalInset: Constants.hitInset))
        }
        .menuOrder(.fixed)
        .accessibilityLabel(title)
        .accessibilityValue(selection.map(optionTitle) ?? anyTitle)
    }

    private var chip: some View {
        HStack(spacing: Constants.spacing) {
            if let chipSwatch, selection != nil {
                Circle()
                    .fill(chipSwatch)
                    .frame(width: swatchSide, height: swatchSide)
                    .overlay(Circle().strokeBorder(ink, lineWidth: Constants.swatchOutlineWidth))
                    .accessibilityHidden(true)
            }
            Text(chipText)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(Typography.caption)
                .accessibilityHidden(true)
        }
        .font(Typography.callout)
        .foregroundColor(ink)
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(minHeight: Constants.height)
        .background(isChosen ? Palette.ink : Palette.fill, in: Radius.controlShape)
        .padding(.vertical, Constants.hitInset)
    }

    private var isChosen: Bool { selection != nil }
    private var ink: Color { isChosen ? Palette.ground : Palette.ink }

    private var chipText: String {
        guard let selection else { return title }
        return (chipTitle ?? optionTitle)(selection)
    }
}

/// The chip's capsule inside its taller hit area.
nonisolated private struct ChipShape: Shape {
    let verticalInset: CGFloat

    func path(in rect: CGRect) -> Path {
        Radius.controlShape.path(in: rect.insetBy(dx: 0, dy: verticalInset))
    }
}

/// A row of filter chips that scrolls sideways, with Clear once any filter is chosen.
///
/// Meant for a header inset by the screen margin: the row scrolls under that margin, so a chip slides off at
/// the screen's edge rather than the margin's.
struct FilterRowView<Filters: Equatable, Chips: View>: View {
    private enum Constants {
        static var spacing: CGFloat { 8 }
        static var clearMinHeight: CGFloat { 44 }
    }

    /// The chosen filters. A change animates the whole row as one, so a chip that grows or shrinks moves its
    /// neighbours and Clear with it, on the same curve.
    let filters: Filters
    let hasChoice: Bool
    let onClear: () -> Void
    let chips: Chips

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(filters: Filters, hasChoice: Bool, onClear: @escaping () -> Void, @ViewBuilder chips: () -> Chips) {
        self.filters = filters
        self.hasChoice = hasChoice
        self.onClear = onClear
        self.chips = chips()
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.spacing) {
                chips
                if hasChoice {
                    Button("Clear", action: onClear)
                        .font(Typography.callout)
                        .foregroundColor(Palette.inkSecondary)
                        .frame(minHeight: Constants.clearMinHeight)
                        .buttonStyle(PressableButtonStyle())
                        .transition(.opacity)
                        .accessibilityLabel("Clear filters")
                        .accessibilityIdentifier("clearFilters")
                }
            }
            .animation(Motion.respecting(reduceMotion: reduceMotion, Motion.controlChange), value: filters)
            .padding(.horizontal, Spacing.screenMargin)
        }
        .padding(.horizontal, -Spacing.screenMargin)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Filters")
    }
}
