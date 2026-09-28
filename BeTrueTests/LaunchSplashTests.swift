//
//  LaunchSplashTests.swift
//  BeTrueTests
//

import QuartzCore
import Testing
import UIKit
@testable import BeTrue

@MainActor
struct LaunchSplashTests {

    /// iPhone SE, iPhone 17 and iPhone 17 Pro Max in portrait, and iPhone 17 in landscape.
    nonisolated static let screens = [
        CGSize(width: 375, height: 667),
        CGSize(width: 402, height: 874),
        CGSize(width: 440, height: 956),
        CGSize(width: 874, height: 402)
    ]

    @Test func launchScreenIsBlackWithWhiteWordmark() throws {
        let view = try #require(LaunchSplashView.loadLaunchScreen())
        let label = try #require(view.subviews.compactMap { $0 as? UILabel }.first)

        #expect(view.backgroundColor?.cgColor.components == [0, 0, 0, 1])
        #expect(label.text == "BeTrue.")
        #expect(label.textColor.cgColor.components == [1, 1, 1, 1])
        #expect(label.font.fontName == "HelveticaNeue-Bold")
    }

    @Test func cutoutLastsUnderASecond() throws {
        #expect((0.7...0.9).contains(try Self.cutoutTimeline().duration))
    }

    @Test func cutoutStartsOnTheLaunchFrameAndEndsOnTheApp() throws {
        let cutout = try Self.cutoutTimeline()
        // First frame equals the static launch screen.
        #expect(cutout.value(of: cutout.backdropOpacity, at: 0) == 1)
        #expect(cutout.value(of: cutout.lettersOpacity, at: 0) == 1)
        #expect(cutout.value(of: cutout.coverOpacity, at: 0) == 1)
        #expect(cutout.value(of: cutout.scale, at: 0) == 1)
        // Last frame shows only the app.
        #expect(cutout.value(of: cutout.backdropOpacity, at: cutout.duration) == 0)
        #expect(cutout.value(of: cutout.lettersOpacity, at: cutout.duration) == 0)
        #expect(cutout.value(of: cutout.coverOpacity, at: cutout.duration) == 0)
    }

