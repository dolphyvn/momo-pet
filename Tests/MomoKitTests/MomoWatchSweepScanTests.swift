import Foundation
import Testing
@testable import MomoKit

/// The TASK-044 R1 structural suite for the launch sweep (the
/// `MomoWatchPatScanTests` shape): both directions per pin — a green
/// fixture with the exact shipped shape, and stub directions that break
/// each load-bearing leg EXACTLY once — plus the standing real-tree runs
/// over `KitRepo.momoWatchSources()`. The executor-level behavior itself is
/// pinned by `WatchSweepPlanTests` (the pure core) and the MomoWatchUITests
/// flows; this suite pins the WIRING the pure core cannot see.
@Suite("MomoWatchSweepScan — the launch sweep's wiring is pinned (TASK-044 R1)")
struct MomoWatchSweepScanTests {

    // MARK: - Fixtures

    private static let greenAppModel = """
    final class MomoWatchAppModel {
        init() {
            transport.onContextData = { _ in }
            transport.onActivation = { }
            transport.activate()
        }

        private func armLaunchSweep() {
            sweepArmed = true
            consumedEraseCountAtArm = consumedEraseCount
        }

        private func flushStrandedJournal() async {
            guard sweepArmed else { return }
            sweepArmed = false
            let journal = await persister.pendingEvents(directory: storeDirectory)
            let drainable = WatchSweepPlan.drainableEvents(
                journal: journal,
                epoch: watchSessionEpoch,
                consumedEraseCountAtArm: consumedEraseCountAtArm,
                consumedEraseCountNow: consumedEraseCount
            )
            for event in drainable {
                transport.sendUserInfo(payload: event.encoded()!)
            }
        }

        func receiveContext(_ data: Data) async {
            if case .consume = decide() {
                await persister.consumeWipe(directory: storeDirectory, eraseCount: 1)
                await flushStrandedJournal()
                return
            }
            await persister.persist(directory: storeDirectory, snapshot: snap)
            await persister.pruneJournal(directory: storeDirectory, watermarkEpoch: e, watermarkSeq: 0)
            await flushStrandedJournal()
        }
    }
    """

    private static let greenTransport = """
    protocol MomoWatchTransporting: AnyObject {
        var onActivation: (@Sendable () -> Void)? { get set }
    }
    final class LiveWatchTransport {
        var onActivation: (@Sendable () -> Void)?
        func session(_ session: WCSession, activationDidCompleteWith state: WCSessionActivationState, error: Error?) {
            onActivation?()
        }
    }
    """

    private static let greenJournal = """
    extension MomoWatchSnapshotPersister {
        func pendingEvents(directory: URL) -> [IntentEvent] { [] }
    }
    """

    private func sweepFiles(
        appModel: String = greenAppModel,
        transport: String = greenTransport,
        journal: String = greenJournal
    ) -> [(name: String, contents: String)] {
        [
            (name: WatchSweepScan.appModelFileName, contents: appModel),
            (name: WatchSweepScan.transportFileName, contents: transport),
            (name: WatchSweepScan.journalFileName, contents: journal),
        ]
    }

    // MARK: - The green fixture

    @Test("green fixture: the armed sweep with both decision legs produces no finding")
    func greenFixture() {
        #expect(WatchSweepScan.sweepWiringViolations(files: sweepFiles()).isEmpty)
        #expect(WatchSweepScan.transportArmViolations(files: sweepFiles()).isEmpty)
        #expect(WatchSweepScan.noTimersViolations(files: sweepFiles()).isEmpty)
    }

    // MARK: - Guard 1 stub directions: the sweep wiring

