import XCTest

/// TASK-032's UI pins (Required Tests 7–9; UX §3; FR-1 AC-1/AC-2): the
/// fresh-install flow S1→S2→S3→Home, the kill/restart semantics around the
/// Enter tap, and the flow's VoiceOver labels at the label level. Every
/// launch runs against its own throwaway store via the disclosed R13
/// enabler (`-momo-store-directory <relative-name>` — the app resolves it
/// against its own temporary directory, so each test starts fresh and the
/// restart tests keep one store across a terminate/relaunch).
@MainActor
final class MomoOnboardingUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Required Test 7 — the fresh-install flow

    func testFreshStoreFlowsThroughThreeStepsToHome() {
        let app = freshApp()
        app.launch()
        // S1 — the move-in line and the flow button.
        XCTAssertTrue(
            app.staticTexts["This little one just moved in."].waitForExistence(timeout: 10),
            "S1 Meet should show the move-in line"
        )
        app.buttons["Say hello"].tap()
        // S2 — prefilled "Momo", whitespace rejected, the clear affordance.
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "S2 Name should show the name field")
        XCTAssertEqual(field.value as? String, "Momo", "the field arrives pre-filled")
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.exists)
        // Clear to empty, then whitespace-only: Continue stays disabled —
        // the disabled button IS the signal (no error copy, no shake).
        app.buttons["Clear name"].tap()
        field.tap()
        field.typeText("   ")
        XCTAssertFalse(
            continueButton.isEnabled,
            "whitespace-only input must keep Continue disabled"
        )
        // The disabled state is the observable validation signal here. The
        // UX-given HINT itself is not observable through XCUITest —
        // XCUIElementAttributes exposes no hint property (verified against
        // this toolchain's headers and the element's snapshot) — so the
        // hint's presence is established by code and verified manually in
        // TASK-039's full accessibility audit.
        // A real name enables Continue and carries into S3's payoff lines.
        app.buttons["Clear name"].tap()
        field.tap()
        field.typeText("Mochi")
        XCTAssertTrue(continueButton.isEnabled, "a valid name enables Continue")
        continueButton.tap()
        XCTAssertTrue(
            app.staticTexts["This is Mochi."].waitForExistence(timeout: 10),
            "S3 Enter interpolates the carried name"
        )
        XCTAssertTrue(app.staticTexts["Meet your new friend."].exists)
        // Begin is THE completion tap → Home.
        app.buttons["Begin"].tap()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "Begin lands on Home (the 3-tab shell)"
        )
    }

    // MARK: Required Test 8 — restart semantics

    func testKillBeforeEnterRestartsOnboardingFromS1() {
        let app = freshApp()
        app.launch()
        XCTAssertTrue(app.staticTexts["This little one just moved in."].waitForExistence(timeout: 10))
        app.buttons["Say hello"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        // Kill before Begin: the typed name lives in view state only, and
        // no completion write ever happened.
        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["This little one just moved in."].waitForExistence(timeout: 10),
            "without the Enter tap, onboarding restarts cleanly from S1"
        )
        XCTAssertFalse(app.tabBars.firstMatch.exists)
    }

    func testCompletedStoreLaunchesStraightToHome() {
        let app = freshApp()
        app.launch()
        walkFlowToHome(app)
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10))
        app.terminate()
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "after the Enter tap, every launch goes straight to Home"
        )
        XCTAssertFalse(
            app.staticTexts["This little one just moved in."].exists,
            "no onboarding step is visible post-completion"
        )
    }

    // MARK: Required Test 9 — a11y labels at the label level

    func testOnboardingAccessibilityLabels() {
        let app = freshApp()
        app.launch()
        XCTAssertTrue(app.staticTexts["This little one just moved in."].waitForExistence(timeout: 10))
        // The S1 canvas is ONE accessibility element with the UX-given label.
        let canvas = app.descendants(matching: .any)["A small creature looks up at you"]
        XCTAssertTrue(canvas.exists, "the canvas reads as one described element")
        XCTAssertTrue(app.buttons["Say hello"].exists)
        app.buttons["Say hello"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.label, "Pet name", "the field's accessibility label")
        XCTAssertTrue(app.buttons["Clear name"].exists, "the clear affordance is labeled")
        // The hint cannot be observed via XCUITest (no hint attribute in
        // XCUIElementAttributes — see the flow test's note); what IS
        // observable and pinned: the disabled state that the hint explains.
        app.buttons["Clear name"].tap()
        field.tap()
        field.typeText("   ")
        XCTAssertFalse(
            app.buttons["Continue"].isEnabled,
            "the disabled state the hint explains is pinned at the label level"
        )
        app.buttons["Clear name"].tap()
        field.tap()
        field.typeText("Mochi")
        app.buttons["Continue"].tap()
        XCTAssertTrue(app.staticTexts["This is Mochi."].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Begin"].exists)
    }

    // MARK: Helpers

    /// Every test runs against its own throwaway store: a unique relative
    /// name per launch, resolved by the app against ITS OWN temporary
    /// directory (the disclosed R13 interpretation — the runner and the
    /// app-under-test live in different sandboxes, so the app performs the
    /// resolution). A unique name per test means a fresh store at every
    /// launch; the restart tests reuse ONE configured app across a
    /// terminate/relaunch, so their store persists across the kill.
    private func freshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory",
            "momo-onboarding-uitest-\(UUID().uuidString)",
        ]
        return app
    }

    /// Walks S1→S2→S3 with the pre-filled default name and taps Begin.
    private func walkFlowToHome(_ app: XCUIApplication) {
        let sayHello = app.buttons["Say hello"]
        XCTAssertTrue(sayHello.waitForExistence(timeout: 10))
        sayHello.tap()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()
        let begin = app.buttons["Begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        begin.tap()
    }
}
