import Foundation
import Testing
@testable import MomoCore

/// Focused invariant tests for TASK-012 (AC-4): one named test per invariant
/// INV-1…11 (05-technical-architecture §3.2). Where the type system enforces,
/// the test proves invalid states are unrepresentable (failing initializers);
/// where enforcement belongs to the engine/store (EPIC-004/005), the test
/// pins the model-side representation and the disposition is documented in
/// the task file's per-invariant table.
@Suite("Domain invariants INV-1…11 (TASK-012)")
struct DomainInvariantsTests {

    // MARK: - Fixtures

    /// A PetState passing INV-2/INV-3, with per-field overrides for the test.
    private func petState(
        mood: Double = 60,
        energy: Double = 85,
        bond: Int = 0,
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        lastFedAt: Instant? = nil,
        satietyPhase: SatietyPhase = .hungry
    ) -> PetState? {
        PetState(
            mood: mood,
            energy: energy,
            bond: bond,
            wakefulness: wakefulness,
            activity: activity,
            lastFedAt: lastFedAt,
            satietyPhase: satietyPhase
        )
    }

    /// A DayRecord passing INV-4/INV-5 and the quest-set rules, with overrides.
    private func dayRecord(
        dayKey: String = "2026-09-08",
        feedCount: Int = 0,
        playCount: Int = 0,
        careCount: Int = 0,
        patCount: Int = 0,
        questSet: [QuestProgress]? = nil,
        helloAwarded: Bool = false,
        familiesUsed: Set<QuestFamily> = [],
        bondAwarded: Int = 0,
        questGenEpoch: Int = 1
    ) -> DayRecord? {
        DayRecord(
            dayKey: dayKey,
            feedCount: feedCount,
            playCount: playCount,
            careCount: careCount,
            patCount: patCount,
            questSet: questSet ?? [
                QuestProgress(questID: .q1, progress: 1, completed: true),
                QuestProgress(questID: .q2, progress: 0, completed: false),
                QuestProgress(questID: .q3, progress: 0, completed: false),
            ].compactMap { $0 },
            helloAwarded: helloAwarded,
            familiesUsed: familiesUsed,
            bondAwarded: bondAwarded,
            questGenEpoch: questGenEpoch
        )
    }

    // MARK: - INV-1 — pet name trimmed non-empty (FR-1, UX S2)

    @Test("INV-1: whitespace-only names are unrepresentable; the stored name is trimmed")
    func inv1PetName() {
        #expect(Pet(id: UUID(), name: "", createdAt: .now) == nil)
        #expect(Pet(id: UUID(), name: "   ", createdAt: .now) == nil)
        #expect(Pet(id: UUID(), name: "\n\t ", createdAt: .now) == nil)
        let pet = Pet(id: UUID(), name: "  Momo  ", createdAt: .now)
        #expect(pet?.name == "Momo")
    }

    // MARK: - INV-2 — mood, energy ∈ 0...100 (PRD §3.1–3.2)

    @Test("INV-2: mood outside 0...100 (including NaN) is unrepresentable")
    func inv2MoodRange() {
        #expect(petState(mood: -0.5) == nil)
        #expect(petState(mood: 100.5) == nil)
        #expect(petState(mood: .nan) == nil)
        #expect(petState(mood: 0) != nil)
        #expect(petState(mood: 100) != nil)
    }

    @Test("INV-2: energy outside 0...100 (including NaN) is unrepresentable")
    func inv2EnergyRange() {
        #expect(petState(energy: -0.5) == nil)
        #expect(petState(energy: 100.5) == nil)
        #expect(petState(energy: .nan) == nil)
        #expect(petState(energy: 0) != nil)
        #expect(petState(energy: 100) != nil)
    }

    // MARK: - INV-3 — bond ∈ 0...1000 (FR-10 AC-2, D3)

    @Test("INV-3: bond outside 0...1000 is unrepresentable at the type boundary")
    func inv3BondRange() {
        #expect(petState(bond: -1) == nil)
        #expect(petState(bond: 1001) == nil)
        #expect(petState(bond: 0) != nil)
        #expect(petState(bond: 1000) != nil)
        // Monotonic non-decrease across ALL mutations (sync, replay, erase)
        // has no type-level hook: values are immutable, so the engine/store
        // produce new states — that contract is pinned by EPIC-004/005 tests.
    }

