import Testing
import Foundation
@testable import MomoCore

/// The §10.2 meta-determinism property (TASK-020; 05 §10.2 "Determinism
/// property tests: identical (state, event sequence, clock, seed) ⇒
/// byte-identical outcome; run as properties over randomized interaction
/// sequences (bounded, seeded — meta-determinism)"):
///
/// For each of six distinct seeds, a seeded schedule generates a bounded
/// mixed step sequence spanning **≥ 3 local days by construction** (80 steps
/// × ≥ 57 min ≥ 76 h > 72 h, so every sequence crosses ≥ 3 local midnights
/// and every 9 h night window between them — the multi-day span is the
/// schedule arithmetic, not draw luck), through the FULL production `reduce`
/// surface: all five interaction kinds, character reports (the pending
/// handshake's real completion, plus cancellation paths), evaluates, and the
/// direct `BondLedger.awardQuestCompletion` mechanism call. Each sequence is
/// then run TWICE from identical (state, clock, calendar, seed) tuples and
/// the WHOLE trajectories must agree step-for-step — every intermediate
/// `EngineState` and every `EngineOutcome` (response + moments + changed),
/// not just the endpoints (`EngineOutcome` equality subsumes its
/// `newState`'s). A final assertion proves the property has teeth: different
/// seeds produce different trajectories.
///
/// House lineage: `BondLedgerPropertyTests` is the single-day pattern this
/// suite generalizes across rollovers and the full event surface. All
/// generation is deterministic — the repo-owned `SeededGenerator` drives the
/// schedule, `ManualEngineClock` serves the report path's fold-to-now, and
/// the calendar is the fixture's injected Gregorian (no wall clock, no
/// ambient randomness anywhere). Engine constants enter only through their
/// constants homes (`Thresholds`); the schedule's minute bounds are test
/// fixture identity, not engine constants.
@Suite("Meta-determinism — seeded multi-day twin trajectories (TASK-020, 05 §10.2)")
struct MetaDeterminismTests {

    private let fixture = InteractionFixture()

    /// Start anchor: mid-morning of the first local day.
    private let start = "2026-09-08T09:30:00Z"

    /// Steps per seed. 80 × the 57-minute step floor ≥ 76 h > 72 h is what
    /// makes "≥ 3 local days" hold for EVERY seed (see the suite header).
    private static let stepsPerSeed = 80
    /// Step duration is `[57, 114)` minutes, drawn from the schedule stream.
    private static let minStepMinutes: UInt64 = 57
    private static let stepMinuteSpread: UInt64 = 58

    /// The mixed step surface (05 §10.2's "interactions of all kinds,
    /// character reports, evaluates, quest-award mechanism calls"). The
    /// composite kinds carry their real choreography completions — a play
    /// round ceases one minute later, an authorized settle completes two
    /// minutes later — so nothing strands pending (the BondLedgerPropertyTests
    /// convention).
    private enum StepKind {
        case pat, feed, play, tuckIn, nap, evaluate, questAward, report, cancel
    }

    // MARK: The property

    @Test("twin runs of a seeded multi-day mixed sequence are equal step-for-step — every intermediate state and outcome (05 §10.2)", arguments: [UInt64(11), 2_026, 70_001, 424_242, 987_654_321, 0xDEAD_BEEF_1234])
    func twinTrajectoriesAreEqualStepForStep(seed: UInt64) {
        let first = run(seed: seed)
        let second = run(seed: seed)
        #expect(first.count == second.count)
        for (a, b) in zip(first, second) {
            #expect(a == b) // outcome equality subsumes its intermediate newState
        }
    }

    @Test("the property has teeth: different seeds produce different trajectories")
    func differentSeedsDiverge() {
        let a = run(seed: 11)
        let b = run(seed: 2_026)
        #expect(a != b)
    }

    // MARK: The seeded runner

