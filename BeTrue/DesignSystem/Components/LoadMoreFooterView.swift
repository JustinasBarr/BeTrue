import SwiftUI

/// The end of an endless grid: the next page loading, a failed page with Retry, or the end of the list.
struct LoadMoreFooterView: View {
    enum Status: Equatable {
        case idle
        case loading
        case failed(message: String)
        case finished
    }

    private enum Constants {
        static let minHeight: CGFloat = 96
        static let horizontalPadding: CGFloat = 16
        static let loadingLineWidth: CGFloat = 96
    }

    let status: Status
    let onRetry: () -> Void

    var body: some View {
        Group {
            switch status {
            case .idle:
                Color.clear
            case .loading:
                LoadingLineView(label: "Loading more photos")
                    .frame(width: Constants.loadingLineWidth)
            case .failed(let message):
                HStack {
                    Text(message)
                        .font(Typography.caption)
                        .foregroundColor(Palette.inkSecondary)
                    Spacer()
                    Button("Retry", action: onRetry)
                        .buttonStyle(SolidButtonStyle())
                        .accessibilityIdentifier("loadMoreRetry")
                }
                .padding(.horizontal, Constants.horizontalPadding)
            case .finished:
                Text("That's everything.")
                    .font(Typography.caption)
                    .foregroundColor(Palette.inkSecondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Constants.minHeight)
    }
}
