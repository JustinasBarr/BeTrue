import SwiftUI

/// The top of each tab: the wordmark with the tab's name, and the credit Pexels asks for.
struct ScreenHeaderView: View {
    private enum Constants {
        static let wordmark = "BeTrue"
        static let credit = String(localized: "Powered by Pexels")
        static let creditURL = URL(string: "https://www.pexels.com")!
    }

    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            (Text(Constants.wordmark).foregroundColor(Palette.ink)
                + Text(" \(title)").foregroundColor(Palette.inkSecondary))
                .font(Typography.wordmark)
                .accessibilityAddTraits(.isHeader)
            Spacer()
            Link(Constants.credit, destination: Constants.creditURL)
                .font(Typography.caption)
                .foregroundColor(Palette.inkSecondary)
        }
    }
}
