import Foundation
import MomoCore

// MARK: - QuestMomentSupport — the quest/bond moment fan-out's pure halves
// (TASK-036 R3/R4/R5/R7; FR-16; UX §5.5–§5.6)

/// The PURE derivations behind the app model's `.deliverMoments` fan-out:
/// which moments are event-born (the greeting door stays state-born), which
/// bond stage a batch celebrates, which haptics a delivery fires (gated),
/// and which quests an engine state application flipped to done. Every
/// function is value-in/value-out — no clocks, no side effects — so the
/// fan-out's decision layer is headless-testable and the app model's arm is
/// mechanical wiring (the wiring itself is pinned by the R9 structural
/// guards and the UI suite).
public enum QuestMomentSupport {

    // MARK: The event-born door (TASK-036 R1)

    /// The moments that ride the NEW event door — every moment EXCEPT the
    /// greeting, which stays on the state-born `.displayState`
    /// `momentRequest` door (the TASK-019 state-alone pin). Order is
    /// preserved (the engine's causal emission order); the batch folds
    /// through `MomoCharacterEvent.moments` FIFO.
    public static func eventBornMoments(_ moments: [CharacterMoment]) -> [CharacterMoment] {
        moments.filter { moment in
            if case .greeting = moment { return false }
            return true
        }
    }

    // MARK: The M2 stage celebration (TASK-036 R4; UX §5.6)

    /// The bond stage a moment batch celebrates, if any — the FIRST
    /// `.bondStageReached` in causal order. The engine mints at most one per
    /// outcome (TASK-018's cap), so "first" is "the" in every real batch.
    public static func celebrationStage(in moments: [CharacterMoment]) -> BondStage? {
        for moment in moments {
            if case .bondStageReached(let stage) = moment { return stage }
        }
        return nil
    }

    // MARK: The M1 flips (TASK-036 R3; UX §5.5's inline completion)

    /// The quests an engine-state application flipped to done, in catalog
    /// order — the `CharacterMoment.questCompleted` moments carry no
    /// payload, so the card's per-row flourish derives WHICH quest flipped
    /// from the day-record diff itself (FR-16's "completion never
    /// reverses" makes a one-way diff total). Records match by `dayKey`;
    /// a day present on only one side contributes nothing (a fresh
    /// record's zero-progress quests flipped nothing).
    public static func flippedQuests(
        before: [DayRecord],
        after: [DayRecord]
    ) -> [QuestID] {
        let beforeByKey = Dictionary(uniqueKeysWithValues: before.map { ($0.dayKey, $0) })
        var flipped: [QuestID] = []
        for record in after {
            guard let previous = beforeByKey[record.dayKey] else { continue }
            let previousDone = Dictionary(uniqueKeysWithValues: previous.questSet.map {
                ($0.questID, $0.completed)
            })
            for questID in QuestCatalog.all.map(\.id) {
                guard let wasDone = previousDone[questID] else { continue }
                let isDone = record.questSet.first { $0.questID == questID }?.completed ?? false
                if !wasDone, isDone, !flipped.contains(questID) {
                    flipped.append(questID)
                }
            }
        }
        return flipped
    }
}

// MARK: - The moment haptics (TASK-036 R7; UX §5.5 M1's "optional light
// haptic" / §5.6 M2's celebration)

/// The authored moment-haptic vocabulary, decided HERE (pure, headless-
/// testable — gate included) and fired by the app model through its
/// injected sink. Independent of Reduce Motion (D16 fades motion, not
/// touch); `.questCompleted` is a light impact (M1's tiny inline moment),
/// `.stageCelebration` a single warm success notification (M2's one-time
/// beat). The engine's `ResponsePlan.haptic` stays nil everywhere — this
/// is presentation-owned, decided at delivery.
public enum MomentHapticKind: Equatable, Sendable {

    /// M1 — a wish completed (UX §5.5: the inline mark fill's soft beat).
    case questCompleted

    /// M2 — a bond stage celebrated once (UX §5.6: the crossing's warm beat).
    case stageCelebration

    /// The kinds one delivery fires, in fire order (M1's beat, then M2's),
    /// gated on the user's haptics setting read AT DELIVERY. Derived from
    /// the RAW batch — the greeting on it never fires anything.
    public static func deliveryKinds(
        for moments: [CharacterMoment],
        hapticsEnabled: Bool
    ) -> [MomentHapticKind] {
        guard hapticsEnabled else { return [] }
        var kinds: [MomentHapticKind] = []
        for moment in moments {
            switch moment {
            case .questCompleted:
                if !kinds.contains(.questCompleted) { kinds.append(.questCompleted) }
            case .bondStageReached:
                if !kinds.contains(.stageCelebration) { kinds.append(.stageCelebration) }
            case .greeting:
                break
            }
        }
        return kinds
    }
}
