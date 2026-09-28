import CoreGraphics

/// How a drag on the viewer turns into feedback and a dismiss decision, tuned against Photos.
enum DismissDragPolicy {
    private enum Constants {
        static let dismissDistance: CGFloat = 120
        /// A flick projected this far dismisses even when the finger itself travelled only a little.
        static let flickDistance: CGFloat = 240
        static let fadeDistance: CGFloat = 320
        static let minimumScale: CGFloat = 0.75
        static let upwardResistance: CGFloat = 0.4
    }

    static func progress(for translation: CGSize) -> CGFloat {
        min(max(translation.height, 0) / Constants.fadeDistance, 1)
    }

    static func scale(for translation: CGSize, reduceMotion: Bool) -> CGFloat {
        reduceMotion ? 1 : 1 - (1 - Constants.minimumScale) * progress(for: translation)
    }

    static func offset(for translation: CGSize) -> CGSize {
        let height = translation.height < 0 ? translation.height * Constants.upwardResistance : translation.height
        return CGSize(width: translation.width, height: height)
    }

    static func shouldDismiss(translation: CGSize, projectedTranslation: CGSize) -> Bool {
        let isStillMovingDown = projectedTranslation.height >= translation.height
        return (translation.height > Constants.dismissDistance && isStillMovingDown)
            || projectedTranslation.height > Constants.flickDistance
    }
}
