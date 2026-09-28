import SwiftUI

/// A video in the grid: its still frame with a play glyph and its length. Opens in the viewer.
struct VideoTileView: View {
    private enum Constants {
        static let badgeSpacing: CGFloat = 3
    }

    let video: Video
    let width: CGFloat

    var body: some View {
        let size = CGSize(width: width, height: width / video.aspectRatio)
        ViewerTileView(item: ViewerItem(video: video), size: size) {
            RemoteImageView(url: video.gridImageURL, pointSize: size)
                .frame(width: size.width, height: size.height)
                .overlay(alignment: .bottomTrailing) { durationLabel }
        }
        .accessibilityLabel(video.spokenDescription)
        .accessibilityAddTraits(.isButton)
        .accessibilityIdentifier("videoTile")
    }

    private var durationLabel: some View {
        TileLabelView {
            HStack(spacing: Constants.badgeSpacing) {
                Image(systemName: "play.fill")
                    .imageScale(.small)
                Text(video.durationText)
                    .monospacedDigit()
            }
        }
    }
}
