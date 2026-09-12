import Foundation
import Testing

/// The TASK-043 structural guards over `Apps/MomoWatch` (the live quest
/// line): the quest slot is display-only on the ONE live read (the pat
/// canvas + pill stay the only targets), the stored line recomputes at
/// exactly the four disclosed legs, and no settings surface exists anywhere
/// in the target (UX-13 — settings are iPhone-owned). The same layered
/// non-vacuity as `MomoWatchPatScanTests`: fixture self-tests prove every
/// predicate turns red on its violation in BOTH stub directions (the
/// load-bearing token stripped, and the token present only in a comment —
/// the comment-stripper must let neither fake compliance nor mute a
/// citation), and the standing tests are the restore-green halves over the
/// real tree.
@Suite("Watch quest scan — display-only slot, four recompute legs, no settings surface (UX-13)")
struct MomoWatchQuestScanTests {

    // MARK: - Fixture self-tests, guard 1 (display-only slot, one live read)

    @Test("stub direction: a tappable quest slot fails the display-only leg")
    func tappableQuestSlotFails() {
        // The pill leaves with the slot's Button, so the pat-target census
        // stays at exactly 1 and ONLY the display-only leg goes red.
        let glance = Self.glanceWithout(["        Button(action: { model.pat() }) { Text(\"Pat\") }"])
            .replacingOccurrences(
                of: "        Text(MomoCopyText.render(questLineKey(for: questLine)))",
                with: "        Button(action: { model.claim() }) { Text(\"claim\") }"
            )
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("action affordance: Button(") == true, "\(findings)")
    }

    @Test("stub direction: a tap gesture on the quest slot fails the display-only leg")
    func tapGestureQuestSlotFails() {
        // The canvas leaves with the slot's gesture, so the pat-target
        // census stays at exactly 1 and ONLY the display-only leg goes red.
        let glance = Self.glanceWithout(["        Rectangle().onTapGesture { model.pat() }"])
            .replacingOccurrences(
                of: "        Text(MomoCopyText.render(questLineKey(for: questLine)))",
                with: "        Text(\"wish\").onTapGesture { model.claim() }"
            )
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("action affordance: .onTapGesture") == true, "\(findings)")
    }

    @Test("stub direction: a second button in the file fails the pat-target census alone")
    func extraButtonFailsCensus() {
        let glance = Self.glanceGreen + "\n" + "    private func stray() -> some View {\n        Button(\"x\") {}\n    }"
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("expected exactly 1 Button(") == true, "\(findings)")
    }

    @Test("stub direction: reverting to the frozen line fails the live-read census alone")
    func frozenRevertFailsLiveReadCensus() {
        let glance = Self.glanceWithout([
            "        let questLine = model.liveQuestLine ?? snapshot.display.questLine",
        ])
        .replacingOccurrences(
            of: "        return VStack {",
            with: "        let questLine = snapshot.display.questLine\n        return VStack {"
        )
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("expected exactly 1 model.liveQuestLine") == true, "\(findings)")
    }

    @Test("stub direction: two frozen-line reads fail both halves of the value census")
    func doubleFrozenReadFailsValueCensus() {
        let glance = Self.glanceWithout([
            "        let questLine = model.liveQuestLine ?? snapshot.display.questLine",
        ])
        .replacingOccurrences(
            of: "        return VStack {",
            with: "        let questLine = snapshot.display.questLine\n        let echo = snapshot.display.questLine\n        return VStack {"
        )
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(glance)])
        #expect(findings.count == 2, "\(findings)")
        #expect(findings.contains { $0.detail.contains("model.liveQuestLine") }, "\(findings)")
        #expect(findings.contains { $0.detail.contains(".display.questLine read") }, "\(findings)")
    }

    @Test("a live read cited only in a doc comment stays legal (the stripper must not mute citations)")
    func glanceCommentCitationPasses() {
        let glance = Self.glanceGreen
            + "\n    // Never add a second model.liveQuestLine or Button( here — the census pins one each."
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(glance)])
        #expect(findings.isEmpty, "\(findings)")
    }

    @Test("green fixture: a Text slot over the one live read + two pat targets produce no finding")
    func questSlotGreenFixturePasses() {
        let findings = WatchQuestScan.questSlotViolations(files: [Self.glanceFile(Self.glanceGreen)])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 2 (the four recompute legs)

    @Test("stub direction: a dropped activation leg fails the count census alone")
    func droppedActivationLegFailsCount() {
        // The gate stays; only the recompute call leaves — the count census
        // (3 calls) is the one red leg.
        let phase = [
            "    func scenePhaseChanged(to phase: ScenePhase) {",
            "        if phase == .active {",
            "            return",
            "        }",
            "        guard phase == .background else { return }",
            "    }",
        ].joined(separator: "\n")
        let model = Self.modelFile(receiveCall: true, phaseBody: phase)
        let findings = WatchQuestScan.recomputeLegsViolations(files: [Self.modelFixture(model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("expected exactly 4 recomputeQuestLine() call legs") == true, "\(findings)")
    }

    @Test("stub direction: an undeclared fifth leg fails the count census alone")
    func fifthLegFailsCount() {
        let model = Self.modelFile(receiveCall: true, extraLegs: 3)
        let findings = WatchQuestScan.recomputeLegsViolations(files: [Self.modelFixture(model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("found 5") == true, "\(findings)")
    }

    @Test("stub direction: an ungated scene handler fails the activation-gate leg alone")
    func ungatedActivationFails() {
        let phase = [
            "    func scenePhaseChanged(to phase: ScenePhase) {",
            "        recomputeQuestLine()",
            "        guard phase == .background else { return }",
            "    }",
        ].joined(separator: "\n")
        let model = Self.modelFile(receiveCall: true, phaseBody: phase)
        let findings = WatchQuestScan.recomputeLegsViolations(files: [Self.modelFixture(model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("gate the activation leg on the active phase") == true, "\(findings)")
    }

    @Test("stub direction: a receive that never recomputes fails the receive leg alone")
    func receiveWithoutRecomputeFails() {
        // The top-up keeps the total at exactly four calls, so ONLY the
        // receive-leg predicate goes red.
        let model = Self.modelFile(receiveCall: false, extraLegs: 3)
        let findings = WatchQuestScan.recomputeLegsViolations(files: [Self.modelFixture(model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("receiveContext never recomputes") == true, "\(findings)")
    }

    @Test("a recompute leg cited only in a doc comment stays legal (the stripper must not mute citations)")
    func modelCommentCitationPasses() {
        let model = Self.modelFile(receiveCall: true)
            + "\n    // The init recomputeQuestLine() leg is the first of the four."
        let findings = WatchQuestScan.recomputeLegsViolations(files: [Self.modelFixture(model)])
        #expect(findings.isEmpty, "\(findings)")
    }

    @Test("green fixture: one definition + the four gated legs produce no finding")
    func recomputeLegsGreenFixturePasses() {
        let findings = WatchQuestScan.recomputeLegsViolations(files: [Self.modelFixture(Self.modelFile(receiveCall: true))])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 3 (no settings surface, UX-13)

    @Test("stub direction: a settings toggle in a Watch source fails the token ban")
    func settingsToggleFails() {
        // A non-View holder, so the view census stays at 1 and ONLY the
        // token ban goes red (the full settings screen is the next test).
        let files: [(name: String, contents: String)] = Self.glanceFiles
        + [(name: "MomoWatchProbe.swift", contents: "final class Probe {\n    func make() {\n        _ = Toggle(\"Haptics\", isOn: .constant(true))\n    }\n}")]
        let findings = WatchQuestScan.noSettingsViolations(files: files)
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchQuestScan.noSettingsSurfaceGuard)
        #expect(findings.first?.detail.contains("Toggle(") == true, "\(findings)")
    }

    @Test("stub direction: a presented sheet fails the token ban")
    func presentedSheetFails() {
        let files: [(name: String, contents: String)] = Self.glanceFiles
        + [(name: "MomoWatchApp.swift", contents: "struct A: App {\n    var body: some Scene {\n        WindowGroup { Text(\"x\").sheet { Text(\"s\") } }\n    }\n}")]
        let findings = WatchQuestScan.noSettingsViolations(files: files)
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains(".sheet") == true, "\(findings)")
    }

    @Test("stub direction: a second view declaration fails the view census alone")
    func secondViewFailsCensus() {
        let files: [(name: String, contents: String)] = Self.glanceFiles
        + [(name: "MomoWatchSettingsView.swift", contents: "struct SettingsScreen: View {\n    var body: some View { Text(\"s\") }\n}")]
        let findings = WatchQuestScan.noSettingsViolations(files: files)
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("expected exactly 1 : View declaration") == true, "\(findings)")
    }

    @Test("a banned surface cited only in a doc comment stays legal (the stripper must not mute citations)")
    func settingsCommentCitationPasses() {
        let files: [(name: String, contents: String)] = [
            Self.glanceFile(Self.glanceGreen + "\n// UX-13: no Toggle( or NavigationStack( may ever appear in this target."),
        ]
        let findings = WatchQuestScan.noSettingsViolations(files: files)
        #expect(findings.isEmpty, "\(findings)")
    }

    @Test("green fixture: the single glance view with no settings surface produces no finding")
    func settingsGreenFixturePasses() {
        let findings = WatchQuestScan.noSettingsViolations(files: Self.glanceFiles)
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - The standing scans over the real Watch target
    // (the restore-green halves; the mutation bites are recorded in the task file)

    @Test("Apps/MomoWatch as it stands keeps the quest slot display-only on the one live read")
    func realTreeQuestSlotIsDisplayOnly() throws {
        let sources = try KitRepo.momoWatchSources()
        #expect(!sources.isEmpty, "Apps/MomoWatch must exist and contain Swift sources")
        let findings = WatchQuestScan.questSlotViolations(files: sources)
        #expect(findings.isEmpty, "quest-slot violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands recomputes the live line at exactly the four legs")
    func realTreeRecomputeLegsHold() throws {
        let sources = try KitRepo.momoWatchSources()
        let findings = WatchQuestScan.recomputeLegsViolations(files: sources)
        #expect(findings.isEmpty, "recompute-legs violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands declares no settings surface (UX-13)")
    func realTreeHasNoSettingsSurface() throws {
        let sources = try KitRepo.momoWatchSources()
        let findings = WatchQuestScan.noSettingsViolations(files: sources)
        #expect(findings.isEmpty, "settings-surface violation: \(findings)")
    }

    // MARK: - Fixtures

    /// The green glance: the one live read with the frozen fallback, a Text
    /// quest slot, and exactly the two pat targets (canvas tap + pill
    /// button).
    private static let glanceGreen = [
        "struct GlanceView: View {",
        "    private func glance(for snapshot: WatchSnapshot) -> some View {",
        "        let questLine = model.liveQuestLine ?? snapshot.display.questLine",
        "        return VStack {",
        "            questSlot(for: questLine)",
        "        }",
        "    }",
        "    private func questSlot(for questLine: QuestGeneration.QuestLine) -> some View {",
        "        Text(MomoCopyText.render(questLineKey(for: questLine)))",
        "    }",
        "    private var petCanvas: some View {",
        "        Rectangle().onTapGesture { model.pat() }",
        "    }",
        "    private var patPill: some View {",
        "        Button(action: { model.pat() }) { Text(\"Pat\") }",
        "    }",
        "}",
    ].joined(separator: "\n")

    /// The green glance wrapped as the file tuple, plus a companion app
    /// model file (so the guard-3 view census holds at exactly one).
    private static var glanceFiles: [(name: String, contents: String)] {
        [glanceFile(glanceGreen), (name: "MomoWatchAppModel.swift", contents: "final class MomoWatchAppModel {}")]
    }

    private static func glanceFile(_ contents: String) -> (name: String, contents: String) {
        (name: WatchQuestScan.glanceFileName, contents: contents)
    }

    /// The green glance, minus the given lines (stubbing by removal — the
    /// red direction for the censuses).
    private static func glanceWithout(_ absent: [String]) -> String {
        glanceGreen
            .components(separatedBy: "\n")
            .filter { line in !absent.contains(where: { line.contains($0) }) }
            .joined(separator: "\n")
    }

    /// A fixture app model: the definition, a receiveContext body whose
    /// recompute call is present (`receiveCall`) or stubbed out, a
    /// scenePhaseChanged with the gated activation leg (or `phaseBody`), and
    /// `extraLegs` top-up calls (default keeps the total at exactly four).
    private static func modelFile(
        receiveCall: Bool,
        phaseBody: String? = nil,
        extraLegs: Int? = nil
    ) -> String {
        let phase = phaseBody ?? [
            "    func scenePhaseChanged(to phase: ScenePhase) {",
            "        if phase == .active {",
            "            recomputeQuestLine()",
            "            return",
            "        }",
            "        guard phase == .background else { return }",
            "    }",
        ].joined(separator: "\n")
        let receive = receiveCall
            ? "        recomputeQuestLine()"
            : "        _ = 0"
        let topUp = extraLegs ?? (receiveCall ? 2 : 3)
        let topUpLines = (0..<topUp).map { _ in "        recomputeQuestLine()" }
        return [
            "final class MomoWatchAppModel {",
            "    private func recomputeQuestLine() {",
            "        _ = 0",
            "    }",
            "    func receiveContext(_ data: Data) async {",
            receive,
            "    }",
            phase,
            "    func extraLegs() {",
            topUpLines.joined(separator: "\n"),
            "    }",
            "}",
        ].joined(separator: "\n")
    }

    private static func modelFixture(_ contents: String) -> (name: String, contents: String) {
        (name: WatchQuestScan.appModelFileName, contents: contents)
    }
}
