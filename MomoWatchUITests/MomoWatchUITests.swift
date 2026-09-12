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
/// iPhone R13 pattern's Watch twin). `-momo-watch-fixture <kind>` (`w1`,
/// `alldone`, `stale` — the TASK-043 kinds; `reset` and `resethold` —
/// TASK-044 R2's erase pair) seeds a deterministic snapshot through the
/// REAL `WatchSnapshotStore.save` before the launch read, so every
/// assertion below exercises the genuine persistence + read path (the
/// MomoApp R10 pattern's Watch twin). The `reset` kind additionally returns
/// a pending marker frame that the launch delivers through the production
/// `receiveContext` — the §6.6 consumption decision runs unmocked; release
/// builds never seed and never deliver (`seedFixtureIfRequested` returns
/// nil there), so the whole leg is release-inert.
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
        let app = seededApp(store: "momo-watch-uitest-w1-\(UUID().uuidString)")

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
        let seeded = seededApp(store: store)
        seeded.terminate()

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
        let app = seededApp(store: "momo-watch-uitest-pill-\(UUID().uuidString)")
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
        let app = seededApp(store: "momo-watch-uitest-canvas-\(UUID().uuidString)")
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

    // MARK: TASK-043 — the all-done fixture renders the all-done line

    /// The `alldone` fixture's carried set is fully complete, so the live
    /// cascade yields `.allDone` at EVERY local hour: the glance's quest
    /// placeholder must render the all-done line
    /// (`HomeCopyKeys.allDoneLineKey` → "Momo had a lovely day.") — the
    /// R2 swap, over the real persistence + read + re-cascade path.
    func testAllDoneFixtureRendersTheAllDoneLine() {
        let app = seededApp(store: "momo-watch-uitest-alldone-\(UUID().uuidString)", fixture: "alldone")
        let glance = watchElement(app, "watch.glance")
        XCTAssertTrue(glance.waitForExistence(timeout: 10), "the all-done fixture must render the glance")
        XCTAssertTrue(
            glance.label.contains("Momo had a lovely day"),
            "the completed set's live cascade must render the all-done line: '\(glance.label)'"
        )
    }

    // MARK: TASK-043 — the stale fixture re-cascades under the local hour

    /// The `stale` fixture's FROZEN line says all-done over a fresh day's
    /// incomplete set (§10.4's stale-data shape: a day-roll the next push
    /// has not refreshed). The Watch's own re-cascade must replace it with
    /// the live wish for the CURRENT local hour — the runner derives the
    /// expected wish from its own clock (the app and runner share the
    /// simulator's clock and timezone, mirroring the app model's
    /// `calendar.component(.hour, from:)`), accepting the NEXT hour's wish
    /// too because the boundary between this derivation and the app's
    /// render may cross an hour (the disclosed no-timer latency, UX-9).
    func testStaleFixtureRendersTheLiveCascadeLine() {
        let hour = Calendar.current.component(.hour, from: Date())
        func wishText(for hour: Int) -> String {
            if hour >= 20 || hour < 7 { return "Tuck-in" }
            if hour < 12 { return "Morning hello" }
            return "Mealtime"
        }
        let accepted = [wishText(for: hour), wishText(for: (hour + 1) % 24)]

        let app = seededApp(store: "momo-watch-uitest-stale-\(UUID().uuidString)", fixture: "stale")
        let glance = watchElement(app, "watch.glance")
        XCTAssertTrue(glance.waitForExistence(timeout: 10), "the stale fixture must render the glance")
        XCTAssertTrue(
            accepted.contains { glance.label.contains($0) },
            "the stale all-done bytes must re-cascade to hour \(hour)'s live wish (±1): expected one of \(accepted), got '\(glance.label)'"
        )
        XCTAssertFalse(
            glance.label.contains("Momo had a lovely day"),
            "the frozen all-done line must not survive the live re-cascade: '\(glance.label)'"
        )
    }

    // MARK: TASK-044 R2 — the erase reset marker consumes to the settling-in line

    /// The §6.6 erase E2E over the REAL consumption path: the `reset` seam
    /// seeds CLEAN w1 bytes and returns a pending marker frame
    /// (`resetMarkerEraseCount` 1 carrying the pre-erase state) that the
    /// launch delivers through the production `receiveContext` — the same
    /// entry a WC delivery lands in, with `WatchResetConsumption.decide`
    /// never mocked. The decision is `.consume`: the fused `consumeWipe`
    /// clears the store and the glance yields to the settling-in line.
    ///
    /// Phase 1 asserts the settle endpoint — a seeded store's ONLY route
    /// back to the settling-in line is the wipe, since the bytes render the
    /// glance first. Phase 2 relaunches over the SAME store with no
    /// fixture: the settling line PERSISTS and no glance returns — the
    /// disk discriminator proving the seeded bytes are genuinely gone (a
    /// decision that skipped the wipe would restore them).
    func testResetMarkerFixtureConsumesToTheSettlingInLine() {
        let store = "momo-watch-uitest-reset-\(UUID().uuidString)"

        // Phase 1 — the marker enters through the real receive path.
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", store,
            "-momo-watch-fixture", "reset",
        ]
        app.launch()
        XCTAssertTrue(
            watchElement(app, "watch.settlingLine").waitForExistence(timeout: 10),
            "the marker's consumption must return the app to the settling-in line"
        )
        XCTAssertFalse(
            watchElement(app, "watch.glance").exists,
            "the settling-in state must be the whole state after the wipe"
        )
        app.terminate()

        // Phase 2 — the wipe must be durable across a relaunch.
        let relaunched = XCUIApplication()
        relaunched.launchArguments = ["-momo-store-directory", store]
        relaunched.launch()
        XCTAssertTrue(
            watchElement(relaunched, "watch.settlingLine").waitForExistence(timeout: 10),
            "the consumed store must stay empty across a relaunch"
        )
        XCTAssertFalse(
            watchElement(relaunched, "watch.glance").exists,
            "the seeded bytes must be gone — no glance may return from a wiped store"
        )
    }

    // MARK: TASK-044 R2 — the control: same seed, no marker frame

    /// The red-direction control for the flow above: `resethold` seeds the
    /// SAME clean bytes and returns NO frame, so nothing consumes — the
    /// glance renders and the settling line never appears. The difference
    /// between the two launches is exactly the marker frame, so the settle
    /// endpoint above is attributable to the marker's consumption, not to
    /// the seeding.
    func testResetHoldFixtureKeepsTheGlanceRendered() {
        let app = seededApp(store: "momo-watch-uitest-resethold-\(UUID().uuidString)", fixture: "resethold")
        XCTAssertTrue(
            watchElement(app, "watch.glance").exists,
            "without the marker frame the seeded glance must survive"
        )
        XCTAssertFalse(
            watchElement(app, "watch.settlingLine").exists,
            "no marker means no consumption — the settling-in line must not appear"
        )
    }

    // MARK: - Helpers

    /// The house element query (the `MomoUITestSupport.homeElement` pattern,
    /// duplicated per target): identifiers land on non-button accessibility
    /// elements, so match ANY element type.
    private func watchElement(_ app: XCUIApplication, _ identifier: String) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: identifier).firstMatch
    }

    /// Launches the app with the named fixture kind seeded into a named
    /// store directory and waits for the glance (both DEBUG seams; see
    /// header). Kinds: `w1` (the standard rendered glance), `alldone` (the
    /// day's set fully complete — TASK-043), `stale` (a frozen all-done line
    /// over a fresh day's incomplete set — TASK-043), `resethold` (the same
    /// bytes with no marker frame — TASK-044 R2's control; the `reset` kind
    /// is NOT here because its endpoint is the settling line, not the
    /// glance).
    private func seededApp(store: String, fixture: String = "w1") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", store,
            "-momo-watch-fixture", fixture,
        ]
        app.launch()
        XCTAssertTrue(
            watchElement(app, "watch.glance").waitForExistence(timeout: 10),
            "the fixture-seeded launch must render the glance"
        )
        return app
    }
}
