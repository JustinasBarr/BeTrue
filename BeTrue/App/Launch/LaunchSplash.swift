//
//  LaunchSplash.swift
//  BeTrue
//

import SwiftUI
import UIKit

extension View {
    /// Covers this view with the launch screen, then reveals it through the wordmark's letters
    /// and zooms into them until it fills the screen.
    ///
    /// Keep `isPresented` on the `App`, not the window, so a second window or a return from the
    /// background never replays the splash.
    func launchSplash(isPresented: Binding<Bool>) -> some View {
        modifier(LaunchSplashModifier(isPresented: isPresented))
    }
}

private struct LaunchSplashModifier: ViewModifier {
    @Binding var isPresented: Bool
    /// The native launch screen hides the status bar (`UIStatusBarHidden`). It stays hidden across
    /// the handoff and returns before anything shows through, so a safe-area change on
    /// home-button iPhones happens under black.
    @State private var hidesStatusBar = true
    @Environment(\.scenePhase) private var scenePhase

    func body(content: Content) -> some View {
        content
            .overlay { previewFixture }
            .accessibilityHidden(isPresented)
            .overlay {
                if isPresented {
                    LaunchSplashOverlayView(
                        onShowStatusBar: { hidesStatusBar = false },
                        onFinish: { isPresented = false })
                        .ignoresSafeArea()
                }
            }
            .statusBarHidden(isPresented && hidesStatusBar)
            .onChange(of: scenePhase) { phase in
                // Finish rather than pause: the app switcher snapshot and the next foreground
                // both show the app, never a half-played splash.
                if phase == .background { isPresented = false }
            }
    }

    /// Debug only: stand-in content under the splash, for captures and UI tests.
    @ViewBuilder private var previewFixture: some View {
        #if DEBUG
        if LaunchSplashSettings.current.showsPreviewFixture { LaunchSplashPreviewFixtureView() }
        #endif
    }
}

private struct LaunchSplashOverlayView: UIViewRepresentable {
    let onShowStatusBar: () -> Void
    let onFinish: () -> Void

    func makeUIView(context: Context) -> LaunchSplashView {
        LaunchSplashView(onShowStatusBar: onShowStatusBar, onFinish: onFinish)
    }

    func updateUIView(_ uiView: LaunchSplashView, context: Context) {}
}

/// Plays the splash on the LaunchScreen storyboard's own view, so its first frame is the static
/// launch screen. Motion is keyframed Core Animation (opacity, and a zoom on the wordmark and one
/// static shape layer), which runs on the render server even while the main thread is busy.
final class LaunchSplashView: UIView {
    private let onShowStatusBar: () -> Void
    private let onFinish: () -> Void
    private let launchScreen: UIView?
    private var startedSize: CGSize?
    private var isFinished = false
    private weak var blockedWindow: UIWindow?
    private var windowAccessibilityElements: [Any]?

