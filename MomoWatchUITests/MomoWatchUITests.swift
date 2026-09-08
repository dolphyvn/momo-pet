import XCTest

/// TASK-010 Requirement 2 — trivial UI smoke for the `MomoWatch` watchOS app
/// (05 §10.1 `MomoWatchUITests`). Launch + one element exists: the W1-spirit
/// glance renders text. Pat flow, snapshot restore and AOD static rendering
/// land in later epics per 05 §10.6 (device obligations stay device-verified).
final class MomoWatchUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsGlanceText() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.staticTexts.firstMatch.waitForExistence(timeout: 10),
            "MomoWatch's placeholder glance should render at launch"
        )
    }
}
