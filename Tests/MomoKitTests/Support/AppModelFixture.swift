import Foundation
@testable import MomoKit
import MomoCore

/// Fixtures for the TASK-031 app-model suites — deterministic calendars,
/// instants, states, and intents over literal time only (the
/// `InteractionFixture`/`StoreFixture` discipline: nothing ambient, every
/// builder total over valid domain values). Time-zone-parametrized
/// calendars serve the boundary suites' UTC rows and the DST rows exactly
/// as the engine's own fold tests build theirs.
enum AppModelFixture {

    /// Fixed pet identity — deterministic bytes for the seed/token pins.
    static let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    /// Fixed handshake token (the settle report's matching token).
    static let handshakeToken = UUID(uuidString: "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D")!

    /// Fixed intent ids (distinct, stable bytes).
    static let intentID1 = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    static let intentID2 = UUID(uuidString: "22222222-3333-4444-8555-666666666666")!

    /// Fixed final pet identities for the onboarding-completion suites
    /// (TASK-032): the executor mints a fresh UUID at the real Enter tap —
    /// the tests inject fixed bytes instead, which is the purity contract's
    /// whole point (determinism testable with injected identity).
    static let onboardedPetID = UUID(uuidString: "D1D0CAFE-4B8A-4C0D-9C1D-3E6F8A2B4C01")!
    static let onboardedPetIDOther = UUID(uuidString: "D1D0CAFE-4B8A-4C0D-9C1D-3E6F8A2B4C02")!

    /// A fixed instant from an ISO-8601 UTC string.
    static func instant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// A Gregorian calendar over the named time zone (the engine fold
    /// tests' shape; UTC is the common case, America/New_York the DST one).
    static func calendar(in timeZoneIdentifier: String = "UTC") -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: timeZoneIdentifier)!
        return gregorian
    }

    /// An awake, mid-range pet over a one-day ledger for `dayKey` — the
    /// plan tests' base carrier. Defaults put the pet in the Energetic band
    /// with nothing pending; parameters vary what a test needs (bands for
    /// play/nap authorization, wakefulness for the boundary rows, a
    /// handshake for the report path).
    static func state(
        petID: UUID = AppModelFixture.petID,
        dayKey: String,
        lastEvaluatedAt: Instant,
        lastOpenedAt: Instant? = nil,
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        energy: Double = 80,
        mood: Double = 70,
        satietyPhase: SatietyPhase = .hungry,
        lastFedAt: Instant? = nil,
        pendingHandshake: Handshake? = nil
    ) -> EngineState {
        let open = lastOpenedAt ?? lastEvaluatedAt
        return EngineState(
            pet: Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!,
            state: PetState(
                mood: mood,
                energy: energy,
                bond: 10,
                wakefulness: wakefulness,
                activity: activity,
                lastFedAt: lastFedAt,
                satietyPhase: satietyPhase
            )!,
            days: [day(dayKey)],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: pendingHandshake,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: open,
            lastEvaluatedAt: lastEvaluatedAt,
            lastGreeting: nil
        )
    }

    /// The pre-onboarding carrier (TASK-032's completion input) — mirrors
    /// the executor's `freshDefaultState` field-for-field: flag false, the
    /// empty ledger, minimum bond, the product name carried, both stamps at
    /// the carrier's mint instant. Literal instants only — nothing ambient.
    static func freshCarrier(at mintedAt: Instant) -> EngineState {
        EngineState(
            pet: Pet(id: petID, name: "Momo", createdAt: mintedAt)!,
            state: PetState(
                mood: 70,
                energy: 80,
                bond: Thresholds.Bond.minimum,
                wakefulness: .awake,
                activity: nil,
                lastFedAt: nil,
                satietyPhase: .hungry
            )!,
            days: [],
            settings: SettingsState(onboardingComplete: false, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: mintedAt,
            lastEvaluatedAt: mintedAt,
            lastGreeting: nil
        )
    }

    /// A minimal valid record for `dayKey` (zero counters, placeholder
    /// three-quest set, no awards) — the ledger filler; its quests sit at
    /// zero progress so nothing completes unless a test drives it to.
    static func day(_ dayKey: String) -> DayRecord {
        DayRecord(
            dayKey: dayKey,
            feedCount: 0,
            playCount: 0,
            careCount: 0,
            patCount: 0,
            questSet: [
                QuestProgress(questID: .q1, progress: 0, completed: false)!,
                QuestProgress(questID: .q2, progress: 0, completed: false)!,
                QuestProgress(questID: .q6, progress: 0, completed: false)!,
            ],
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: 1
        )!
    }

    /// An iPhone intent over the given day/instant (D20's attributed day
    /// key derived by the caller — here, the fixture's caller).
    static func intent(
        id: UUID = AppModelFixture.intentID1,
        dayKey: String,
        timestamp: Instant,
        kind: InteractionIntent.Kind
    ) -> InteractionIntent {
        InteractionIntent(
            id: id,
            source: .iPhone,
            localDayKey: dayKey,
            timestamp: timestamp,
            kind: kind
        )
    }
}