    // MARK: - INV-4 — day counters ≥ 0 (FR-6 AC-3)

    @Test("INV-4: negative day counters are unrepresentable")
    func inv4DayCounters() {
        #expect(dayRecord(feedCount: -1) == nil)
        #expect(dayRecord(playCount: -1) == nil)
        #expect(dayRecord(careCount: -1) == nil)
        #expect(dayRecord(patCount: -1) == nil)
        #expect(dayRecord() != nil) // all-zero record is valid
    }

    // MARK: - INV-5 — bondAwarded ∈ 0...20 daily cap (PRD §3.3, FR-10 AC-1)

    @Test("INV-5: the stored daily bond total can never leave 0...20")
    func inv5DailyCap() {
        #expect(dayRecord(bondAwarded: -1) == nil)
        #expect(dayRecord(bondAwarded: 21) == nil)
        #expect(dayRecord(bondAwarded: 0) != nil)
        #expect(dayRecord(bondAwarded: 20) != nil)
        // The clamp-at-award arithmetic (§4.6) is engine-owned (EPIC-004);
        // this type caps the stored total.
    }

    // MARK: - INV-6 — quest progress ≤ target; completed ⇒ target met (FR-16)

    @Test("INV-6: progress beyond the catalog target is unrepresentable")
    func inv6ProgressBounds() {
        // Q2's target is 1 (Feed ×1); Q3's is 2 (Feed ×2).
        #expect(QuestProgress(questID: .q2, progress: -1, completed: false) == nil)
        #expect(QuestProgress(questID: .q2, progress: 2, completed: false) == nil)
        #expect(QuestProgress(questID: .q2, progress: 1, completed: false) != nil)
        #expect(QuestProgress(questID: .q3, progress: 2, completed: true) != nil)
    }

    @Test("INV-6: completed without the target met is unrepresentable")
    func inv6CompletedImpliesTargetMet() {
        #expect(QuestProgress(questID: .q3, progress: 1, completed: true) == nil)
        #expect(QuestProgress(questID: .q1, progress: 0, completed: true) == nil)
        // In-flight progress below target is valid — INV-6 constrains the
        // completed direction only (completion reversal is engine/store, TR5).
        #expect(QuestProgress(questID: .q3, progress: 1, completed: false) != nil)
    }

