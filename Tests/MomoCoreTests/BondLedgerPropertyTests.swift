import Testing
import Foundation
@testable import MomoCore

/// The bond-ledger properties over randomized (seeded, replayable) event
/// sequences (TASK-017 AC-1/AC-2/AC-5; FR-10):
///
/// - **Cap by construction (AC-1/INV-5):** on one local dayKey no sequence
///   moves bond past +20; per-day `bondAwarded` never exceeds the cap.
/// - **Ledger exactness:** at every step, cumulative bond EQUALS the sum of
///   every day's `bondAwarded` — the day ledger records what was actually
///   applied (contract Requirement 2), which is what makes the cap exact
///   rather than nominal.
/// - **Monotonicity (AC-2/INV-3):** nothing — interactions, reports, folds,
///   day rollovers — ever decreases bond, including sequences spanning
///   midnight.
/// - **Guard discipline (AC-4; TASK-018's named re-pin, amended per
///   REVIEW-TASK-018 MINOR-1):** at most three moments per event — at most
///   two `.questCompleted` (one per completing quest) and one
///   `.bondStageReached`, quest moments first, the stage moment last — and
///   the stage guard advances only WITH an emission, and never regresses.
/// - **Twin equality (AC-5/FR-13):** identical (state, event stream, clock,
///   calendar, seed) tuples produce whole-state-equal final states, bond
///   fields included.
@Suite("Bond ledger properties — seeded sequences (TASK-017)")
struct BondLedgerPropertyTests {

    private let fixture = InteractionFixture()

    /// One seeded event step: a mixed stream of interactions (with their
    /// real choreography completions), evaluations, and direct quest-award
    /// mechanism calls, advancing a monotonic clock 10–20 min per step.
    private enum StepKind: CaseIterable {
        case pat, feed, play, tuckIn, nap, evaluate, quest
    }

    /// Runs `steps` events from a fresh single-day state anchored at `start`,
    /// returning every step-boundary state (the initial state first).
    private func run(_ steps: Int, seed: UInt64, start: String) -> [EngineState] {
        var rng = SeededGenerator(seed: seed)
        var now = fixture.instant(start)
        var state = fixture.state(
            dayKey: DayKey.make(from: now, calendar: fixture.calendar),
            lastEvaluatedAt: now
        )
        var boundaries: [EngineState] = [state]
        for i in 0..<steps {
            now = now.addingTimeInterval(Double(600 + Int(rng.next() % 601)))
            let dayKey = DayKey.make(from: now, calendar: fixture.calendar)
            let kind = StepKind.allCases[Int(rng.next() % UInt64(StepKind.allCases.count))]
            let outcome = step(kind, state: state, now: now, dayKey: dayKey, id: i)
            state = outcome.newState
            check(boundaries.last!, outcome)
            boundaries.append(state)
        }
        return boundaries
    }

    /// Executes one step kind — choreography events carry their real
    /// completions (a play round ceases one minute later; an authorized
    /// settle completes two minutes later), so nothing strands pending.
    private func step(
        _ kind: StepKind,
        state: EngineState,
        now: Instant,
        dayKey: String,
        id: Int
    ) -> EngineOutcome {
        let intentID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!
        switch kind {
        case .pat:
            return fixture.send(state, .pat(gesture: .tap, zone: .head), at: now, dayKey: dayKey, intentID: intentID)
        case .feed:
            return fixture.send(state, .feed, at: now, dayKey: dayKey, intentID: intentID)
        case .play:
            let authorized = fixture.send(state, .play, at: now, dayKey: dayKey, intentID: intentID)
            return fixture.report(authorized.newState, .playRoundFinished, at: now.addingTimeInterval(60))
        case .tuckIn:
            let offered = fixture.send(state, .tuckIn, at: now, dayKey: dayKey, intentID: intentID)
            guard offered.newState.pendingHandshake?.kind == .settle else { return offered }
            return fixture.report(offered.newState, .settleFinished, at: now.addingTimeInterval(120))
        case .nap:
            return fixture.send(state, .nap, at: now, dayKey: dayKey, intentID: intentID)
        case .evaluate:
            return fixture.evaluate(state, at: now)
        case .quest:
            let awarded = BondLedger.awardQuestCompletion(to: state, dayKey: dayKey)
            return EngineOutcome(newState: awarded, response: nil, moments: [], changed: awarded != state)
        }
    }

