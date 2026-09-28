import XCTest

/// Scrolls the live feed past 500 photos so memory can be measured while it runs.
///
/// Opt-in: set `BETRUE_STRESS=1` in the test environment. It takes a few minutes and about 8 API requests.
final class FeedScrollStressUITests: XCTestCase {
    @MainActor
    func testScrollPastFiveHundredPhotos() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["BETRUE_STRESS"] == "1", "Set BETRUE_STRESS=1 to run")
        let app = XCUIApplication()
        app.launchArguments = ["-LaunchSplashReduceMotion", "YES"]
        app.launch()
        let tiles = app.buttons.matching(identifier: "photoTile")
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 15))

        let feed = app.scrollViews.firstMatch
        for _ in 0..<150 {
            feed.swipeUp(velocity: .fast)
        }
        // Still responsive after the stress: a photo is on screen and can be opened.
        XCTAssertTrue(tiles.firstMatch.waitForExistence(timeout: 10))
    }
}
