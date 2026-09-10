import Testing
import Foundation
@testable import MomoKit
import MomoCore

// MARK: - HomeReadModelTests — the Home read-model pins (TASK-033 Required
// Tests 1–3; UX §5.1, §5.4, §5.5)

/// The Home composition's headless pins: the status row's key derivations
/// (all bands), the contextual line's greeting-over-ambient priority and its
/// day-stable slot draws, the quest rows' catalog order / soft marks /
/// window flags, and the action row's pill gates. All time is literal over
/// the injected UTC calendar — the `AppModelFixture` discipline.
@Suite
struct HomeReadModelTests {

    private let calendar = AppModelFixture.calendar()

    // MARK: Local builder (the fixture's shape + the greeting stamp and
    // band inputs, which the plan fixtures never need)

    private func state(
        lastGreeting: GreetingStamp? = nil,
        days: [DayRecord] = [AppModelFixture.day("2026-09-10")],
        mood: Double = 70,
        energy: Double = 80,
        bond: Int = 10,
        wakefulness: Wakefulness = .awake
    ) -> EngineState {
        EngineState(
            pet: Pet(id: AppModelFixture.petID, name: "Momo", createdAt: AppModelFixture.instant("2026-01-01T00:00:00Z"))!,
            state: PetState(
                mood: mood,
                energy: energy,
                bond: bond,
                wakefulness: wakefulness,
                activity: nil,
                lastFedAt: nil,
                satietyPhase: .hungry
            )!,
            days: days,
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: AppModelFixture.instant("2026-09-10T09:00:00Z"),
            lastEvaluatedAt: AppModelFixture.instant("2026-09-10T09:00:00Z"),
            lastGreeting: lastGreeting
        )
    }

    private func makeModel(
        _ built: EngineState? = nil,
        at iso: String = "2026-09-10T09:00:00Z"
    ) -> HomeReadModel {
        makeHomeReadModel(built ?? state(), at: AppModelFixture.instant(iso), calendar: calendar)
    }

    // MARK: Required Test 1 — the status row's keys

    /// The fresh-default pet (mood 70 → content, energy 80 → energetic, bond
    /// 10 → newFriends) renders the OBS-1 vocabulary keys plus the status
    /// classes' keys, and carries the bands and wakefulness verbatim.
    @Test("status row: fresh default derives the catalog keys")
    func statusRowFreshDefaultKeys() {
        let model = makeModel()
        #expect(model.petName == "Momo")
        #expect(model.moodBand == .content)
        #expect(model.energyBand == .energetic)
        #expect(model.bondStage == .newFriends)
        #expect(model.wakefulness == .awake)
        #expect(model.moodWordKey == "momo.line.vocab.mood.content")
        #expect(model.energyWordKey == "momo.line.status.energy.energetic")
        #expect(model.energyPhraseKey == "momo.line.vocab.energy.energetic")
        #expect(model.stageNameKey == "momo.line.status.stage.newFriends")
        #expect(model.bondDescriptorKey == "momo.line.vocab.stage.newFriends")
    }

