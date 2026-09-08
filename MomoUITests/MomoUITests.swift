import XCTest

/// TASK-010 Requirement 2 — trivial UI smoke for the `Momo` iPhone app
/// (05 §10.1 `MomoUITests`). Launch + one element exists: the 3-tab shell
/// (UX-1: Home · Room · Settings) is reachable. Real FR coverage
/// (onboarding, core loop, settings, accessibility audit) lands in later
/// epics per 05 §10.6.
final class MomoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsTabBar() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Momo's 3-tab shell should be reachable at launch"
        )
    }
}
