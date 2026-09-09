import Testing
import Foundation
@testable import MomoCore

/// The satiety window (05 §4.5 DECISION; TASK-016 Requirement 4; AC-3): the
/// phase is DERIVED at every fold instant from `lastFedAt`, half-open at both
/// boundaries (30:00 is recentlyFed's first minute, 90:00 hungry's), and a
/// feed anchors the clock while a refusal leaves it alone.
@Suite("Satiety window — derivation + boundaries + clock anchoring (TASK-016)")
struct SatietyWindowTests {

    private let fixture = InteractionFixture()

    private let day = "2026-09-08"

    // MARK: Pure boundary table (TimeFold's derivation, exact at the cuts)

    @Test("satiety boundaries are exact and half-open: 29:59 full / 30:00 recentlyFed / 89:59 recentlyFed / 90:00 hungry")
    func satietyBoundariesExact() {
        let fedAt = fixture.instant("2026-09-08T09:00:00Z")
        let calendar = fixture.calendar
        // (offset, expected) — the window values come from the constants home;
        // the ±1 s probes are the boundary evidence.
        let probes: [(seconds: TimeInterval, expected: SatietyPhase)] = [
            (1, .full),
            (Double(InteractionRules.satietySplitMinutes) * 60 - 1, .full),          // 29:59
            (Double(InteractionRules.satietySplitMinutes) * 60, .recentlyFed),       // 30:00 — recentlyFed's first minute
            (Double(InteractionRules.satietyWindowMinutes) * 60 - 1, .recentlyFed),  // 89:59
            (Double(InteractionRules.satietyWindowMinutes) * 60, .hungry),           // 90:00 — hungry's first minute
        ]
        for probe in probes {
            let to = fedAt.addingTimeInterval(probe.seconds)
            let fold = TimeFold.apply(
                petState: PetState(mood: 60, energy: 80, bond: 0, wakefulness: .awake,
                                   activity: nil, lastFedAt: fedAt, satietyPhase: .hungry)!,
                days: [],
                pendingHandshake: nil,
                from: fedAt,
                to: to,
                calendar: calendar,
                petID: fixture.petID
            )
            #expect(fold.petState.satietyPhase == probe.expected,
                    "at +\(probe.seconds)s since the feed the phase must be \(probe.expected)")
        }
    }

    @Test("never fed is hungry (nil lastFedAt), through the fold and through reduce")
    func neverFedIsHungry() {
        let derived = TimeFold.apply(
            petState: PetState(mood: 60, energy: 80, bond: 0, wakefulness: .awake,
                               activity: nil, lastFedAt: nil, satietyPhase: .full)!,
            days: [],
            pendingHandshake: nil,
            from: fixture.instant("2026-09-08T09:00:00Z"),
            to: fixture.instant("2026-09-08T09:01:00Z"),
            calendar: fixture.calendar,
            petID: fixture.petID
        )
        #expect(derived.petState.satietyPhase == .hungry) // the stored value is NOT carried — re-derived

        var rng = SeededGenerator(seed: 7)
        let state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        let outcome = reduce(state, .evaluate(now: fixture.instant("2026-09-08T10:00:00Z")),
                             clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rng)
        #expect(outcome.newState.state.satietyPhase == .hungry)
    }

    // MARK: End-to-end clock anchoring through reduce

    @Test("a feed anchors lastFedAt at the intent's instant and lands .full")
    func feedAnchorsTheClock() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        let outcome = fixture.send(start, .feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        #expect(outcome.newState.state.lastFedAt == fixture.instant("2026-09-08T09:00:00Z"))
        #expect(outcome.newState.state.satietyPhase == .full)
    }

    @Test("the phase re-derives on later folds: full → recentlyFed at +30 min → hungry at +90 min")
    func phaseReDerivesEndToEnd() {
        var state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        var rng = SeededGenerator(seed: 7)
        let feed = fixture.intent(.feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        state = reduce(state, .interaction(feed), clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rng).newState
        #expect(state.state.satietyPhase == .full)

        var rngA = SeededGenerator(seed: 7)
        let at30 = reduce(state, .evaluate(now: fixture.instant("2026-09-08T09:30:00Z")),
                          clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rngA)
        #expect(at30.newState.state.satietyPhase == .recentlyFed) // 30:00 = recentlyFed's first minute

        var rngB = SeededGenerator(seed: 7)
        let at90 = reduce(at30.newState, .evaluate(now: fixture.instant("2026-09-08T10:30:00Z")),
                          clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rngB)
        #expect(at90.newState.state.satietyPhase == .hungry) // 90:00 = hungry's first minute
    }

    @Test("the response class follows the derived phase: nibble in the 30–90 window, meal after it")
    func responseClassFollowsDerivedPhase() {
        var state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        var rng = SeededGenerator(seed: 7)
        let firstFeed = fixture.intent(.feed, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        state = reduce(state, .interaction(firstFeed), clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rng).newState

        // +31 min (into the recentlyFed class): the nibble — and note the
        // feed-family repetition is at instance 2 (×0.6) here, ×0.25 satiety.
        var rngA = SeededGenerator(seed: 7)
        let nibbled = reduce(state, .interaction(fixture.intent(.feed, at: fixture.instant("2026-09-08T09:31:00Z"), dayKey: day)),
                             clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rngA)
        #expect(nibbled.response?.reaction == ReactionKeys.nibble)
        #expect(nibbled.newState.state.satietyPhase == .full) // re-anchored

        // +2 h past the second feed: hungry again — the next feed is the full meal class.
        var rngB = SeededGenerator(seed: 7)
        let waited = reduce(nibbled.newState, .evaluate(now: fixture.instant("2026-09-08T11:31:00Z")),
                            clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rngB)
        #expect(waited.newState.state.satietyPhase == .hungry)
        var rngC = SeededGenerator(seed: 7)
        let mealed = reduce(waited.newState, .interaction(fixture.intent(.feed, at: fixture.instant("2026-09-08T11:31:00Z"), dayKey: day)),
                            clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rngC)
        #expect(mealed.response?.reaction == ReactionKeys.eating)
    }
}