    @Test("INV-6: the exactly-3 quest set with no duplicates is unrepresentable to violate")
    func inv6QuestSetShape() {
        // FR-14/15 (05 §3.1: "exactly 3"); PRD §5.3: no duplicate quests in a set.
        #expect(dayRecord(questSet: []) == nil)
        #expect(dayRecord(questSet: [
            QuestProgress(questID: .q1, progress: 1, completed: true),
            QuestProgress(questID: .q2, progress: 0, completed: false),
        ].compactMap { $0 }) == nil)
        let duplicate = [
            QuestProgress(questID: .q2, progress: 0, completed: false),
            QuestProgress(questID: .q2, progress: 1, completed: false),
            QuestProgress(questID: .q3, progress: 0, completed: false),
        ].compactMap { $0 }
        #expect(dayRecord(questSet: duplicate) == nil)
        #expect(dayRecord() != nil)
    }

    // MARK: - INV-7 — hello at most once per dayKey, device-agnostic (UX-6)

    @Test("INV-7: the hello award is a single flag per day record, not a counter")
    func inv7HelloOncePerDay() {
        let awarded = dayRecord(helloAwarded: true)
        #expect(awarded != nil)
        // Value semantics: the award state is exactly one Bool — the type
        // cannot represent "two hellos". One record per dayKey (never
        // window-gated, either device) is the store's uniqueness contract
        // (EPIC-005); the never-window-gated attribution is engine-owned.
        #expect(awarded == dayRecord(dayKey: "2026-09-08", helloAwarded: true))
        #expect(awarded != dayRecord(dayKey: "2026-09-08", helloAwarded: false))
    }

    // MARK: - INV-8 — wakefulness states are the closed §4.7 set (04 §4.1 rule 4)

    @Test("INV-8: the wakefulness state set is exactly the §4.7 diagram's four states")
    func inv8WakefulnessCaseSet() {
        func name(of state: Wakefulness) -> String {
            // Exhaustive switch: adding or removing a case breaks compilation,
            // pinning the closed state set at the type boundary.
            switch state {
            case .awake: return "awake"
            case .settling: return "settling"
            case .asleep: return "asleep"
            case .waking: return "waking"
            }
        }
        #expect([name(of: .awake), name(of: .settling), name(of: .asleep), name(of: .waking)]
            == ["awake", "settling", "asleep", "waking"])
        // Only-legal-transitions (the §4.7 diagram itself) is the engine's
        // pure reduction — EPIC-004 pins it (05 §10.3).
    }

    // MARK: - INV-9 — UTC instants stored; dayKey derived, never a date type

    @Test("INV-9: timestamps are timezone-free Instants; day keys exist only as derived strings")
    func inv9UtcInstantsAndDerivedKeys() {
        // Instant = Date (absolute, timezone-free); `localDayKey`/`dayKey`
        // are plain derived strings — no timezone-bearing date type exists on
        // any model type. The derivation itself is pinned by DayKeyTests
        // (boundary, timezone variation, DST).
        let timestamp = Date(timeIntervalSinceReferenceDate: 0) // 2001-01-01T00:00:00Z
        let intent = InteractionIntent(
            id: UUID(),
            source: .iPhone,
            localDayKey: "2001-01-01",
            timestamp: timestamp,
            kind: .feed
        )
        #expect(intent.timestamp == timestamp)
        #expect(intent.localDayKey == "2001-01-01")
    }

    // MARK: - INV-10 — intent effects exactly once (FR-18 AC-1; §6.4)

    @Test("INV-10: every intent carries a non-optional UUID idempotency key")
    func inv10IntentIdempotencyKey() {
        let shared = UUID()
        let first = InteractionIntent(
            id: shared, source: .iPhone, localDayKey: "2026-09-08",
            timestamp: .now, kind: .pat(gesture: .tap, zone: nil) // the Watch's form (FR-17)
        )
        let duplicate = InteractionIntent(
            id: shared, source: .watch, localDayKey: "2026-09-08",
            timestamp: .now, kind: .pat(gesture: .tap, zone: nil)
        )
        let distinct = InteractionIntent(
            id: UUID(), source: .iPhone, localDayKey: "2026-09-08",
            timestamp: .now, kind: .pat(gesture: .tap, zone: nil)
        )
        // Same key = the same logical event (a replayed delivery the engine
        // must no-op, §6.4); a different key is a distinct event even when
        // everything else matches. The exactly-once machinery consuming the
        // key is EPIC-004/005.
        #expect(first.id == duplicate.id)
        #expect(first.id != distinct.id)
    }

    // MARK: - INV-11 — no composed user-facing strings (FR-12; §4.9)

    @Test("INV-11: character-facing outputs are enums and key slots only")
    func inv11KeysNotProse() {
        // CharacterDisplayState's field inventory carries no String at all —
        // bands, stage, wakefulness, activity, hint, and the moment request
        // are enums (reviewer-verifiable inventory; the engine composing no
        // prose is EPIC-004's contract, and the catalog side is the standing
        // banned-vocabulary scan).
        let display = CharacterDisplayState(
            moodBand: makeMoodBand(80),
            energyBand: makeEnergyBand(10),
            bondStage: makeBondStage(400),
            wakefulness: .awake,
            activity: .playing,
            satietyHint: .recentlyFed,
            momentRequest: .bondStageReached(.bestFriends)
        )
        #expect(display.moodBand == .joyful)
        #expect(display.energyBand == .exhausted)
        #expect(display.bondStage == .bestFriends)
        #expect(display.momentRequest == .bondStageReached(.bestFriends))

        // ResponsePlan: the only strings are optional key slots — nil lineKey
        // means the animation speaks alone (04 §9.2).
        let silent = ResponsePlan(reaction: ReactionID(rawValue: "react.tap.head"), lineKey: nil, haptic: nil)
        #expect(silent.lineKey == nil)
        #expect(silent.haptic == nil)
        #expect(silent.reaction == ReactionID(rawValue: "react.tap.head"))
    }
}
