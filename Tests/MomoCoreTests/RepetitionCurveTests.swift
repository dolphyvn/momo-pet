import Testing
import Foundation
@testable import MomoCore

/// The same-family repetition curve (05 §4.5; TASK-016 Requirement 5; AC-4):
/// 1.0 / 0.6 / 0.25 / 0.0 per family per local day, read BEFORE the
/// interaction increments its counter, independent of satiety, care exempt,
/// reset by the new day, and instance-1 for an expired-dayKey intent.
///
/// Each instance is a FRESH fixture whose ledger pre-carries the family's
/// day counter — the fold stays the identity (zero elapsed) so the pins are
/// the pure interaction arithmetic, with the constants and the production
/// operation order (delta × multiplier) restated independently.
@Suite("Repetition curve — per family per local day (TASK-016)")
struct RepetitionCurveTests {

    private let fixture = InteractionFixture()

    private let day = "2026-09-08"
    private let t = "2026-09-08T09:00:00Z"

    private func curveInstance(_ index: Int) -> Double {
        InteractionRules.repetitionMultipliers[index]
    }

    // MARK: Feed family

    @Test("feed curve: 1st/2nd/3rd/4th same day apply 1.0/0.6/0.25/0.0 exactly — and all four still count + respond")
    func feedCurveExact() {
        for (instance, priorFeeds) in [(0, 0), (1, 1), (2, 2), (3, 3)] {
            let start = fixture.state(dayKey: day, feed: priorFeeds, lastEvaluatedAt: fixture.instant(t))
            let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
            #expect(outcome.newState.state.energy == start.state.energy
                + InteractionRules.mealEnergyDelta * curveInstance(instance))
            #expect(outcome.newState.days.first?.feedCount == priorFeeds + 1) // counts at every softness (I-1)
            #expect(outcome.response != nil) // the 4th+ still responds warmly — softening, never punishment (D18)
            #expect(outcome.response?.reaction == ReactionKeys.eating)
        }
    }

    // MARK: Pet family

    @Test("pat curve: mood gains 1.0/0.6/0.25/0.0 exactly; the 4th still counts and still responds")
    func patCurveExact() {
        for (instance, priorPats) in [(0, 0), (1, 1), (2, 2), (3, 3)] {
            let start = fixture.state(dayKey: day, pat: priorPats, lastEvaluatedAt: fixture.instant(t))
            let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
            #expect(outcome.newState.state.mood == start.state.mood
                + InteractionRules.touchMoodDelta * curveInstance(instance))
            #expect(outcome.newState.state.bond == start.state.bond) // G2 at every volume
            #expect(outcome.newState.days.first?.patCount == priorPats + 1)
            #expect(outcome.response?.reaction == ReactionKeys.tapHead)
        }
    }

    // MARK: Play family (curve applied at the cease)

    @Test("play curve: cease applies −10/+6 × 1.0/0.6/0.25/0.0; the 4th still counts and still clears")
    func playCurveExactAtCease() {
        let token = UUID()
        for (instance, priorRounds) in [(0, 0), (1, 1), (2, 2), (3, 3)] {
            let start = fixture.state(
                dayKey: day,
                play: priorRounds,
                activity: .playing,
                pendingHandshake: Handshake(kind: .play, token: token),
                lastEvaluatedAt: fixture.instant(t)
            )
            let outcome = fixture.report(start, .playRoundFinished, at: fixture.instant(t))
            #expect(outcome.newState.state.energy == start.state.energy
                + InteractionRules.playRoundEnergyDelta * curveInstance(instance))
            #expect(outcome.newState.state.mood == start.state.mood
                + InteractionRules.playRoundMoodDelta * curveInstance(instance))
            #expect(outcome.newState.days.first?.playCount == priorRounds + 1)
            #expect(outcome.newState.state.activity == nil)
            #expect(outcome.newState.pendingHandshake == nil)
        }
    }

    // MARK: Independence of satiety and of family

    @Test("repetition is independent of satiety: the 2nd nibble is ×0.25 × 0.6, the 2nd meal ×0.6")
    func curveIndependentOfSatiety() {
        let fedAt = fixture.instant("2026-09-08T08:00:00Z")
        let recentlyFed = fixture.state(
            dayKey: day,
            feed: 1,
            lastFedAt: fedAt,
            satietyPhase: .recentlyFed,
            lastEvaluatedAt: fixture.instant(t)
        )
        let nibble = fixture.send(recentlyFed, .feed, at: fixture.instant(t), dayKey: day)
        #expect(nibble.response?.reaction == ReactionKeys.nibble)
        #expect(nibble.newState.state.energy == recentlyFed.state.energy
            + InteractionRules.mealEnergyDelta * (curveInstance(1) * InteractionRules.nibbleEffectMultiplier))

        let hungry = fixture.state(
            dayKey: day,
            feed: 1,
            lastFedAt: fixture.instant("2026-09-08T06:00:00Z"),
            satietyPhase: .hungry,
            lastEvaluatedAt: fixture.instant(t)
        )
        let meal = fixture.send(hungry, .feed, at: fixture.instant(t), dayKey: day)
        #expect(meal.response?.reaction == ReactionKeys.eating)
        #expect(meal.newState.state.energy == hungry.state.energy
            + InteractionRules.mealEnergyDelta * curveInstance(1))
    }

    @Test("families are independent: a fed-up day does not soften a fresh pat or round")
    func familiesIndependent() {
        // Three feeds banked: a pat and a play round are still instance 1.
        let busy = fixture.state(dayKey: day, feed: 3, lastEvaluatedAt: fixture.instant(t))
        let pat = fixture.send(busy, .pat(gesture: .stroke, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(pat.newState.state.mood == busy.state.mood + InteractionRules.touchMoodDelta * curveInstance(0))

        let playStart = fixture.state(
            dayKey: day,
            feed: 3,
            activity: .playing,
            pendingHandshake: Handshake(kind: .play, token: UUID()),
            lastEvaluatedAt: fixture.instant(t)
        )
        let ceased = fixture.report(playStart, .playRoundFinished, at: fixture.instant(t))
        #expect(ceased.newState.state.energy == playStart.state.energy
            + InteractionRules.playRoundEnergyDelta * curveInstance(0))

        // …and three pats do not soften a fresh feed.
        let petted = fixture.state(dayKey: day, pat: 3, lastEvaluatedAt: fixture.instant(t))
        let fed = fixture.send(petted, .feed, at: fixture.instant(t), dayKey: day)
        #expect(fed.newState.state.energy == petted.state.energy + InteractionRules.mealEnergyDelta * curveInstance(0))
    }

    // MARK: Care exemption

    @Test("care carries NO multiplier: the 4th blanket-adjust is as warm as the 1st")
    func careExempt() {
        for priorCare in [0, 1, 2, 3] {
            let start = fixture.state(
                dayKey: day,
                care: priorCare,
                wakefulness: .asleep,
                lastEvaluatedAt: fixture.instant("2026-09-08T21:00:00Z")
            )
            let outcome = fixture.send(start, .tuckIn, at: fixture.instant("2026-09-08T21:00:00Z"), dayKey: day)
            #expect(outcome.response?.reaction == ReactionKeys.blanketAdjust)
            #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.tuckInMoodDelta)
            #expect(outcome.newState.state.energy == start.state.energy + InteractionRules.tuckInEnergyDelta)
            #expect(outcome.newState.days.first?.careCount == priorCare + 1)
        }
    }

    // MARK: Day scoping

    @Test("a new day resets the curve (the counters are per-dayKey)")
    func newDayResets() {
        let nextDay = "2026-09-09"
        let start = fixture.state(
            mood: 60,
            energy: 80,
            wakefulness: .awake,
            activity: nil,
            lastFedAt: nil,
            satietyPhase: .hungry,
            pendingHandshake: nil,
            days: [fixture.day(dayKey: day, feed: 3), fixture.day(dayKey: nextDay)],
            lastEvaluatedAt: fixture.instant("2026-09-09T09:00:00Z")
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant("2026-09-09T09:00:00Z"), dayKey: nextDay)
        #expect(outcome.newState.state.energy == start.state.energy + InteractionRules.mealEnergyDelta * curveInstance(0))
        #expect(outcome.newState.days.first { $0.dayKey == day }?.feedCount == 3) // yesterday untouched
        #expect(outcome.newState.days.first { $0.dayKey == nextDay }?.feedCount == 1)
    }

    @Test("an expired-dayKey intent: instance-1 effects, NO ledger attribution at all")
    func expiredDayKeyFullEffectNoAttribution() {
        // The intent's localDayKey predates the pet and has no ledger entry
        // (§5.4 pruning or pre-pet history) — effects land on current state;
        // no counter moves, no record appears.
        let expiredKey = "2020-01-01"
        let start = fixture.state(dayKey: day, feed: 2, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: expiredKey)
        #expect(outcome.newState.state.energy == start.state.energy + InteractionRules.mealEnergyDelta * curveInstance(0))
        #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.mealMoodDelta * curveInstance(0))
        #expect(outcome.newState.days.count == 1) // no retroactive record
        #expect(outcome.newState.days.first?.feedCount == 2) // the present day's counter untouched
        #expect(outcome.response != nil)
    }

    @Test("an expired-dayKey pat is also unattributed (instance-1 effect, no count)")
    func expiredDayKeyPat() {
        let expiredKey = "2020-01-01"
        let start = fixture.state(dayKey: day, pat: 1, lastEvaluatedAt: fixture.instant(t))
        let patted = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: expiredKey)
        #expect(patted.newState.state.mood == start.state.mood + InteractionRules.touchMoodDelta * curveInstance(0))
        #expect(patted.newState.days.count == 1)
        #expect(patted.newState.days.first?.patCount == 1)
    }

    @Test("the play round attributes to the CEASE instant's day, not the authorization's")
    func ceaseDayAttribution() {
        // A round authorized on a day with three rounds banked, ceasing on a
        // FRESH day (the cease instant is when the round "happened" — FR-7
        // AC-2's completion rule, pinned directly on HandshakeMachine so the
        // fold's night arithmetic stays out of the exact pins). The ledger
        // pre-carries the cease day because in the reduce flow the fold's
        // rollover always creates the landing day BEFORE the report is
        // applied — HandshakeMachine alone never invents a record (the
        // expired-dayKey no-op), it only counts into an existing one.
        let nextDay = "2026-09-09"
        let authorizeDay = fixture.state(
            mood: 60,
            energy: 80,
            bond: 0,
            wakefulness: .awake,
            activity: .playing,
            lastFedAt: nil,
            satietyPhase: .hungry,
            pendingHandshake: Handshake(kind: .play, token: UUID()),
            days: [fixture.day(dayKey: day, play: 3), fixture.day(dayKey: nextDay)],
            lastEvaluatedAt: fixture.instant("2026-09-08T23:00:00Z")
        )
        let nextDayInstant = fixture.instant("2026-09-09T00:30:00Z")
        let ceased = HandshakeMachine.apply(
            .playRoundFinished,
            to: authorizeDay,
            at: nextDayInstant,
            calendar: fixture.calendar
        )
        #expect(ceased.days.first { $0.dayKey == day }?.playCount == 3) // the authorization day untouched
        #expect(ceased.days.first { $0.dayKey == nextDay }?.playCount == 1) // the fresh day's instance 1
        #expect(ceased.state.energy == authorizeDay.state.energy
            + InteractionRules.playRoundEnergyDelta * curveInstance(0)) // × the NEW day's curve
    }
}
