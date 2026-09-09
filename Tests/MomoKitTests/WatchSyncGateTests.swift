import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-023 gate matrix (contract Requirement 5, AC-3): every §6.4 cell
/// of the two-guard composition, every §6.6 reset case the pure halves can
/// express (unseen epoch → 0-init applies; iPhone reinstall → empty table
/// applies warm), the expired-dayKey pass-through shape, the watermark
/// advance's max/no-regression semantics, and the INV-10 / FR-18 AC-1
/// exactly-once properties over duplicate, replay, and redelivery streams.
///
/// Delivery-order honesty (the TASK-021 concurrency lesson's cousin): the
/// transport contract is FIFO (`transferUserInfo`, 05 §6.1), so EXACTLY-ONCE
/// is pinned over the contract's stream shape (in-order with duplicates,
/// replays, and redeliveries interleaved/appended). The shuffled-delivery
/// property pins what the formula actually guarantees under ANY order —
/// at-most-once per UUID (never a double application) — because a
/// higher-seq event applied ahead of lower-seq ones legitimately blocks the
/// laggards by the §6.4 ">" rule; that blocking IS the watermark guard
/// working, not a defect, and pinning full application under shuffles would
/// pin a falsehood.
@Suite("WatchSyncGate — §6.4 cell matrix, §6.6 resets, INV-10 exactly-once (TASK-023)")
struct WatchSyncGateTests {

    private let fixture = SyncFixture()

    // MARK: - The §6.4 cells

    @Test("an unseen epoch's watermark is 0: the first pat (seq 1) applies immediately")
    func freshEpochAppliesAtSeqOne() {
        let sync = SyncState()
        let event = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        #expect(sync.watermark(for: fixture.epoch1) == 0)
        #expect(WatchSyncGate.shouldApply(event, seenIntentIDs: [], watermarkForEpoch: 0))
        #expect(sync.shouldApply(event, seenIntentIDs: []), "the accessor-driven wrapper resolves the same 0")
    }