    init(onShowStatusBar: @escaping () -> Void, onFinish: @escaping () -> Void) {
        self.onShowStatusBar = onShowStatusBar
        self.onFinish = onFinish
        launchScreen = Self.loadLaunchScreen()
        super.init(frame: .zero)
        accessibilityIdentifier = "launchSplash"
        isAccessibilityElement = true
        accessibilityLabel = wordmark?.text
        if let launchScreen { addSubview(launchScreen) }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// The root view of the storyboard named by `UILaunchStoryboardName`.
    static func loadLaunchScreen(bundle: Bundle = .main) -> UIView? {
        guard let name = bundle.object(forInfoDictionaryKey: "UILaunchStoryboardName") as? String,
              bundle.url(forResource: name, withExtension: "storyboardc") != nil
        else { return nil }
        return UIStoryboard(name: name, bundle: bundle).instantiateInitialViewController()?.view
    }

    private var wordmark: UILabel? {
        launchScreen?.subviews.lazy.compactMap { $0 as? UILabel }.first
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard let window, !isFinished, blockedWindow == nil else { return }
        // SwiftUI's accessibilityHidden does not reach the UIKit navigation bar, so while the
        // splash covers the window it is the window's only accessibility element.
        windowAccessibilityElements = window.accessibilityElements
        window.accessibilityElements = [self]
        blockedWindow = window
        // The splash starts from layout, so make sure one follows now that it has a window.
        setNeedsLayout()
    }

    override func willMove(toWindow newWindow: UIWindow?) {
        super.willMove(toWindow: newWindow)
        if newWindow == nil { unblockWindow() }
    }

    private func unblockWindow() {
        blockedWindow?.accessibilityElements = windowAccessibilityElements
        blockedWindow = nil
        windowAccessibilityElements = nil
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        launchScreen?.frame = bounds
        guard !isFinished, window != nil, bounds.width > 0, bounds.height > 0 else { return }
        if let startedSize {
            // A rotation or resize mid-splash would restart the motion; cut to the app instead.
            if startedSize != bounds.size { finish() }
            return
        }
        startedSize = bounds.size
        start()
    }

    private func start() {
        guard let launchScreen, let wordmark, let ground = launchScreen.backgroundColor,
              window?.windowScene?.activationState != .background
        else {
            finish()
            return
        }
        launchScreen.layoutIfNeeded()

        let settings = LaunchSplashSettings.current
        // Without glyph outlines, or a solid stroke to zoom into, fade as for Reduce Motion.
        let cutout = settings.reduceMotion ? nil : LaunchSplashCutout(wordmark: wordmark, in: launchScreen)
        let timeline = cutout.map { LaunchSplashTimeline.cutout(fillScale: $0.fillScale) } ?? .reducedMotion

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        let scene = LaunchSplashScene(launchScreen: launchScreen, wordmark: wordmark, ground: ground,
                                      cutout: cutout, timeline: timeline)

        #if DEBUG
        if let freezeTime = settings.freezeTime {
            scene.pose(at: freezeTime)
            CATransaction.commit()
            return
        }
        #endif

        CATransaction.setCompletionBlock { [weak self] in self?.finish() }
        scene.play()
        CATransaction.commit()

        let onShowStatusBar = onShowStatusBar
        DispatchQueue.main.asyncAfter(deadline: .now() + timeline.statusBarTime) { onShowStatusBar() }
        // One-shot backstop in case the render server never reports completion.
        DispatchQueue.main.asyncAfter(deadline: .now() + timeline.duration + 1) { [weak self] in
            self?.finish()
        }
    }

    private func finish() {
        guard !isFinished else { return }
        isFinished = true
        unblockWindow()
        // Deferred: this can run inside a layout pass, where SwiftUI state must not change.
        let onFinish = onFinish
        DispatchQueue.main.async {
            onFinish()
            UIAccessibility.post(notification: .screenChanged, argument: nil)
        }
    }
}

/// The splash's layers on the launch screen view: the wordmark and, for the cutout, one black
/// shape layer covering the screen except for the wordmark's letters. The cover sits under the
/// wordmark and over the launch screen's own black ground, so the launch frame does not change
/// until that ground fades. The cover's path is built once; only its transform and opacity
/// animate. It has no sublayers, mask, blur or shadow. Its cost on physical devices has not been
/// measured.
private struct LaunchSplashScene {
    let timeline: LaunchSplashTimeline
    let launchScreen: UIView
    let ground: UIColor
    let letters: CALayer
    let cover: CAShapeLayer?
    /// Where the wordmark and the cover scale about, in the launch screen's coordinates, so the
    /// white letters stay over their cutout.
    let zoomAnchor: CGPoint

