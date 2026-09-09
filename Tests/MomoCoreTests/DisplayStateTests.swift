import Testing
import Foundation
@testable import MomoCore

/// The §4.11 read-model derivations (TASK-019 Requirements 1–2; Required
/// Test 1): golden `makeDisplayState`/`makeCharacterDisplayState` vectors —
/// field-for-field expectations restating the OBS-1 keys, the `Bands`
/// derivations' outputs at corner inputs, the cascade's answer over TODAY's
/// record (absent record ⇒ cascade over the empty set ⇒ `.allDone`), the
/// greeting stamp's projection into both models, and an injected-calendar
/// proof at a DST-adjacent instant. Pure: the only time input is the
/// caller's `now` + calendar.
@Suite("Display read-models — §4.11 golden vectors (TASK-019)")
struct DisplayStateTests {

    private let fixture = InteractionFixture()
    private let day = "2026-09-08"

    // MARK: makeDisplayState — the golden vector

    @Test("the golden display vector: every §4.11 field resolves as the spec text reads")
    func goldenDisplayVector() {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let state = fixture.state(dayKey: day, mood: 60, energy: 80, bond: 0, lastEvaluatedAt: now)
        let display = makeDisplayState(state, at: now, calendar: fixture.calendar)
        #expect(display == DisplayState(
            petName: "Momo",
            moodWordKey: "momo.line.vocab.mood.content",        // mood 60 → content
            energyPhraseKey: "momo.line.vocab.energy.energetic", // energy 80 → energetic
            bondStage: .newFriends,                              // bond 0
            bondDescriptorKey: "momo.line.vocab.stage.newFriends",
            questLine: .wish(.q1),                               // hour 9 < Q1's 10:00 close, Q1 incomplete
            wakefulness: .awake,
            greeting: nil                                        // no greeting stamp yet
        ))
    }

    @Test("an absent day-record cascades over the empty set — allDone")
    func absentDayRecordCascadesToAllDone() {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let state = fixture.state(dayKey: "2026-09-07", lastEvaluatedAt: now) // only YESTERDAY's record
        let display = makeDisplayState(state, at: now, calendar: fixture.calendar)
        #expect(display.questLine == .allDone)
    }

    @Test("the night-hour cascade surfaces the evening wish; a complete set is allDone at the same hour")
    func nightHourCascade() {
        let now = fixture.instant("2026-09-08T21:00:00Z") // hour 21, inside Q6's window
        let pending = fixture.state(dayKey: day, lastEvaluatedAt: now) // the placeholder set carries Q6, incomplete
        #expect(makeDisplayState(pending, at: now, calendar: fixture.calendar).questLine == .wish(.q6))
        // A ledger whose set is FULLY complete (the placeholder trio, done):
        // every cascade rule falls through to allDone at the same evening
        // hour.
        let completed = [.q1, .q2, .q6].map { QuestProgress(questID: $0, progress: QuestCatalog.entry(for: $0).target, completed: true)! }
        let dayRecord = DayRecord(
            dayKey: day, feedCount: 0, playCount: 0, careCount: 1, patCount: 0,
            questSet: completed, helloAwarded: false, familiesUsed: [.care],
            bondAwarded: 0, questGenEpoch: 0
        )!
        let finished = fixture.state(days: [dayRecord], lastEvaluatedAt: now)
        #expect(makeDisplayState(finished, at: now, calendar: fixture.calendar).questLine == .allDone)
    }

    @Test("the greeting stamp projects into the display's greeting field; no stamp projects nil")
    func greetingStampProjects() {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let unstamped = fixture.state(dayKey: day, lastEvaluatedAt: now)
        #expect(makeDisplayState(unstamped, at: now, calendar: fixture.calendar).greeting == nil)
        let stamped = unstamped.with(lastGreeting: GreetingStamp(kind: .missedYou, at: now))
        #expect(makeDisplayState(stamped, at: now, calendar: fixture.calendar).greeting == .missedYou)
    }

    /// The derivation consumes the INJECTED calendar: at 2026-03-08T07:30Z
    /// (moments after America/New_York's spring-forward) the local hour is
    /// 3 — INSIDE Q6's early-morning tail — not the UTC hour 7, which would
    /// cascade to the morning anchor instead. Also proves the day record is
    /// matched by the LOCAL dayKey.
    @Test("a DST-adjacent instant derives its hour through the injected calendar")
    func dstAdjacentInstantUsesInjectedCalendar() {
        let eastern = InteractionFixture(timeZoneIdentifier: "America/New_York")
        let now = fixture.instant("2026-03-08T07:30:00Z") // 03:30 EDT locally (DST began 07:00Z)
        let state = fixture.state(dayKey: "2026-03-08", lastEvaluatedAt: now)
        let display = makeDisplayState(state, at: now, calendar: eastern.calendar)
        #expect(display.questLine == .wish(.q6),
                "the local hour is 3 (Q6's tail), not the UTC hour 7 (Q1's window) — the calendar must be the injected one")
        #expect(makeDisplayState(state, at: now, calendar: fixture.calendar).questLine == .wish(.q1),
                "the same instant under UTC cascades to the morning anchor — the derivation is calendar-relative")
    }

    // MARK: makeCharacterDisplayState — the golden vector + corners

    @Test("the golden character vector: bands, stage, machine fields, satiety hint, moment request")
    func goldenCharacterVector() {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let state = fixture.state(
            dayKey: day,
            mood: 60, energy: 80, bond: 0,
            activity: nil,
            satietyPhase: .hungry,
            lastEvaluatedAt: now
        )
        let model = makeCharacterDisplayState(state)
        #expect(model == CharacterDisplayState(
            moodBand: .content,
            energyBand: .energetic,
            bondStage: .newFriends,
            wakefulness: .awake,
            activity: nil,
            satietyHint: .hungry,
            momentRequest: nil
        ))
    }

    /// Every band × stage × wakefulness corner at least once — inputs and
    /// expectations are raw values (the corners are PRD-table content, so a
    /// drifted constant cannot hide behind them; `BandDerivationTests` owns
    /// the exhaustive sweeps).
    @Test("the corner matrix: band × stage × wakefulness corners project verbatim", arguments: [
        (mood: 75.0, energy: 75.0, bond: 150, wakefulness: Wakefulness.awake,
         moodBand: MoodBand.joyful, energyBand: EnergyBand.energetic, stage: BondStage.gettingClose),
        (mood: 20.0, energy: 20.0, bond: 400, wakefulness: Wakefulness.settling,
         moodBand: MoodBand.wistful, energyBand: EnergyBand.drowsy, stage: BondStage.bestFriends),
        (mood: 0.0, energy: 0.0, bond: 750, wakefulness: Wakefulness.asleep,
         moodBand: MoodBand.low, energyBand: EnergyBand.exhausted, stage: BondStage.soulCompanions),
        (mood: 45.0, energy: 45.0, bond: 149, wakefulness: Wakefulness.waking,
         moodBand: MoodBand.content, energyBand: EnergyBand.relaxed, stage: BondStage.newFriends),
    ])
    func cornerMatrix(
        mood: Double, energy: Double, bond: Int, wakefulness: Wakefulness,
        moodBand: MoodBand, energyBand: EnergyBand, stage: BondStage
    ) {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let state = fixture.state(
            dayKey: day,
            mood: mood, energy: energy, bond: bond,
            wakefulness: wakefulness,
            lastEvaluatedAt: now
        )
        let model = makeCharacterDisplayState(state)
        #expect(model.moodBand == moodBand)
        #expect(model.energyBand == energyBand)
        #expect(model.bondStage == stage)
        #expect(model.wakefulness == wakefulness)
        // The satiety hint stays OPTIONAL, carrying the phase verbatim (the
        // 04 §9.2 shape; Requirement 2's recorded reading).
        #expect(model.satietyHint == SatietyHint.hungry)
    }

    @Test("the moment request is the stamped greeting; an activity and a fed phase ride their fields")
    func stampedCharacterVector() {
        let now = fixture.instant("2026-09-08T09:00:00Z")
        let state = fixture.state(
            dayKey: day,
            activity: .playing,
            satietyPhase: .recentlyFed,
            lastEvaluatedAt: now
        ).with(lastGreeting: GreetingStamp(kind: .nightGlance, at: now))
        let model = makeCharacterDisplayState(state)
        #expect(model.activity == .playing)
        #expect(model.satietyHint == .recentlyFed)
        #expect(model.momentRequest == .greeting(.nightGlance))
    }
}
