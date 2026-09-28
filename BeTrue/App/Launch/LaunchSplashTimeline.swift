//
//  LaunchSplashTimeline.swift
//  BeTrue
//

import Foundation
import QuartzCore

/// The splash motion as keyframe tracks, sampled from easing curves and interpolated linearly.
nonisolated struct LaunchSplashTimeline: Equatable {
    nonisolated struct Track: Equatable {
        /// Fractions of the timeline duration, from 0 to 1.
        var keyTimes: [Double]
        var values: [Double]

        init(samples: Int, _ value: (_ progress: Double) -> Double) {
            keyTimes = (0...samples).map { Double($0) / Double(samples) }
            values = keyTimes.map(value)
        }

        /// A track that holds one value throughout.
        static func constant(_ value: Double) -> Self { Self(samples: 1) { _ in value } }

        var isConstant: Bool { values.allSatisfy { $0 == values.first } }

        func value(atProgress progress: Double) -> Double {
            guard let next = keyTimes.firstIndex(where: { $0 >= progress }) else { return values.last ?? 0 }
            guard next > 0 else { return values[0] }
            let span = keyTimes[next] - keyTimes[next - 1]
            let fraction = (progress - keyTimes[next - 1]) / span
            return values[next - 1] + (values[next] - values[next - 1]) * fraction
        }
    }

    var duration: TimeInterval
    /// When the status bar returns: after the handoff frame, before anything shows through.
    var statusBarTime: TimeInterval
    /// The launch screen's own black ground.
    var backdropOpacity: Track
    /// The white wordmark.
    var lettersOpacity: Track
    /// The black cover with the wordmark's letters cut out of it.
    var coverOpacity: Track
    /// The wordmark and its cutout, about the cutout's zoom anchor.
    var scale: Track

    /// A timeline without a cover fades the black ground instead.
    var cutsOutLetters: Bool { coverOpacity.values.contains { $0 > 0 } }

    var tracks: [Track] { [backdropOpacity, lettersOpacity, coverOpacity, scale] }

    /// Holds the launch frame while the wordmark draws in a little. About half way the white
    /// letters fade, so the live app shows through their shapes while the rest is still black.
    /// Then the wordmark zooms into the stem of its "T" until the stem covers the screen, which
    /// it does at `fillScale`, and a fifth past it, so the whole app shows before the end.
    static func cutout(fillScale: Double) -> Self {
        let duration = 0.8
        // One key per frame at 60 Hz.
        let samples = 48
        // Beats, as fractions of the duration.
        let hold = 0.06
        let drawIn = (end: 0.48, scale: 0.9)
        let groundFade = (start: 0.34, end: 0.4)
        let lettersFade = (start: 0.4, end: 0.56)
        let coverFade = (start: 0.94, end: 1.0)
        let endScale = 1.2 * fillScale
        return Self(
            duration: duration,
            statusBarTime: 0.05 * duration,
            // Under the cover it only shows through the letters, so it goes just before they fade.
            backdropOpacity: Track(samples: samples) { 1 - ramp($0, groundFade.start, groundFade.end) },
            lettersOpacity: Track(samples: samples) {
                1 - smoothstep(ramp($0, lettersFade.start, lettersFade.end))
            },
            // The stem covers the screen by then; the cover goes so that the last frame is the app.
            coverOpacity: Track(samples: samples) { 1 - ramp($0, coverFade.start, coverFade.end) },
            // The zoom eases in log scale, so it reads as one steady dive rather than a slow
            // start and a sudden rush at the end.
            scale: Track(samples: samples) { progress in
                progress < drawIn.end
                    ? 1 - (1 - drawIn.scale) * smoothstep(ramp(progress, hold, drawIn.end))
                    : drawIn.scale * pow(endScale / drawIn.scale, smoothstep(ramp(progress, drawIn.end, 1)))
            }
        )
    }

    /// Reduce Motion: nothing moves; a short fade after the launch frame.
    static let reducedMotion: Self = {
        let duration = 0.35
        let hold = 0.1 / duration
        let fade = { (progress: Double) in easeOut(ramp(progress, hold, 1)) }
        return Self(
            duration: duration,
            statusBarTime: hold * duration / 2,
            backdropOpacity: Track(samples: 16) { 1 - fade($0) },
            lettersOpacity: Track(samples: 16) { 1 - fade($0) },
            coverOpacity: .constant(0),
            scale: .constant(1)
        )
    }()

    func value(of track: Track, at time: TimeInterval) -> Double {
        track.value(atProgress: clamp(time / duration))
    }

    /// Nil for a track that never changes.
    func animation(_ keyPath: String, _ track: Track, value: (Double) -> Any) -> CAKeyframeAnimation? {
        track.isConstant ? nil : animation(keyPath, keyTimes: track.keyTimes, values: track.values.map(value))
    }

    func animation(_ keyPath: String, keyTimes: [Double], values: [Any]) -> CAKeyframeAnimation {
        let animation = CAKeyframeAnimation(keyPath: keyPath)
        animation.duration = duration
        animation.keyTimes = keyTimes.map { NSNumber(value: $0) }
        animation.values = values
        animation.calculationMode = .linear
        return animation
    }
}

nonisolated private func clamp(_ value: Double) -> Double { min(max(value, 0), 1) }
/// 0 before `start`, 1 after `end`, linear between.
nonisolated private func ramp(_ progress: Double, _ start: Double, _ end: Double) -> Double {
    clamp((progress - start) / (end - start))
}
nonisolated private func smoothstep(_ x: Double) -> Double { x * x * (3 - 2 * x) }
nonisolated private func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
