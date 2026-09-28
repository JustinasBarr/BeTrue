import SwiftUI

/// Says what is on screen is a saved copy, and how old it is.
struct SavedCopyBannerView: View {
    private enum Constants {
        static let refreshInterval: TimeInterval = 60
        static let spacing: CGFloat = 8
        static let verticalPadding: CGFloat = 8
        static let horizontalPadding: CGFloat = 12
    }

    let savedAt: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: Constants.refreshInterval)) { context in
            HStack(spacing: Constants.spacing) {
                Image(systemName: "wifi.slash")
                    .accessibilityHidden(true)
                Text("Offline · saved \(Self.formatter.localizedString(for: savedAt, relativeTo: context.date))")
                Spacer(minLength: 0)
            }
            .font(Typography.caption)
            .foregroundColor(Palette.inkSecondary)
            .padding(.vertical, Constants.verticalPadding)
            .padding(.horizontal, Constants.horizontalPadding)
            .background(Palette.fill, in: Radius.controlShape)
        }
        .accessibilityElement(children: .combine)
        .accessibilityIdentifier("savedCopyBanner")
    }

    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()
}
