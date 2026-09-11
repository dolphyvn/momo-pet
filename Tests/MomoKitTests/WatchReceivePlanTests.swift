import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-040 R2 receive-plan suite (05 §6.4; ADR-003): the pure decision
/// matrix through `WatchReceivePlan.decide` (the accessor-driven
/// composition — the plan resolves `SyncState.shouldApply`, never a raw
/// gate), INV-10's EXACTLY-ONCE shape over the FIFO contract stream with
/// duplicates/replays/redeliveries, O2's AT-MOST-ONCE shape under seeded
/// shuffles (never "strengthened" — a stale unseen-UUID event under a
/// shuffled order is a legitimate no-op), and the F-1 watermark-propagation
/// leg: an applied intent's `postSync` is what the NEXT snapshot builds
/// from, driven through `AppModelPlanCore.plan` exactly as the executor's
/// receive path will route it.
@Suite("WatchReceivePlan — accessor-driven decisions, INV-10, F-1 propagation (TASK-040; 05 §6.4)")
struct WatchReceivePlanTests {

    private let fixture = SyncFixture()
    private let storeFixture = StoreFixture()

    /// The injected UTC calendar (the StoreFixture derivation; no ambient).
    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }

    /// A fixed clock (the receive path's fold-to-now input at kit level).
    private var clock: some EngineClock {
        TickingClock(at: fixture.instant("2026-09-09T21:30:00Z"), step: 0)
    }

    // MARK: - The decision matrix

    @Test("a new event applies and the postSync records its watermark (max-semantics)")
    func newEventAppliesAndRecords() throws {
        let event = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 4)
        guard case .apply(let postSync) = WatchReceivePlan.decide(
            event: event, sync: SyncState(), seenIntentIDs: []
        ) else {
            Issue.record("a first-ever event must apply")
            return
        }
        #expect(postSync.watermark(for: fixture.epoch1) == 4)
        #expect(postSync.nextSnapshotSeq == SyncState().nextSnapshotSeq,
                "the receive path consumes no snapshot seq — that is the push's")
    }

    @Test("a duplicate UUID is a full no-op — even with a HIGHER seq than the watermark")
    func duplicateUUIDIgnores() {
        let event = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        guard case .apply(let postSync) = WatchReceivePlan.decide(
            event: event, sync: SyncState(), seenIntentIDs: []
        ) else {
            Issue.record("precondition: the first delivery applies")
            return
        }
        let redelivered = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 9)
        #expect(WatchReceivePlan.decide(event: redelivered, sync: postSync, seenIntentIDs: [fixture.intentID(1)])
            == .ignore, "the UUID belt guards before the seq half is ever consulted")
    }

    @Test("an unseen UUID at or below the epoch watermark is a full no-op (the seq half)")
    func staleSeqIgnores() {
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 5)
        )
        let stale = fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 5)
        let older = fixture.event(fixture.intent(id: fixture.intentID(3)), epoch: fixture.epoch1, seq: 1)
        #expect(WatchReceivePlan.decide(event: stale, sync: sync, seenIntentIDs: []) == .ignore,
                "EQUAL to the watermark is stale — the gate is strictly greater")
        #expect(WatchReceivePlan.decide(event: older, sync: sync, seenIntentIDs: []) == .ignore)
    }

    @Test("the watermark is per-epoch: another epoch's seq 1 applies beside a watermark of 9")
    func watermarksArePerEpoch() throws {
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 9)
        )
        let otherEpoch = fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch2, seq: 1)
        guard case .apply(let postSync) = WatchReceivePlan.decide(
            event: otherEpoch, sync: sync, seenIntentIDs: []
        ) else {
            Issue.record("an epoch's watermark must not gate another epoch")
            return
        }
        #expect(postSync.watermark(for: fixture.epoch2) == 1)
        #expect(postSync.watermark(for: fixture.epoch1) == 9, "the other epoch's table is untouched")
    }

    // MARK: - INV-10: EXACTLY-ONCE over the FIFO contract stream

    @Test("the FIFO contract stream with duplicates/replays/redeliveries applies each distinct intent exactly once")
    func fifoStreamAppliesExactlyOnce() {
        // The §6.4 stream shape: six distinct watch pats, polluted with an
        // exact duplicate, a whole-stream replay (appended), and a stale-seq
        // straggler (an unseen id below the advancing watermark) — in FIFO
        // order, what `transferUserInfo` delivers.
        let distinct = (1...6).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        let duplicate = distinct[2]
        let staleStraggler = fixture.event(fixture.intent(id: fixture.intentID(99)), epoch: fixture.epoch1, seq: 2)
        let stream = distinct + [duplicate] + distinct + [staleStraggler]

        var sync = SyncState()
        var belt = Set<UUID>()
        var applied: [UUID] = []
        for event in stream {
            if case .apply(let postSync) = WatchReceivePlan.decide(
                event: event, sync: sync, seenIntentIDs: belt
            ) {
                applied.append(event.intent.id)
                belt.insert(event.intent.id)
                sync = postSync
            }
        }
        #expect(applied.map { $0 } == (1...6).map { fixture.intentID($0) },
                "each distinct intent applied exactly once, in order")
        #expect(sync.watermark(for: fixture.epoch1) == 6)
        // The identical stream again (relaunch/redelivery): a complete no-op.
        var secondPass = 0
        for event in stream {
            if case .apply = WatchReceivePlan.decide(event: event, sync: sync, seenIntentIDs: belt) {
                secondPass += 1
            }
        }
        #expect(secondPass == 0, "replaying the whole stream applies nothing")
    }

    // MARK: - O2: AT-MOST-ONCE under seeded shuffles (never strengthened)

    @Test("INV-10 under ANY delivery order through the plan core: no UUID ever applies twice",
          arguments: [UInt64(1), 0x9E3779B97F4A, 0xFFFF_FFFF_FFFF_FFFF])
    func atMostOnceUnderShuffledDelivery(_ seed: UInt64) {
        let distinct = (1...5).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        var stream = distinct + distinct
        var generator = SeededGenerator(seed: seed)
        stream.shuffle(using: &generator)
        var sync = SyncState()
        var belt = Set<UUID>()
        var applied: [UUID] = []
        for event in stream {
            if case .apply(let postSync) = WatchReceivePlan.decide(
                event: event, sync: sync, seenIntentIDs: belt
            ) {
                applied.append(event.intent.id)
                belt.insert(event.intent.id)
                sync = postSync
            }
        }
        #expect(Set(applied).count == applied.count, "no double application under any order")
        let distinctIDs = Set(distinct.map { $0.intent.id })
        #expect(applied.allSatisfy { distinctIDs.contains($0) })
        var secondPass = 0
        for event in stream {
            if case .apply = WatchReceivePlan.decide(event: event, sync: sync, seenIntentIDs: belt) {
                secondPass += 1
            }
        }
        #expect(secondPass == 0, "idempotence holds regardless of the delivery order")
    }

    // MARK: - The F-1 leg: watermark propagation to the NEXT snapshot

    @Test("an applied intent's postSync is the next snapshot's watermark pair (the AppModelPlanCore-driven executor loop)")
    func watermarkPropagatesToNextSnapshot() throws {
        var state = storeFixture.state(wakefulness: .awake, activity: nil)
        var sync = SyncState()
        // Pre-apply snapshot: nothing applied yet — the executor advertises
        // the zero sentinel (inert against every real epoch).
        let before = makeWatchSnapshot(
            state: state,
            display: makeDisplayState(state, at: clock.now(), calendar: utc),
            questInputs: [],
            watermarkEpoch: StoreRules.zeroWatchSyncEpoch,
            sync: sync
        )
        #expect(before.snapshot.lastAppliedEpoch == StoreRules.zeroWatchSyncEpoch)
        sync = before.nextSync

        // The receive path, exactly as the executor routes it: decide →
        // apply through the plan core → adopt postSync → track the epoch.
        let event = fixture.event(fixture.intent(id: fixture.intentID(7)), epoch: fixture.epoch1, seq: 3)
        guard case .apply(let postSync) = WatchReceivePlan.decide(
            event: event, sync: sync, seenIntentIDs: Set(state.processedIntents)
        ) else {
            Issue.record("a fresh epoch's first event must apply")
            return
        }
        let plan = AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(event.intent),
            clock: clock,
            calendar: utc
        )
        state = plan.appliedState
        sync = postSync

        // THE F-1 PIN: the next built snapshot carries the updated pair.
        let after = makeWatchSnapshot(
            state: state,
            display: makeDisplayState(state, at: clock.now(), calendar: utc),
            questInputs: [],
            watermarkEpoch: fixture.epoch1,
            sync: sync
        )
        #expect(after.snapshot.lastAppliedIntentSeq == 3)
        #expect(after.snapshot.lastAppliedEpoch == fixture.epoch1)
        #expect(after.snapshot.snapshotSeq == 2, "the receive consumed no seq; the push did")
    }

    @Test("a no-op receive leaves the next snapshot's CONTENT untouched (the seq advance is the push's own)")
    func noOpReceiveLeavesSnapshotContentUntouched() throws {
        var state = storeFixture.state(wakefulness: .awake, activity: nil)
        var sync = SyncState()
        let event = fixture.event(fixture.intent(id: fixture.intentID(7)), epoch: fixture.epoch1, seq: 3)
        guard case .apply(let postSync) = WatchReceivePlan.decide(
            event: event, sync: sync, seenIntentIDs: Set(state.processedIntents)
        ) else {
            Issue.record("precondition: the first delivery applies")
            return
        }
        state = AppModelPlanCore.plan(
            state: state, trigger: .interaction(event.intent), clock: clock, calendar: utc
        ).appliedState
        sync = postSync

        let content = makeWatchSnapshot(
            state: state,
            display: makeDisplayState(state, at: clock.now(), calendar: utc),
            questInputs: [],
            watermarkEpoch: fixture.epoch1,
            sync: sync
        )
        sync = content.nextSync // the executor threads the consumed seq back

        // A duplicate redelivery: the decision is .ignore and NOTHING the
        // executor owns moves — no plan runs, no sync write exists.
        #expect(WatchReceivePlan.decide(event: event, sync: sync, seenIntentIDs: Set(state.processedIntents))
            == .ignore)

        let untouched = makeWatchSnapshot(
            state: state,
            display: makeDisplayState(state, at: clock.now(), calendar: utc),
            questInputs: [],
            watermarkEpoch: fixture.epoch1,
            sync: sync
        )
        #expect(untouched.snapshot.display == content.snapshot.display)
        #expect(untouched.snapshot.questInputs == content.snapshot.questInputs)
        #expect(untouched.snapshot.lastAppliedIntentSeq == content.snapshot.lastAppliedIntentSeq)
        #expect(untouched.snapshot.lastAppliedEpoch == content.snapshot.lastAppliedEpoch)
        #expect(untouched.snapshot.hapticsEnabled == content.snapshot.hapticsEnabled)
        #expect(untouched.snapshot.snapshotSeq == content.snapshot.snapshotSeq + 1,
                "successive builds consume the seq by design; content is what stays")
    }
}
