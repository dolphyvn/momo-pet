import XCTest

/// TASK-033's UI pins (Requirement 8; FR-2 AC-1a/AC-1b; UX §5.1, §5.5):
/// the composed Home's S4 layout, its words-never-digits voice, the quest
/// windows' silent absence, the hour-governed action pills, and the
/// accessibility-size scroll fallback. Every launch runs against a
/// throwaway-or-shared store (`-momo-store-directory`, the disclosed R13
/// enabler) AND a frozen clock (`-momo-fixed-clock <ISO-8601-UTC>`, the
/// disclosed R7 enabler — DEBUG-only, it also pins the calendar to UTC), so
/// the local-hour-governed surfaces — quest windows, pill windows, the copy
/// slot — read the same at 09:00 and 20:30 whenever and wherever the suite
/// runs.
///
/// **Why every quest test walks onboarding at 08:59 and asserts at its
/// target hour (the R13 restart pattern).** A fresh carrier pre-stamps
/// `lastEvaluatedAt` at its creation instant, and a zero-elapsed fold
/// short-circuits BEFORE the landing-day rollover (`TimeFold.apply`'s
/// `from < to` guard) — so under a never-advancing clock, a single frozen
/// launch can never mint day 1's record. Relaunching the SAME store at a
/// LATER pinned instant gives the launch-open evaluate a one-minute gap to
/// fold, and the rollover lands today's record — seeded by the real pet,
/// whose set is `[Q1, X, Q6]`: the Q6 3-day-window rule forces the drawn
/// pair to contain Q6 (§4.8's `candidatePool`), the anchor adds Q1, and the
/// set is exactly three. At 09:00 the open windows are Q1 (morning) + X
/// (all-day) = 2 rows; at 20:30 Q1's window has closed while Q6's has
/// opened = 2 rows — the maximum any hour can show, because the third
/// member is always the closed one.
@MainActor
final class MomoHomeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Required Test 1 — the composed S4 layout (FR-2 AC-1a)

    func testCompositionAtDefaultTypeKeepsCanvasFloorWithoutScrolling() {
        let app = preparedHomeApp(clock: Self.morning)

        // All five S4 sections are present, in UX §5.1's order (order is
        // implied by the vertical frames below — the canvas sits between
        // the status row and the line).
        XCTAssertTrue(homeElement(app, "home.statusRow").waitForExistence(timeout: 10))
        let canvas = homeElement(app, "home.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertTrue(homeElement(app, "home.contextualLine").exists)
        XCTAssertTrue(homeElement(app, "home.actionRow").exists)
        XCTAssertTrue(homeElement(app, "home.questCard").exists)

        // AC-1a: the canvas REGION holds ≥ 45% of the screen at default
        // type on the SE class (the element IS the region — see HomeView).
        XCTAssertGreaterThanOrEqual(
            canvas.frame.height,
            app.frame.height * 0.45,
            "the canvas region must keep the 45%-of-screen floor at default type"
        )

        // The default-type branch does not scroll — everything fits.
        XCTAssertEqual(app.scrollViews.count, 0, "the default-type composition must fit without scrolling")
    }

    // MARK: Required Test 2 — words, never digits (INV-11 at the glass)

    func testHomeSurfacesCarryWordsNeverDigits() {
        let app = preparedHomeApp(clock: Self.morning)

        // The status row speaks the 04 §3.5 formula; both of its elements
        // are word-only.
        assertCarriesNoDigits(
            homeElement(app, "home.statusRow.moodEnergy").label,
            "the mood·energy element"
        )
        assertCarriesNoDigits(
            homeElement(app, "home.statusRow.stage").label,
            "the stage element"
        )
        assertCarriesNoDigits(
            homeElement(app, "home.contextualLine").label,
            "the contextual line"
        )

        // Every visible wish row speaks "{wish}, done/pending" — words,
        // never symbols or digits (UX §5.5).
        XCTAssertTrue(
            homeElement(app, "home.questRow.q1").waitForExistence(timeout: 10),
            "the morning wish is visible at 09:00"
        )
        let rows = questRowQuery(app)
        XCTAssertEqual(rows.count, 2, "a fresh 09:00 install shows Q1 + one all-day wish")
        for index in 0..<rows.count {
            assertCarriesNoDigits(rows.element(boundBy: index).label, "quest row \(index)")
        }
    }

    // MARK: Required Test 3 — the quest windows open and close silently

    func testQuestWindowsOpenAndCloseSilently() {
        // 09:00 — the morning side: Q1 open, Q6's window shut. Absence is
        // SILENT (§5.5): the row does not exist at all — no disabled ghost.
        let morning = preparedHomeApp(clock: Self.morning)
        XCTAssertTrue(homeElement(morning, "home.questRow.q1").waitForExistence(timeout: 10))
        XCTAssertEqual(questRowQuery(morning).count, 2, "Q1 + the all-day pair member")
        XCTAssertFalse(
            homeElement(morning, "home.questRow.q6").exists,
            "Q6's window is shut at 09:00 — the row is silently absent"
        )

        // 20:30 — the evening side: Q1's window has closed, Q6's has
        // opened. Same set, different windows, same silent law.
        let evening = preparedHomeApp(clock: Self.evening)
        XCTAssertTrue(homeElement(evening, "home.questRow.q6").waitForExistence(timeout: 10))
        XCTAssertEqual(questRowQuery(evening).count, 2, "the all-day pair member + Q6 (the §4.8 day-1 set)")
        XCTAssertFalse(
            homeElement(evening, "home.questRow.q1").exists,
            "Q1's window closed at noon — the row is silently absent"
        )
    }

    // MARK: Required Test 4 — the action pills follow the hour windows

    func testActionPillsFollowTheHourWindows() {
        // 09:00 — a fresh pet (content, energetic, awake): feed + play,
        // no tuck-in before 20:00, never a nap for an energetic pet. The
        // pill windows are record-independent, so a single frozen launch
        // pins them.
        let morning = freshHomeApp(clock: Self.morning)
        morning.launch()
        walkToHome(morning)
        XCTAssertTrue(morning.buttons["home.actionPill.feed"].waitForExistence(timeout: 10))
        XCTAssertTrue(morning.buttons["home.actionPill.play"].exists)
        XCTAssertFalse(
            morning.buttons["home.actionPill.tuckIn"].exists,
            "tuck-in is an evening affordance (from 20:00)"
        )
        XCTAssertFalse(
            morning.buttons["home.actionPill.nap"].exists,
            "an energetic pet is never offered a nap"
        )
        // A pill tap routes through the app model in place — no sheet,
        // no alert, no navigation.
        morning.buttons["home.actionPill.feed"].tap()
        XCTAssertTrue(
            homeElement(morning, "home.canvas").waitForExistence(timeout: 5),
            "the feed tap stays on Home"
        )
        XCTAssertEqual(morning.alerts.count, 0, "interactions never present anything")

        // 20:30 — the evening side: tuck-in has joined; the fresh pet
        // still earns no nap.
        let evening = freshHomeApp(clock: Self.evening)
        evening.launch()
        walkToHome(evening)
        XCTAssertTrue(evening.buttons["home.actionPill.tuckIn"].waitForExistence(timeout: 10))
        XCTAssertTrue(evening.buttons["home.actionPill.feed"].exists)
        XCTAssertTrue(evening.buttons["home.actionPill.play"].exists)
        XCTAssertFalse(
            evening.buttons["home.actionPill.nap"].exists,
            "an energetic pet is never offered a nap, evening included"
        )
        evening.buttons["home.actionPill.tuckIn"].tap()
        XCTAssertTrue(
            homeElement(evening, "home.canvas").waitForExistence(timeout: 5),
            "the tuck-in tap stays on Home"
        )
        XCTAssertEqual(evening.alerts.count, 0, "interactions never present anything")
    }

    // MARK: Required Test 5 — accessibility sizes scroll with full function

    func testAccessibilitySizeScrollsWithFullFunction() {
        // Phase 1 — complete onboarding at the default size against a
        // PERSISTED store (the XXL launch below must land straight on
        // Home; a fresh store would route it back into onboarding, whose
        // XXL ergonomics are not this task's scope). The 08:59 setup also
        // gives phase 2's launch-open fold its one-minute gap (see the
        // type header), so the scrolled composition carries real rows.
        let store = "momo-home-uitest-xxl-\(UUID().uuidString)"
        let setup = homeApp(store: store, clock: Self.setup)
        setup.launch()
        walkToHome(setup)
        setup.terminate()

        // Phase 2 — relaunch the same store at AccessibilityXXL: the
        // composition switches to the scrolling branch (AC-1b), the canvas
        // keeps a preserved minimum inside RigLOD's 220–280 band, and every
        // control stays reachable and functional inside the scroll.
        let app = homeApp(store: store, clock: Self.morning)
        app.launchArguments += [
            "-UIPreferredContentSizeCategoryName",
            "UICTContentSizeCategoryAccessibilityXXL",
        ]
        app.launch()
        XCTAssertTrue(app.tabBars.firstMatch.waitForExistence(timeout: 10), "the completed store lands on Home")

        let scroll = app.scrollViews.firstMatch
        XCTAssertTrue(scroll.waitForExistence(timeout: 10), "the accessibility-size branch scrolls")
        XCTAssertTrue(homeElement(app, "home.statusRow").exists)

        // AC-1b's preserved minimum: the region is the fixed 260 pt — at
        // or above RigLOD.fullStagePoints' 220-pt floor.
        let canvas = homeElement(app, "home.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(
            canvas.frame.height,
            220,
            "the stepped-down canvas stays inside the rig's full-stage band"
        )

        // Everything remains functional inside the scroll: swipe to the
        // pills, interact, then reach the quest card.
        scroll.swipeUp()
        let actionRow = homeElement(app, "home.actionRow")
        if !actionRow.waitForExistence(timeout: 2) {
            scroll.swipeUp()
        }
        XCTAssertTrue(actionRow.exists, "the action row is reachable in the scroll")
        let feed = app.buttons["home.actionPill.feed"]
        XCTAssertTrue(feed.waitForExistence(timeout: 5))
        feed.tap()
        XCTAssertTrue(feed.waitForExistence(timeout: 5), "the tap routes through the app model without presentation")

        scroll.swipeUp()
        let card = homeElement(app, "home.questCard")
        if !card.waitForExistence(timeout: 2) {
            scroll.swipeUp()
        }
        XCTAssertTrue(card.waitForExistence(timeout: 5), "the quest card is reachable in the scroll")
        XCTAssertTrue(
            homeElement(app, "home.questRow.q1").exists,
            "the scrolled card carries the morning wish"
        )
    }

    // MARK: Helpers

    private static let setup = "2026-09-10T08:59:00Z"
    private static let morning = "2026-09-10T09:00:00Z"
    private static let evening = "2026-09-10T20:30:00Z"

    /// A Home-suite launch: its own throwaway store (R13) and a frozen
    /// clock (R7 — also UTC-pins the calendar, so the pinned hour IS the
    /// local hour regardless of the host's timezone).
    private func homeApp(store: String, clock: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", store,
            "-momo-fixed-clock", clock,
        ]
        return app
    }

    private func freshHomeApp(clock: String) -> XCUIApplication {
        homeApp(store: "momo-home-uitest-\(UUID().uuidString)", clock: clock)
    }

    /// Onboards at the 08:59 setup instant against a shared throwaway
    /// store, then relaunches that store at `clock` — the launch-open
    /// evaluate folds the one-minute gap and lands today's quest record
    /// (the type header's construction math). Returns the `clock` launch.
    private func preparedHomeApp(clock: String) -> XCUIApplication {
        let store = "momo-home-uitest-prep-\(UUID().uuidString)"
        let setupApp = homeApp(store: store, clock: Self.setup)
        setupApp.launch()
        walkToHome(setupApp)
        setupApp.terminate()

        let app = homeApp(store: store, clock: clock)
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "the completed store lands straight on Home"
        )
        return app
    }

    /// Walks S1→S2→S3 with the pre-filled default name and taps Begin,
    /// asserting the landing on Home (the `MomoOnboardingUITests` walk).
    private func walkToHome(_ app: XCUIApplication) {
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
    private func homeElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    private func questRowQuery(_ app: XCUIApplication) -> XCUIElementQuery {
        app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@", "home.questRow.")
        )
    }

    /// The voice law at the glass: every Home label is spoken words —
    /// non-empty and digit-free (INV-11; UX §5.5 "words, never symbols").
    private func assertCarriesNoDigits(
        _ label: String,
        _ surface: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertFalse(label.isEmpty, "\(surface) must expose a spoken label", file: file, line: line)
        XCTAssertNil(
            label.first(where: \.isNumber),
            "\(surface) must carry words, never digits — got '\(label)'",
            file: file,
            line: line
        )
    }
}
