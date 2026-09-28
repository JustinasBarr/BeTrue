import SwiftUI

/// Ways to finish what the user is typing, on a panel under the search field.
///
/// Tapping a completion searches for it; its arrow puts it in the field instead, to keep typing. The part the
/// user typed is dimmed, so the eye lands on what the completion adds.
struct SearchCompletionListView: View {
    private enum Constants {
        static let rowHeight: CGFloat = 44
        static let rowLeadingPadding: CGFloat = 12
        static let glyphSpacing: CGFloat = 12
        static let fillButtonSide: CGFloat = 44
        /// Keeps a pressed row's highlight off the panel's edge.
        static let panelInset: CGFloat = 6
        static let outlineWidth: CGFloat = 1
    }

    let query: String
    let completions: [String]
    let onChoose: (String) -> Void
    let onFill: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(completions, id: \.self) { completion in
                row(completion)
            }
        }
        .padding(Constants.panelInset)
        .background(Palette.ground, in: Radius.panelShape)
        .overlay(Radius.panelShape.strokeBorder(Palette.hairline, lineWidth: Constants.outlineWidth))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Suggestions")
        .accessibilityIdentifier("searchCompletions")
    }

    private func row(_ completion: String) -> some View {
        HStack(spacing: 0) {
            Button {
                onChoose(completion)
            } label: {
                HStack(spacing: Constants.glyphSpacing) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(Palette.inkSecondary)
                        .accessibilityHidden(true)
                    highlighted(completion)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                }
                .padding(.leading, Constants.rowLeadingPadding)
                .frame(minHeight: Constants.rowHeight)
            }
            .buttonStyle(CompletionRowButtonStyle())
            .accessibilityIdentifier("searchCompletion")
            Button {
                onFill(completion)
            } label: {
                Image(systemName: "arrow.up.left")
                    .foregroundColor(Palette.inkSecondary)
                    .frame(width: Constants.fillButtonSide, height: Constants.fillButtonSide)
            }
            .buttonStyle(PressableButtonStyle())
            .accessibilityLabel("Edit \u{201C}\(completion)\u{201D} in the search field")
        }
        .font(Typography.body)
    }

    private func highlighted(_ completion: String) -> Text {
        guard let range = SearchCompleter.matchedRange(of: query, in: completion) else {
            return Text(completion).foregroundColor(Palette.ink)
        }
        return Text(completion[..<range.lowerBound]).foregroundColor(Palette.ink)
            + Text(completion[range]).foregroundColor(Palette.inkSecondary)
            + Text(completion[range.upperBound...]).foregroundColor(Palette.ink)
    }
}

/// A list row lights a capsule behind itself while pressed, rather than shrinking out of line with its neighbours.
private struct CompletionRowButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(configuration.isPressed ? Palette.fill : .clear, in: Radius.controlShape)
            .contentShape(Radius.controlShape)
    }
}
