import Foundation
@testable import MomoCore

/// A test clock that advances on every read: the store holds its own copy of
/// any value-semantic clock, so `ManualEngineClock` cannot move a store's
/// `savedAt` between saves. `TickingClock` is a reference type precisely so a
/// store's repeated `clock.now()` reads return distinct, strictly increasing
/// instants — what the byte-stability and concurrency suites need.
final class TickingClock: EngineClock, @unchecked Sendable {

    private let lock = NSLock()
    private var current: Instant
    private let step: TimeInterval

    init(at start: Instant, step: TimeInterval = 1) {
        self.current = start
        self.step = step
    }

    func now() -> Instant {
        lock.lock()
        defer {
            current = current.addingTimeInterval(step)
            lock.unlock()
        }
        return current
    }
}

/// Shared fixtures for the TASK-021 SnapshotStore suites: a fully-populated
/// persisted `EngineState` (every field non-default), per-case state builders
/// for the roundtrip matrix, and the compile-pinned case sets of every
/// persisted enum (TASK-013's discipline: a NEW case fails the build in the
/// `pin…` switches below, forcing the roundtrip matrix to grow with it).
///
/// All time is literal (`instant(_:)` over fixed ISO strings) — nothing here
/// touches an ambient clock, mirroring the `InteractionFixture` discipline.
struct StoreFixture {

    /// Fixed pet identity — deterministic bytes for the checksum pins.
    let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    /// Fixed handshake token and processed-intent ids (same determinism).
    let handshakeToken = UUID(uuidString: "A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D")!
    let intentID1 = UUID(uuidString: "11111111-2222-4333-8444-555555555555")!
    let intentID2 = UUID(uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE")!

    func instant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// A ledger record; `DayRecord`'s failable init enforces exactly three
    /// quests per record (FR-14/15), so callers pass exactly three.
    func day(
        dayKey: String,
        feed: Int,
        play: Int,
        care: Int,
        pat: Int,
        questSet: [QuestProgress],
        helloAwarded: Bool,
        familiesUsed: Set<QuestFamily>,
        bondAwarded: Int,
        questGenEpoch: Int = 1
    ) -> DayRecord {
        DayRecord(
            dayKey: dayKey,
            feedCount: feed,
            playCount: play,
            careCount: care,
            patCount: pat,
            questSet: questSet,
            helloAwarded: helloAwarded,
            familiesUsed: familiesUsed,
            bondAwarded: bondAwarded,
            questGenEpoch: questGenEpoch
        )!
    }

    func quest(_ id: QuestID, progress: Int, completed: Bool) -> QuestProgress {
        QuestProgress(questID: id, progress: progress, completed: completed)!
    }

    /// The fully-populated persisted state (Requirement 8's roundtrip anchor):
    /// every `EngineState` field non-default, and every case of every
    /// persisted enum reachable somewhere in the value —
    ///
    /// - Wakefulness `.waking`, Activity `.eating`, SatietyPhase `.recentlyFed`
    ///   (in `state`)
    /// - HandshakeKind `.settle` (in `pendingHandshake`), GreetingKind
    ///   `.missedYou` (in `lastGreeting`), BondStage `.gettingClose`
    ///   (in `highestCelebratedStage`)
    /// - all seven `QuestID`s across the three records' quest sets, and all
    ///   five `QuestFamily`s in record three's `familiesUsed`
    /// - populated ledger, non-empty processed-intent belt, distinct open /
    ///   evaluate / feed / greeting stamps.
    func populatedState() -> EngineState {
        EngineState(
            pet: Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!,
            state: PetState(
                mood: 72.5,
                energy: 41.25,
                bond: 456,
                wakefulness: .waking,
                activity: .eating,
                lastFedAt: instant("2026-03-03T08:30:00Z"),
                satietyPhase: .recentlyFed
            )!,
            days: [
                day(
                    dayKey: "2026-03-01",
                    feed: 1, play: 0, care: 0, pat: 2,
                    questSet: [quest(.q1, progress: 1, completed: true),
                               quest(.q2, progress: 1, completed: true),
                               quest(.q3, progress: 0, completed: false)],
                    helloAwarded: true,
                    familiesUsed: [.greet, .feed],
                    bondAwarded: 12
                ),
                day(
                    dayKey: "2026-03-02",
                    feed: 2, play: 2, care: 1, pat: 3,
                    questSet: [quest(.q4, progress: 2, completed: true),
                               quest(.q5, progress: 1, completed: false),
                               quest(.q6, progress: 1, completed: true)],
                    helloAwarded: true,
                    familiesUsed: [.feed, .play, .care],
                    bondAwarded: 20
                ),
                day(
                    dayKey: "2026-03-03",
                    feed: 0, play: 1, care: 1, pat: 1,
                    questSet: [quest(.q7, progress: 3, completed: true),
                               quest(.q1, progress: 0, completed: false),
                               quest(.q2, progress: 0, completed: false)],
                    helloAwarded: false,
                    familiesUsed: [.greet, .feed, .play, .care, .pet],
                    bondAwarded: 8
                ),
            ],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: false),
            pendingHandshake: Handshake(kind: .settle, token: handshakeToken),
            processedIntents: [intentID1, intentID2],
            highestCelebratedStage: .gettingClose,
            lastOpenedAt: instant("2026-03-03T09:00:00Z"),
            lastEvaluatedAt: instant("2026-03-03T09:00:01Z"),
            lastGreeting: GreetingStamp(kind: .missedYou, at: instant("2026-03-03T09:00:00Z"))
        )
    }

