import Foundation

// MARK: - Engine ↔ Character interface types (04-character-system §9.2;
// placement: MomoCore per 05 §2.1/§4.11, so EPIC-006 starts against them).

// MARK: Key namespaces

/// A reaction identifier (04 §9.2 `ResponsePlan.reaction` / `CharacterReport`).
/// The vocabulary IS 04 §8.4's clip-identifier namespace (dot-namespaced,
/// e.g. `react.tap.head`), enumerated one-to-one by the character/catalog
/// side (04 §4.3, §6; §8.5 manifest) — MomoCore deliberately carries the key
/// type, not the enumeration, so the namespace stays catalog-owned (INV-11:
/// keys, never composed prose).
public struct ReactionID: Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

/// A haptic identifier (04 §9.2 `ResponsePlan.haptic` — presentation-owned
/// vocabulary; same key discipline as `ReactionID`).
public struct HapticID: Equatable, Hashable, Sendable {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }
}

// MARK: - CharacterDisplayState

/// The character-facing read-model shape (04 §9.2). EPIC-004 derives it from
/// engine state (`makeCharacterDisplayState`, 05 §4.11); the full rig consumes
/// it per 04 §9.2, so no consumer derives its own view of engine state.
///
/// INV-11 by field inventory: bands/stage/wakefulness/activity/satiety are
/// enums; the only optional slot is the `CharacterMoment` request — no
/// composed user-facing strings exist on this type.
public struct CharacterDisplayState: Equatable, Sendable {

    public let moodBand: MoodBand
    public let energyBand: EnergyBand
    public let bondStage: BondStage
    public let wakefulness: Wakefulness
    public let activity: Activity?

    /// Window owned by the engine (05 §4.5); the character renders only the
    /// hint it is given (04 §9.3).
    public let satietyHint: SatietyHint?

    /// The one L4 moment the engine currently requests, if any.
    public let momentRequest: CharacterMoment?

    public init(
        moodBand: MoodBand,
        energyBand: EnergyBand,
        bondStage: BondStage,
        wakefulness: Wakefulness,
        activity: Activity?,
        satietyHint: SatietyHint?,
        momentRequest: CharacterMoment?
    ) {
        self.moodBand = moodBand
        self.energyBand = energyBand
        self.bondStage = bondStage
        self.wakefulness = wakefulness
        self.activity = activity
        self.satietyHint = satietyHint
        self.momentRequest = momentRequest
    }
}

// MARK: - CharacterMoment

/// Greeting kinds (04 §9.2: `.freshMorning` / `.welcomeBack` / `.missedYou`
/// (≥ 36 h) / `.nightGlance` — the ≥ 36 h rule is engine-owned, FR-12 AC-2).
public enum GreetingKind: Equatable, Hashable, Sendable {
    case freshMorning
    case welcomeBack
    case missedYou
    case nightGlance
}

/// Rare system moments (04 §9.2; L4 in 04 §4.1 — app-hide pauses, never cancels).
public enum CharacterMoment: Equatable, Sendable {
    case greeting(GreetingKind)
    /// PRD §5.4 sparkle (no modal).
    case questCompleted
    /// FR-10 AC-4 one-time celebration (the `highestCelebratedStage` guard is
    /// engine-owned, §4.6).
    case bondStageReached(BondStage)
}

// MARK: - ResponsePlan

/// The engine's full answer to an interaction (04 §9.2): the character
/// executes this plan and never decides warm/declined itself (D18).
public struct ResponsePlan: Equatable, Sendable {

    /// The reaction to run — 04 §4.3/§6 vocabulary in §8.4's namespace.
    public let reaction: ReactionID

    /// Optional String Catalog key (§10; nil = the animation speaks alone).
    public let lineKey: String?

    /// Optional haptic — presentation-owned vocabulary.
    public let haptic: HapticID?

    public init(reaction: ReactionID, lineKey: String?, haptic: HapticID?) {
        self.reaction = reaction
        self.lineKey = lineKey
        self.haptic = haptic
    }
}

// MARK: - HandshakeKind

/// Handshake classes (04 §9.2). `.wake` exists for contract totality — waking
/// is expected never to cancel (04 §9.2; 05 §4.7).
public enum HandshakeKind: Equatable, Hashable, Sendable {
    case settle
    case wake
    case play
}

// MARK: - CharacterReport

/// Character → engine completions (04 §9.2). Every report path is idempotent
/// on the engine side — late/duplicate/stale reports are matched by token and
/// tolerated (04 §9.2; 05 §4.7; the tolerance is EPIC-004's engine contract,
/// this type is its carrier).
public enum CharacterReport: Sendable {
    case reactionFinished(ReactionID)
    case playRoundFinished
    /// Preemption path (04 §9.2 cancellation) — idempotent, same tolerance.
    case handshakeCancelled(HandshakeKind)
    /// Settling → engine flips `.asleep` (the tuck-in handshake).
    case settleFinished
    /// Waking → engine flips `.awake` (the wake stretch's report). Added at
    /// TASK-015 as the exact-type finalization 04 §9.2 delegates ("TASK-006
    /// finalizes exact types"): 04 §9.2's wake prose ("report → engine sets
    /// `.awake`") and 05 §4.7's diagram ("`waking ──wakeFinished──► awake`")
    /// both name this report, but the sketch's enum omitted it. Expected never
    /// to be cancelled — app-hide pauses waking and it completes on return
    /// (04 §9.2; the `.wake` cancellation kind exists for totality only).
    case wakeFinished
    case momentFinished(CharacterMoment)
}
