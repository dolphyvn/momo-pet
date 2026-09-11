import XCTest

/// TASK-041 Requirement 10 / Required Test 3 — the W1 suite over the real
/// watchOS app on the pinned Watch SE simulator: the fresh launch's
/// settling-in line and nothing else, the fixture-seeded W1 glance's four
/// slots + inert pat targets, and the disk-restore assertion.
///
/// **The disclosed seams (both DEBUG-only; a Release build ignores the
/// fixture argument and the restore test fails loudly rather than passing
/// vacuously).** `-momo-store-directory <name>` points the store at a
/// throwaway directory (a RELATIVE value resolves inside the app's own
/// temporary directory, so two launches of the same app instance share it
/// while tests stay isolated from one another and from production — the
/// iPhone R13 pattern's Watch twin). `-momo-watch-fixture w1` seeds a
/// deterministic snapshot through the REAL `WatchSnapshotStore.save` before
/// the launch read, so every assertion below exercises the genuine
/// persistence + read path (the MomoApp R10 pattern's Watch twin).
///
/// **Restore-measurement semantics (honest by construction).** The restore
/// launch's clock starts immediately before `app.launch()` and stops when
/// the glance element exists — the full XCUITest round-trip (springboard
/// handoff, process spawn, first frame) is INSIDE the measurement. That
/// overhead is large, sim-dependent, and has nothing to do with restoring,
/// so asserting a bare wall-clock ~2 s against it would measure the harness,
/// not the app. Instead each run also measures a BASELINE launch over a
/// fresh empty store (identical mechanics, settling-in endpoint), and the
/// assertion is `restore − baseline ≤ 2.0 s`: the launch overhead cancels,
/// and the bound is exactly NFR-9's ~2 s restore budget, spent on the disk
/// read + render the task must prove. The baseline duration is recorded in
/// the failure message for auditability.
@MainActor
final class MomoWatchUITests: XCTestCase {

    /// NFR-9's restore budget, asserted as the DELTA over the measured
    /// baseline launch (see the header's semantics note).
    private static let restoreBudget: TimeInterval = 2.0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: Required Test 3a — fresh launch shows the settling-in line only

    func testFreshLaunchShowsTheSettlingInLineOnly() {
        let app = XCUIApplication()
        app.launch()

        let settling = watchElement(app, "watch.settlingLine")
        XCTAssertTrue(
            settling.waitForExistence(timeout: 10),
            "a fresh store must render the UX §9 settling-in line"
        )
        // The settling-in state is the WHOLE state: no glance slots, no
        // error, no retry affordance, ever.
        XCTAssertFalse(
            watchElement(app, "watch.glance").exists,
            "no glance slots may render pre-first-sync"
        )
    }

    // MARK: Required Test 3b — the seeded glance renders W1's content

    func testFixtureSeededGlanceRendersTheW1Content() {
        let app = seededW1App(store: "momo-watch-uitest-w1-\(UUID().uuidString)")

        // The composite VoiceOver element (status + canvas + quest announce
        // as ONE, UX §10's W1 row resolved over the shipped strings) —
        // asserted by its load-bearing segments: the status formula, the
        // stage word, the wish preamble, and the pill pre-announcement.
        let glance = watchElement(app, "watch.glance")
        XCTAssertTrue(glance.waitForExistence(timeout: 10), "the seeded store must render the W1 glance")
        XCTAssertTrue(
            glance.label.hasPrefix("Momo feels content and has plenty of energy. Getting Close. Today's wish: "),
            "the composite must open with UX §10's resolved status + stage: '\(glance.label)'"
        )
        XCTAssertTrue(glance.label.contains("Gentle pats"), "the quest line must name the seeded wish: '\(glance.label)'")
        XCTAssertTrue(glance.label.hasSuffix("Pat button."), "the composite must pre-announce the pill: '\(glance.label)'")

        // The settling-in line is gone — a renderable snapshot replaced it.
        XCTAssertFalse(
            watchElement(app, "watch.settlingLine").exists,
            "the settling-in line must yield to the rendered snapshot"
        )

        // The pat targets are labeled and ≥ 44 pt (AC-3's target floor);
        // both capture for real since TASK-042 (the flows below).
        let canvas = watchElement(app, "watch.canvas")
        XCTAssertTrue(canvas.exists, "the tappable canvas target must exist")
        XCTAssertGreaterThanOrEqual(
            canvas.frame.height,
            44,
            "the canvas pat target must clear the 44 pt floor"
        )
        let pill = watchElement(app, "watch.patPill")
        XCTAssertTrue(pill.exists, "the Pat pill target must exist")
        XCTAssertGreaterThanOrEqual(
            pill.frame.height,
            44,
            "the Pat pill target must clear the 44 pt floor"
        )
    }

