import SwiftUI

/// A whole-screen message: offline, an error, no results, or setup still needed.
struct StateView: View {
    struct Action {
        let title: String
        let perform: () -> Void
    }

    private enum Constants {
        static let spacing: CGFloat = 12
        static let actionTopPadding: CGFloat = 12
        static let horizontalPadding: CGFloat = 24
        static let glyphSize: CGFloat = 28
    }

    let systemImage: String
    let title: String
    let detail: String
    var action: Action?
    /// Lets UI tests tell one state apart from another.
    var identifier = "stateView"

    var body: some View {
        VStack(alignment: .leading, spacing: Constants.spacing) {
            Image(systemName: systemImage)
                .font(.system(size: Constants.glyphSize))
                .foregroundColor(Palette.ink)
                .accessibilityHidden(true)
            Text(title)
                .font(Typography.title)
                .foregroundColor(Palette.ink)
                .accessibilityAddTraits(.isHeader)
            Text(detail)
                .font(Typography.body)
                .foregroundColor(Palette.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            if let action {
                Button(action.title, action: action.perform)
                    .buttonStyle(SolidButtonStyle())
                    .padding(.top, Constants.actionTopPadding)
                    .accessibilityIdentifier("stateAction")
            }
        }
        .padding(.horizontal, Constants.horizontalPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(identifier)
    }
}
