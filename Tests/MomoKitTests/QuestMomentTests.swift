import Testing
import Foundation
@testable import MomoKit
import MomoCore

// MARK: - QuestMomentTests — the moment fan-out's pure halves (TASK-036
// R3/R4/R7/R10; FR-16; UX §5.5–§5.6)

/// The `.deliverMoments` fan-out's decision layer, headless: which moments
/// ride the event door (the greeting stays state-born), which stage a batch
/// celebrates, which haptics fire (gated at delivery), and which quests an
/// engine-state application flipped. All value-in/value-out — the wiring
/// half lives in the app model, pinned by the R9 structural guards.
@Suite
struct QuestMomentTests {

    // MARK: R1 — the event-born door

    /// The greeting stays on the state-born `.displayState` door; everything
    /// else rides `.moments`, order preserved (the engine's causal emission:
    /// quest completions mint before the bond crossing they caused).
    @Test("eventBornMoments: the greeting alone is excluded, order preserved")
    func eventBornFilter() {
        let batch: [CharacterMoment] = [
            .greeting(.freshMorning),
            .questCompleted,
            .bondStageReached(.gettingClose),
        ]
        #expect(QuestMomentSupport.eventBornMoments(batch) == [
            .questCompleted,
            .bondStageReached(.gettingClose),
        ])
        // An all-greeting batch (the greeting-only outcome) delivers
        // nothing through the event door.
        #expect(QuestMomentSupport.eventBornMoments([.greeting(.welcomeBack)]).isEmpty)
        #expect(QuestMomentSupport.eventBornMoments([]).isEmpty)
        // The maximal real batch passes whole.
        #expect(QuestMomentSupport.eventBornMoments([
            .questCompleted, .questCompleted, .bondStageReached(.soulCompanions),
        ]) == [.questCompleted, .questCompleted, .bondStageReached(.soulCompanions)])
    }

    // MARK: R4 — the M2 celebration stage

    /// The stage a batch celebrates is the FIRST `.bondStageReached` in
    /// causal order; greeting-bearing and quest-only batches celebrate
    /// nothing.
    @Test("celebrationStage: the first crossing wins; none otherwise")
    func celebrationStage() {
        #expect(QuestMomentSupport.celebrationStage(in: [
            .questCompleted,
            .bondStageReached(.gettingClose),
        ]) == .gettingClose)
        #expect(QuestMomentSupport.celebrationStage(in: [
            .greeting(.missedYou),
            .questCompleted,
        ]) == nil)
        #expect(QuestMomentSupport.celebrationStage(in: []) == nil)
        // A greeting BEFORE the crossing doesn't shadow it.
        #expect(QuestMomentSupport.celebrationStage(in: [
            .greeting(.freshMorning),
            .bondStageReached(.bestFriends),
        ]) == .bestFriends)
    }

    // MARK: R3 — the M1 flips

    func record(
        _ dayKey: String,
        _ entries: (QuestID, Bool)...
    ) -> DayRecord {
        DayRecord(
            dayKey: dayKey,
            feedCount: 0, playCount: 0, careCount: 0, patCount: 0,
            questSet: entries.map { id, done in
                QuestProgress(questID: id, progress: done ? 1 : 0, completed: done)!
            },
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: 1
        )!
    }

    /// A completion flips; a reversal contributes nothing (FR-16's
    /// completion-never-reverses makes the one-way diff total); an absent
    /// day on either side contributes nothing.
    @Test("flippedQuests: one-way completion diff over matching day keys")
    func flipDiff() {
        let before = [
            record("2026-09-09", (.q1, true), (.q2, false), (.q6, false)),
            record("2026-09-10", (.q1, false), (.q2, false), (.q6, false)),
        ]
        let after = [
            // Today's completion first (the state's day order)…
            record("2026-09-10", (.q1, true), (.q2, false), (.q6, false)),
            // …yesterday: q2 completes, q1 STAYS done (no re-flip).
            record("2026-09-09", (.q1, true), (.q2, true), (.q6, false)),
            // A brand-new day: nothing to diff against, nothing flips.
            record("2026-09-11", (.q1, false), (.q2, false), (.q6, false)),
        ]
        #expect(
            QuestMomentSupport.flippedQuests(before: before, after: after)
                == [.q1, .q2])
        // No change, no flips.
        #expect(QuestMomentSupport.flippedQuests(before: after, after: after).isEmpty)
        #expect(QuestMomentSupport.flippedQuests(before: [], after: after).isEmpty)
        #expect(QuestMomentSupport.flippedQuests(before: before, after: []).isEmpty)
    }

    /// Within one record the flips report in CATALOG order (the diff walks
    /// `QuestCatalog.all`), not set order — the card's flourish finds its
    /// row by identity anyway, but the order is pinned.
    @Test("flippedQuests: catalog order within a record")
    func flipCatalogOrder() {
        let before = [record("2026-09-10", (.q6, false), (.q1, false), (.q2, false))]
        let after = [record("2026-09-10", (.q6, true), (.q1, true), (.q2, false))]
        #expect(
            QuestMomentSupport.flippedQuests(before: before, after: after) == [.q1, .q6])
    }

    // MARK: R7 — the moment haptics

    /// The delivery kinds dedupe in causal order — the real batch is
    /// quests-then-crossing (the engine's `reconcileStage` runs after every
    /// path's quest mutation), so M1's light impact fires before M2's warm
    /// beat; the greeting never fires anything.
    @Test("deliveryKinds: deduped causal fire order")
    func hapticKinds() {
        #expect(MomentHapticKind.deliveryKinds(
            for: [.questCompleted, .questCompleted, .bondStageReached(.gettingClose)],
            hapticsEnabled: true
        ) == [.questCompleted, .stageCelebration])
        // Quest-only, crossing-only, greeting-only, empty.
        #expect(MomentHapticKind.deliveryKinds(for: [.questCompleted], hapticsEnabled: true)
            == [.questCompleted])
        #expect(MomentHapticKind.deliveryKinds(for: [.bondStageReached(.bestFriends)], hapticsEnabled: true)
            == [.stageCelebration])
        #expect(MomentHapticKind.deliveryKinds(for: [.greeting(.freshMorning)], hapticsEnabled: true)
            == [])
        #expect(MomentHapticKind.deliveryKinds(for: [], hapticsEnabled: true) == [])
    }

    /// The gate reads the user's haptics setting AT DELIVERY: disabled, the
    /// same batch fires nothing (D16's corollary — Reduce Motion fades
    /// motion, not touch; this gate is the settings one, not RM).
    @Test("deliveryKinds: the haptics setting gates the whole batch")
    func hapticGate() {
        #expect(MomentHapticKind.deliveryKinds(
            for: [.questCompleted, .bondStageReached(.gettingClose)],
            hapticsEnabled: false
        ).isEmpty)
    }
}