    /// A state over the populated ledger with one PetState dimension varied —
    /// the per-case roundtrip matrix's builder (every argument keeps the rest
    /// of the state non-default, so each matrix row still roundtrips a rich
    /// value, not a skeleton).
    func state(
        wakefulness: Wakefulness = .waking,
        activity: Activity? = .eating,
        satietyPhase: SatietyPhase = .recentlyFed,
        handshakeKind: HandshakeKind = .settle,
        greetingKind: GreetingKind = .missedYou,
        celebratedStage: BondStage = .gettingClose
    ) -> EngineState {
        var populated = populatedState()
        // Value-semantics rebuilds: `let`-immutable types, so a fresh value
        // is constructed per variation (no mutation anywhere).
        let variedPetState = PetState(
            mood: populated.state.mood,
            energy: populated.state.energy,
            bond: populated.state.bond,
            wakefulness: wakefulness,
            activity: activity,
            lastFedAt: populated.state.lastFedAt,
            satietyPhase: satietyPhase
        )!
        populated = EngineState(
            pet: populated.pet,
            state: variedPetState,
            days: populated.days,
            settings: populated.settings,
            pendingHandshake: Handshake(kind: handshakeKind, token: handshakeToken),
            processedIntents: populated.processedIntents,
            highestCelebratedStage: celebratedStage,
            lastOpenedAt: populated.lastOpenedAt,
            lastEvaluatedAt: populated.lastEvaluatedAt,
            lastGreeting: GreetingStamp(kind: greetingKind, at: populated.lastGreeting!.at)
        )
        return populated
    }

    /// A state whose bond is `bond` — the content-identifiable marker the
    /// chain/demotion/stress pins read out of loaded generations.
    func state(bond: Int) -> EngineState {
        EngineState(
            pet: Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!,
            state: PetState(
                mood: 60, energy: 80, bond: bond,
                wakefulness: .awake, activity: nil, lastFedAt: nil, satietyPhase: .hungry
            )!,
            days: [day(
                dayKey: "2026-03-03",
                feed: 0, play: 0, care: 0, pat: 0,
                questSet: [quest(.q1, progress: 0, completed: false),
                           quest(.q2, progress: 0, completed: false),
                           quest(.q6, progress: 0, completed: false)],
                helloAwarded: false,
                familiesUsed: [],
                bondAwarded: 0
            )],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: instant("2026-03-03T09:00:00Z"),
            lastEvaluatedAt: instant("2026-03-03T09:00:00Z"),
            lastGreeting: nil
        )
    }

    /// A state carrying exactly the given day ledger and intent belt over an
    /// otherwise minimal pet — the retention tests' carrier (TASK-022). The
    /// ledger is taken AS GIVEN (any order, any size, duplicates allowed at
    /// the caller's request): retention fixtures construct their adversarial
    /// inputs explicitly and assert on what the prune keeps.
    func state(days: [DayRecord], processedIntents: [UUID]) -> EngineState {
        EngineState(
            pet: Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!,
            state: PetState(
                mood: 60, energy: 80, bond: 10,
                wakefulness: .awake, activity: nil, lastFedAt: nil, satietyPhase: .hungry
            )!,
            days: days,
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: processedIntents,
            highestCelebratedStage: .newFriends,
            lastOpenedAt: instant("2026-03-03T09:00:00Z"),
            lastEvaluatedAt: instant("2026-03-03T09:00:00Z"),
            lastGreeting: nil
        )
    }

