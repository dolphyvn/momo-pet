import Foundation
import MomoCore

// MARK: - HomeCopyKeys — the Home composition's copy-key minting (TASK-033
// Requirement 1; INV-11; 04-character-system §3.5, §10.3–§10.4;
// 03-ux-architecture §5.1, §5.5)

/// Key-only minting for the Home screen (INV-11: engine and MomoKit emit
/// catalog KEYS, never composed prose — the view resolves them through
/// `MomoCopy`). Three keyspaces meet here:
///
/// - **The contextual line** (UX-12's single rotating slot): the latest
///   care-moment line (TASK-035's visual reaction class — tuck-in settle,
///   refusal, blanket-adjust), else the greeting in effect, else the
///   day-stable ambient slot draw (`LineSelection.slotLineKey` — same (pet,
///   day, slot) ⇒ same line all day, 04 §10.1 rule 7). That is UX-12's
///   priority VERBATIM — interaction reaction > greeting > ambient. The
///   feed/play/touch spoken lines stay accessibility-only and never enter
///   the visual slot (04 §10.1 rule 7's restraint).
/// - **The status-row words** (UX §5.1's `{mood word} · {energy word} ·
///   {stage}` row): the mood WORD comes from the OBS-1 vocabulary
///   (`VocabularyKeys.moodWordKey`); the energy word and stage NAME are the
///   catalog-era status classes minted here — `momo.line.status.energy.<band>`
///   and `momo.line.status.stage.<stage>` (PRD §3.2/§3.3's normative names as
///   catalog entries; TASK-033 Requirement 3).
/// - **The quest wishes** (PRD §5.2's wish lines, TASK-033 Requirement 3):
///   `momo.line.quest.q<n>` per `QuestID`.
/// - **The moment lines** (TASK-036; UX §5.6's celebration class): the M2
///   banner template and the M3 all-done warm line — `momo.line.moment.01`
///   and `.02`, FIXED lookups (the OBS-D precedent), never seeded draws.
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
    /// return-greeting pool, catalog order 01–03). `nightGlance` still has
    /// NO pool — its "Shhh…" class belongs to the night canvas surface
    /// (Phase 2's absence/night work; the TASK-036 moment class landing is
    /// the stage celebration, not a nightGlance pool) — so the contextual
    /// resolver falls through to the ambient slot line for it.
    public static func greetingLineKey(for kind: GreetingKind) -> String? {
        switch kind {
        case .welcomeBack: return "momo.line.greeting.01"
        case .missedYou: return "momo.line.greeting.02"
        case .freshMorning: return "momo.line.greeting.03"
        case .nightGlance: return nil
        }
    }

    /// The care-moment line key for a care-moment kind — the VISUAL reaction
    /// class (TASK-035; 04 §10.1 rule 7's "few care moments"). A FIXED
    /// lookup at catalog order 01–03, never a seeded draw (contract
    /// adjudication, OBS-D precedent): a refusal line must say refusal, and
    /// a day-stable draw cannot serve both tuck-in and refusal. The mirrors
    /// `greetingLineKey`'s shape exactly.
    public static func careMomentLineKey(for kind: CareMomentKind) -> String {
        switch kind {
        case .tuckIn: return "momo.line.care-moment.01"
        case .refusal: return "momo.line.care-moment.02"
        case .blanketAdjust: return "momo.line.care-moment.03"
        }
    }

    /// The contextual line key for the current open (UX-12's single rotating
    /// slot, priority verbatim): the latest care-moment line when one is in
    /// effect, else the greeting — including the fresh-day greeting drawn
    /// at the first open — else the ambient slot draw. A nil greeting (the
    /// sub-floor re-evaluations of `Greeting.select`) is the ambient case by
    /// definition, so the fallthrough needs no extra state. The care-moment
    /// input is the app model's presentation-side memory of the latest
    /// visual care moment (TASK-035 R5 — never persisted).
    public static func contextualLineKey(
        greeting: GreetingKind?,
        petID: UUID,
        dayKey: String,
        slot: CopyRules.LineSlot,
        careMoment: CareMomentKind? = nil
    ) -> String {
        if let careMoment {
            return careMomentLineKey(for: careMoment)
        }
        return greeting.flatMap(greetingLineKey) ?? ambientLineKey(petID: petID, dayKey: dayKey, slot: slot)
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

    // MARK: The moments (TASK-036 R6; UX §5.6's celebration lines)

    /// The M2 stage-banner template — `momo.line.moment.01`, UX §5.6's
    /// "{name} and you are now {Stage}." half. A FIXED lookup at a single
    /// catalog key, never a seeded draw (the OBS-D adjudication's
    /// precedent: a celebration line must say THE celebration; a
    /// day-stable draw cannot serve that). The template carries positional
    /// `%1$@`/`%2$@` placeholders (name, stage word) so a localized
    /// reordering stays locale-correct; the descriptor sentence
    /// (`VocabularyKeys.bondDescriptorKey`) is appended by the composer.
    public static let celebrationBannerTemplateKey = "momo.line.moment.01"

    /// The M3 all-done warm line — `momo.line.moment.02`, UX §5.5's
    /// one-line warm note the card grows when the §4.8 cascade reads
    /// `.allDone`. Fixed, like `01`.
    public static let allDoneLineKey = "momo.line.moment.02"
}

// MARK: - The care moments (TASK-035 R5; 04 §10.1 rule 7's "few care
// moments"; UX-12's "interaction reaction" visual half)

/// The three VISUAL care-moment classes (the only reaction lines that enter
/// the contextual line's visual slot): the tuck-in settle (01), the
/// politely-full refusal (02), and the already-asleep blanket-adjust (03).
/// Nap and the settling-reaffirm have NO visual line — animation only
/// (rule 7's restraint).
public enum CareMomentKind: Equatable, Sendable {
    /// Tuck-in authorization — the pet settles ("Momo snuggles down under
    /// the blanket.").
    case tuckIn
    /// The politely-full feed refusal — warm, zero penalty ("Momo is full
    /// and thanks you with a nod.").
    case refusal
    /// The blanket-adjust on an already-sleeping pet — counts, stays asleep
    /// ("Momo shifts sleepily under the blanket.").
    case blanketAdjust
}

/// The pure care-moment classifier (TASK-035 R5): which VISUAL care moment
/// — if any — an interaction's response raised, read from the response's
/// reaction and the POST-application engine state. Disambiguations the
/// state half carries: a nap mints the same `settling` reaction as a
/// tuck-in authorization but NO `.settle` handshake token (the nap touches
/// no slot), and the tuck-in reaffirm on an already-settling pet mints
/// `blanketAdjust` WITHOUT the pet being asleep — so the token and the
/// wakefulness/activity split the tuck-in (01) from the reaffirm (no line)
/// and the blanket-adjust (03) from both. Pure: value-in/value-out.
public enum CareMoment {

    /// The care moment the response raised, or nil — every non-care
    /// reaction, the feed-enjoys/nibble family, declined paths, nap
    /// acceptance, and the settling-reaffirm classify nil (animation only).
    public static func classify(response: ResponsePlan, state: EngineState) -> CareMomentKind? {
        let pet = state.state
        switch response.reaction {
        case ReactionKeys.politelyFull:
            return .refusal
        case ReactionKeys.settling where state.pendingHandshake?.kind == .settle:
            return .tuckIn
        case ReactionKeys.blanketAdjust
            where pet.wakefulness == .asleep || pet.activity == .napping:
            return .blanketAdjust
        default:
            return nil
        }
    }
}
