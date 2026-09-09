import Testing
import Foundation
@testable import MomoCore

/// The greeting selector's rule table (TASK-019 Requirement 5; FR-12 AC-2;
/// UX §4; Required Test 6), in RULE ORDER, plus the evaluate-path emission
/// pins: the selector reads the PRE-stamp `lastOpenedAt`, the moment
/// composes FIRST, the stamp lands on the new state, and no other event
/// path ever greets. Behavior over the named thresholds
/// (`Thresholds.Greeting`); their raw literals are pinned in
/// `ThresholdsPinnedToPRDTests`.
@Suite("Greeting selection — the AC-6 table + evaluate emission (TASK-019)")
struct GreetingSelectionTests {

    private let fixture = InteractionFixture()

    // MARK: The rule table (first match wins)

    @Test("a gap below the re-greet floor selects nothing — scenePhase flapping never re-greets")
    func belowFloorIsNil() {
        let open = fixture.instant("2026-09-08T10:00:00Z")
        let soon = open.addingTimeInterval(Double(Thresholds.Greeting.regreetFloorMinutes - 1) * 60)
        #expect(Greeting.select(previousOpen: open, now: soon, calendar: fixture.calendar) == nil)
    }

    @Test("a gap exactly at the floor greets — same-day daytime is a welcome back")
    func atFloorGreets() {
        let open = fixture.instant("2026-09-08T10:00:00Z")
        let now = open.addingTimeInterval(Double(Thresholds.Greeting.regreetFloorMinutes) * 60)
        #expect(Greeting.select(previousOpen: open, now: now, calendar: fixture.calendar) == .welcomeBack)
    }

    @Test("a backward gap selects nothing — no greeting is invented for time that did not pass")
    func backwardGapIsNil() {
        let open = fixture.instant("2026-09-08T10:00:00Z")
        #expect(Greeting.select(previousOpen: open, now: open.addingTimeInterval(-3_600), calendar: fixture.calendar) == nil)
    }

    @Test("an absence of 36 h or more is missedYou — even inside the night window (the absence outranks the hour)")
    func missedYouEvenAtNight() {
        let open = fixture.instant("2026-09-05T13:00:00Z")
        let atThreshold = open.addingTimeInterval(Double(Thresholds.Greeting.missedYouAfterHours) * 3_600)
        // 2026-09-07T01:00Z — hour 1, inside the night window, yet:
        #expect(Greeting.select(previousOpen: open, now: atThreshold, calendar: fixture.calendar) == .missedYou)
        // One minute short of the bound, the same open lands nightGlance:
        let justUnder = atThreshold.addingTimeInterval(-60)
        #expect(Greeting.select(previousOpen: open, now: justUnder, calendar: fixture.calendar) == .nightGlance)
    }

    /// The missedYou-vs-freshMorning half of the ordering (REVIEW-TASK-019
    /// NITPICK-1): a 36 h absence landing in DAYTIME is still missedYou —
    /// the absence outranks the dayKey change (missedYou-vs-nightGlance is
    /// pinned by `missedYouEvenAtNight`).
    @Test("a 36 h absence landing at 14:00 is missedYou, not freshMorning")
    func missedYouOutranksFreshMorning() {
        let open = fixture.instant("2026-09-07T02:00:00Z")
        let now = open.addingTimeInterval(Double(Thresholds.Greeting.missedYouAfterHours) * 3_600) // 14:00 the next day
        #expect(DayKey.make(from: now, calendar: fixture.calendar) != DayKey.make(from: open, calendar: fixture.calendar))
        #expect(Greeting.select(previousOpen: open, now: now, calendar: fixture.calendar) == .missedYou)
    }

    @Test("a same-day return at night is a nightGlance")
    func nightGlanceSameDay() {
        let open = fixture.instant("2026-09-08T10:00:00Z")
        #expect(Greeting.select(previousOpen: open, now: fixture.instant("2026-09-08T23:00:00Z"), calendar: fixture.calendar) == .nightGlance)
    }

    @Test("the first open of a local day in daytime is a freshMorning — including a 14:00 first open")
    func freshMorningFirstOpens() {
        let previousEvening = fixture.instant("2026-09-07T20:00:00Z")
        #expect(Greeting.select(previousOpen: previousEvening, now: fixture.instant("2026-09-08T09:00:00Z"), calendar: fixture.calendar) == .freshMorning)
        #expect(Greeting.select(previousOpen: previousEvening, now: fixture.instant("2026-09-08T14:00:00Z"), calendar: fixture.calendar) == .freshMorning)
    }

    /// A dayKey change DURING the night window is still a nightGlance — the
    /// hour governs before the day comparison (a 00:10 open after a 23:50
    /// open crossed midnight, but it is not a "morning").
    @Test("a midnight-crossing open in the night window is nightGlance, not freshMorning")
    func midnightCrossingIsNightGlance() {
        let open = fixture.instant("2026-09-07T23:50:00Z")
        #expect(Greeting.select(previousOpen: open, now: fixture.instant("2026-09-08T00:10:00Z"), calendar: fixture.calendar) == .nightGlance)
    }

