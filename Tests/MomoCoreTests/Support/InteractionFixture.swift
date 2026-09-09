import Foundation
@testable import MomoCore

/// Shared fixtures for the TASK-016 interaction suites (response matrix,
/// satiety, repetition, play rounds, care): a configurable `EngineState`
/// builder plus send/report wrappers over `reduce`. Events default to a
/// zero-elapsed fold (`lastEvaluatedAt == the event instant`) so exact-value
/// pins carry NO fold dynamics — `TimeFoldTests` owns that arithmetic; the
/// tests that need a real fold say so with distinct instants.
struct InteractionFixture {

    let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    /// Gregorian calendar over the given zone — injected, deterministic (D20's
    /// pattern; the DST tests inject America/New_York).
    let calendar: Calendar

    init(timeZoneIdentifier: String = "UTC") {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        self.calendar = gregorian
    }

    func instant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func quest(_ id: QuestID) -> QuestProgress {
        QuestProgress(questID: id, progress: 0, completed: false)!
    }

    /// A ledger record with the given counters and bond-ledger fields
    /// (placeholder quest set — real generation is TASK-018's; the
    /// bond-ledger fields are TASK-017's, defaulted to a fresh day).
    func day(
        dayKey: String,
        feed: Int = 0,
        play: Int = 0,
        care: Int = 0,
        pat: Int = 0,
        helloAwarded: Bool = false,
        familiesUsed: Set<QuestFamily> = [],
        bondAwarded: Int = 0
    ) -> DayRecord {
        DayRecord(
            dayKey: dayKey,
            feedCount: feed,
            playCount: play,
            careCount: care,
            patCount: pat,
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            helloAwarded: helloAwarded,
            familiesUsed: familiesUsed,
            bondAwarded: bondAwarded,
            questGenEpoch: 0
        )!
    }

    /// A state over an explicit ledger (the multi-day cases). The bond-era
    /// presets (TASK-017) all default to fresh: bond 0, hello un-awarded, no
    /// families, guard at `.newFriends`.
    func state(
        mood: Double = 60,
        energy: Double = 80,
        bond: Int = 0,
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        lastFedAt: Instant? = nil,
        satietyPhase: SatietyPhase = .hungry,
        pendingHandshake: Handshake? = nil,
        highestCelebratedStage: BondStage = .newFriends,
        days: [DayRecord],
        lastEvaluatedAt: Instant
    ) -> EngineState {
        let pet = Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!
        return EngineState(
            pet: pet,
            state: PetState(
                mood: mood,
                energy: energy,
                bond: bond,
                wakefulness: wakefulness,
                activity: activity,
                lastFedAt: lastFedAt,
                satietyPhase: satietyPhase
            )!,
            days: days,
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: pendingHandshake,
            processedIntents: [],
            highestCelebratedStage: highestCelebratedStage,
            lastOpenedAt: lastEvaluatedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A state over a single-day ledger with the given counters (the common case).
    func state(
        dayKey: String,
        feed: Int = 0,
        play: Int = 0,
        care: Int = 0,
        pat: Int = 0,
        helloAwarded: Bool = false,
        familiesUsed: Set<QuestFamily> = [],
        bondAwarded: Int = 0,
        mood: Double = 60,
        energy: Double = 80,
        bond: Int = 0,
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        lastFedAt: Instant? = nil,
        satietyPhase: SatietyPhase = .hungry,
        pendingHandshake: Handshake? = nil,
        highestCelebratedStage: BondStage = .newFriends,
        lastEvaluatedAt: Instant
    ) -> EngineState {
        state(
            mood: mood,
            energy: energy,
            bond: bond,
            wakefulness: wakefulness,
            activity: activity,
            lastFedAt: lastFedAt,
            satietyPhase: satietyPhase,
            pendingHandshake: pendingHandshake,
            highestCelebratedStage: highestCelebratedStage,
            days: [day(
                dayKey: dayKey,
                feed: feed,
                play: play,
                care: care,
                pat: pat,
                helloAwarded: helloAwarded,
                familiesUsed: familiesUsed,
                bondAwarded: bondAwarded
            )],
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    func intent(
        _ kind: InteractionIntent.Kind,
        at timestamp: Instant,
        dayKey: String,
        source: InteractionIntent.Source = .iPhone,
        id: UUID = UUID()
    ) -> InteractionIntent {
        InteractionIntent(id: id, source: source, localDayKey: dayKey, timestamp: timestamp, kind: kind)
    }

    /// Sends one interaction through `reduce` at zero elapsed — the semantics
    /// see EXACTLY the fixture state. Pass `intentID` to pin the belt's
    /// recorded id when a test compares whole states across twin runs (the
    /// default mints a fresh UUID per call).
    func send(
        _ state: EngineState,
        _ kind: InteractionIntent.Kind,
        at timestamp: Instant,
        dayKey: String,
        source: InteractionIntent.Source = .iPhone,
        seed: UInt64 = 7,
        intentID: UUID = UUID()
    ) -> EngineOutcome {
        var rng = SeededGenerator(seed: seed)
        return reduce(
            state,
            .interaction(intent(kind, at: timestamp, dayKey: dayKey, source: source, id: intentID)),
            clock: ManualEngineClock(),
            calendar: calendar,
            rng: &rng
        )
    }

    /// Sends an `.evaluate` at the given instant (the identity fold when
    /// `at == lastEvaluatedAt`).
    func evaluate(_ state: EngineState, at instant: Instant) -> EngineOutcome {
        var rng = SeededGenerator(seed: 7)
        return reduce(
            state,
            .evaluate(now: instant),
            clock: ManualEngineClock(),
            calendar: calendar,
            rng: &rng
        )
    }

    /// Sends a character report whose fold target is `at` (the identity fold
    /// when `at == lastEvaluatedAt`).
    func report(_ state: EngineState, _ report: CharacterReport, at instant: Instant, seed: UInt64 = 7) -> EngineOutcome {
        var rng = SeededGenerator(seed: seed)
        return reduce(
            state,
            .characterReport(report),
            clock: ManualEngineClock(at: instant),
            calendar: calendar,
            rng: &rng
        )
    }
}
