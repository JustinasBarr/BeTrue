import SwiftUI

/// A thin line that says work is under way where a spinner would be too loud: a short ink stroke sweeps
/// across a faint track. With Reduce Motion the track stays still.
struct LoadingLineView: View {
    private enum Constants {
        static let height: CGFloat = 2
        /// The stroke's length as a share of the track.
        static let strokeFraction: CGFloat = 0.3
        static let sweepDuration: TimeInterval = 1.2
    }

    let label: String

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: reduceMotion)) { timeline in
            GeometryReader { proxy in
                let width = proxy.size.width
                let stroke = width * Constants.strokeFraction
                Radius.controlShape
                    .fill(reduceMotion ? Palette.inkTertiary : Palette.hairline)
                    .overlay(alignment: .leading) {
                        if !reduceMotion {
                            Radius.controlShape
                                .fill(Palette.ink)
                                .frame(width: stroke)
                                .offset(x: -stroke + sweep(at: timeline.date) * (width + stroke))
                        }
                    }
                    .clipShape(Radius.controlShape)
            }
        }
        .frame(height: Constants.height)
        .accessibilityElement()
        .accessibilityLabel(label)
    }

    /// 0 to 1 across one sweep, easing in and out, so the stroke speeds through the middle.
    private func sweep(at date: Date) -> CGFloat {
        let progress = date.timeIntervalSinceReferenceDate
            .truncatingRemainder(dividingBy: Constants.sweepDuration) / Constants.sweepDuration
        let eased = progress < 0.5 ? 2 * progress * progress : 1 - pow(-2 * progress + 2, 2) / 2
        return CGFloat(eased)
    }
}
