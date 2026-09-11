import XCTest

/// TASK-010 Requirement 2 — trivial UI smoke for the `Momo` iPhone app
/// (05 §10.1 `MomoUITests`). TASK-032's gate (R1) routes a fresh store to
/// onboarding, so this smoke walks the three-step flow (its own throwaway
/// store — the R13 launch-argument enabler) before asserting the 3-tab
/// shell (UX-1: Home · Room · Settings) is reachable; the flow's own pins
/// live in `MomoOnboardingUITests`. Real FR coverage (core loop, settings,
/// accessibility audit) lands in later epics per 05 §10.6.
///
/// `@MainActor` (TASK-039 R4): XCTest test methods run on the main actor,
/// so the unannotated class triggered one actor-isolation warning per
/// `async`-propagating method under Swift 6's default isolation — 19 in
/// the pre-consolidation tree. The annotation retires them; XCUIApplication
/// interaction is main-actor work anyway.
@MainActor
final class MomoUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLaunchShowsTabBar() {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory",
            "momo-smoke-uitest-\(UUID().uuidString)",
        ]
        app.launch()
        XCTAssertTrue(
            app.staticTexts["This little one just moved in."].waitForExistence(timeout: 10),
            "a fresh store should open on onboarding S1"
        )
        app.buttons["Say hello"].tap()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()
        app.buttons["Begin"].tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Momo's 3-tab shell should be reachable after onboarding"
        )
    }
}