    /// The per-step invariants (see the suite header). Every assertion is a
    /// property of the WHOLE state, so each step re-proves them.
    private func check(_ prev: EngineState, _ outcome: EngineOutcome) {
        let next = outcome.newState
        // INV-3: monotonic, in range.
        #expect(next.state.bond >= prev.state.bond)
        #expect((Thresholds.Bond.minimum...Thresholds.Bond.maximum).contains(next.state.bond))
        // Ledger exactness + INV-5, on every day, at every step.
        #expect(next.state.bond == next.days.reduce(0) { $0 + $1.bondAwarded })
        for day in next.days {
            #expect(day.bondAwarded <= BondRules.dailyBondCap)
            #expect(day.familiesUsed.isSubset(of: BondRules.varietyTrio)) // only counting families record
        }
        // Guard discipline — TASK-018 supersession, AMENDED per
        // REVIEW-TASK-018 MINOR-1 (the contract's "at most one completion
        // per event structurally" premise was disproven: a pat serves both
        // Q1 and Q7, and §4.8's own offline-pat shape lets one event complete
        // both — QuestTickTests.doubleCompletionLoops is the live coverage).
        // This property generator cannot reach a double (its fixture set has
        // no Q7 and its intent clock is monotone), which is why the bound is
        // wider than what this suite observes. At most three moments: ≤ 2
        // questCompleted (one per completing quest; the Q1+Q7 pair is the
        // only reachable one) and ≤ 1 bondStageReached — quest moments FIRST,
        // the stage moment LAST (the completions are what cause any
        // crossing); the stage guard advances only WITH a bondStageReached
        // emission and never regresses.
        #expect(outcome.moments.count <= 3)
        var questCount = 0
        var stageSeen = false
        for moment in outcome.moments {
            switch moment {
            case .questCompleted:
                #expect(!stageSeen) // quest moments compose first…
                #expect(questCount < 2) // …at most two completions per event
                questCount += 1
            case .bondStageReached(let stage):
                #expect(!stageSeen) // at most one stage moment, always last
                stageSeen = true
                #expect(next.highestCelebratedStage == stage) // the guard advanced WITH the emission
            default:
                Issue.record("unexpected moment kind in the re-pinned era: \(moment)")
            }
        }
        if !stageSeen {
            #expect(next.highestCelebratedStage == prev.highestCelebratedStage)
        }
    }

    // MARK: AC-1 — cap by construction over randomized single-day sequences

    @Test("cap by construction: no seeded single-day sequence moves bond past +20", arguments: [UInt64(1), 7, 1_234, 99_073])
    func capByConstruction(seed: UInt64) {
        // ≤ 30 steps × ≤ 20 min keeps every step inside the start's dayKey.
        let states = run(30, seed: seed, start: "2026-09-08T10:00:00Z")
        let final = states.last!
        #expect(final.state.bond <= BondRules.dailyBondCap)
        #expect(final.days.count == 1) // the sequence never left its day
        for state in states {
            #expect(state.state.bond <= BondRules.dailyBondCap)
        }
    }

    // MARK: AC-2 — monotonicity across day rollovers

    @Test("nothing — events, folds, or midnight — ever decreases bond", arguments: [UInt64(3), 41, 555])
    func monotonicAcrossRollover(seed: UInt64) {
        // Starting near midnight, the sequence crosses into the next day:
        // the ledger resets (a fresh DayRecord) while bond only grows.
        let states = run(9, seed: seed, start: "2026-09-08T22:00:00Z")
        #expect(states.count > 1)
        for (prev, next) in zip(states, states.dropFirst()) {
            #expect(next.state.bond >= prev.state.bond)
        }
        let final = states.last!
        #expect(DayKey.make(from: fixture.instant("2026-09-09T00:00:00Z"), calendar: fixture.calendar)
            != DayKey.make(from: fixture.instant("2026-09-08T22:00:00Z"), calendar: fixture.calendar)) // fixture sanity
        #expect(final.state.bond == final.days.reduce(0) { $0 + $1.bondAwarded }) // exactness survives the rollover
        let rolloverDay = DayKey.make(from: fixture.instant("2026-09-09T00:00:00Z"), calendar: fixture.calendar)
        if let newDay = final.days.first(where: { $0.dayKey == rolloverDay }) {
            #expect(newDay.bondAwarded <= BondRules.dailyBondCap) // the new day earns under its own cap
        }
    }

    // MARK: AC-5 — twin equality

    @Test("twin runs over identical tuples are whole-state equal, bond fields included")
    func twinRunsAreWholeStateEqual() {
        let a = run(42, seed: 2_026, start: "2026-09-08T10:00:00Z")
        let b = run(42, seed: 2_026, start: "2026-09-08T10:00:00Z")
        #expect(a.count == b.count)
        #expect(a.last == b.last)
        // The whole trajectory replays identically, not just the endpoint.
        for (x, y) in zip(a, b) {
            #expect(x == y)
        }
    }
}