    /// The full band sweep: every mood/energy band and every bond stage maps
    /// to its own word/phrase/name/descriptor key (the lookups are total —
    /// no band renders another band's entry).
    @Test("status row: all bands map to their own keys")
    func statusRowAllBands() {
        // Interior values per band (nowhere near a cut-off).
        #expect(makeModel(state(mood: 90, energy: 90, bond: 50)).moodWordKey == "momo.line.vocab.mood.joyful")
        #expect(makeModel(state(mood: 70, energy: 70, bond: 50)).moodWordKey == "momo.line.vocab.mood.content")
        #expect(makeModel(state(mood: 30, energy: 30, bond: 50)).moodWordKey == "momo.line.vocab.mood.wistful")
        #expect(makeModel(state(mood: 10, energy: 10, bond: 50)).moodWordKey == "momo.line.vocab.mood.low")
        #expect(makeModel(state(energy: 90)).energyWordKey == "momo.line.status.energy.energetic")
        #expect(makeModel(state(energy: 70)).energyWordKey == "momo.line.status.energy.relaxed")
        #expect(makeModel(state(energy: 30)).energyWordKey == "momo.line.status.energy.drowsy")
        #expect(makeModel(state(energy: 10)).energyWordKey == "momo.line.status.energy.exhausted")
        #expect(makeModel(state(energy: 90)).energyPhraseKey == "momo.line.vocab.energy.energetic")
        #expect(makeModel(state(energy: 30)).energyPhraseKey == "momo.line.vocab.energy.drowsy")
        #expect(makeModel(state(energy: 10)).energyPhraseKey == "momo.line.vocab.energy.exhausted")
        #expect(makeModel(state(bond: 50)).stageNameKey == "momo.line.status.stage.newFriends")
        #expect(makeModel(state(bond: 200)).stageNameKey == "momo.line.status.stage.gettingClose")
        #expect(makeModel(state(bond: 500)).stageNameKey == "momo.line.status.stage.bestFriends")
        #expect(makeModel(state(bond: 900)).stageNameKey == "momo.line.status.stage.soulCompanions")
        #expect(makeModel(state(bond: 500)).bondDescriptorKey == "momo.line.vocab.stage.bestFriends")
        #expect(makeModel(state(bond: 900)).bondDescriptorKey == "momo.line.vocab.stage.soulCompanions")
    }

    // MARK: Required Test 2 — the contextual line

    /// UX-12's priority at the greeting tier: the three greeting kinds with
    /// catalog pools render their own slot lines; nightGlance (no pool yet —
    /// TASK-034/035's canvas/moment surface) and a nil stamp fall through to
    /// the ambient slot draw.
    @Test("contextual line: greeting kinds route their pool, others fall to ambient")
    func contextualLineGreetingPriority() {
        func stamped(_ kind: GreetingKind) -> HomeReadModel {
            makeModel(state(lastGreeting: GreetingStamp(kind: kind, at: AppModelFixture.instant("2026-09-10T09:00:00Z"))))
        }
        #expect(stamped(.welcomeBack).contextualLineKey == "momo.line.greeting.01")
        #expect(stamped(.missedYou).contextualLineKey == "momo.line.greeting.02")
        #expect(stamped(.freshMorning).contextualLineKey == "momo.line.greeting.03")
        // nightGlance and the nil stamp: the AMBIENT draw for the 09:00 slot
        // (morning), in the slot-line namespace with a two-digit index.
        #expect(stamped(.nightGlance).contextualLineKey.hasPrefix("momo.line.morning."))
        #expect(stamped(.nightGlance).contextualLineKey.dropFirst("momo.line.morning.".count).count == 2)
        #expect(stamped(.nightGlance).contextualLineKey == makeModel().contextualLineKey)
    }

    /// The ambient draw is day-stable (identical inputs ⇒ identical key) and
    /// follows the local hour through all four slots (04 §10.4: night
    /// [22,07), morning [07,12), day [12,18), evening [18,22)).
    @Test("contextual line: ambient draw is day-stable and slot-routed")
    func ambientLineSlotsAndStability() {
        let morning = makeModel().contextualLineKey
        #expect(morning == makeModel().contextualLineKey, "identical (pet, day, slot) ⇒ identical key")
        #expect(morning.hasPrefix("momo.line.morning."))
        #expect(makeModel(at: "2026-09-10T13:00:00Z").contextualLineKey.hasPrefix("momo.line.day."))
        #expect(makeModel(at: "2026-09-10T19:00:00Z").contextualLineKey.hasPrefix("momo.line.evening."))
        #expect(makeModel(at: "2026-09-10T23:00:00Z").contextualLineKey.hasPrefix("momo.line.night."))
        #expect(makeModel(at: "2026-09-10T03:00:00Z").contextualLineKey.hasPrefix("momo.line.night."))
    }

    // MARK: Required Test 3 — quest rows and action pills

