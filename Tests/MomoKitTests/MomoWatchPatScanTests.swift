import Foundation
import Testing

/// The TASK-042 structural guards over `Apps/MomoWatch` (the pat target):
/// the intent journal has ONE writer (the persister's journal extension —
/// the O1 census), the pat flow is immediate locally and durable in order
/// (reaction fold first; estimate → gate → haptic → append → send; exactly
/// one send leg), and the haptic seam is the single platform touch behind
/// the semantics-typed protocol. The same layered non-vacuity as
/// `MomoWatchGlanceScanTests`: fixture self-tests prove every predicate
/// turns red on its violation in BOTH stub directions (the load-bearing
/// token stripped, and the token present only in a comment — the
/// comment-stripper must let neither fake compliance nor mute a citation),
/// and the standing tests are the restore-green halves over the real tree.
@Suite("Watch pat scan — the offline-first flow, one journal writer, one haptic seam")
struct MomoWatchPatScanTests {

    // MARK: - Fixture self-tests, guard 1 (journal single-writer)

    @Test("stub direction: a second journal touch site fails the census")
    func secondJournalWriterFails() {
        let files: [(name: String, contents: String)] = [
            (name: WatchPatScan.journalFileName, contents: Self.journalLegGreen),
            (name: "MomoWatchAppModel.swift", contents: Self.appModel("        let count = IntentJournal(directory: directory).events().count")),
        ]
        let findings = WatchPatScan.journalWriterViolations(files: files)
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchPatScan.journalWriterGuard)
        #expect(findings.first?.detail.contains("MomoWatchAppModel.swift") == true)
    }

    @Test("stub direction: no journal file at all fails the census")
    func missingJournalFileFails() {
        let findings = WatchPatScan.journalWriterViolations(files: [
            (name: "MomoWatchAppModel.swift", contents: Self.appModel("        _ = 0")),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("exactly one file") == true)
    }

    @Test("a journal type cited only in a doc comment stays legal (the stripper must not mute citations)")
    func journalCommentCitationPasses() {
        let files: [(name: String, contents: String)] = [
            (name: WatchPatScan.journalFileName, contents: Self.journalLegGreen),
            (name: "MomoWatchAppModel.swift", contents: Self.appModel("        // Never touch IntentJournal( here — the O1 census pins it to the persister.")),
        ]
        let findings = WatchPatScan.journalWriterViolations(files: files)
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 2 (pat flow order)

    @Test("stub direction: a pat() that defers the reaction behind the durable leg fails the order leg")
    func patDeferringReactionFails() {
        let pat = [
            "    func pat() {",
            "        Task { await self.finishPat() }",
            "        _ = WatchPatPlan.reactionKind(for: snapshot.display.wakefulness)",
            "    }",
        ].joined(separator: "\n")
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles(pat: pat))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("fold FIRST") == true)
    }

    @Test("stub direction: a pat() that journals inline fails the immediacy leg")
    func patJournallingInlineFails() {
        let pat = [
            "    func pat() {",
            "        _ = WatchPatPlan.reactionKind(for: snapshot.display.wakefulness)",
            "        await persister.appendPat(directory: directory, now: now, calendar: calendar, watchSessionEpoch: epoch, lastAppliedEpoch: epoch, lastAppliedIntentSeq: 0)",
            "    }",
        ].joined(separator: "\n")
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles(pat: pat))
        #expect(findings.contains { $0.detail.contains("durable-leg work inline") }, "\(findings)")
    }

    @Test("stub direction: a durable leg without the pending-count read fails that leg alone")
    func finishWithoutEstimateFails() {
        let finish = [
            "    func finishPat() async {",
            "        if snapshot.hapticsEnabled {",
            "            haptics.play(.tick)",
            "        }",
            "        _ = await persister.appendPat(directory: directory, now: now, calendar: calendar, watchSessionEpoch: epoch, lastAppliedEpoch: epoch, lastAppliedIntentSeq: 0)",
            "        transport.sendUserInfo(payload: payload)",
            "    }",
        ].joined(separator: "\n")
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles(finish: finish))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("persister.pendingPatCount(") == true)
    }

    @Test("stub direction: a haptic played outside the gate fails the toggle leg")
    func finishPlayingOutsideGateFails() {
        let finish = [
            "    func finishPat() async {",
            "        _ = await persister.pendingPatCount(directory: directory, epoch: epoch)",
            "        haptics.play(.tick)",
            "        if snapshot.hapticsEnabled { _ = 0 }",
            "        _ = await persister.appendPat(directory: directory, now: now, calendar: calendar, watchSessionEpoch: epoch, lastAppliedEpoch: epoch, lastAppliedIntentSeq: 0)",
            "        transport.sendUserInfo(payload: payload)",
            "    }",
        ].joined(separator: "\n")
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles(finish: finish))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("OUTSIDE the hapticsEnabled gate") == true)
    }

    @Test("stub direction: journaling before the haptic fails the R3 order leg")
    func finishJournallingBeforeHapticFails() {
        let finish = [
            "    func finishPat() async {",
            "        _ = await persister.pendingPatCount(directory: directory, epoch: epoch)",
            "        _ = await persister.appendPat(directory: directory, now: now, calendar: calendar, watchSessionEpoch: epoch, lastAppliedEpoch: epoch, lastAppliedIntentSeq: 0)",
            "        if snapshot.hapticsEnabled {",
            "            haptics.play(.tick)",
            "        }",
            "        transport.sendUserInfo(payload: payload)",
            "    }",
        ].joined(separator: "\n")
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles(finish: finish))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("fires FIRST") == true)
    }

    @Test("stub direction: sending before the append fails the drain-order leg")
    func finishSendingBeforeAppendFails() {
        let finish = [
            "    func finishPat() async {",
            "        _ = await persister.pendingPatCount(directory: directory, epoch: epoch)",
            "        if snapshot.hapticsEnabled {",
            "            haptics.play(.tick)",
            "        }",
            "        transport.sendUserInfo(payload: payload)",
            "        _ = await persister.appendPat(directory: directory, now: now, calendar: calendar, watchSessionEpoch: epoch, lastAppliedEpoch: epoch, lastAppliedIntentSeq: 0)",
            "    }",
        ].joined(separator: "\n")
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles(finish: finish))
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("only journaled events drain") == true)
    }

    @Test("stub direction: a second send leg anywhere in the target fails the send census alone")
    func secondSendLegFails() {
        let files: [(name: String, contents: String)] = Self.patFiles()
        + [(name: "MomoWatchTransport.swift", contents: "func resend() {\n        transport.sendUserInfo(payload: payload)\n    }")]
        let findings = WatchPatScan.patFlowViolations(files: files)
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("expected exactly 1 transport.sendUserInfo(") == true)
    }

    @Test("a send leg cited only in a doc comment cannot break the census (stripper)")
    func sendCommentCitationPasses() {
        let files: [(name: String, contents: String)] = Self.patFiles()
        + [(name: "MomoWatchTransport.swift", contents: "// The app model's transport.sendUserInfo(payload: leg lands in MomoWatchPat.swift.")]
        let findings = WatchPatScan.patFlowViolations(files: files)
        #expect(findings.isEmpty, "\(findings)")
    }

    @Test("green fixture: fold-then-defer pat + ordered durable leg produce no finding")
    func patFlowGreenFixturePasses() {
        let findings = WatchPatScan.patFlowViolations(files: Self.patFiles())
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 3 (haptic seam)

    @Test("stub direction: a missing seam protocol fails that leg alone")
    func missingSeamProtocolFails() {
        let pat = Self.patFileWithout([
            "protocol MomoWatchHaptics: AnyObject {",
        ])
        let findings = WatchPatScan.hapticSeamViolations(files: [(name: WatchPatScan.patFileName, contents: pat)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("seam protocol is missing") == true)
    }

    @Test("stub direction: a seam method that is not semantics-typed fails that leg alone")
    func untypedSeamMethodFails() {
        let pat = Self.patFileWithout(["    func play(_ haptic: WatchPatHaptic)"])
        let findings = WatchPatScan.hapticSeamViolations(files: [(name: WatchPatScan.patFileName, contents: pat)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("semantics-typed") == true)
    }

    @Test("stub direction: a platform haptic call outside the seam file fails the census")
    func platformTouchOutsideSeamFails() {
        let files: [(name: String, contents: String)] = [
            (name: WatchPatScan.patFileName, contents: Self.seamGreen),
            (name: "GlanceView.swift", contents: "func buzz() {\n        WKInterfaceDevice.current().play(.click)\n    }"),
        ]
        let findings = WatchPatScan.hapticSeamViolations(files: files)
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchPatScan.hapticSeamGuard)
        #expect(findings.first?.detail.contains("GlanceView.swift") == true)
    }

    @Test("green fixture: the protocol + typed play + one platform touch produce no finding")
    func hapticSeamGreenFixturePasses() {
        let findings = WatchPatScan.hapticSeamViolations(files: [
            (name: WatchPatScan.patFileName, contents: Self.seamGreen),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - The standing scans over the real Watch target
    // (the restore-green halves; the mutation bites are recorded in the task file)

    @Test("Apps/MomoWatch as it stands touches the intent journal in exactly one file")
    func realTreeJournalIsSingleWriter() throws {
        let sources = try KitRepo.momoWatchSources()
        #expect(!sources.isEmpty, "Apps/MomoWatch must exist and contain Swift sources")
        let findings = WatchPatScan.journalWriterViolations(files: sources)
        #expect(findings.isEmpty, "journal-writer violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands pats immediately and drains in order")
    func realTreePatFlowIsOrdered() throws {
        let sources = try KitRepo.momoWatchSources()
        let findings = WatchPatScan.patFlowViolations(files: sources)
        #expect(findings.isEmpty, "pat-flow violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands keeps the platform haptic in the one seam")
    func realTreeHapticSeamIsSingle() throws {
        let sources = try KitRepo.momoWatchSources()
        let findings = WatchPatScan.hapticSeamViolations(files: sources)
        #expect(findings.isEmpty, "haptic-seam violation: \(findings)")
    }

    // MARK: - Fixtures

    /// Assembles a fixture pat file from the green pat + finish bodies
    /// (overridable per stub direction).
    private static func patFiles(
        pat: String? = nil,
        finish: String? = nil
    ) -> [(name: String, contents: String)] {
        var contents = Self.patFileWithout([])
        contents += "\n" + (pat ?? [
            "    func pat() {",
            "        _ = WatchPatPlan.reactionKind(for: snapshot.display.wakefulness)",
            "        Task { await self.finishPat() }",
            "    }",
        ].joined(separator: "\n"))
        contents += "\n" + (finish ?? [
            "    func finishPat() async {",
            "        _ = await persister.pendingPatCount(directory: directory, epoch: epoch)",
            "        if snapshot.hapticsEnabled {",
            "            haptics.play(.tick)",
            "        }",
            "        _ = await persister.appendPat(directory: directory, now: now, calendar: calendar, watchSessionEpoch: epoch, lastAppliedEpoch: epoch, lastAppliedIntentSeq: 0)",
            "        transport.sendUserInfo(payload: payload)",
            "    }",
        ].joined(separator: "\n"))
        return [(name: WatchPatScan.patFileName, contents: contents)]
    }

    /// The green seam file skeleton, minus the given lines (stubbing by
    /// removal — the red direction for presence predicates).
    private static func patFileWithout(_ absent: [String]) -> String {
        Self.seamGreen
            .components(separatedBy: "\n")
            .filter { line in !absent.contains(where: { line.contains($0) }) }
            .joined(separator: "\n")
    }

    /// The green seam: protocol, typed play, live conformance with the one
    /// platform touch.
    private static let seamGreen = [
        "protocol MomoWatchHaptics: AnyObject {",
        "    func play(_ haptic: WatchPatHaptic)",
        "}",
        "final class LiveWatchHaptics: MomoWatchHaptics {",
        "    func play(_ haptic: WatchPatHaptic) {",
        "        WKInterfaceDevice.current().play(.click)",
        "    }",
        "}",
    ].joined(separator: "\n")

    /// The green journal-extension file (one touch site).
    private static let journalLegGreen = [
        "extension MomoWatchSnapshotPersister {",
        "    func appendPat(directory: URL) -> IntentEvent? {",
        "        let journal = IntentJournal(directory: directory)",
        "        return nil",
        "    }",
        "}",
    ].joined(separator: "\n")

    /// A fixture app model wrapper with one code line (the red direction
    /// for the journal census).
    private static func appModel(_ line: String) -> String {
        [
            "final class MomoWatchAppModel {",
            "    func probe() {",
            line,
            "    }",
            "}",
        ].joined(separator: "\n")
    }
}
