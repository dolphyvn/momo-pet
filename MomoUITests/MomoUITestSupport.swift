import XCTest

/// Shared UI-test fixture machinery (TASK-039 R5): the launch/clock/walk
/// helpers the suites previously DUPLICATED, extracted verbatim onto one
/// `XCTestCase` extension so every suite rides the same enablers. The moved
/// bodies are unchanged — same arguments, same waits, same failure
/// messages — so the existing tests pass unchanged in name and assertion
/// strength. Suite-specific helpers only one suite uses (the Home voice
/// pins, the Settings filesystem polls, the onboarding fresh-store
/// factory) stayed with their suites.
///
/// The three enablers these helpers encode, all disclosed in the task
/// records that introduced them: a throwaway-or-owned store directory
/// (`-momo-store-directory`, R13), a frozen clock that also UTC-pins the
/// calendar (`-momo-fixed-clock`, R7), and the onboarding-complete fixture
/// (`-momo-fixture <kind>`, R10).
///
/// The extension is `@MainActor` (TASK-039 R4's isolation discipline): the
/// suites are `@MainActor` classes, XCUIApplication interaction is
/// main-actor work, and an unannotated extension would re-import the
/// actor-isolation warnings the class annotations retired.
@MainActor
extension XCTestCase {

    // MARK: The frozen clock instants (the R7 enabler's vocabulary)

    /// The 08:59 setup instant: one minute before morning, so the
    /// relaunch-open evaluate has a gap to fold across (the R13 restart
    /// pattern's precondition — a zero-elapsed fold never mints the day).
    static let setup = "2026-09-10T08:59:00Z"

    /// The morning instant: quest Q1's window open, Q6's shut, feed + play
    /// offered.
    static let morning = "2026-09-10T09:00:00Z"

    /// The evening instant: Q6 open, Q1 shut, tuck-in offered.
    static let evening = "2026-09-10T20:30:00Z"

    // MARK: Launch construction

    /// A Home-suite launch: its own throwaway store (R13) and a frozen
    /// clock (R7 — also UTC-pins the calendar, so the pinned hour IS the
    /// local hour regardless of the host's timezone).
    func homeApp(store: String, clock: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", store,
            "-momo-fixed-clock", clock,
        ]
        return app
    }

    /// A Home-suite launch against a fresh throwaway store.
    func freshHomeApp(clock: String) -> XCUIApplication {
        homeApp(store: "momo-home-uitest-\(UUID().uuidString)", clock: clock)
    }

    /// Every onboarding-suite test runs against its own throwaway store: a
    /// unique relative name per launch, resolved by the app against ITS OWN
    /// temporary directory (the disclosed R13 interpretation — the runner
    /// and the app-under-test live in different sandboxes, so the app
    /// performs the resolution). A unique name per test means a fresh store
    /// at every launch; the restart tests reuse ONE configured app across a
    /// terminate/relaunch, so their store persists across the kill.
    func freshApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory",
            "momo-onboarding-uitest-\(UUID().uuidString)",
        ]
        return app
    }

    /// A fixture launch (the R10 enabler): a THROWAWAY store (the fixture
    /// rides the fresh-default fallback, so the store must never pre-exist)
    /// + the frozen clock (morning unless overridden) + the
    /// `-momo-fixture <kind>` argument, then the LAUNCH with the landing
    /// assertion — the fixture's onboarding-complete state skips the
    /// onboarding walk and lands straight on Home.
    func fixtureHomeApp(kind: String, clock: String = XCTestCase.morning) -> XCUIApplication {
        let app = homeApp(store: "momo-uitest-fixture-\(UUID().uuidString)", clock: clock)
        app.launchArguments += ["-momo-fixture", kind]
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "the fixture's onboarding-complete state skips the walk"
        )
        return app
    }

    // MARK: The shared onboarding walk + element lookup

    /// Walks S1→S2→S3 with the pre-filled default name and taps Begin,
    /// asserting the landing on Home (the three-tab shell).
    func walkToHome(_ app: XCUIApplication) {
        let sayHello = app.buttons["Say hello"]
        XCTAssertTrue(sayHello.waitForExistence(timeout: 10), "onboarding S1 should greet a fresh store")
        sayHello.tap()
        let continueButton = app.buttons["Continue"]
        XCTAssertTrue(continueButton.waitForExistence(timeout: 10))
        continueButton.tap()
        let begin = app.buttons["Begin"]
        XCTAssertTrue(begin.waitForExistence(timeout: 10))
        begin.tap()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "Begin lands on Home")
    }

    /// Identifiers land on non-button accessibility elements; `.any`
    /// matches them regardless of the element type SwiftUI materializes.
    func homeElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }
}
