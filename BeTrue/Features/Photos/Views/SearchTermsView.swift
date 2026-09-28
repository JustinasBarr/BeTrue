import SwiftUI

/// Recent searches as chips, or a few ideas before the first one. A recent search can be removed.
struct SearchTermsView: View {
    private enum Constants {
        static let suggestions = ["Mountains", "Night city", "Portraits", "Ocean", "Architecture"]
        static let spacing: CGFloat = 8
        static let height: CGFloat = 36
        static let horizontalPadding: CGFloat = 12
    }

    let recentSearches: [String]
    let onChoose: (String) -> Void
    let onRemove: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Constants.spacing) {
                ForEach(isRecent ? recentSearches : Constants.suggestions, id: \.self) { term in
                    termButton(term)
                }
            }
        }
    }

    private var isRecent: Bool { !recentSearches.isEmpty }

    @ViewBuilder
    private func termButton(_ term: String) -> some View {
        let button = Button {
            onChoose(term)
        } label: {
            HStack(spacing: Constants.spacing) {
                Image(systemName: isRecent ? "clock.arrow.circlepath" : "magnifyingglass")
                    .foregroundColor(Palette.inkSecondary)
                    .accessibilityHidden(true)
                Text(term)
                    .foregroundColor(Palette.ink)
            }
            .font(Typography.callout)
            .padding(.horizontal, Constants.horizontalPadding)
            .frame(minHeight: Constants.height)
            .background(Palette.fill, in: Radius.controlShape)
        }
        .buttonStyle(PressableButtonStyle())
        if isRecent {
            button
                .contextMenu {
                    Button("Remove", role: .destructive) { onRemove(term) }
                }
                .accessibilityAction(named: "Remove") { onRemove(term) }
                .accessibilityIdentifier("recentSearch")
        } else {
            button
                .accessibilityIdentifier("searchSuggestion")
        }
    }
}