    @Test func appShowsThroughTheLetterShapesFromHalfWay() throws {
        let cutout = try Self.cutoutTimeline()
        let time = { (fraction: Double) in fraction * cutout.duration }
        #expect(Self.transmittance(cutout, at: time(0.35), inLetters: true) <= 0.01,
                "The letters are still white")
        #expect(Self.transmittance(cutout, at: time(0.6), inLetters: true) >= 0.99,
                "The app shows through the letters")
        #expect(Self.transmittance(cutout, at: time(0.6), inLetters: false) <= 0.01,
                "Around the letters is still black")
    }

    @Test(arguments: screens)
    func liveViewShowsFromAboutHalfWay(screen: CGSize) throws {
        let cutout = try Self.cutout(on: screen)
        let timeline = LaunchSplashTimeline.cutout(fillScale: cutout.fillScale)
        let visible = { (fraction: Double) in
            Self.visibleFraction(timeline, cutout, at: fraction * timeline.duration)
        }

        #expect(visible(0.35) == 0, "Nothing shows through before the letters fade")
        #expect(visible(0.5) > 0.001, "The live view shows through the letters at half way")
        #expect(visible(0.75) > 0.1, "The letters open up as they zoom")
        #expect(visible(0.95) == 1, "The stem covers the screen before the end")
        #expect(visible(1) == 1, "The last frame covers nothing")
    }

    /// Every layer only ever uncovers more of the app, and the zoom only draws in before it
    /// zooms out.
    @Test func revealNeverGoesBack() throws {
        let cutout = try Self.cutoutTimeline()
        for fading in [cutout.backdropOpacity, cutout.lettersOpacity, cutout.coverOpacity] {
            #expect(zip(fading.values, fading.values.dropFirst()).allSatisfy { $0 >= $1 })
        }
        let scale = cutout.scale.values
        let turn = try #require(scale.indices.min { scale[$0] < scale[$1] })
        #expect(zip(scale[...turn], scale[...turn].dropFirst()).allSatisfy { $0 >= $1 })
        #expect(zip(scale[turn...], scale[turn...].dropFirst()).allSatisfy { $0 <= $1 })
        #expect(scale[turn] >= 0.85, "The draw-in stays slight")
    }

    /// The white wordmark is gone before the letters grow much.
    @Test func whiteLettersFadeBeforeTheyGrow() throws {
        let cutout = try Self.cutoutTimeline()
        #expect(cutout.value(of: cutout.lettersOpacity, at: 0.1 * cutout.duration) == 1)
        for (letters, scale) in zip(cutout.lettersOpacity.values, cutout.scale.values) where letters > 0.02 {
            #expect(scale <= 1.2, "White letters at \(letters) opacity scaled by \(scale)")
        }
    }

    @Test(arguments: screens)
    func statusBarReturnsBeforeAnythingShowsThrough(screen: CGSize) throws {
        let cutout = try Self.cutout(on: screen)
        for timeline in [LaunchSplashTimeline.cutout(fillScale: cutout.fillScale), .reducedMotion] {
            #expect(timeline.statusBarTime > 0)
            #expect(Self.visibleFraction(timeline, cutout, at: timeline.statusBarTime) == 0)
        }
    }

    @Test(arguments: screens)
    func cutoutStaysBlackWhileTheStatusBarAppears(screen: CGSize) throws {
        let cutout = try Self.cutout(on: screen)
        let timeline = LaunchSplashTimeline.cutout(fillScale: cutout.fillScale)
        // Margin for the status bar's own appearance animation.
        let settled = timeline.statusBarTime + 0.05
        #expect(Self.visibleFraction(timeline, cutout, at: settled) == 0)
    }

    @Test func reducedMotionIsAShortFadeWithoutMovement() throws {
        let fade = LaunchSplashTimeline.reducedMotion
        #expect(fade.duration <= 0.5)
        #expect(!fade.cutsOutLetters)
        #expect(fade.scale.values.allSatisfy { $0 == 1 })
        #expect(fade.value(of: fade.backdropOpacity, at: 0) == 1)
        #expect(fade.value(of: fade.backdropOpacity, at: fade.duration) == 0)
        #expect(fade.value(of: fade.lettersOpacity, at: fade.duration) == 0)
        #expect(try Self.cutoutTimeline().cutsOutLetters)
    }

    @Test(arguments: screens)
    func tracksAreWellFormedKeyframes(screen: CGSize) throws {
        let cutout = LaunchSplashTimeline.cutout(fillScale: try Self.cutout(on: screen).fillScale)
        for track in cutout.tracks + LaunchSplashTimeline.reducedMotion.tracks {
            #expect(track.keyTimes.count == track.values.count)
            #expect(track.keyTimes.first == 0)
            #expect(track.keyTimes.last == 1)
            #expect(zip(track.keyTimes, track.keyTimes.dropFirst()).allSatisfy { $0 < $1 })
        }
    }

    /// The cutout's glyphs cover the same pixels as the wordmark's own ink, so the white letters
    /// hand over to the live app in the same shapes, counters included.
    @Test(arguments: screens)
    func cutoutMatchesTheWordmarkInk(screen: CGSize) throws {
        let (launchScreen, wordmark) = try Self.launchScreen(on: screen)
        let cutout = try #require(LaunchSplashCutout(wordmark: wordmark, in: launchScreen))
        let region = wordmark.frame.insetBy(dx: -4, dy: -4)
        let label = Self.ink(in: region) { context in
            // UILabel's own text drawing, where its layer shows it.
            context.translateBy(x: wordmark.frame.minX, y: wordmark.frame.minY)
            wordmark.drawText(in: wordmark.bounds)
        }
        let glyphs = Self.ink(in: region) { context in
            context.addPath(cutout.glyphs)
            context.setFillColor(UIColor.white.cgColor)
            context.fillPath(using: .evenOdd)
        }

        try #require(label.pixels.filter { $0 > 127 }.count > 1000)
        // Every edge within half a point (one pixel) of the other's, so no stroke, counter or
        // glyph is missing, extra or misplaced. Anti-aliasing differs between text and path
        // drawing, so single edge pixels may still differ.
        #expect(Self.strays(label, from: glyphs) == 0, "Label ink with no cutout nearby")
        #expect(Self.strays(glyphs, from: label) == 0, "Cutout with no label ink nearby")
        // And overall within a quarter point.
        let labelCentroid = Self.centroid(label)
        let glyphsCentroid = Self.centroid(glyphs)
        #expect(abs(labelCentroid.x - glyphsCentroid.x) <= Self.inkScale / 4)
        #expect(abs(labelCentroid.y - glyphsCentroid.y) <= Self.inkScale / 4)
    }

    /// The cover spans the screen at every scale, and the zoom ends inside solid ink, where the
    /// whole screen shows the app.
    @Test(arguments: screens)
    func coverSpansTheScreenAndTheZoomEndsInsideALetter(screen: CGSize) throws {
        let (launchScreen, wordmark) = try Self.launchScreen(on: screen)
        let cutout = try #require(LaunchSplashCutout(wordmark: wordmark, in: launchScreen))
        let timeline = LaunchSplashTimeline.cutout(fillScale: cutout.fillScale)
        let screenBounds = launchScreen.bounds

        #expect(wordmark.frame.insetBy(dx: -1, dy: -1).contains(cutout.glyphs.boundingBoxOfPath))
        let cover = cutout.coverPath.boundingBoxOfPath
        for scale in timeline.scale.values {
            let zoomed = cover.applying(Self.zoom(scale, about: cutout.zoomAnchor))
            #expect(zoomed.contains(screenBounds), "The cover leaves the screen's edge bare at \(scale)")
        }
        let steps = (0...8).map { CGFloat($0) / 8 }
        let landing = cutout.landing
        #expect(steps.allSatisfy { across in
            steps.allSatisfy { down in
                cutout.glyphs.contains(CGPoint(x: landing.minX + across * landing.width,
                                               y: landing.minY + down * landing.height), using: .evenOdd)
            }
        }, "The landing is all ink")
        let endScale = try #require(timeline.scale.values.last)
        #expect(landing.applying(Self.zoom(endScale, about: cutout.zoomAnchor)).contains(screenBounds))
    }

    @Test func previewFixtureIsOffWithoutItsLaunchArgument() {
        #expect(!LaunchSplashSettings.current.showsPreviewFixture)
    }

    // MARK: - Helpers

    /// The pixels per point that ink is compared at.
    private static let inkScale: CGFloat = 2

    private static func launchScreen(on screen: CGSize) throws -> (UIView, UILabel) {
        let view = try #require(LaunchSplashView.loadLaunchScreen())
        view.frame = CGRect(origin: .zero, size: screen)
        view.layoutIfNeeded()
        let wordmark = try #require(view.subviews.compactMap { $0 as? UILabel }.first)
        return (view, wordmark)
    }

    private static func cutout(on screen: CGSize) throws -> LaunchSplashCutout {
        let (launchScreen, wordmark) = try launchScreen(on: screen)
        return try #require(LaunchSplashCutout(wordmark: wordmark, in: launchScreen))
    }

    /// The cutout timeline on the iPhone 17 in portrait.
    private static func cutoutTimeline() throws -> LaunchSplashTimeline {
        .cutout(fillScale: try cutout(on: screens[1]).fillScale)
    }

    /// Scales by `scale` about `anchor`, as the splash scales the wordmark and the cover.
    private static func zoom(_ scale: Double, about anchor: CGPoint) -> CGAffineTransform {
        CGAffineTransform(translationX: anchor.x, y: anchor.y)
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: -anchor.x, y: -anchor.y)
    }

    /// How much of the app shows at `time` at a point inside or outside the letters: through
    /// the launch screen's ground, then the white letters or the cover around them.
    private static func transmittance(_ timeline: LaunchSplashTimeline, at time: TimeInterval,
                                      inLetters: Bool) -> Double {
        let value = { (track: LaunchSplashTimeline.Track) in timeline.value(of: track, at: time) }
        let ground = 1 - value(timeline.backdropOpacity)
        return ground * (1 - value(inLetters ? timeline.lettersOpacity : timeline.coverOpacity))
    }

    /// Share of the screen where the live view shows through at `time`, sampled on a grid.
    private static func visibleFraction(_ timeline: LaunchSplashTimeline, _ cutout: LaunchSplashCutout,
                                        at time: TimeInterval, samples: Int = 64) -> Double {
        let unscaled = zoom(timeline.value(of: timeline.scale, at: time), about: cutout.zoomAnchor).inverted()
        let letterBounds = cutout.glyphs.boundingBoxOfPath
        let bounds = cutout.bounds
        var visible = 0.0
        for column in 0..<samples {
            for row in 0..<samples {
                let point = CGPoint(x: bounds.minX + (CGFloat(column) + 0.5) * bounds.width / CGFloat(samples),
                                    y: bounds.minY + (CGFloat(row) + 0.5) * bounds.height / CGFloat(samples))
                    .applying(unscaled)
                let inLetters = letterBounds.contains(point) && cutout.glyphs.contains(point, using: .evenOdd)
                visible += transmittance(timeline, at: time, inLetters: inLetters)
            }
        }
        return visible / Double(samples * samples)
    }

    /// Grey levels of white-on-black drawing in `region`, row by row at `inkScale`.
    private static func ink(in region: CGRect, draw: (CGContext) -> Void) -> (pixels: [UInt8], width: Int) {
        let format = UIGraphicsImageRendererFormat()
        format.scale = inkScale
        format.opaque = true
        let image = UIGraphicsImageRenderer(size: region.size, format: format).image { context in
            UIColor.black.setFill()
            context.fill(CGRect(origin: .zero, size: region.size))
            context.cgContext.translateBy(x: -region.minX, y: -region.minY)
            draw(context.cgContext)
        }
        guard let cgImage = image.cgImage else { return ([], 0) }
        var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height)
        pixels.withUnsafeMutableBytes { buffer in
            let context = CGContext(data: buffer.baseAddress, width: cgImage.width, height: cgImage.height,
                                    bitsPerComponent: 8, bytesPerRow: cgImage.width,
                                    space: CGColorSpaceCreateDeviceGray(),
                                    bitmapInfo: CGImageAlphaInfo.none.rawValue)
            context?.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
        }
        return (pixels, cgImage.width)
    }

    /// Pixels over half inked in `ink` with no pixel over a quarter inked in `other` within one
    /// pixel.
    private static func strays(_ ink: (pixels: [UInt8], width: Int),
                               from other: (pixels: [UInt8], width: Int)) -> Int {
        let width = ink.width, height = ink.pixels.count / max(width, 1)
        var strays = 0
        for y in 0..<height {
            for x in 0..<width where ink.pixels[y * width + x] > 127 {
                let near = (max(y - 1, 0)...min(y + 1, height - 1)).contains { nearY in
                    (max(x - 1, 0)...min(x + 1, width - 1)).contains { nearX in
                        other.pixels[nearY * width + nearX] > 63
                    }
                }
                if !near { strays += 1 }
            }
        }
        return strays
    }

    /// Ink-weighted centre, in pixels.
    private static func centroid(_ ink: (pixels: [UInt8], width: Int)) -> CGPoint {
        var total = 0.0, x = 0.0, y = 0.0
        for (index, level) in ink.pixels.enumerated() {
            let weight = Double(level)
            total += weight
            x += weight * Double(index % ink.width)
            y += weight * Double(index / ink.width)
        }
        return total > 0 ? CGPoint(x: x / total, y: y / total) : .zero
    }
}