    /// Generates the seed's schedule and runs the whole sequence through
    /// production `reduce`, returning every engine outcome in order. A pure
    /// function of `seed` (identical calls rebuild identical initial states,
    /// schedules, clocks, and engine seeds — that identity IS the property).
    private func run(seed: UInt64) -> [EngineOutcome] {
        var schedule = SeededGenerator(seed: seed)
        var now = fixture.instant(start)
        var state = fixture.state(
            dayKey: DayKey.make(from: now, calendar: fixture.calendar),
            lastEvaluatedAt: now
        )
        var outcomes: [EngineOutcome] = []
        for index in 0..<Self.stepsPerSeed {
            now = now.addingTimeInterval(
                Double(Self.minStepMinutes + schedule.next() % Self.stepMinuteSpread) * 60
            )
            let kind = kindStep(schedule: &schedule)
            let engineSeed = schedule.next()
            let dayKey = DayKey.make(from: now, calendar: fixture.calendar)
            let produced = step(kind, state: state, now: now, dayKey: dayKey, id: index, engineSeed: engineSeed)
            for (outcome, wasInteraction) in produced {
                check(outcome, interaction: wasInteraction, greetingAllowed: kind == .evaluate)
                outcomes.append(outcome)
            }
            state = produced.last!.outcome.newState
        }
        // Fixture sanity (house pattern — BondLedgerPropertyTests): assert
        // the consequences the property's premise depends on — the sequence
        // really crossed ≥ 3 local midnights (each landing day's ledger
        // record exists only because a fold crossed its midnight) and BOTH
        // sides of the 22:00/07:00 night window (night onsets land `.asleep`
        // on the step that crosses them — no report path can move a pet OUT
        // of `.asleep`; mornings surface as `.waking` or as the deferred
        // wake-stretch mint, depending on which step shape crossed 07:00).
        #expect(state.days.count >= 3)
        #expect(outcomes.contains { $0.newState.state.wakefulness == .asleep })
        #expect(outcomes.contains {
            $0.newState.state.wakefulness == .waking || $0.newState.pendingHandshake?.kind == .wake
        })
        return outcomes
    }

    /// Draws one step kind from the schedule stream (uniform over the nine).
    private func kindStep(schedule: inout SeededGenerator) -> StepKind {
        let all: [StepKind] = [.pat, .feed, .play, .tuckIn, .nap, .evaluate, .questAward, .report, .cancel]
        return all[Int(schedule.next() % UInt64(all.count))]
    }

    // MARK: One step

    /// Executes one step kind, returning EVERY engine outcome it produced
    /// paired with whether that outcome was an interaction event (the only
    /// kind that answers with a ResponsePlan). The composite kinds are two
    /// calls: the interaction, then its real choreography completion. The
    /// engine rng for each call is derived from the schedule's per-step
    /// draw, so the full tuple is a pure function of the master seed.
    private func step(
        _ kind: StepKind,
        state: EngineState,
        now: Instant,
        dayKey: String,
        id: Int,
        engineSeed: UInt64
    ) -> [(outcome: EngineOutcome, interaction: Bool)] {
        let intentID = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", id))!
        switch kind {
        case .pat:
            return [(engine(state, .interaction(fixture.intent(.pat(gesture: .tap, zone: .head), at: now, dayKey: dayKey, id: intentID)), at: now, seed: engineSeed), true)]
        case .feed:
            return [(engine(state, .interaction(fixture.intent(.feed, at: now, dayKey: dayKey, id: intentID)), at: now, seed: engineSeed), true)]
        case .play:
            let authorized = engine(state, .interaction(fixture.intent(.play, at: now, dayKey: dayKey, id: intentID)), at: now, seed: engineSeed)
            // The round's real choreography completion one minute later (the
            // unified cease — the engine answers it, stale or not).
            return [(authorized, true), (engine(authorized.newState, .characterReport(.playRoundFinished), at: now.addingTimeInterval(60), seed: engineSeed &+ 1), false)]
        case .tuckIn:
            let offered = engine(state, .interaction(fixture.intent(.tuckIn, at: now, dayKey: dayKey, id: intentID)), at: now, seed: engineSeed)
            guard offered.newState.pendingHandshake?.kind == .settle else { return [(offered, true)] }
            return [(offered, true), (engine(offered.newState, .characterReport(.settleFinished), at: now.addingTimeInterval(120), seed: engineSeed &+ 1), false)]
        case .nap:
            return [(engine(state, .interaction(fixture.intent(.nap, at: now, dayKey: dayKey, id: intentID)), at: now, seed: engineSeed), true)]
        case .evaluate:
            return [(engine(state, .evaluate(now: now), at: now, seed: engineSeed), false)]
        case .questAward:
            let awarded = BondLedger.awardQuestCompletion(to: state, dayKey: dayKey)
            return [(EngineOutcome(newState: awarded, response: nil, moments: [], changed: awarded != state), false)]
        case .report:
            // Answer whatever handshake is pending — the natural
            // choreography; with nothing pending the report is the
            // tolerated stale no-op the idempotency contract requires.
            let report: CharacterReport
            switch state.pendingHandshake?.kind {
            case .settle: report = .settleFinished
            case .wake: report = .wakeFinished
            case .play: report = .playRoundFinished
            case nil: report = .reactionFinished(ReactionKeys.tapHead)
            }
            return [(engine(state, .characterReport(report), at: now, seed: engineSeed), false)]
        case .cancel:
            let cancelled = state.pendingHandshake?.kind ?? .play
            return [(engine(state, .characterReport(.handshakeCancelled(cancelled)), at: now, seed: engineSeed), false)]
        }
    }

    /// One `reduce` call with the given derived seed and a clock set to the
    /// step instant (the report path's fold target; the other kinds never
    /// read it — pinned by `EngineReduceTests.clockUnread`).
    private func engine(_ state: EngineState, _ event: EngineEvent, at instant: Instant, seed: UInt64) -> EngineOutcome {
        var rng = SeededGenerator(seed: seed)
        return reduce(state, event, clock: ManualEngineClock(at: instant), calendar: fixture.calendar, rng: &rng)
    }

    // MARK: Per-step invariants

    /// Light per-step invariants over the mixed surface (the bond ledger's
    /// discipline is `BondLedgerPropertyTests`' contract): the INV-2/INV-3
    /// domains hold at every step, the response seam stays honest (one plan
    /// per fresh interaction event, never on any other event kind), and the
    /// moment composition stays within the engine's bound with the greeting
    /// evaluate-only.
    private func check(_ outcome: EngineOutcome, interaction: Bool, greetingAllowed: Bool) {
        let next = outcome.newState
        #expect((Thresholds.Scalar.lower...Thresholds.Scalar.upper).contains(next.state.mood))
        #expect((Thresholds.Scalar.lower...Thresholds.Scalar.upper).contains(next.state.energy))
        #expect((Thresholds.Bond.minimum...Thresholds.Bond.maximum).contains(next.state.bond))
        if interaction {
            #expect(outcome.response != nil) // 04 §9.2: one plan per interaction event
        } else {
            #expect(outcome.response == nil)
        }
        #expect(outcome.moments.count <= 3)
        for moment in outcome.moments {
            if case .greeting = moment {
                #expect(greetingAllowed, "the greeting is evaluate-only (TASK-019)")
            }
        }
    }
}