    @Test("a duplicate UUID is a no-op even with a higher seq (UUID outranks seq)")
    func duplicateUUIDIsNoOpEvenWithHigherSeq() {
        let event = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 2)
        let seen: Set<UUID> = [fixture.intentID(1)]
        #expect(!WatchSyncGate.shouldApply(event, seenIntentIDs: seen, watermarkForEpoch: 1))
        // The adversarial inflation: a redelivery claiming seq 99 against a
        // watermark of 1 is STILL the same pat — no double application.
        let inflated = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 99)
        #expect(!WatchSyncGate.shouldApply(inflated, seenIntentIDs: seen, watermarkForEpoch: 1))
    }

    @Test("a replayed old seq is a no-op even when the UUID is unseen (the retention interplay)")
    func replayedSeqIsNoOpEvenWhenUUIDUnseen() {
        // The shape retention produces: the belt forgot the UUID, but the
        // watermark still stands at 2 — the replay of seq 2 (or lower) must
        // not re-apply.
        #expect(!WatchSyncGate.shouldApply(
            fixture.event(fixture.intent(id: fixture.intentID(7)), epoch: fixture.epoch1, seq: 2),
            seenIntentIDs: [],
            watermarkForEpoch: 2
        ))
        #expect(!WatchSyncGate.shouldApply(
            fixture.event(fixture.intent(id: fixture.intentID(7)), epoch: fixture.epoch1, seq: 1),
            seenIntentIDs: [],
            watermarkForEpoch: 2
        ))
    }

    @Test("the boundary is strictly greater: seq == watermark is a no-op")
    func boundarySeqEqualsWatermarkIsNoOp() {
        #expect(!WatchSyncGate.shouldApply(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 5),
            seenIntentIDs: [],
            watermarkForEpoch: 5
        ))
        #expect(WatchSyncGate.shouldApply(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 6),
            seenIntentIDs: [],
            watermarkForEpoch: 5
        ))
    }

    @Test("both guards passing is the only apply cell")
    func bothGuardsPassApplies() {
        #expect(WatchSyncGate.shouldApply(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 3),
            seenIntentIDs: [fixture.intentID(2)],
            watermarkForEpoch: 2
        ))
    }

    @Test("a stale-epoch watermark never gates: another epoch's events apply from seq 1 (0-init)")
    func staleEpochWatermarkNeverGates() {
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 5)
        )
        // A DIFFERENT epoch's intent at seq 1: epoch1's watermark of 5 must
        // not touch it — the 0-init accessor resolves epoch2's watermark.
        let freshEpochEvent = fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch2, seq: 1)
        #expect(sync.shouldApply(freshEpochEvent, seenIntentIDs: []))
    }

    // MARK: - The §6.6 reset cases (pure-half expressible)

    @Test("epoch re-pair / watch app reinstall: the new epoch's seqs 1, 2, … apply with no starvation")
    func epochResetAppliesWithoutStarvation() {
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 9)
        )
        for seq in 1...3 {
            let event = fixture.event(fixture.intent(id: fixture.intentID(100 + seq)), epoch: fixture.epoch2, seq: seq)
            #expect(sync.shouldApply(event, seenIntentIDs: []), "seq \(seq) of the new epoch must apply")
            sync = sync.recordingApplied(event)
        }
        #expect(sync.watermark(for: fixture.epoch2) == 3)
        #expect(sync.watermark(for: fixture.epoch1) == 9, "the old epoch's watermark is untouched")
    }

    @Test("iPhone reinstall: empty table, no epochs known — stale queued pats apply warm")
    func iPhoneReinstallAppliesWarm() {
        // The §6.6 row: a fresh iPhone store knows NO epochs and NO UUIDs.
        let sync = SyncState()
        let queued = (5...7).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        for event in queued {
            #expect(sync.shouldApply(event, seenIntentIDs: []),
                    "a stale queued pat applies warm onto the fresh pet")
        }
    }

    // MARK: - Expired-dayKey pass-through (§6.4 step 3 is ENGINE-side)

    @Test("the gate never reads the dayKey: an expired-dayKey intent passes through unchanged")
    func gatePassesExpiredDayKeyIntentsThrough() {
        // A dayKey pruned by the 7-day retention (§5.4): the GATE's answer is
        // the same apply verdict as any other intent — the engine's
        // InteractionSemantics owns the effects/attribution split (TASK-016).
        // The signature has no dayKey input; this pin holds the shape.
        let expired = fixture.event(
            fixture.intent(id: fixture.intentID(1), dayKey: "2026-01-01"),
            epoch: fixture.epoch1,
            seq: 1
        )
        #expect(WatchSyncGate.shouldApply(expired, seenIntentIDs: [], watermarkForEpoch: 0))
        #expect(expired.intent.localDayKey == "2026-01-01", "the gate passes the intent through unchanged")
    }

    // MARK: - The watermark advance (recordingApplied)

    @Test("recordingApplied advances the watermark to the applied seq, per epoch")
    func recordingAppliedAdvancesWatermark() {
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 3)
        )
        #expect(sync.watermark(for: fixture.epoch1) == 3)
        #expect(sync.watermark(for: fixture.epoch2) == 0, "another epoch's watermark is untouched")
    }

    @Test("recordingApplied never regresses: an out-of-order lower seq keeps the max")
    func recordingAppliedNeverRegresses() {
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 5)
        )
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2)
        )
        #expect(sync.watermark(for: fixture.epoch1) == 5,
                "a late-arriving lower seq must not reopen the gate for replays")
    }

    // MARK: - INV-10 / FR-18 AC-1 properties

    @Test("exactly-once under the FIFO contract: duplicates, replays, and redeliveries are no-ops")
    func exactlyOnceUnderFIFOWithDuplicatesReplaysRedeliveries() {
        let distinct = (1...5).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        // The contract's stream: the FIFO batch, polluted with an immediate
        // duplicate of every event, an out-of-order replay of seq 2 after
        // seq 4, and then the WHOLE batch redelivered (transferUserInfo's
        // documented duplicates-possible semantics).
        var stream = distinct
        stream.append(contentsOf: distinct) // immediate duplicates
        stream.append(distinct[1])          // replay of seq 2 after seq 4 applied
        stream.append(contentsOf: distinct) // full redelivery of the batch
        var seen = Set<UUID>()
        var sync = SyncState()
        var applied: [UUID] = []
        for event in stream where sync.shouldApply(event, seenIntentIDs: seen) {
            applied.append(event.intent.id)
            seen.insert(event.intent.id)
            sync = sync.recordingApplied(event)
        }
        #expect(applied.map(\.uuidString) == distinct.map(\.intent.id.uuidString),
                "each distinct pat applied exactly once, in order; nothing else")
        #expect(sync.watermark(for: fixture.epoch1) == 5)

        // The identical stream again (relaunch/redelivery): a complete no-op.
        var secondPassApplied = 0
        for event in stream where sync.shouldApply(event, seenIntentIDs: seen) {
            secondPassApplied += 1
            seen.insert(event.intent.id)
            sync = sync.recordingApplied(event)
        }
        #expect(secondPassApplied == 0, "replaying the whole stream applies nothing")
    }

    @Test("INV-10 under ANY delivery order: no UUID ever applies more than once",
          arguments: [UInt64(1), 0x9E3779B97F4A, 0xFFFF_FFFF_FFFF_FFFF])
    func atMostOnceUnderShuffledDelivery(_ seed: UInt64) {
        let distinct = (1...5).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        // A polluted multiset (every event twice) in a seeded shuffle.
        var stream = distinct + distinct
        var generator = SeededGenerator(seed: seed)
        stream.shuffle(using: &generator)
        var seen = Set<UUID>()
        var sync = SyncState()
        var applied: [UUID] = []
        for event in stream where sync.shouldApply(event, seenIntentIDs: seen) {
            applied.append(event.intent.id)
            seen.insert(event.intent.id)
            sync = sync.recordingApplied(event)
        }
        #expect(Set(applied).count == applied.count, "no double application under any order")
        // Only genuine first-batch members ever apply (duplicates of an
        // APPLIED id can't slip through; unseen-id replays below the watermark
        // can't either) — the σ-independent part: WHICH members apply varies
        // with the shuffle, that none applies twice does not.
        let distinctIDs = Set(distinct.map { $0.intent.id })
        #expect(applied.allSatisfy { distinctIDs.contains($0) })
        // Idempotence regardless of order: the surviving state answers the
        // whole polluted stream with all no-ops on a second pass.
        var secondPassApplied = 0
        for event in stream where sync.shouldApply(event, seenIntentIDs: seen) {
            secondPassApplied += 1
        }
        #expect(secondPassApplied == 0)
    }
}