    init(launchScreen: UIView, wordmark: UILabel, ground: UIColor, cutout: LaunchSplashCutout?,
         timeline: LaunchSplashTimeline) {
        self.timeline = timeline
        self.launchScreen = launchScreen
        self.ground = ground
        letters = wordmark.layer
        zoomAnchor = cutout?.zoomAnchor ?? wordmark.center
        guard let cutout, timeline.cutsOutLetters else {
            cover = nil
            return
        }
        let cover = CAShapeLayer()
        cover.frame = launchScreen.bounds
        cover.path = cutout.coverPath
        cover.fillColor = ground.cgColor
        cover.fillRule = .evenOdd
        launchScreen.layer.insertSublayer(cover, at: 0)
        self.cover = cover
    }

    /// Sets every layer to its value at `time`, without animation.
    func pose(at time: TimeInterval) {
        let value = { (track: LaunchSplashTimeline.Track) in timeline.value(of: track, at: time) }
        launchScreen.layer.backgroundColor = backdropColor(value(timeline.backdropOpacity))
        letters.opacity = Float(value(timeline.lettersOpacity))
        letters.transform = zoom(letters, by: value(timeline.scale))
        guard let cover else { return }
        cover.transform = zoom(cover, by: value(timeline.scale))
        cover.opacity = Float(value(timeline.coverOpacity))
    }

    /// Poses the last frame, so nothing flashes when the animations are removed, then animates
    /// from the first frame to it.
    func play() {
        pose(at: timeline.duration)
        add(timeline.animation("backgroundColor", timeline.backdropOpacity, value: backdropColor),
            to: launchScreen.layer)
        add(timeline.animation("opacity", timeline.lettersOpacity) { Float($0) }, to: letters)
        add(timeline.animation("transform", timeline.scale) { zoomValue(letters, by: $0) }, to: letters)
        guard let cover else { return }
        add(timeline.animation("opacity", timeline.coverOpacity) { Float($0) }, to: cover)
        add(timeline.animation("transform", timeline.scale) { zoomValue(cover, by: $0) }, to: cover)
    }

    /// Scales `layer` about `zoomAnchor` rather than its own anchor point. Scale and offset are
    /// proportional, so keyframes in between still scale about the same point.
    private func zoom(_ layer: CALayer, by scale: Double) -> CATransform3D {
        var transform = CATransform3DMakeScale(scale, scale, 1)
        transform.m41 = (1 - scale) * (zoomAnchor.x - layer.position.x)
        transform.m42 = (1 - scale) * (zoomAnchor.y - layer.position.y)
        return transform
    }

    private func zoomValue(_ layer: CALayer, by scale: Double) -> NSValue {
        NSValue(caTransform3D: zoom(layer, by: scale))
    }

    private func backdropColor(_ opacity: Double) -> CGColor {
        ground.withAlphaComponent(ground.cgColor.alpha * opacity).cgColor
    }

    private func add(_ animation: CAKeyframeAnimation?, to layer: CALayer) {
        guard let animation, let keyPath = animation.keyPath else { return }
        layer.add(animation, forKey: "launchSplash.\(keyPath)")
    }
}

struct LaunchSplashSettings {
    var reduceMotion: Bool
    /// Debug only: hold the splash this many seconds into its timeline, for screenshots and tests.
    var freezeTime: TimeInterval?
    /// Debug only: show `LaunchSplashPreviewFixtureView` under the splash.
    var showsPreviewFixture = false

    static var current: Self {
        var settings = Self(reduceMotion: UIAccessibility.isReduceMotionEnabled, freezeTime: nil)
        #if DEBUG
        let arguments = UserDefaults.standard
        if arguments.bool(forKey: "LaunchSplashReduceMotion") { settings.reduceMotion = true }
        if arguments.object(forKey: "LaunchSplashFreezeAt") != nil {
            settings.freezeTime = arguments.double(forKey: "LaunchSplashFreezeAt")
        }
        settings.showsPreviewFixture = arguments.bool(forKey: "LaunchSplashPreviewFixture")
        #endif
        return settings
    }
}