    /// A minimal valid record for `dayKey` (zero counters, placeholder quest
    /// set, no awards) — the bulk filler for oversized retention fixtures.
    func minimalDay(_ dayKey: String) -> DayRecord {
        day(
            dayKey: dayKey,
            feed: 0, play: 0, care: 0, pat: 0,
            questSet: [quest(.q1, progress: 0, completed: false),
                       quest(.q2, progress: 0, completed: false),
                       quest(.q6, progress: 0, completed: false)],
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0
        )
    }

    /// `count` zero-padded dayKeys on consecutive UTC days starting at the
    /// `startingISO` instant — derived through MomoCore's `DayKey.make` with
    /// an injected UTC calendar (the sanctioned derivation; no ambient
    /// anything), so fixture keys are guaranteed to be in the production
    /// format the retention function's lexicographic rule relies on.
    func consecutiveDayKeys(startingISO: String, count: Int) -> [String] {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        let start = instant(startingISO)
        return (0..<count).map { offset in
            DayKey.make(from: start.addingTimeInterval(Double(offset) * 86_400), calendar: utc)
        }
    }

    /// Deterministic distinct intent id `n` — stable bytes for the belt pins.
    func intentID(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012X", n))!
    }

    // MARK: - Persisted enum case sets (compile-pinned; a new case is a
    // BUILD ERROR here, so the matrix below can never silently miss one)

    static let allWakefulness: [Wakefulness] = [.awake, .settling, .asleep, .waking]
    static func pin(_ c: Wakefulness) -> String {
        switch c {
        case .awake: "awake"
        case .settling: "settling"
        case .asleep: "asleep"
        case .waking: "waking"
        }
    }

    /// The `nil` activity is part of the persisted domain (no active
    /// activity) and gets an explicit matrix row alongside the three cases.
    static let allActivity: [Activity?] = [nil, .eating, .playing, .napping]
    static func pin(_ c: Activity?) -> String {
        switch c {
        case nil: "nil"
        case .eating: "eating"
        case .playing: "playing"
        case .napping: "napping"
        }
    }

    static let allSatietyPhase: [SatietyPhase] = [.full, .recentlyFed, .hungry]
    static func pin(_ c: SatietyPhase) -> String {
        switch c {
        case .full: "full"
        case .recentlyFed: "recentlyFed"
        case .hungry: "hungry"
        }
    }

    static let allHandshakeKind: [HandshakeKind] = [.settle, .wake, .play]
    static func pin(_ c: HandshakeKind) -> String {
        switch c {
        case .settle: "settle"
        case .wake: "wake"
        case .play: "play"
        }
    }

    static let allGreetingKind: [GreetingKind] = [.freshMorning, .welcomeBack, .missedYou, .nightGlance]
    static func pin(_ c: GreetingKind) -> String {
        switch c {
        case .freshMorning: "freshMorning"
        case .welcomeBack: "welcomeBack"
        case .missedYou: "missedYou"
        case .nightGlance: "nightGlance"
        }
    }

    static let allBondStage: [BondStage] = [.newFriends, .gettingClose, .bestFriends, .soulCompanions]
    static func pin(_ c: BondStage) -> String {
        switch c {
        case .newFriends: "newFriends"
        case .gettingClose: "gettingClose"
        case .bestFriends: "bestFriends"
        case .soulCompanions: "soulCompanions"
        }
    }

    static let allQuestID: [QuestID] = [.q1, .q2, .q3, .q4, .q5, .q6, .q7]
    static func pin(_ c: QuestID) -> String {
        switch c {
        case .q1: "q1"
        case .q2: "q2"
        case .q3: "q3"
        case .q4: "q4"
        case .q5: "q5"
        case .q6: "q6"
        case .q7: "q7"
        }
    }

    static let allQuestFamily: [QuestFamily] = [.greet, .feed, .play, .care, .pet]
    static func pin(_ c: QuestFamily) -> String {
        switch c {
        case .greet: "greet"
        case .feed: "feed"
        case .play: "play"
        case .care: "care"
        case .pet: "pet"
        }
    }
}
