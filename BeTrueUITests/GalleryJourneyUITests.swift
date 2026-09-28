import XCTest

/// The main journey against the live API: browse, open a photo, close it, search.
///
/// Skipped when no API key is configured, because the app then shows setup guidance instead of photos.
final class GalleryJourneyUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testBrowseOpenCloseAndSearch() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-LaunchSplashReduceMotion", "YES"]
        app.launch()
        XCTAssertTrue(app.buttons["appearanceToggle"].waitForExistence(timeout: 5))
        try XCTSkipIf(app.otherElements["missingAPIKey"].exists, "No API key configured")

        let firstTile = app.buttons.matching(identifier: "photoTile").firstMatch
        XCTAssertTrue(firstTile.waitForExistence(timeout: 15), "Feed never showed a photo")
        firstTile.tap()

        let close = app.buttons["viewerClose"]
        XCTAssertTrue(close.waitForExistence(timeout: 5), "Viewer did not open")
        close.tap()
        XCTAssertTrue(close.waitForNonExistence(timeout: 5), "Viewer did not close")
        XCTAssertTrue(firstTile.isHittable, "Feed is not back where it was")

        // The search sits above the feed and fills the same grid, so its results replace the curated photos.
        let curatedLabel = firstTile.label
        let searchField = app.textFields["searchField"]
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("forest\n")
        XCTAssertTrue(firstTile.waitForLabel(otherThan: curatedLabel, timeout: 15), "Search showed no results")
    }
}

private extension XCUIElement {
    /// XCTest on iOS 16 has no built-in wait for disappearance.
    func waitForNonExistence(timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == false")
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }

    /// Waits for the element to show something else, such as a grid's first photo after new results arrive.
    func waitForLabel(otherThan label: String, timeout: TimeInterval) -> Bool {
        let predicate = NSPredicate(format: "exists == true AND label != %@", label)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: self)
        return XCTWaiter.wait(for: [expectation], timeout: timeout) == .completed
    }
}
