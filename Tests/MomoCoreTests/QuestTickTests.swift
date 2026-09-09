import Testing
import Foundation
@testable import MomoCore

/// The §4.8 window-checked quest ticks as engine decisions (TASK-018
/// Required Test 6; AC-3/AC-4): scope (in-set, event families only),
/// qualifying-only progress (the window gates the TICK, never the count),
/// the event's-own-time rule, dayKey attribution, the expired-dayKey
/// disposition, the award's clamp interplay, completion idempotence,
/// multiple completions in one event, and the moment ordering
/// `[questCompleted?, bondStageReached?]`.
///
/// House discipline: named constants only — raw spec literals live in
/// `QuestGenerationPinnedTests`.
@Suite("Quest ticks — window-checked completion at the counting events (TASK-018)")
struct QuestTickTests {

    private let fixture = InteractionFixture()
    private let day = "2026-09-08"

    private func quest(_ id: QuestID, progress: Int = 0, completed: Bool = false) -> QuestProgress {
        QuestProgress(questID: id, progress: progress, completed: completed)!
    }

    /// A state whose single day carries an arbitrary quest set at arbitrary
    /// progress (the tick pins need sets/shapes the fixture placeholder
    /// cannot express).
    private func state(
        questSet: [QuestProgress],
        bond: Int = 0,
        helloAwarded: Bool = false,
        bondAwarded: Int = 0,
        energy: Double = 80,
        highestCelebratedStage: BondStage = .newFriends,
        lastEvaluatedAt: Instant
    ) -> EngineState {
        fixture.state(
            energy: energy,
            bond: bond,
            highestCelebratedStage: highestCelebratedStage,
            days: [DayRecord(
                dayKey: day,
                feedCount: 0,
                playCount: 0,
                careCount: 0,
                patCount: 0,
                questSet: questSet,
                helloAwarded: helloAwarded,
                familiesUsed: [],
                bondAwarded: bondAwarded,
                questGenEpoch: QuestGeneration.currentEpoch
            )!],
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    // MARK: Scope — out-of-set quests never tick

    @Test("out-of-set quests never tick: feeds advance an in-set Q3 but never an out-of-set Q2")
    func outOfSetNeverTicks() {
        let set = [quest(.q1), quest(.q3), quest(.q6)] // Q3 (target 2) in set; Q2 is NOT
        var current = state(questSet: set, helloAwarded: true, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        // First feed: Q3 advances (no completion — target is 2); no moment.
        let first = fixture.send(current, .feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(first.moments.isEmpty)
        #expect(first.newState.days.first?.feedCount == 1) // the count is unaffected
        let q3AfterFirst = first.newState.days.first?.questSet.first { $0.questID == .q3 }
        #expect(q3AfterFirst?.progress == 1)
        #expect(q3AfterFirst?.completed == false)
        // Second feed: Q3 completes; Q2 (out of set) stays absent and unticked.
        current = first.newState
        let second = fixture.send(current, .feed, at: fixture.instant("2026-09-08T10:00:00Z"), dayKey: day)
        #expect(second.moments == [.questCompleted])
        #expect(second.newState.days.first?.feedCount == 2)
        #expect(second.newState.days.first?.questSet.map(\.questID) == [.q1, .q3, .q6]) // Q2 never joined the set
        let q3AfterSecond = second.newState.days.first?.questSet.first { $0.questID == .q3 }
        #expect(q3AfterSecond?.completed == true)
    }

    // MARK: Qualifying-only progress — the window gates the TICK

    /// The same state with its evaluation high-water mark moved (test-side
    /// only) so a follow-up event folds zero elapsed — the exact-value pins
    /// carry no fold dynamics (the fixture's stated discipline).
    private func rebased(_ base: EngineState, at instant: Instant) -> EngineState {
        EngineState(
            pet: base.pet,
            state: base.state,
            days: base.days,
            settings: base.settings,
            pendingHandshake: base.pendingHandshake,
            processedIntents: base.processedIntents,
            highestCelebratedStage: base.highestCelebratedStage,
            lastOpenedAt: instant,
            lastEvaluatedAt: instant,
            lastGreeting: nil
        )
    }

    @Test("a daytime care event defers Q6: the count stands, the tick waits for the window")
    func q6DefersToALaterInWindowCare() {
        // A drowsy nap at 09:00 IS a care event (it counts and records)…
        let morning = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            energy: 30,
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let napped = fixture.send(morning, .nap, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(napped.newState.days.first?.careCount == 1) // the care happened
        #expect(napped.newState.days.first?.questSet.last?.progress == 0) // …but 09:00 is outside Q6's window
        #expect(napped.moments.isEmpty)
        // …and the evening tuck-in (in window) is the tick that completes Q6
        // (the ledger carries the nap's count into the evening zero-elapsed).
        let tucked = fixture.send(
            rebased(napped.newState, at: fixture.instant("2026-09-08T20:30:00Z")),
            .tuckIn,
            at: fixture.instant("2026-09-08T20:30:00Z"),
            dayKey: day
        )
        #expect(tucked.moments == [.questCompleted])
        #expect(tucked.newState.days.first?.questSet.last?.completed == true)
        #expect(tucked.newState.days.first?.careCount == 2)
    }

    @Test("a post-noon pat never ticks Q1: the window never re-opens (silent expiry, §5.1 rule 6)")
    func postNoonPatNeverTicksQ1() {
        var current = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T14:00:00Z")
        )
        for stamp in ["2026-09-08T14:00:00Z", "2026-09-08T15:30:00Z", "2026-09-08T18:00:00Z"] {
            let outcome = fixture.send(current, .pat(gesture: .tap, zone: .head), at: fixture.instant(stamp), dayKey: day)
            #expect(outcome.moments.isEmpty)
            #expect(outcome.newState.days.first?.questSet.first?.progress == 0) // progress never starts
            current = outcome.newState
        }
        #expect(current.days.first?.patCount == 3) // every pat still counted
    }

    // MARK: Attribution + the expired-dayKey disposition

    @Test("an expired-dayKey event ticks nothing: no progress, no completion, no moment")
    func expiredDayKeyTicksNothing() {
        let start = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let staleKey = "2026-01-01" // no ledger entry
        let patted = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: staleKey)
        #expect(patted.moments.isEmpty) // in-window hour, but no ledger → no tick
        #expect(patted.newState.days.first?.questSet.first?.progress == 0)
        let fed = fixture.send(start, .feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: staleKey)
        #expect(fed.moments.isEmpty)
        #expect(fed.newState.days.first?.questSet.first { $0.questID == .q2 }?.progress == 0)
        #expect(fed.newState.days.count == 1) // no retroactive record was created
    }

    // MARK: The award's clamp interplay (AC-4)

    @Test("a completion at the +20 cap clamps its +4 to the remaining headroom; the moment still emits")
    func questAwardClampsAtDailyCap() {
        let headroom = 2 // the ledger holds 18 banked — the +4 truncates to +2
        let start = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            helloAwarded: true,
            bondAwarded: BondRules.dailyBondCap - headroom,
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(outcome.moments == [.questCompleted]) // the completion happened…
        #expect(outcome.newState.days.first?.questSet.first { $0.questID == .q2 }?.completed == true)
        #expect(outcome.newState.state.bond == start.state.bond + headroom) // …but only `headroom` applied
        #expect(outcome.newState.days.first?.bondAwarded == BondRules.dailyBondCap) // the ledger is exact
    }

    @Test("a completion at the 1000 plateau applies zero bond; the ledger truthfully records it")
    func questAwardClampsAtPlateau() {
        let start = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            bond: Thresholds.Bond.maximum,
            helloAwarded: true,
            highestCelebratedStage: .soulCompanions, // the guard matches the plateau — no stage catch-up noise
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(outcome.moments == [.questCompleted])
        #expect(outcome.newState.state.bond == Thresholds.Bond.maximum) // the plateau holds
        #expect(outcome.newState.days.first?.bondAwarded == 0) // nothing applied, nothing recorded
    }

    // MARK: Completion idempotence (AC-4)

    @Test("a completed quest never re-emits, never re-awards, never un-completes")
    func completionIsIdempotent() {
        let start = state(
            questSet: [quest(.q1, progress: 1, completed: true), quest(.q2), quest(.q6)],
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(outcome.moments.isEmpty) // Q1 already done — the pat completes nothing
        #expect(outcome.newState.state.bond == start.state.bond)
        #expect(outcome.newState.days.first?.questSet.first?.completed == true)
        #expect(outcome.newState.days.first?.questSet.first?.progress == 1) // capped at target
        #expect(outcome.newState.days.first?.patCount == 1) // the pat still counted
    }

    @Test("an all-done day shows no further completions on any counting event (AC-4)")
    func allDoneDayIsQuiet() {
        let start = state(
            questSet: [quest(.q1, progress: 1, completed: true), quest(.q2, progress: 1, completed: true), quest(.q6, progress: 1, completed: true)],
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T20:30:00Z")
        )
        let patted = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T20:30:00Z"), dayKey: day)
        #expect(patted.moments.isEmpty)
        let fed = fixture.send(patted.newState, .feed, at: fixture.instant("2026-09-08T20:31:00Z"), dayKey: day)
        #expect(fed.moments.isEmpty)
        let tucked = fixture.send(fed.newState, .tuckIn, at: fixture.instant("2026-09-08T20:32:00Z"), dayKey: day)
        #expect(tucked.moments.isEmpty)
        #expect(tucked.newState.state.bond == start.state.bond) // no quest award anywhere
        #expect(tucked.newState.days.first?.feedCount == 1 && tucked.newState.days.first?.careCount == 1) // the counts are honest
    }

    // MARK: Multiples + moment ordering (Required Test 6)

    @Test("one event CAN complete two quests: a morning pat with Q1 fresh and Q7 at 2/3 banks +8")
    func doubleCompletionLoops() {
        let start = state(
            questSet: [quest(.q1), quest(.q7, progress: 2), quest(.q6)],
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        // The pat serves .greet (Q1: 0→1 = target) AND .pet (Q7: 2→3 = target).
        #expect(outcome.moments == [.questCompleted, .questCompleted]) // one per completion, set order
        #expect(outcome.newState.days.first?.bondAwarded == 2 * BondRules.questBondDelta) // both awards applied
        let q1 = outcome.newState.days.first?.questSet.first { $0.questID == .q1 }
        let q7 = outcome.newState.days.first?.questSet.first { $0.questID == .q7 }
        #expect(q1?.completed == true && q7?.completed == true)
    }

    @Test("a completion that crosses a stage composes questCompleted FIRST, bondStageReached SECOND")
    func completionCrossingOrdersTheMoments() {
        let start = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            bond: 146,
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z")
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(outcome.newState.state.bond == 146 + BondRules.questBondDelta) // 150 — the crossing
        #expect(outcome.moments == [.questCompleted, .bondStageReached(.gettingClose)]) // the completion causes it
        #expect(outcome.newState.highestCelebratedStage == .gettingClose)
    }

    // MARK: The unified play cease is a counting event (report-path emissions)

    @Test("play rounds tick Q4 at the cease: the second round's completion emits ON THE REPORT event")
    func playCeaseTicksAndEmitsOnTheReport() {
        let start = state(
            questSet: [quest(.q1), quest(.q4), quest(.q6)],
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T10:00:00Z")
        )
        // Round 1: authorization (no tick — not a counting event), then the
        // cease ticks Q4 to 1/2 — no completion, no moment.
        let authorized1 = fixture.send(start, .play, at: fixture.instant("2026-09-08T10:00:00Z"), dayKey: day)
        #expect(authorized1.moments.isEmpty)
        let ceased1 = fixture.report(authorized1.newState, .playRoundFinished, at: fixture.instant("2026-09-08T10:01:00Z"))
        #expect(ceased1.moments.isEmpty)
        #expect(ceased1.newState.days.first?.questSet.first { $0.questID == .q4 }?.progress == 1)
        #expect(ceased1.newState.days.first?.playCount == 1)
        // Round 2: the cease completes Q4 — the moment surfaces on the
        // report event (the §4.8 tick rides the unified cease's instant).
        let authorized2 = fixture.send(ceased1.newState, .play, at: fixture.instant("2026-09-08T10:02:00Z"), dayKey: day)
        let ceased2 = fixture.report(authorized2.newState, .playRoundFinished, at: fixture.instant("2026-09-08T10:03:00Z"))
        #expect(ceased2.moments == [.questCompleted])
        #expect(ceased2.newState.days.first?.questSet.first { $0.questID == .q4 }?.completed == true)
        #expect(ceased2.newState.days.first?.bondAwarded == BondRules.questBondDelta)
        // Round 3: nothing left in the play family — the cease is silent.
        let authorized3 = fixture.send(ceased2.newState, .play, at: fixture.instant("2026-09-08T10:04:00Z"), dayKey: day)
        let ceased3 = fixture.report(authorized3.newState, .playRoundFinished, at: fixture.instant("2026-09-08T10:05:00Z"))
        #expect(ceased3.moments.isEmpty)
    }
}