    // MARK: Required Test 3c — the disk restore stays within the budget

    func testSnapshotRestoreStaysWithinTheBudget() {
        // Phase 1 — warm the sim with a baseline launch over a FRESH store
        // and measure it (the overhead the delta assertion cancels).
        let baselineStart = Date()
        let baselineApp = XCUIApplication()
        baselineApp.launchArguments = [
            "-momo-store-directory", "momo-watch-uitest-baseline-\(UUID().uuidString)",
        ]
        baselineApp.launch()
        XCTAssertTrue(
            watchElement(baselineApp, "watch.settlingLine").waitForExistence(timeout: 10),
            "the baseline launch must reach its settling-in endpoint"
        )
        let baselineElapsed = Date().timeIntervalSince(baselineStart)
        baselineApp.terminate()

        // Phase 2 — seed a store through the real store path.
        let store = "momo-watch-uitest-restore-\(UUID().uuidString)"
        let seededApp = seededW1App(store: store)
        seededApp.terminate()

        // Phase 3 — relaunch over the SAME store WITHOUT the fixture: the
        // glance must come back from DISK within the budget (the delta over
        // the measured baseline, launch overhead cancelled).
        let restoreStart = Date()
        let app = XCUIApplication()
        app.launchArguments = ["-momo-store-directory", store]
        app.launch()
        let glance = watchElement(app, "watch.glance")
        XCTAssertTrue(
            glance.waitForExistence(timeout: 10),
            "the relaunched app must restore the snapshot from disk"
        )
        let restoreElapsed = Date().timeIntervalSince(restoreStart)

        XCTAssertLessThanOrEqual(
            restoreElapsed - baselineElapsed,
            Self.restoreBudget,
            String(
                format: "restore must stay within the ~%.1f s budget over the measured baseline (restore %.2f s, baseline %.2f s)",
                Self.restoreBudget, restoreElapsed, baselineElapsed
            )
        )
    }

    // MARK: TASK-042 — the pat-pill flow

    /// The pill is a REAL pat target now: tapping it must run the whole
    /// offline-first flow (the immediate reaction fold, the haptic seam, the
    /// journal append, the drain attempt) and leave the app alive with the
    /// glance still rendered — no crash, no wedge, no error surface (the
    /// journal's keep-as-is discipline makes every I/O outcome quiet).
    func testPatPillTapKeepsTheGlanceRendered() {
        let app = seededW1App(store: "momo-watch-uitest-pill-\(UUID().uuidString)")
        let pill = watchElement(app, "watch.patPill")
        XCTAssertTrue(pill.isHittable, "the Pat pill must be tappable in the rendered glance")
        pill.tap()
        // The glance survives the flow: still rendered, app foreground.
        XCTAssertTrue(
            watchElement(app, "watch.glance").exists,
            "the glance must still render after a pat"
        )
        XCTAssertEqual(
            app.state, .runningForeground,
            "the app must stay foreground after the pat flow"
        )
    }

    // MARK: TASK-042 — the canvas tap flow

    /// The canvas is the touch-only pat affordance (the composite a11y
    /// element keeps VoiceOver users on the pill): tapping anywhere on the
    /// slot must run the same flow and leave the glance rendered.
    func testCanvasTapKeepsTheGlanceRendered() {
        let app = seededW1App(store: "momo-watch-uitest-canvas-\(UUID().uuidString)")
        let canvas = watchElement(app, "watch.canvas")
        XCTAssertTrue(canvas.isHittable, "the canvas must be tappable in the rendered glance")
        canvas.tap()
        XCTAssertTrue(
            watchElement(app, "watch.glance").exists,
            "the glance must still render after a canvas pat"
        )
        XCTAssertEqual(
            app.state, .runningForeground,
            "the app must stay foreground after the canvas pat flow"
        )
    }

    // MARK: - Helpers

    /// The house element query (the `MomoUITestSupport.homeElement` pattern,
    /// duplicated per target): identifiers land on non-button accessibility
    /// elements, so match ANY element type.
    private func watchElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Launches the app with the W1 fixture seeded into a named store
    /// directory and waits for the glance (both DEBUG seams; see header).
    private func seededW1App(store: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", store,
            "-momo-watch-fixture", "w1",
        ]
        app.launch()
        XCTAssertTrue(
            watchElement(app, "watch.glance").waitForExistence(timeout: 10),
            "the fixture-seeded launch must render the W1 glance"
        )
        return app
    }
}