    /// The fixture's fresh-install-shaped set (Q1, Q2, Q6, zero progress) in
    /// record order, with the window flags tracking each quest's PRD §5.2
    /// window: 09:00 has Q1+Q2 open (Q6's evening window shut); 20:30 opens
    /// Q6 and has shut Q1; the 06:30 early-morning tail of Q6's window has
    /// all three open.
    @Test("quest rows: catalog order, soft marks, and window flags")
    func questRowsOrderMarksWindows() {
        // Tuples aren't Equatable; the pin rides a tiny local value.
        struct RowPin: Equatable {
            let questID: QuestID
            let completed: Bool
            let visible: Bool
        }
        func flags(_ iso: String) -> [RowPin] {
            makeModel(at: iso).questRows.map {
                RowPin(questID: $0.questID, completed: $0.isCompleted, visible: $0.isWindowVisible)
            }
        }
        #expect(flags("2026-09-10T09:00:00Z") == [
            RowPin(questID: .q1, completed: false, visible: true),
            RowPin(questID: .q2, completed: false, visible: true),
            RowPin(questID: .q6, completed: false, visible: false),
        ])
        #expect(flags("2026-09-10T20:30:00Z") == [
            RowPin(questID: .q1, completed: false, visible: false),
            RowPin(questID: .q2, completed: false, visible: true),
            RowPin(questID: .q6, completed: false, visible: true),
        ])
        #expect(flags("2026-09-10T06:30:00Z") == [
            RowPin(questID: .q1, completed: false, visible: true),
            RowPin(questID: .q2, completed: false, visible: true),
            RowPin(questID: .q6, completed: false, visible: true),
        ])
        // Wish keys name their quest, one row per quest.
        let rows = makeModel().questRows
        #expect(rows.map(\.wishKey) == ["momo.line.quest.q1", "momo.line.quest.q2", "momo.line.quest.q6"])
    }

    /// Per-wish soft marks project the record's completion flags; an absent
    /// day record yields an EMPTY row list (no record, no wishes — the same
    /// semantics as the §4.11 cascade).
    @Test("quest rows: completion projects; absent record yields no rows")
    func questRowsCompletionAndAbsence() {
        let withCompletion = DayRecord(
            dayKey: "2026-09-10",
            feedCount: 0,
            playCount: 0,
            careCount: 0,
            patCount: 1,
            questSet: [
                QuestProgress(questID: .q1, progress: 1, completed: true)!,
                QuestProgress(questID: .q2, progress: 0, completed: false)!,
                QuestProgress(questID: .q6, progress: 0, completed: false)!,
            ],
            helloAwarded: true,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: 1
        )!
        #expect(makeModel(state(days: [withCompletion])).questRows.map(\.isCompleted) == [true, false, false])
        #expect(makeModel(state(days: [])).questRows.isEmpty)
    }

    /// UX §5.4's action row: feed+play always; tuck-in appears with the Q6
    /// window's evening onset (20:00, from `Thresholds` — never restated);
    /// nap only in the WAKING hours of a drowsy/exhausted pet.
    @Test("action pills: windows and bands gate tuck-in and nap")
    func actionPillsGates() {
        // 09:00, energetic, awake: just feed and play (no nap on a fresh pet).
        #expect(makeModel().actionPills.count == 2)
        // 20:30: tuck-in's window is open.
        #expect(makeModel(at: "2026-09-10T20:30:00Z").actionPills.count == 3)
        // Exhausted and awake at 20:30: the full row, in order.
        let full = makeModel(state(energy: 10), at: "2026-09-10T20:30:00Z")
        if case .feed = full.actionPills[0] {} else { Issue.record("first pill should be feed") }
        if case .play = full.actionPills[1] {} else { Issue.record("second pill should be play") }
        if case .tuckIn = full.actionPills[2] {} else { Issue.record("third pill should be tuckIn") }
        if case .nap = full.actionPills[3] {} else { Issue.record("fourth pill should be nap") }
        // Asleep at 20:30: tuck-in yes, nap no (nap is a waking-hours chip).
        #expect(makeModel(state(energy: 10, wakefulness: .asleep), at: "2026-09-10T20:30:00Z").actionPills.count == 3)
        // Drowsy and awake at 09:00: nap without tuck-in.
        let drowsy = makeModel(state(energy: 30))
        #expect(drowsy.actionPills.count == 3)
        if case .nap = drowsy.actionPills[2] {} else { Issue.record("third pill should be nap") }
        // The early-morning tail of the care window (06:30): still no
        // tuck-in pill — the pill's gate is the evening onset only.
        #expect(makeModel(at: "2026-09-10T06:30:00Z").actionPills.count == 2)
    }
}