    @Test("stub direction: activation before the sinks' binding fails the init order leg alone")
    func initOrderSwapFails() {
        let swapped = Self.greenAppModel
            .replacingOccurrences(of: "transport.onActivation = { }\n", with: "")
            .replacingOccurrences(
                of: "transport.activate()",
                with: "transport.activate()\n        transport.onActivation = { }"
            )
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: swapped))
        #expect(violations.count == 1)
        #expect(violations.first?.guardName == WatchSweepScan.sweepWiringGuard)
        #expect(violations.first?.detail.contains("sink-before-activate") == true)
    }

    @Test("stub direction: a missing arm leg fails the arm pin alone")
    func missingArmLegFails() {
        let armless = Self.greenAppModel
            .replacingOccurrences(of: "sweepArmed = true\n", with: "")
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: armless))
        #expect(violations.count == 1)
        #expect(violations.first?.detail.contains("armLaunchSweep() is missing a leg: sweepArmed = true") == true)
    }

    @Test("stub direction: a missing one-shot disarm fails the drain pin alone")
    func missingDisarmFails() {
        let sticky = Self.greenAppModel
            .replacingOccurrences(of: "sweepArmed = false\n", with: "")
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: sticky))
        #expect(violations.count == 1)
        #expect(violations.first?.detail.contains("missing a leg: sweepArmed = false") == true)
    }

    @Test("stub direction: sending before the one-writer read fails the read-before-send order alone")
    func sendBeforeReadFails() {
        let drainBlock = [
            "        let journal = await persister.pendingEvents(directory: storeDirectory)",
            "        let drainable = WatchSweepPlan.drainableEvents(",
            "            journal: journal,",
            "            epoch: watchSessionEpoch,",
            "            consumedEraseCountAtArm: consumedEraseCountAtArm,",
            "            consumedEraseCountNow: consumedEraseCount",
            "        )",
        ].joined(separator: "\n")
        let sendBlock = [
            "        for event in drainable {",
            "            transport.sendUserInfo(payload: event.encoded()!)",
            "        }",
        ].joined(separator: "\n")
        let eager = Self.greenAppModel
            .replacingOccurrences(of: drainBlock + "\n" + sendBlock, with: sendBlock + "\n" + drainBlock)
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: eager))
        #expect(violations.count == 1, "\(violations)")
        #expect(violations.first?.detail.contains("sends before (or regardless of) the one-writer journal read") == true)
    }

    @Test("stub direction: a single decision leg fails the flush census alone")
    func missingSteadyLegFails() {
        let singleLeg = Self.greenAppModel.replacingOccurrences(
            of: "await persister.pruneJournal(directory: storeDirectory, watermarkEpoch: e, watermarkSeq: 0)\n        await flushStrandedJournal()",
            with: "await persister.pruneJournal(directory: storeDirectory, watermarkEpoch: e, watermarkSeq: 0)"
        )
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: singleLeg))
        #expect(violations.count == 1)
        #expect(violations.first?.detail.contains("exactly 2 receive decision legs") == true)
    }

    @Test("stub direction: a steady leg ahead of the prune fails the prune-order pin alone")
    func steadyFlushBeforePruneFails() {
        let early = Self.greenAppModel.replacingOccurrences(
            of: [
                "        await persister.persist(directory: storeDirectory, snapshot: snap)",
                "        await persister.pruneJournal(directory: storeDirectory, watermarkEpoch: e, watermarkSeq: 0)",
                "        await flushStrandedJournal()",
            ].joined(separator: "\n"),
            with: [
                "        await flushStrandedJournal()",
                "        await persister.persist(directory: storeDirectory, snapshot: snap)",
                "        await persister.pruneJournal(directory: storeDirectory, watermarkEpoch: e, watermarkSeq: 0)",
            ].joined(separator: "\n")
        )
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: early))
        #expect(violations.count == 1, "\(violations)")
        #expect(violations.first?.detail.contains("must follow the watermark prune") == true)
    }

    @Test("stub direction: a consume leg ahead of the wipe fails the post-wipe pin alone")
    func consumeFlushBeforeWipeFails() {
        let early = Self.greenAppModel.replacingOccurrences(
            of: [
                "            await persister.consumeWipe(directory: storeDirectory, eraseCount: 1)",
                "            await flushStrandedJournal()",
            ].joined(separator: "\n"),
            with: [
                "            await flushStrandedJournal()",
                "            await persister.consumeWipe(directory: storeDirectory, eraseCount: 1)",
            ].joined(separator: "\n")
        )
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: early))
        #expect(violations.count == 1, "\(violations)")
        #expect(violations.first?.detail.contains("must follow its awaited consumeWipe") == true)
    }

    @Test("stub direction: a comment-only flush call cannot green the census")
    func commentOnlyFlushFails() {
        let commented = Self.greenAppModel.replacingOccurrences(
            of: "await flushStrandedJournal()",
            with: "// await flushStrandedJournal()"
        )
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: commented))
        #expect(violations.count == 1, "\(violations)")
        #expect(violations.first?.detail.contains("receive decision legs") == true)
        #expect(violations.first?.detail.contains("found 0") == true)
    }

    @Test("stub direction: a sweep read outside the one-writer extension fails the O1 pin alone")
    func pendingEventsOffTheOneWriterFails() {
        let homeless = Self.greenJournal.replacingOccurrences(
            of: "func pendingEvents(directory: URL)", with: "func sweepRead(directory: URL)"
        )
        let violations = WatchSweepScan.sweepWiringViolations(files: sweepFiles(journal: homeless))
        #expect(violations.count == 1)
        #expect(violations.first?.file == WatchSweepScan.journalFileName)
        #expect(violations.first?.detail.contains("one-writer extension (O1)") == true)
    }

    // MARK: - Guard 2 stub directions: the transport arm signal

    @Test("stub direction: a transport without the activation sink fails its declaration pins")
    func transportWithoutSinkFails() {
        let sinkless = Self.greenTransport.replacingOccurrences(
            of: "    var onActivation: (@Sendable () -> Void)? { get set }\n", with: ""
        ).replacingOccurrences(
            of: "    var onActivation: (@Sendable () -> Void)?\n", with: ""
        )
        let violations = WatchSweepScan.transportArmViolations(files: sweepFiles(transport: sinkless))
        #expect(violations.count == 2)
        #expect(violations.allSatisfy { $0.guardName == WatchSweepScan.transportArmGuard })
    }

    @Test("stub direction: an activation delegate that never raises the sink fails alone")
    func delegateWithoutRaiseFails() {
        let silent = Self.greenTransport.replacingOccurrences(of: "onActivation?()\n", with: "")
        let violations = WatchSweepScan.transportArmViolations(files: sweepFiles(transport: silent))
        #expect(violations.count == 1)
        #expect(violations.first?.detail.contains("does not raise the onActivation sink") == true)
    }

    // MARK: - Guard 3 stub directions: event-driven only

    @Test("stub direction: a timer token in any production source fails; the other guards stay green")
    func timerTokenFails() {
        let timed = Self.greenAppModel.replacingOccurrences(
            of: "    func receiveContext(",
            with: "    let t = Timer(timeInterval: 1, repeats: true) { _ in }\n    func receiveContext("
        )
        #expect(WatchSweepScan.noTimersViolations(files: sweepFiles(appModel: timed)).count == 1)
        #expect(WatchSweepScan.sweepWiringViolations(files: sweepFiles(appModel: timed)).isEmpty,
                "the timer ban is its own guard — a timer mutation bites exactly one")
    }

    // MARK: - The standing real-tree runs

    @Test("Apps/MomoWatch as it stands arms the sweep and drains at the decision legs")
    func realTreeSweepWiring() throws {
        let findings = WatchSweepScan.sweepWiringViolations(files: try KitRepo.momoWatchSources())
        #expect(findings.isEmpty, "sweep-wiring violation: \(findings)")
    }

    @Test("the transport as it stands raises activation completion")
    func realTreeTransportArm() throws {
        let findings = WatchSweepScan.transportArmViolations(files: try KitRepo.momoWatchSources())
        #expect(findings.isEmpty, "transport-arm violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands carries no timer tokens")
    func realTreeNoTimers() throws {
        let findings = WatchSweepScan.noTimersViolations(files: try KitRepo.momoWatchSources())
        #expect(findings.isEmpty, "timer-token violation: \(findings)")
    }
}
