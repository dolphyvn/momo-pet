import Foundation
import MomoCore

// MARK: - HomeCopyKeys — the Home composition's copy-key minting (TASK-033
// Requirement 1; INV-11; 04-character-system §3.5, §10.3–§10.4;
// 03-ux-architecture §5.1, §5.5)

/// Key-only minting for the Home screen (INV-11: engine and MomoKit emit
/// catalog KEYS, never composed prose — the view resolves them through
/// `MomoCopy`). Three keyspaces meet here:
///
/// - **The contextual line** (UX-12's single rotating slot): the greeting in
///   effect, else the day-stable ambient slot draw (`LineSelection.slotLineKey`
///   — same (pet, day, slot) ⇒ same line all day, 04 §10.1 rule 7). Reaction
///   lines outrank greetings in UX-12's priority; they arrive with the
///   reaction/care surfaces (TASK-034/035) and extend `contextualLineKey` —
///   this task's resolver is the greeting/ambient half of that priority.
/// - **The status-row words** (UX §5.1's `{mood word} · {energy word} ·
///   {stage}` row): the mood WORD comes from the OBS-1 vocabulary
///   (`VocabularyKeys.moodWordKey`); the energy word and stage NAME are the
///   catalog-era status classes minted here — `momo.line.status.energy.<band>`
///   and `momo.line.status.stage.<stage>` (PRD §3.2/§3.3's normative names as
///   catalog entries; TASK-033 Requirement 3).
/// - **The quest wishes** (PRD §5.2's wish lines, TASK-033 Requirement 3):
///   `momo.line.quest.q<n>` per `QuestID`.
///
/// Pure and total: every function is an exhaustive `switch` or a delegation
/// to the frozen selection surface. No string here is user-facing text — all
/// of them are namespace structure under §8.4's dot convention.
public enum HomeCopyKeys {

    // MARK: The contextual line (UX-12; 04 §10.3's greeting pool)

    /// The day-stable ambient slot-line key for the local time slot —
    /// `momo.line.<slot>.<nn>` via the frozen selection surface (a fresh pool
    /// of 10 per time slot as of the TASK-033 catalog landing; epoch 2).
    public static func ambientLineKey(
        petID: UUID,
        dayKey: String,
        slot: CopyRules.LineSlot
    ) -> String {
        LineSelection.slotLineKey(petID: petID, dayKey: dayKey, slot: slot)
    }

    /// The greeting line key for the in-effect greeting kind (04 §10.3's
    /// return-greeting pool, catalog order 01–03). `nightGlance` has NO pool
    /// yet — its "Shhh…" class is the canvas/moment surface, landing with the
    /// reaction/care tasks (TASK-034/035) — so the contextual resolver falls
    /// through to the ambient slot line for it.
    public static func greetingLineKey(for kind: GreetingKind) -> String? {
        switch kind {
        case .welcomeBack: return "momo.line.greeting.01"
        case .missedYou: return "momo.line.greeting.02"
        case .freshMorning: return "momo.line.greeting.03"
        case .nightGlance: return nil
        }
    }

    /// The contextual line key for the current open (UX-12's single rotating
    /// slot): the greeting in effect — including the fresh-day greeting drawn
    /// at the first open — else the ambient slot draw. A nil greeting (the
    /// sub-floor re-evaluations of `Greeting.select`) is the ambient case by
    /// definition, so the fallthrough needs no extra state.
    public static func contextualLineKey(
        greeting: GreetingKind?,
        petID: UUID,
        dayKey: String,
        slot: CopyRules.LineSlot
    ) -> String {
        greeting.flatMap(greetingLineKey) ?? ambientLineKey(petID: petID, dayKey: dayKey, slot: slot)
    }

    // MARK: Status-row words (UX §5.1's status row; PRD §3.2–§3.3)

    /// The status row's energy word key — `momo.line.status.energy.<band>`
    /// (PRD §3.2's normative band names, capitalized in the catalog: the row
    /// is a noun-like readout, distinct in register from the a11y phrase).
    public static func energyWordKey(for band: EnergyBand) -> String {
        switch band {
        case .energetic: return "momo.line.status.energy.energetic"
        case .relaxed: return "momo.line.status.energy.relaxed"
        case .drowsy: return "momo.line.status.energy.drowsy"
        case .exhausted: return "momo.line.status.energy.exhausted"
        }
    }

    /// The status row's stage-name key — `momo.line.status.stage.<stage>`
    /// (PRD §3.3's normative stage names, capitalized in the catalog).
    public static func stageNameKey(for stage: BondStage) -> String {
        switch stage {
        case .newFriends: return "momo.line.status.stage.newFriends"
        case .gettingClose: return "momo.line.status.stage.gettingClose"
        case .bestFriends: return "momo.line.status.stage.bestFriends"
        case .soulCompanions: return "momo.line.status.stage.soulCompanions"
        }
    }

    // MARK: Quest wishes (PRD §5.2's wish lines; UX §5.5's card rows)

    /// The quest card's wish-line key for a quest — `momo.line.quest.q<n>`
    /// (lowercase numeral per the catalog grammar; PRD §5.2's "Name — wish"
    /// framing lives in the catalog ENTRY, never composed here).
    public static func questWishKey(for questID: QuestID) -> String {
        switch questID {
        case .q1: return "momo.line.quest.q1"
        case .q2: return "momo.line.quest.q2"
        case .q3: return "momo.line.quest.q3"
        case .q4: return "momo.line.quest.q4"
        case .q5: return "momo.line.quest.q5"
        case .q6: return "momo.line.quest.q6"
        case .q7: return "momo.line.quest.q7"
        }
    }
}
