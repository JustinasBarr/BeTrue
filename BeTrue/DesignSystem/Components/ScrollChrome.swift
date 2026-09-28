import Combine
import QuartzCore
import SwiftUI

/// What the floating chrome shows while content scrolls: how far the tab bar has shrunk, and whether the
/// screen's pinned header (the search) is on screen.
struct ScrollChrome: Equatable {
    struct Bar: Equatable {
        /// 0 at full size, 1 at the smallest size.
        var shrink: Double
        /// How the bar springs to this size. Faster scrolling makes it quicker.
        var spring: ChromeSpring
    }

    struct Header: Equatable {
        var isShown: Bool
        var spring: ChromeSpring
    }

    var bar: Bar
    var header: Header

    /// Everything at full size, as at the top of the content.
    static let top = ScrollChrome(bar: Bar(shrink: 0, spring: .settle),
                                  header: Header(isShown: true, spring: .settle))
}

/// A spring as plain numbers, so the timing chosen from scroll speed stays comparable.
struct ChromeSpring: Equatable {
    let response: Double
    let dampingFraction: Double

    /// Returning to the top, or after a tab change. Matches `Motion.quick`.
    static let settle = ChromeSpring(response: 0.3, dampingFraction: 0.9)
    /// The bar popping back to full size once scrolling stops.
    static let pop = ChromeSpring(response: 0.4, dampingFraction: 0.65)

    var animation: Animation { .spring(response: response, dampingFraction: dampingFraction) }
}

/// Turns scroll offsets into chrome states.
///
/// Scrolling down hides the header and shrinks the bar by scroll speed: a slow scroll leaves it at full size,
/// a fling takes it to the smallest size. The bar keeps the smallest size the scroll reached and pops back to
/// full size once scrolling stops. Scrolling up shows the header and restores the bar, but only after a longer
/// pull, so a small correction does not bring the header back.
struct ScrollChromeMachine {
    enum Constants {
        /// Travel down before the header hides and the bar may shrink.
        static let hideDistance: CGFloat = 12
        /// Travel up before the header comes back and the bar returns to full size.
        static let revealDistance: CGFloat = 100
        /// Offsets closer to the top than this always show everything.
        static let topZone: CGFloat = 24
        /// Ignores sub-pixel layout noise.
        static let jitter: CGFloat = 0.5
        /// Below this speed, in points per second, the bar keeps its full size.
        static let shrinkStartSpeed = 400.0
        /// At this speed and above, the bar is at its smallest.
        static let fullShrinkSpeed = 3000.0
        /// The bar shrinks in steps this big, so the chrome changes a few times per scroll, not every frame.
        static let shrinkStep = 0.1
        /// At this speed, in points per second, a change takes `normalDuration`.
        static let normalSpeed = 1000.0
        static let normalDuration = 0.4
        static let shortestDuration = 0.24
        static let longestDuration = 0.6
        /// Shrinking settles with a small overshoot, growing with a bigger one, so both read as a pop.
        static let shrinkDamping = 0.75
        static let growDamping = 0.65
        /// The header moves without bounce both ways: an overshoot would show its edge jiggling.
        static let headerDamping = 1.0
        /// How much each new sample moves the smoothed speed.
        static let speedSmoothing = 0.35
        /// Bounds the time between samples so a long pause or a double-reported frame cannot skew speed.
        static let shortestSampleGap = 1.0 / 240
        static let longestSampleGap = 1.0 / 30
    }

    private enum Direction {
        case downward
        case upward
    }

    private(set) var chrome = ScrollChrome.top
    /// Smoothed scroll speed in points per second.
    private(set) var speed = 0.0

    private var lastOffset: CGFloat?
    private var lastSampleTime: TimeInterval = 0
    private var direction: Direction?
    /// Travel in `direction` since the run started.
    private var travel: CGFloat = 0

    /// How long a change takes at the current speed.
    var changeDuration: Double {
        let scaled = Constants.normalDuration * (Constants.normalSpeed / max(speed, 1)).squareRoot()
        return min(max(scaled, Constants.shortestDuration), Constants.longestDuration)
    }

