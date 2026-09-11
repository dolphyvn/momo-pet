import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-042 R3/R5/R6 pure-core suite (05 §6.4 step 1; ADR-015 D2): the
/// pat event's construction pins, the per-epoch monotonic `watchSeq`
/// derivation (the FULL-PRUNE MONOTONICITY test is the contract's named
/// pin — a reused seq after the iPhone's apply would be declined forever),
/// the completion-haptic ESTIMATE's truth table (the estimate decides which
/// haptic plays and nothing else — the reviewer's acceptance is THIS math),
/// and the wakefulness → reaction-kind map. Everything here is total and
/// headless: the executor threads values through, nothing reads a clock,
/// the calendar, or the disk.
@Suite("WatchPatPlan — pat event, seq monotonicity, completion estimate, reaction map (TASK-042)")
struct WatchPatPlanTests {

    private let fixture = SyncFixture()

    // MARK: - The seq derivation (R3's pinned formula)

    @Test("fresh Watch: empty journal + no epoch-matched watermark → seq 1")
    func freshWatchDerivesSeqOne() {
        let next = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: WatchPatPlan.journalMaxSeq(in: [], epoch: fixture.epoch1),
            lastAppliedEpoch: StoreRules.zeroWatchSyncEpoch,
            lastAppliedIntentSeq: 0,
            currentEpoch: fixture.epoch1
        )
        #expect(next == 1)
    }

    @Test("pending journal entries raise the floor: next = journal max + 1")
    func journalMaxRaisesTheFloor() {
        let events = [
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1),
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2),
        ]
        let next = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: WatchPatPlan.journalMaxSeq(in: events, epoch: fixture.epoch1),
            lastAppliedEpoch: StoreRules.zeroWatchSyncEpoch,
            lastAppliedIntentSeq: 0,
            currentEpoch: fixture.epoch1
        )
        #expect(next == 3)
    }

    @Test("FULL-PRUNE MONOTONICITY: journal emptied by the apply + epoch-matched watermark N → N+1, never 1")
    func fullPruneNeverReusesASeq() {
        // The drain's steady state: the iPhone applied everything (the prune
        // removed ≤ watermark) and the next snapshot carried watermark 3. A
        // journal-max-only derivation would mint 1 again — the watermark
        // term is what keeps the seq monotonic (the contract's named pin;
        // the mutation bite flips this term and expects EXACTLY this test
        // red).
        let next = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: 0,
            lastAppliedEpoch: fixture.epoch1,
            lastAppliedIntentSeq: 3,
            currentEpoch: fixture.epoch1
        )
        #expect(next == 4, "a reused seq 1 would sit below the watermark and be declined forever")
    }

    @Test("a STALE-EPOCH watermark is inert: journal max + 1 (the same rule the prune applies)")
    func staleEpochWatermarkIsInert() {
        // The held snapshot predates a re-pair (its watermark names another
        // epoch): it neither raises the floor nor resets the derivation.
        let next = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: 2,
            lastAppliedEpoch: fixture.epoch2,
            lastAppliedIntentSeq: 99,
            currentEpoch: fixture.epoch1
        )
        #expect(next == 3)
    }

    @Test("a MIXED-EPOCH journal never inflates this epoch's derivation (§6.2: seq resets with the epoch)")
    func mixedEpochJournalIsUnaffected() {
        // A defensive shape the wipe discipline should never produce (an old
        // epoch's entries lingering): their seqs — even enormous ones — stay
        // out of the new epoch's math.
        let events = [
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 2),
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch2, seq: 99),
        ]
        #expect(WatchPatPlan.journalMaxSeq(in: events, epoch: fixture.epoch1) == 2)
        let next = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: WatchPatPlan.journalMaxSeq(in: events, epoch: fixture.epoch1),
            lastAppliedEpoch: fixture.epoch1,
            lastAppliedIntentSeq: 1,
            currentEpoch: fixture.epoch1
        )
        #expect(next == 3)
    }

    @Test("the watermark term wins when it exceeds the journal max (the steady drained state)")
    func watermarkExceedingJournalMaxWins() {
        let events = [fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)]
        let next = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: WatchPatPlan.journalMaxSeq(in: events, epoch: fixture.epoch1),
            lastAppliedEpoch: fixture.epoch1,
            lastAppliedIntentSeq: 5,
            currentEpoch: fixture.epoch1
        )
        #expect(next == 6)
    }

    // MARK: - The pat event's construction (§6.4 step 1)

    @Test("the pat event is a .watch-sourced .pat(.tap, nil) with its own epoch + seq")
    func patEventShapeIsPinned() {
        let now = fixture.instant("2026-09-09T21:30:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!

        let event = WatchPatPlan.makePatEvent(
            now: now, calendar: calendar,
            watchSessionEpoch: fixture.epoch1, watchSeq: 7
        )

        // `InteractionIntent.Kind` is deliberately non-Equatable (messages,
        // not compared values) — the DTO's field-wise `==` IS the house way
        // to pin an intent's full shape: a twin event over the same minted
        // id, equal in every field including the kind.
        let twin = IntentEvent(
            intent: InteractionIntent(
                id: event.intent.id,
                source: .watch,
                localDayKey: DayKey.make(from: now, calendar: calendar),
                timestamp: now,
                kind: .pat(gesture: .tap, zone: nil)
            ),
            watchSessionEpoch: fixture.epoch1,
            watchSeq: 7
        )
        #expect(event == twin, "epoch, seq, source, kind, dayKey, and timestamp all pinned")
    }

    @Test("the event's dayKey derives from the EVENT'S OWN instant (the 23:30 offline-midnight attribution)")
    func patEventAttributesItsOwnDay() {
        // 03:30 UTC is 23:30 the previous day in New York: the pat must
        // journal ITS day (§6.6), not the iPhone's apply-day.
        let now = fixture.instant("2026-09-10T03:30:00Z")
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!

        let event = WatchPatPlan.makePatEvent(
            now: now, calendar: calendar,
            watchSessionEpoch: fixture.epoch1, watchSeq: 1
        )

        #expect(event.intent.localDayKey == "2026-09-09")
        #expect(event.intent.localDayKey == DayKey.make(from: now, calendar: calendar))
    }

    @Test("every pat mints a FRESH idempotency id (INV-10's capture-time key)")
    func patEventMintsAFreshID() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let now = fixture.instant("2026-09-09T21:30:00Z")
        let first = WatchPatPlan.makePatEvent(now: now, calendar: calendar, watchSessionEpoch: fixture.epoch1, watchSeq: 1)
        let second = WatchPatPlan.makePatEvent(now: now, calendar: calendar, watchSessionEpoch: fixture.epoch1, watchSeq: 2)
        #expect(first.intent.id != second.intent.id)
    }

    // MARK: - The completion-haptic ESTIMATE (ADR-015 D2's truth table)

    /// Q7's catalog target (pet ×3) — the estimate's constant on the right
    /// of the strict equality.
    private var q7Target: Int { QuestCatalog.entry(for: .q7).target }

    @Test("ESTIMATE: the on-wrist completing pat fires — progress + pending + 1 == target (UX §6.3's 3rd pat)")
    func completingPatEstimatesTrue() {
        #expect(q7Target == 3, "the catalog constant the estimate leans on (UX §6.3's example)")
        #expect(WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [fixture.quest(.q7, progress: 2, completed: false)],
            pendingPatCount: 0
        ))
        // Two of the three already sit in the pending journal (offline pats).
        #expect(WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [fixture.quest(.q7, progress: 1, completed: false)],
            pendingPatCount: 1
        ))
    }

    @Test("ESTIMATE: an ordinary pat stays an ordinary pat — below target estimates false (tick)")
    func ordinaryPatEstimatesFalse() {
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [fixture.quest(.q7, progress: 0, completed: false)],
            pendingPatCount: 0
        ))
    }

    @Test("ESTIMATE: the OVERSHOOT pat estimates false — the completion already sat in the pending pats")
    func overshootPatEstimatesFalse() {
        // progress 2 + pending 1 already IS the completing trio; the fourth
        // on-wrist pat is past it. The double must fire on exactly the
        // completing pat, never again (strict ==, never >=).
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [fixture.quest(.q7, progress: 2, completed: false)],
            pendingPatCount: 1
        ))
        // An already-complete Q7 in the snapshot is likewise past it.
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [fixture.quest(.q7, progress: 3, completed: true)],
            pendingPatCount: 0
        ))
    }

    @Test("ESTIMATE: a non-Q7 quest line estimates false (Q6 wish, all-done)")
    func nonQ7QuestLineEstimatesFalse() {
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .wish(.q6),
            questInputs: [fixture.quest(.q7, progress: 2, completed: false)],
            pendingPatCount: 0
        ))
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .allDone,
            questInputs: [fixture.quest(.q7, progress: 2, completed: false)],
            pendingPatCount: 0
        ))
    }

    @Test("ESTIMATE: a missing Q7 progress row estimates false (the under-count-safe fallback)")
    func missingQ7InputEstimatesFalse() {
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [fixture.quest(.q1, progress: 1, completed: true)],
            pendingPatCount: 0
        ))
        #expect(!WatchPatPlan.isCompletingPat(
            questLine: .wish(.q7),
            questInputs: [],
            pendingPatCount: 0
        ))
    }

    // MARK: - The pending pat count (the estimate's third term)

    @Test("pending count: this epoch's journaled pats only (foreign epochs and non-pats count nothing)")
    func pendingPatCountsThisEpochsPats() {
        let events = [
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1),
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2),
            // A future intent vocabulary's non-pat kind in the same epoch.
            fixture.event(
                fixture.intent(id: fixture.intentID(4), kind: .feed),
                epoch: fixture.epoch1, seq: 3),
            fixture.event(fixture.intent(id: fixture.intentID(3)), epoch: fixture.epoch2, seq: 1),
        ]
        #expect(WatchPatPlan.pendingPatCount(in: events, epoch: fixture.epoch1) == 2)
        #expect(WatchPatPlan.pendingPatCount(in: events, epoch: fixture.epoch2) == 1)
        #expect(WatchPatPlan.pendingPatCount(in: [], epoch: fixture.epoch1) == 0)
    }

    // MARK: - The reaction-kind map (ADR-015 D1; 04 §6.4's state-distinct rule)

    @Test("reaction kinds: awake/waking bounce, settling/asleep stir (the pinned four-case map)")
    func reactionKindFollowsWakefulness() {
        #expect(WatchPatPlan.reactionKind(for: .awake) == .bounce, "the happy micro-bounce")
        #expect(WatchPatPlan.reactionKind(for: .waking) == .bounce, "a pat during the wake transition greets the riser")
        #expect(WatchPatPlan.reactionKind(for: .settling) == .stir)
        #expect(WatchPatPlan.reactionKind(for: .asleep) == .stir, "the pet stirs and STAYS asleep")
    }
}
