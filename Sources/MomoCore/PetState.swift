import Foundation

// MARK: - Wakefulness / Activity / Satiety (05 §3.1, 04 §9.2)

/// The wakefulness machine's states (05 §3.1; INV-8's §4.7 transition diagram
/// is engine-owned — EPIC-004 — while the closed case set is enforced here).
public enum Wakefulness: Equatable, Sendable {
    case awake
    case settling
    case asleep
    case waking
}

/// The current sustained activity, if any (05 §3.1; 04 §4.2).
public enum Activity: Equatable, Sendable {
    case eating
    case playing
    case napping
}

/// The satiety window's three phases (05 §4.5: Full 0–30 min, Recently fed
/// 30–90 min, Hungry > 90 min since last feed — the window value and the
/// derivation from `lastFedAt` are engine-owned, EPIC-004; this type is the
/// stored/rendered phase).
public enum SatietyPhase: Equatable, Sendable {
    case full
    case recentlyFed
    case hungry
}

/// 04 §9.2's name for the same value (`CharacterDisplayState.satietyHint`) —
/// one type, both spec names.
public typealias SatietyHint = SatietyPhase

// MARK: - PetState

/// The three pet dimensions plus the machine/phase fields the engine derives
/// and the renderer consumes (05-technical-architecture §3.1).
///
/// Bands are DERIVED, never stored (PRD §3; `makeMoodBand`/`makeEnergyBand`/
/// `makeBondStage` are the only derivation path).
///
/// All properties are `let`: value semantics, immutable by construction — the
/// engine produces new state at each evaluation instead of mutating (05 §3).
/// INV-2/INV-3's ranges are enforced at this type boundary by the failable
/// initializer; their across-mutation rules (monotonicity) are engine/store
/// contracts pinned by tests in EPIC-004/005.
public struct PetState: Equatable, Sendable {

    /// Mood scalar, 0...100 (INV-2; PRD §3.1, D10).
    public let mood: Double

    /// Energy scalar, 0...100 (INV-2; PRD §3.2, D10).
    public let energy: Double

    /// Cumulative bond, 0...1000 (INV-3: in range here; monotonic non-decreasing
    /// across ALL mutations is the engine/store contract — FR-10 AC-2, D3).
    public let bond: Int

    /// Wakefulness machine state (INV-8's legal-transition diagram: §4.7).
    public let wakefulness: Wakefulness

    /// The active sustained activity, if any.
    public let activity: Activity?

    /// Satiety clock anchor — the instant of the last accepted feed
    /// (§4.5), or nil before the first feed ever.
    public let lastFedAt: Instant?

    /// Satiety phase, derived by the engine at each evaluation and stored for
    /// render (§4.5). Not derivable here on purpose: the 90-minute window value
    /// is engine-owned (EPIC-004).
    public let satietyPhase: SatietyPhase

    /// Fails (returns nil) when `mood` or `energy` falls outside 0...100
    /// (INV-2) or `bond` falls outside 0...1000 (INV-3) — invalid dimension
    /// values are unrepresentable. NaN is rejected: it compares false against
    /// both bounds.
    public init?(
        mood: Double,
        energy: Double,
        bond: Int,
        wakefulness: Wakefulness,
        activity: Activity?,
        lastFedAt: Instant?,
        satietyPhase: SatietyPhase
    ) {
        guard Self.isInMoodRange(mood), Self.isInEnergyRange(energy), Self.isInBondRange(bond) else {
            return nil
        }
        self.mood = mood
        self.energy = energy
        self.bond = bond
        self.wakefulness = wakefulness
        self.activity = activity
        self.lastFedAt = lastFedAt
        self.satietyPhase = satietyPhase
    }

    /// INV-2 mood half (PRD §3.1: internal continuous scalar 0–100).
    public static func isInMoodRange(_ value: Double) -> Bool {
        Thresholds.Scalar.lower <= value && value <= Thresholds.Scalar.upper
    }

    /// INV-2 energy half (PRD §3.2: internal continuous scalar 0–100).
    public static func isInEnergyRange(_ value: Double) -> Bool {
        Thresholds.Scalar.lower <= value && value <= Thresholds.Scalar.upper
    }

    /// INV-3 range half (PRD §3.3: cumulative scalar 0–1000).
    public static func isInBondRange(_ value: Int) -> Bool {
        (Thresholds.Bond.minimum...Thresholds.Bond.maximum).contains(value)
    }
}