    /// `offset` is the content's distance from the top: 0 at rest, negative as it scrolls down,
    /// positive while pulled to refresh.
    mutating func scroll(to offset: CGFloat, at time: TimeInterval) {
        guard let lastOffset else { return record(offset, at: time) }
        if offset > -Constants.topZone {
            record(offset, at: time)
            endRun()
            chrome = ScrollChrome(bar: bar(shrink: 0, spring: .settle), header: header(isShown: true, spring: .settle))
            return
        }
        let delta = offset - lastOffset
        // A slow drag moves less than this each frame, so it counts once it adds up.
        guard abs(delta) >= Constants.jitter else { return }
        let gap = min(max(time - lastSampleTime, Constants.shortestSampleGap), Constants.longestSampleGap)
        record(offset, at: time)
        let sampleSpeed = Double(abs(delta)) / gap
        let movement: Direction = delta < 0 ? .downward : .upward
        if movement == direction {
            speed += Constants.speedSmoothing * (sampleSpeed - speed)
        } else {
            endRun()
            direction = movement
            speed = sampleSpeed
        }
        travel += abs(delta)
        switch movement {
        case .downward:
            guard travel >= Constants.hideDistance else { return }
            let shrink = max(chrome.bar.shrink, shrink(at: speed))
            chrome = ScrollChrome(bar: bar(shrink: shrink, spring: spring(damping: Constants.shrinkDamping)),
                                  header: header(isShown: false, spring: spring(damping: Constants.headerDamping)))
        case .upward:
            guard travel >= Constants.revealDistance else { return }
            chrome = ScrollChrome(bar: bar(shrink: 0, spring: spring(damping: Constants.growDamping)),
                                  header: header(isShown: true, spring: spring(damping: Constants.headerDamping)))
        }
    }

    /// Scrolling stopped: the bar pops back to full size, and the header stays as it is.
    mutating func rest() {
        endRun()
        chrome.bar = bar(shrink: 0, spring: .pop)
    }

    /// Shows everything and forgets the last offset, as when another tab's content takes over.
    mutating func reset() {
        self = ScrollChromeMachine()
    }

    /// Zero below `shrinkStartSpeed`, rising quickly past it and easing toward 1, in whole steps.
    private func shrink(at speed: Double) -> Double {
        let range = Constants.fullShrinkSpeed - Constants.shrinkStartSpeed
        let progress = min(max((speed - Constants.shrinkStartSpeed) / range, 0), 1)
        return (progress.squareRoot() / Constants.shrinkStep).rounded(.down) * Constants.shrinkStep
    }

    private func spring(damping: Double) -> ChromeSpring {
        ChromeSpring(response: changeDuration, dampingFraction: damping)
    }

    /// The new bar, or the current one unchanged when its size stays, so its spring does not churn.
    private func bar(shrink: Double, spring: ChromeSpring) -> ScrollChrome.Bar {
        shrink == chrome.bar.shrink ? chrome.bar : ScrollChrome.Bar(shrink: shrink, spring: spring)
    }

    /// The new header, or the current one unchanged when its visibility stays.
    private func header(isShown: Bool, spring: ChromeSpring) -> ScrollChrome.Header {
        isShown == chrome.header.isShown ? chrome.header : ScrollChrome.Header(isShown: isShown, spring: spring)
    }

    private mutating func record(_ offset: CGFloat, at time: TimeInterval) {
        lastOffset = offset
        lastSampleTime = time
    }

    private mutating func endRun() {
        direction = nil
        travel = 0
    }
}

/// Feeds scroll offsets to a `ScrollChromeMachine` and tells it when scrolling has stopped.
///
/// Offsets arrive every frame; `chrome` changes only when the bar's size step or the header changes.
final class ScrollChromeModel: ObservableObject {
    private enum Constants {
        static let restDelay = 0.6
    }

    @Published private(set) var chrome = ScrollChrome.top

    private var machine = ScrollChromeMachine()
    private var restDeadline: TimeInterval = 0
    private var restTask: Task<Void, Never>?

    func scrolled(to offset: CGFloat) {
        let now = CACurrentMediaTime()
        machine.scroll(to: offset, at: now)
        publish()
        restDeadline = now + Constants.restDelay
        if restTask == nil {
            restTask = Task { await waitForRest() }
        }
    }

    func reset() {
        restTask?.cancel()
        restTask = nil
        machine.reset()
        publish()
    }

    /// One task per scroll, pushed back by each new offset, rather than a new task every frame.
    private func waitForRest() async {
        while !Task.isCancelled {
            let remaining = restDeadline - CACurrentMediaTime()
            guard remaining > 0 else { break }
            try? await Task.sleep(for: .seconds(remaining))
        }
        guard !Task.isCancelled else { return }
        restTask = nil
        machine.rest()
        publish()
    }

    private func publish() {
        guard machine.chrome != chrome else { return }
        chrome = machine.chrome
    }
}