    @Test("a same-day daytime return past the floor is a welcomeBack")
    func welcomeBackSameDay() {
        let open = fixture.instant("2026-09-08T09:00:00Z")
        #expect(Greeting.select(previousOpen: open, now: fixture.instant("2026-09-08T11:00:00Z"), calendar: fixture.calendar) == .welcomeBack)
    }

    // MARK: Evaluate-path emission (the stamps + first composition)

    /// The emission proof doubles as the PRE-stamp proof: the fold span is
    /// five minutes, but the PREVIOUS OPEN is 23 h and a dayKey away — a
    /// greeting fires, which only the pre-stamp open can explain (had the
    /// selector read the post-stamp `lastOpenedAt` (= now), the gap would be
    /// zero and it would stay silent).
    @Test("evaluate emits at most one greeting, FIRST, and stamps it on the new state (reading the PRE-stamp open)")
    func evaluateEmitsGreetingFirstAndStamps() {
        let calendar = fixture.calendar
        let previousOpen = fixture.instant("2026-09-07T10:00:00Z")
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let base = fixture.state(
            days: [fixture.day(dayKey: "2026-09-08")],
            lastEvaluatedAt: now.addingTimeInterval(-300) // a 5-minute fold
        )
        let opened = EngineState(
            pet: base.pet,
            state: base.state,
            days: base.days,
            settings: base.settings,
            pendingHandshake: base.pendingHandshake,
            processedIntents: base.processedIntents,
            highestCelebratedStage: base.highestCelebratedStage,
            lastOpenedAt: previousOpen,
            lastEvaluatedAt: base.lastEvaluatedAt,
            lastGreeting: nil
        )
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(opened, .evaluate(now: now), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
        #expect(outcome.moments.first == CharacterMoment.greeting(.freshMorning))
        #expect(outcome.moments.count == 1)
        #expect(outcome.newState.lastGreeting == GreetingStamp(kind: .freshMorning, at: now))
        // The stamp survives into both read-models.
        #expect(makeDisplayState(outcome.newState, at: now, calendar: calendar).greeting == .freshMorning)
        #expect(makeCharacterDisplayState(outcome.newState).momentRequest == .greeting(.freshMorning))
    }

    @Test("a zero-gap evaluate stays silent and keeps the previous stamp")
    func zeroGapEvaluateStaysSilent() {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let stamped = fixture.state(days: [fixture.day(dayKey: "2026-09-08")], lastEvaluatedAt: now)
            .with(lastGreeting: GreetingStamp(kind: .welcomeBack, at: now))
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(stamped, .evaluate(now: now), clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rng)
        #expect(outcome.moments.isEmpty)
        #expect(outcome.newState.lastGreeting == GreetingStamp(kind: .welcomeBack, at: now),
                "a silent re-evaluation must not clear or re-stamp the greeting in effect")
    }

    @Test("interactions never greet — a next-day pat carries no greeting moment and no new stamp")
    func interactionsNeverGreet() {
        let previousOpen = fixture.instant("2026-09-07T10:00:00Z")
        let state = fixture.state(days: [fixture.day(dayKey: "2026-09-08")], lastEvaluatedAt: previousOpen)
        let opened = EngineState(
            pet: state.pet,
            state: state.state,
            days: state.days,
            settings: state.settings,
            pendingHandshake: state.pendingHandshake,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: previousOpen,
            lastEvaluatedAt: previousOpen,
            lastGreeting: nil
        )
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(opened, .interaction(fixture.intent(.pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: "2026-09-08")),
                             clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rng)
        #expect(outcome.response != nil)
        #expect(!outcome.moments.contains { moment in
            if case .greeting = moment { return true }
            return false
        })
        #expect(outcome.newState.lastGreeting == nil)
    }

    @Test("reports never greet — a next-day report carries no greeting moment and no new stamp")
    func reportsNeverGreet() {
        let previousOpen = fixture.instant("2026-09-07T10:00:00Z")
        let settle = Handshake(kind: .settle, token: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000002")!)
        let state = fixture.state(
            wakefulness: .settling,
            pendingHandshake: settle,
            days: [fixture.day(dayKey: "2026-09-08")],
            lastEvaluatedAt: previousOpen
        )
        let opened = EngineState(
            pet: state.pet,
            state: state.state,
            days: state.days,
            settings: state.settings,
            pendingHandshake: state.pendingHandshake,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: previousOpen,
            lastEvaluatedAt: previousOpen,
            lastGreeting: nil
        )
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(opened, .characterReport(.settleFinished), clock: ManualEngineClock(at: fixture.instant("2026-09-08T09:00:00Z")), calendar: fixture.calendar, rng: &rng)
        #expect(!outcome.moments.contains { moment in
            if case .greeting = moment { return true }
            return false
        })
        #expect(outcome.newState.lastGreeting == nil)
    }
}
