//
//  LaunchSplashUITests.swift
//  BeTrueUITests
//

import XCTest

/// These tests put the DEBUG-only preview fixture (`-LaunchSplashPreviewFixture YES`) under the
/// splash, so they find and tap the same control whatever the network-backed gallery shows.
/// `testLaunchWithoutTheFixtureArgumentShowsNoFixture` covers the normal launch.
final class LaunchSplashUITests: XCTestCase {
    /// Just past half way, when the app shows through the letters and black still covers the rest.
    private static let midReveal = "0.45"

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testSplashFinishesAndRevealsTheApp() {
        let app = launch()
        assertSplashGone(in: app, within: 4)
    }

    @MainActor
    func testReducedMotionFinishes() {
        let app = launch(arguments: ["-LaunchSplashReduceMotion", "YES"])
        assertSplashGone(in: app, within: 3)
    }

    @MainActor
    func testLaunchWithoutTheFixtureArgumentShowsNoFixture() {
        let app = launch(withFixture: false)
        // An unfrozen splash can finish before launch() returns, so only its end is awaited here;
        // the frozen launches above show that it appears.
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        XCTAssertTrue(app.otherElements["launchSplash"].waitForNonExistence(timeout: 4), "Splash still present")
        XCTAssertFalse(app.otherElements["previewFixture"].exists)
        XCTAssertFalse(fixtureToggle(in: app).exists)
    }

    @MainActor
    func testAppIsBlockedWhileSplashIsShown() {
        for freezeAt in ["0", Self.midReveal] {
            let app = launch(arguments: ["-LaunchSplashFreezeAt", freezeAt])
            XCTAssertTrue(app.otherElements["launchSplash"].waitForExistence(timeout: 5))
            XCTAssertFalse(fixtureToggle(in: app).exists, "App reachable at \(freezeAt) s")
            app.terminate()
        }
    }

    @MainActor
    func testTapsDoNotReachTheAppWhileSplashIsShown() {
        var app = launch()
        assertSplashGone(in: app, within: 4)
        let toggleFrame = fixtureToggle(in: app).frame
        let value = fixtureToggle(in: app).value as? String
        app.terminate()

        // Held while the app already shows through.
        app = launch(arguments: ["-LaunchSplashFreezeAt", Self.midReveal])
        XCTAssertTrue(app.otherElements["launchSplash"].waitForExistence(timeout: 5))
        let togglePoint = app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: toggleFrame.midX, dy: toggleFrame.midY))
        togglePoint.tap()

        // Backgrounding ends the held splash; the tap must not have changed the toggle.
        XCUIDevice.shared.press(.home)
        app.activate()
        assertSplashGone(in: app, within: 4)
        XCTAssertEqual(fixtureToggle(in: app).value as? String, value)

        // Control: the same point does change it once the splash is gone.
        togglePoint.tap()
        XCTAssertNotEqual(fixtureToggle(in: app).value as? String, value)
    }

    @MainActor
    func testBackgroundingDuringSplashFinishesIt() {
        let app = launch(arguments: ["-LaunchSplashFreezeAt", "0"])
        XCTAssertTrue(app.otherElements["launchSplash"].waitForExistence(timeout: 5))

        XCUIDevice.shared.press(.home)
        app.activate()

        assertSplashGone(in: app, within: 4)
    }

    @MainActor
    func testSplashDoesNotReplayOnForeground() {
        let app = launch()
        assertSplashGone(in: app, within: 4)

        XCUIDevice.shared.press(.home)
        app.activate()

        XCTAssertTrue(fixtureToggle(in: app).waitForExistence(timeout: 5))
        XCTAssertFalse(app.otherElements["launchSplash"].exists)
    }

    @MainActor
    private func launch(arguments: [String] = [], withFixture: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = (withFixture ? ["-LaunchSplashPreviewFixture", "YES"] : []) + arguments
        app.launch()
        return app
    }

    /// The preview fixture's button, always on screen once the app is showing.
    @MainActor
    private func fixtureToggle(in app: XCUIApplication) -> XCUIElement {
        app.buttons["previewFixtureToggle"]
    }

    @MainActor
    private func assertSplashGone(in app: XCUIApplication, within timeout: TimeInterval,
                                  file: StaticString = #filePath, line: UInt = #line) {
        let button = fixtureToggle(in: app)
        XCTAssertTrue(button.waitForExistence(timeout: timeout), "App content never appeared", file: file, line: line)
        XCTAssertTrue(button.isHittable, "App content is not hittable", file: file, line: line)
        XCTAssertFalse(app.otherElements["launchSplash"].exists, "Splash still present", file: file, line: line)
    }
}
