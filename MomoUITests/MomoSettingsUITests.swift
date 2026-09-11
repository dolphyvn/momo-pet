import XCTest

/// TASK-038's UI pins (Required Tests; FR-19 AC-1/2/3; UX §1.2 S6): the
/// Settings tab's EXACT inventory at the glass (the R8 red line's on-glass
/// face), the rename flowing through the plan core to Home and Room, the
/// S6.2 system alert's verbatim copy and its Keep no-op, the erase
/// roundtrip (the store directory DELETED — a runner-side `FileManager`
/// assertion on the `-momo-store-directory` path, not merely overwritten —
/// and the re-onboarding completion), and the relaunch-after-erase
/// landing on S1 (the TASK-032 restart precedent: a persisted pre-erase
/// store would resurrect the old pet on Home — the discriminating
/// evidence).
///
/// Every launch rides the disclosed enablers: a throwaway-or-owned store
/// (`-momo-store-directory`) and a frozen clock (`-momo-fixed-clock`, which
/// also UTC-pins the calendar). Fixture launches (the TASK-037 room test's
/// shape) ride `-momo-fixture stage-crossing` so the onboarding-complete
/// state lands straight on Home. The erase roundtrip is the one suite that
/// hands the app an ABSOLUTE store path under the runner's temporary
/// directory — honored as-is by the enabler — so the runner can assert the
/// directory's existence before and absence after the erase (a loud
/// PRE-CHECK failure means the cross-process visibility assumption broke;
/// it never silently passes).
@MainActor
final class MomoSettingsUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private static let morning = "2026-09-10T09:00:00Z"

    /// The FR-19 MUST-NOT vocabulary — the R8 guard's list, mirrored at the
    /// glass: no rendered label (or identifier) on the Settings surface may
    /// carry any of it.
    private static let forbiddenVocabulary = [
        "account", "sign in", "signin", "notification", "healthkit",
        "purchase", "subscription", "sound",
    ]

    // MARK: Required Test 1 — the inventory census (FR-19 AC-1)

    func testSettingsInventoryIsExactlyTheFR19Surface() {
        let app = fixtureHomeApp()
        app.tabBars.buttons["Settings"].tap()

        // The four groups' controls, all present.
        for identifier in [
            "settings.name.field",
            "settings.name.save",
            "settings.haptics.toggle",
            "settings.erase.row",
            "settings.about",
        ] {
            XCTAssertTrue(
                homeElement(app, identifier).waitForExistence(timeout: 10),
                "\(identifier) is part of the FR-19 inventory"
            )
        }
        // …and the namespace carries EXACTLY those five — no sixth row can
        // sneak in without this census failing.
        XCTAssertEqual(
            app.descendants(matching: .any).matching(
                NSPredicate(format: "identifier BEGINSWITH %@", "settings.")).count,
            5,
            "the settings namespace is exactly the five pinned controls"
        )

        // Zero forbidden rows: no rendered label or identifier on this
        // surface carries the MUST-NOT vocabulary (the tab bar's three
        // labels bound the query's liveness — the TASK-037 N-2 shape).
        let elements = app.descendants(matching: .any).allElementsBoundByIndex
        for element in elements {
            let text = "\(element.label) \(element.identifier)".lowercased()
            for word in Self.forbiddenVocabulary {
                XCTAssertFalse(
                    text.contains(word),
                    "the Settings surface carries forbidden vocabulary '\(word)' in '\(text)'"
                )
            }
        }
        XCTAssertEqual(app.tabBars.buttons.count, 3, "the three tabs prove the query is live")
        XCTAssertEqual(app.alerts.count, 0, "the inventory census presents nothing")
    }

    // MARK: Required Test 2 — rename flows to Home + Room (FR-19 AC-1)

    func testRenameFlowsToHomeAndRoomLabels() {
        let app = fixtureHomeApp()
        app.tabBars.buttons["Settings"].tap()

        let field = homeElement(app, "settings.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(
            field.value as? String, "Momo",
            "the field is pre-filled with the current name")
        let save = homeElement(app, "settings.name.save")

        // The Save gate (INV-1's UI face): empty the field — Save goes
        // disabled; a typed name re-enables it.
        field.doubleTap()
        field.typeText(String(repeating: XCUIKeyboardKey.delete.rawValue, count: 8))
        XCTAssertEqual(field.value as? String, "", "the field cleared for the gate check")
        XCTAssertFalse(save.isEnabled, "Save is disabled while the trimmed field is empty")
        field.typeText("Mochi")
        XCTAssertEqual(field.value as? String, "Mochi")
        XCTAssertTrue(save.isEnabled, "Save re-enables for a non-empty name")

        // Commit + dismiss the rename keyboard (the field's return key):
        // a keyboard left up swallows the tab-bar taps — they land on the
        // keyboard's keys and type junk into the still-focused field
        // (bitten at the glass: the field read 'MochiXx' at failure).
        field.typeText("\n")
        let keyboardGone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: app.keyboards.firstMatch
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [keyboardGone], timeout: 5), .completed,
            "the return key dismisses the rename keyboard")

        save.tap()

        // Home reflects the rename immediately (the canvas speaks the name).
        app.tabBars.buttons["Home"].tap()
        let canvas = homeElement(app, "home.canvas")
        XCTAssertTrue(canvas.waitForExistence(timeout: 10))
        let relabeled = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Mochi"),
            object: canvas
        )
        XCTAssertEqual(
            XCTWaiter().wait(for: [relabeled], timeout: 5), .completed,
            "the canvas speaks the new name after the save")

        // The Room label re-interpolates the same name.
        app.tabBars.buttons["Room"].tap()
        let scene = homeElement(app, "room.scene")
        XCTAssertTrue(scene.waitForExistence(timeout: 10))
        XCTAssertEqual(
            scene.label, "Mochi\u{2019}s cozy room",
            "the room scene label re-interpolates the renamed pet")
    }

    // MARK: Required Test 3 — the alert verbatim + Keep cancels (FR-19 AC-2)

    func testEraseAlertReadsVerbatimAndKeepCancels() {
        let app = fixtureHomeApp()
        app.tabBars.buttons["Settings"].tap()

        homeElement(app, "settings.erase.row").tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "the erase row opens the SYSTEM alert")

        // The verbatim S6.2 copy — the name interpolates TWICE. Depending
        // on the OS materialization the title/message surface as child
        // static texts or fold into the alert's own label; the copy must
        // read verbatim either way.
        let message = "This deletes Momo and all memories on this iPhone; "
            + "Momo\u{2019}s Watch snapshot resets at its next sync. This can\u{2019}t be undone."
        XCTAssertTrue(
            alert.staticTexts["Erase everything?"].exists || alert.label.hasPrefix("Erase everything?"),
            "the alert's title reads verbatim")
        XCTAssertTrue(
            alert.staticTexts[message].exists || alert.label.contains(message),
            "the alert's message interpolates the name twice, verbatim")

        // The two S6.2 buttons.
        XCTAssertTrue(alert.buttons["Erase"].exists, "the destructive confirm")
        XCTAssertTrue(alert.buttons["Keep Momo"].exists, "the named cancel")

        // Keep performs NOTHING: the alert dismisses, the surface (and the
        // session) stay intact.
        alert.buttons["Keep Momo"].tap()
        let gone = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == false"),
            object: alert
        )
        XCTAssertEqual(XCTWaiter().wait(for: [gone], timeout: 5), .completed, "Keep dismisses the alert")
        XCTAssertTrue(
            homeElement(app, "settings.erase.row").waitForExistence(timeout: 5),
            "the keep leaves the Settings surface intact")
        XCTAssertEqual(app.tabBars.buttons.count, 3, "the keep never navigates")
    }

    // MARK: Required Test 4 — the erase roundtrip (FR-19 AC-2)

    func testEraseRoundtripDeletesTheStoreDirectoryAndReonboards() {
        // An ABSOLUTE store path under the RUNNER's temporary directory —
        // the enabler honors it as-is, and the runner can see the same
        // bytes, which is the whole point of this test's filesystem pins.
        let storeDirectory = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("momo-settings-uitest-erase-\(UUID().uuidString)", isDirectory: true)
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", storeDirectory.path,
            "-momo-fixed-clock", Self.morning,
        ]
        app.launch()
        walkToHome(app)

        // PRE-CHECK (loud): the onboarding completion write created the
        // store directory, and the RUNNER can see it. If cross-process
        // visibility ever breaks, this fails — never the absence pin
        // silently passing on an invisible directory.
        XCTAssertTrue(
            Self.waitForPath(storeDirectory.path, timeout: 10),
            "the completion write creates the store directory the runner can see")

        // Settings → Erase → confirm.
        app.tabBars.buttons["Settings"].tap()
        homeElement(app, "settings.erase.row").tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.buttons["Erase"].tap()

        // The store directory is GONE — deleted, not overwritten (AC-2's
        // "deletes every local store"; the rotation's stale bytes go with
        // it).
        XCTAssertTrue(
            Self.waitForPathAbsence(storeDirectory.path, timeout: 10),
            "the erase deletes the store directory itself")

        // The app lands on S1 — fresh.
        XCTAssertTrue(
            app.buttons["Say hello"].waitForExistence(timeout: 10),
            "the erase routes to onboarding S1")

        // …and the erase path never re-persists: the directory stays gone
        // (a re-persisting erase would resurrect a store a fresh install
        // does not have).
        Thread.sleep(forTimeInterval: 1.0)
        XCTAssertFalse(
            FileManager.default.fileExists(atPath: storeDirectory.path),
            "the erase path never re-persists — no store exists until onboarding completes")

        // Complete onboarding again ⇒ a CLEAN Home (the store's first write
        // recreates the directory).
        walkToHome(app)
        XCTAssertTrue(homeElement(app, "home.canvas").waitForExistence(timeout: 10), "the re-onboarding lands on Home")
        XCTAssertTrue(
            Self.waitForPath(storeDirectory.path, timeout: 10),
            "the re-onboarding's completion write recreates the store directory")
    }

    // MARK: Required Test 5 — relaunch after erase lands on S1 (FR-19 AC-2)

    func testRelaunchAfterEraseLandsOnS1() {
        // A relative store name — both launches resolve it against the
        // app's own temporary directory, so they share the store.
        let store = "momo-settings-uitest-relaunch-\(UUID().uuidString)"

        let app = XCUIApplication()
        app.launchArguments = ["-momo-store-directory", store, "-momo-fixed-clock", Self.morning]
        app.launch()
        walkToHome(app)

        // Erase: Settings → confirm → S1, then terminate mid-onboarding.
        app.tabBars.buttons["Settings"].tap()
        homeElement(app, "settings.erase.row").tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10))
        alert.buttons["Erase"].tap()
        XCTAssertTrue(app.buttons["Say hello"].waitForExistence(timeout: 10))
        app.terminate()

        // Relaunch the SAME store: the erased (absent) store relaunches
        // into onboarding. A persisted pre-erase store would have landed
        // straight on Home — this is the discriminating glass evidence
        // that erase actually deleted the bytes.
        let relaunched = XCUIApplication()
        relaunched.launchArguments = ["-momo-store-directory", store, "-momo-fixed-clock", Self.morning]
        relaunched.launch()
        XCTAssertTrue(
            relaunched.buttons["Say hello"].waitForExistence(timeout: 10),
            "the erased store relaunches into onboarding S1")
        XCTAssertFalse(
            relaunched.tabBars.firstMatch.exists,
            "the relaunch does NOT land on Home — the pre-erase store is truly gone")
    }

    // MARK: Helpers

    /// A fixture launch (the R10 enabler, TASK-037's shape): a THROWAWAY
    /// store + the frozen morning clock + the `stage-crossing` fixture,
    /// whose onboarding-complete state lands straight on Home.
    private func fixtureHomeApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = [
            "-momo-store-directory", "momo-settings-uitest-fixture-\(UUID().uuidString)",
            "-momo-fixed-clock", Self.morning,
            "-momo-fixture", "stage-crossing",
        ]
        app.launch()
        XCTAssertTrue(
            app.tabBars.firstMatch.waitForExistence(timeout: 10),
            "the fixture's onboarding-complete state skips the walk")
        return app
    }

    /// Walks S1→S2→S3 with the pre-filled default name and taps Begin,
    /// asserting the landing on Home (the `MomoHomeUITests` walk).
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

    /// Polls the runner's FileManager until the path exists (the async
    /// completion write lands a runloop or two after the tap).
    private static func waitForPath(_ path: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if FileManager.default.fileExists(atPath: path) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return FileManager.default.fileExists(atPath: path)
    }

    /// Polls the runner's FileManager until the path is absent.
    private static func waitForPathAbsence(_ path: String, timeout: TimeInterval) -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !FileManager.default.fileExists(atPath: path) { return true }
            Thread.sleep(forTimeInterval: 0.25)
        }
        return !FileManager.default.fileExists(atPath: path)
    }
}
