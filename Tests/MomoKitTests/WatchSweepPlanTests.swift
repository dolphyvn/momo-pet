import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-044 R1 launch-sweep suite (05 §6.4, §10.4 "journal drain on
/// reconnect"): the pure drain decision through `WatchSweepPlan
/// .drainableEvents` — the stranded event's VERBATIM delivery, the reset
/// interaction's count re-check (a consumption between arm and execution
/// suppresses the sweep to zero sends), the epoch filter, and the
/// re-activation shape whose safety is INV-10 CITED at the plan seam (the
/// sweep re-sends journaled events; `WatchReceivePlan.decide` — the SAME
/// decision the iPhone executor runs — is what keeps the re-send a no-op;
/// this suite asserts that composition, it does not re-derive INV-10).
@Suite("WatchSweepPlan — verbatim drain, reset suppression, INV-10-cited re-activation (TASK-044; 05 §6.4)")
struct WatchSweepPlanTests {

    private let fixture = SyncFixture()

    // MARK: - The named trio (R1)

    @Test("the stranded event is enqueued VERBATIM: field-for-field and byte-for-byte")
    func strandedSentVerbatim() throws {
        // The F-R1 shape: the event was journaled (append precedes send) and
        // the crash landed before the drain — the journal holds it, the
        // iPhone never saw it. The sweep's read hands the journal over
        // verbatim; the plan's output must be the SAME event, in order.
        let stranded = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        let journal = [
            stranded,
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2),
        ]
        let drainable = WatchSweepPlan.drainableEvents(
            journal: journal,
            epoch: fixture.epoch1,
            consumedEraseCountAtArm: 0,
            consumedEraseCountNow: 0
        )
        #expect(drainable == journal, "no re-sequencing, no mutation: the drain is the journal's own order")
        #expect(drainable.count == 2)
        // Byte-for-byte: each drained event re-encodes to the canonical
        // bytes the journal stores (the send payload is the journaled
        // event's encoding, never a re-derived one).
        for (drained, journaled) in zip(drainable, journal) {
            #expect(SyncFixture.canonicalString(drained) == SyncFixture.canonicalString(journaled))
        }
    }

    @Test("a consumption between arm and execution suppresses the sweep entirely (the reset interaction)")
    func markerSuppressedSendsNothing() {
        // The hazard: the marker frame consumed at receive wiped this very
        // journal; if the sweep's read raced ahead of the wipe it would hold
        // pre-erase entries. The count re-check is the second defense (the
        // executor's awaited consumeWipe before the read is the first): the
        // consumed count advanced since arming ⇒ NOTHING may drain, however
        // full the journal it is holding.
        let journal = [
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1),
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2),
        ]
        #expect(WatchSweepPlan.drainableEvents(
            journal: journal,
            epoch: fixture.epoch1,
            consumedEraseCountAtArm: 0,
            consumedEraseCountNow: 1
        ).isEmpty, "any consumption since the arm suppresses the whole sweep")
        #expect(WatchSweepPlan.drainableEvents(
            journal: journal,
            epoch: fixture.epoch1,
            consumedEraseCountAtArm: 3,
            consumedEraseCountNow: 3
        ).count == 2, "an UNCHANGED count (erase happened before the arm) drains normally")
    }

    @Test("re-activation re-sends are exactly-once iPhone-side (INV-10 cited at the plan seam)")
    func reActivationIdempotent() {
        // The sweep does not delete journal lines on send (the watermark
        // prune owns removal), so a second activation re-sends the SAME
        // events. Each re-send must be a no-op iPhone-side — asserted here
        // through `WatchReceivePlan.decide`, the plan core the receive
        // executor routes every delivery through (INV-10 cited, not
        // re-derived: the first delivery applies, the verbatim re-send is
        // the gate's already-pinned duplicate/replay cell).
        let events = [
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1),
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2),
        ]
        let firstSweep = WatchSweepPlan.drainableEvents(
            journal: events, epoch: fixture.epoch1,
            consumedEraseCountAtArm: 0, consumedEraseCountNow: 0
        )
        let secondSweep = WatchSweepPlan.drainableEvents(
            journal: events, epoch: fixture.epoch1,
            consumedEraseCountAtArm: 0, consumedEraseCountNow: 0
        )
        #expect(firstSweep == secondSweep, "re-activation re-drains the same pending events")

        // First activation's deliveries apply; the second activation's
        // verbatim re-deliveries are every one a full no-op.
        var sync = SyncState()
        var seen: Set<UUID> = []
        for event in firstSweep {
            guard case .apply(let postSync) = WatchReceivePlan.decide(event: event, sync: sync, seenIntentIDs: seen) else {
                Issue.record("the first delivery of a pending event must apply")
                return
            }
            sync = postSync
            seen.insert(event.intent.id)
        }
        for event in secondSweep {
            #expect(WatchReceivePlan.decide(event: event, sync: sync, seenIntentIDs: seen) == .ignore,
                    "the re-activation's re-send is a no-op for every event (INV-10)")
        }
    }

    // MARK: - The filter's edges

    @Test("dead-epoch entries never drain (the epoch filter)")
    func deadEpochNeverDrains() {
        let journal = [
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch2, seq: 1),
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 7),
        ]
        let drainable = WatchSweepPlan.drainableEvents(
            journal: journal,
            epoch: fixture.epoch1,
            consumedEraseCountAtArm: 0,
            consumedEraseCountNow: 0
        )
        #expect(drainable == [journal[1]], "only this Watch's own epoch drains; a stale-epoch survivor is declined")
    }

    @Test("an empty journal drains to nothing (the post-wipe read shape)")
    func emptyJournalDrainsNothing() {
        #expect(WatchSweepPlan.drainableEvents(
            journal: [],
            epoch: fixture.epoch1,
            consumedEraseCountAtArm: 0,
            consumedEraseCountNow: 0
        ).isEmpty, "the consume branch's awaited wipe-then-sweep order serves this shape")
    }
}
