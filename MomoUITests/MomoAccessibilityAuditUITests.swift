import XCTest

/// TASK-039 R6 — the FR-20 AC-2 automated audit (UX 03 §10's matrix, the
/// launch-blocking NFR-6): `performAccessibilityAudit` runs over every
/// reachable iPhone surface — S1/S2/S3 onboarding, S4 Home, S5 Room,
/// S6 Settings (with the S6.1 rename legs), and the S6.2 system erase
/// alert — plus the state-in-words VoiceOver template and the 44-pt
/// target floor.
///
/// **Filtering discipline (no blanket catch-all).** Every audit runs with
/// `XCUIAccessibilityAuditType.all`; the issue handler returns "ignore"
/// ONLY for rows in the disclosure table below — each row names the
/// surface, the audit type, the element, and the WHY. Any issue outside
/// the table fails the suite. An empty table means the surface audited
/// clean with zero filtering.
///
/// **Watch (W1): the pat leg is EPIC-008's** — the watchOS glance's audit,
/// its pat target, and its state-in-words template ride the Watch app's
/// own epic (this suite pins the iPhone surfaces only).
///
/// **Reduce Motion:** the RM substitution (the director's
/// `reduceMotionOverlay` path replacing `overlay` — TASK-034 R3's
/// `reactionMotion` closure reading the RESOLVED flag) is pinned at the
/// unit level in the package; the glass cannot observe rendered motion
/// without pixel diffing, which this suite does not do — the RM rows of
/// the §10 checklist are disclosed as manual evidence in the task record.
@MainActor
final class MomoAccessibilityAuditUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    // MARK: The disclosure table (explicit; rows added ONLY with a why)

    /// One disclosed ignore: a surface, an audit type, an element match,
    /// and the reason the issue is accepted. Anything not in this table
    /// fails its audit.
    private struct DisclosedIssue {
        let surface: String
        let auditType: XCUIAccessibilityAuditType
        /// Matches the issue's element identifier or the issue's compact
        /// description (contains, case-insensitive).
        let elementMatch: String
        let reason: String
    }

    private static let disclosures: [DisclosedIssue] = [
        // The S4 text-clipped audit fires on the quest card's wish texts —
        // the ONLY line-limited texts on Home (RigDisciplineTests'
        // homeLineLimitCensusMatchesDisclosure pins that census, so a NEW
        // capped text fails there and must earn its own row): the wish is
        // capped at one line at DEFAULT type with minimumScaleFactor 0.8,
        // so a long wish SCALES instead of truncating (the authored
        // stable-height card, §5.5); at accessibility sizes the cap lifts
        // entirely and the wish wraps in the AC-1b scroll. The audit's
        // heuristic cannot observe the 0.8 scale mitigation.
        DisclosedIssue(
            surface: "S4 Home",
            auditType: .textClipped,
            elementMatch: "Text clipped",
            reason: "the quest wishes' authored one-line default-type cap "
                + "with a 0.8 scale floor — scaling, never truncation; the "
                + "cap lifts at accessibility sizes (AC-1b scroll)"),
        // The S6.2 audit fires ONLY on the system alert's own labels
        // (verified inventory: the 'Erase everything?' title and the message
        // UILabels carry frames; two unnamed internal nodes don't) — "User
        // will not be able to change the font size of this UILabel".
        // UIAlertController owns its labels' type behavior; the app neither
        // can nor should restyle Apple's alert — exactly §10's S6.2 Dynamic
        // Type cell reading "System". Scoped to this surface, this audit
        // type, and this exact issue text: a Dynamic Type issue on ANY app
        // surface still fails.
        DisclosedIssue(
            surface: "S6.2 Erase alert",
            auditType: .dynamicType,
            elementMatch: "Dynamic Type font sizes are partially unsupported",
            reason: "the system alert's own UILabels — Apple's surface, "
                + "outside the app's restyle reach (§10 S6.2: Dynamic Type "
                + "= System)"),
    ]

    // MARK: The audit runner

    /// Runs the FULL audit over the app's current surface, ignoring only
    /// disclosed issues, and fails loudly on anything else.
    private func auditSurface(
        _ app: XCUIApplication,
        surface: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        var undisclosed: [String] = []
        try app.performAccessibilityAudit { issue in
            let elementDescription = issue.element.map { "\($0.identifier) \($0.label)" } ?? ""
            let disclosed = Self.disclosures.contains { row in
                row.surface == surface
                    && issue.auditType == row.auditType
                    && (elementDescription.localizedCaseInsensitiveContains(row.elementMatch)
                        || issue.compactDescription.localizedCaseInsensitiveContains(row.elementMatch))
            }
            if !disclosed {
                undisclosed.append(
                    "[\(surface)] \(issue.auditType): \(issue.compactDescription)"
                    + " — element: '\(elementDescription)'")
                // Frame interpolated by hand: NSStringFromRect is AppKit and
                // does not exist in the iOS test bundle.
                let frame = issue.element?.frame ?? .zero
                let frameText = "\(frame.origin.x),\(frame.origin.y) "
                    + "\(frame.size.width)x\(frame.size.height)"
                print("AUDIT-ISSUE [\(surface)] type=\(issue.auditType.rawValue) "
                    + "compact='\(issue.compactDescription)' "
                    + "detailed='\(issue.detailedDescription)' "
                    + "element-id='\(issue.element?.identifier ?? "")' "
                    + "element-label='\(issue.element?.label ?? "")' "
                    + "element-frame='\(frameText)'")
            }
            return disclosed
        }
        XCTAssertTrue(
            undisclosed.isEmpty,
            "\(surface): \(undisclosed.count) undisclosed accessibility issue(s):\n"
            + undisclosed.joined(separator: "\n"),
            file: file, line: line)
    }

    // MARK: S1–S3 — onboarding

    func testS1MeetSurfacesAuditClean() async throws {
        let app = freshApp()
        app.launch()
        XCTAssertTrue(
            app.staticTexts["This little one just moved in."].waitForExistence(timeout: 10))
        try await auditSurface(app, surface: "S1 Meet")
        assertTargetAtLeast44(app.buttons["Say hello"], "S1 Say hello")
    }

    func testS2NameSurfacesAuditClean() async throws {
        let app = freshApp()
        app.launch()
        app.buttons["Say hello"].tap()
        let field = app.textFields.firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10))
        XCTAssertEqual(field.label, "Pet name", "the S2 field is labeled (§10 S1–S3 row)")
        try await auditSurface(app, surface: "S2 Name")
        assertTargetAtLeast44(app.buttons["Continue"], "S2 Continue")
    }

    func testS3EnterSurfacesAuditClean() async throws {
        let app = freshApp()
        app.launch()
        app.buttons["Say hello"].tap()
        XCTAssertTrue(app.textFields.firstMatch.waitForExistence(timeout: 10))
        app.buttons["Continue"].tap()
        XCTAssertTrue(
            app.staticTexts["This is Momo."].waitForExistence(timeout: 10),
            "S3 interpolates the default name")
        try await auditSurface(app, surface: "S3 Enter")
        assertTargetAtLeast44(app.buttons["Begin"], "S3 Begin")
    }

    // MARK: S4 — Home

    func testS4HomeSurfacesAuditClean() async throws {
        let app = fixtureHomeApp(kind: "stage-crossing")
        try await auditSurface(app, surface: "S4 Home")
        // §10 S4 row: the action pills ≥ 44 pt.
        assertTargetAtLeast44(app.buttons["home.actionPill.feed"], "S4 feed pill")
        assertTargetAtLeast44(app.buttons["home.actionPill.play"], "S4 play pill")
    }

    // MARK: S5 — Room

    func testS5RoomSurfacesAuditClean() async throws {
        let app = fixtureHomeApp(kind: "stage-crossing")
        app.tabBars.buttons["Room"].tap()
        XCTAssertTrue(homeElement(app, "room.scene").waitForExistence(timeout: 10))
        try await auditSurface(app, surface: "S5 Room")
    }

    // MARK: S6 (+ S6.1 legs) — Settings

    func testS6SettingsSurfacesAuditClean() async throws {
        let app = fixtureHomeApp(kind: "stage-crossing")
        app.tabBars.buttons["Settings"].tap()
        let field = homeElement(app, "settings.name.field")
        XCTAssertTrue(field.waitForExistence(timeout: 10))

        // §10 S6.1 row: the rename field is labeled, its value announced,
        // and Save labeled — asserted at the element level (the automated
        // legs of the rename row; the full rename flow's pins live in
        // `MomoSettingsUITests`).
        XCTAssertEqual(field.label, "Pet name", "the rename field is labeled")
        XCTAssertEqual(field.value as? String, "Momo", "the field's value is announced")
        XCTAssertEqual(
            homeElement(app, "settings.name.save").label, "Save", "Save is labeled")

        try await auditSurface(app, surface: "S6 Settings")

        // §10 S6 row: native 44 pt rows — the erase row is a list row.
        assertTargetAtLeast44(homeElement(app, "settings.erase.row"), "S6 erase row")

        // The destructive erase is clearly traited (§10 S6 row): the alert
        // leg below asserts the SYSTEM alert carries the destructive role
        // where it belongs.
    }

    // MARK: S6.2 — the system erase alert

    func testS62EraseAlertAuditsClean() async throws {
        let app = fixtureHomeApp(kind: "stage-crossing")
        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(homeElement(app, "settings.erase.row").waitForExistence(timeout: 10))
        homeElement(app, "settings.erase.row").tap()
        let alert = app.alerts.firstMatch
        XCTAssertTrue(alert.waitForExistence(timeout: 10), "the erase row opens the SYSTEM alert")
        XCTAssertTrue(alert.buttons["Erase"].exists, "the destructive confirm is present")

        try await auditSurface(app, surface: "S6.2 Erase alert")

        alert.buttons["Keep Momo"].tap()
    }

    // MARK: The state-in-words VoiceOver template (§10's S4 row)

    /// The status row's two elements compose the pet state in words:
    /// "{name} feels {mood word} and {energy phrase}." on the mood·energy
    /// element, then "{stage}. {descriptor}." on the stage element — the
    /// shipped rendering of §10's template "{name} feels {mood word} and
    /// has {energy phrase}. You two are {stage}." (a fresh 09:00 pet is
    /// content · energetic · New Friends, so the expected strings are the
    /// concrete catalog compositions).
    ///
    /// **Template delta (disclosed, a finding — not silently patched):**
    /// §10's example ends "You two are Getting Close."; the shipped stage
    /// element speaks "Getting Close. Just getting to know each other." —
    /// the stage WORD without the "You two are" carrier. The mood·energy
    /// half matches the template exactly (the "has" comes from the energy
    /// phrase itself). The delta is recorded in the task file for the
    /// orchestrator's copy decision; this pin asserts the SHIPPED strings
    /// so the audit's evidence is what VoiceOver actually reads.
    func testStatusRowComposesTheStateInWordsTemplate() {
        let app = fixtureHomeApp(kind: "stage-crossing")
        let moodEnergy = homeElement(app, "home.statusRow.moodEnergy")
        XCTAssertTrue(moodEnergy.waitForExistence(timeout: 10))
        XCTAssertEqual(
            moodEnergy.label,
            "Momo feels content and has plenty of energy",
            "the mood·energy element speaks the template's first half verbatim")

        let stage = homeElement(app, "home.statusRow.stage")
        XCTAssertTrue(stage.waitForExistence(timeout: 10))
        XCTAssertEqual(
            stage.label,
            "New Friends. Just getting to know each other.",
            "the stage element speaks the stage word and descriptor")

        // Reading order (disclosed, unobservable at the glass): both
        // composites report IDENTICAL accessibility frames through XCUITest
        // — verified on this exact surface, both minY 28.0, the combined
        // elements collapsing onto the row's frame — so a frame comparison
        // cannot encode VoiceOver's traversal. The order is pinned
        // structurally instead:
        // RigDisciplineTests.homeStatusRowSpeaksMoodEnergyBeforeStage
        // asserts the mood·energy element is DECLARED before the stage
        // element (VoiceOver reads declaration order; source-as-text is the
        // established guard pattern).
    }

    // MARK: Helpers

    /// The §10 target floor: a tappable control's accessibility frame is
    /// ≥ 44 pt on its shorter side.
    private func assertTargetAtLeast44(
        _ element: XCUIElement,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(element.waitForExistence(timeout: 10), "\(name) exists", file: file, line: line)
        XCTAssertGreaterThanOrEqual(
            min(element.frame.width, element.frame.height), 44,
            "\(name) must be a ≥ 44 pt target (§10 global commitments)",
            file: file, line: line)
    }
}
