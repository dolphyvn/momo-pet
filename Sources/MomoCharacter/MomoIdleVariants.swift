import MomoCore

/// The idle-variant identities of the Phase 1 catalog (04 §5.2, Direction C
/// set + this task's two gated entries). Variants are DATA: a new variant is
/// a new case + catalog row — the schedulers never change (Requirement 3).
public enum MomoVariantID: String, Sendable, CaseIterable {

    /// A small sideways weight-shift with a hint of lean (the eager
    /// micro weight-shift of §3.2's Joyful row).
    case weightShift
    /// One ear lifts in a quick twitch.
    case singleEarTwitch
    /// The tail gives one soft sideways flick.
    case tailFlick
    /// The whole body slowly looks around (§5.2's "slow full-body
    /// look-around").
    case fullBodyLookAround
    /// The creature settles onto one cheek for a moment (the species-
    /// flavored "cheek-press rest").
    case cheekPressRest
    /// The two ears take opposite angles for a beat — §3.1's "asymmetric =
    /// curious/alert" read ("per-ear curious asymmetry").
    case perEarCuriousAsymmetry
    /// Soul Companions' calm-coexist idle (§3.4): rests with the eyes
    /// half-closed, facing you. Bond-gated.
    case calmCoexist
    /// The Drowsy head-nod micro-motion (§3.3). Energy-gated.
    case headNod
}

/// One catalog row: identity, draw weight, held-duration range, the
/// property groups its rendering animates (§7.4 rule 4), its envelope
/// family, and its gates. Selection is seed-deterministic (weighted draw);
/// gates filter the selectable set by the GIVEN display state.
public struct MomoVariantSpec: Sendable, Equatable {

    public let id: MomoVariantID
    /// Relative draw weight inside the selectable set (unnormalized).
    public let selectionWeight: Double
    /// The held-pose duration band (authored; entry/exit are the envelope
    /// family's, not part of the hold).
    public let holdRange: ClosedRange<Double>
    public let propertyGroups: MomoPropertyGroup
    /// Spring variants (§7.2's spring family — ears/tail/nod) fix their
    /// entry/exit to the idle spring response; crossfade variants draw the
    /// §7.1 state-crossfade band.
    public let usesSpringEnvelope: Bool
    /// Present only when the energy band equals this value (headNod).
    public let energyGate: EnergyBand?
    /// Present only when the bond stage is at least this stage (calmCoexist).
    public let minimumBondStage: BondStage?

    public init(
        id: MomoVariantID,
        selectionWeight: Double,
        holdRange: ClosedRange<Double>,
        propertyGroups: MomoPropertyGroup,
        usesSpringEnvelope: Bool,
        energyGate: EnergyBand? = nil,
        minimumBondStage: BondStage? = nil
    ) {
        self.id = id
        self.selectionWeight = selectionWeight
        self.holdRange = holdRange
        self.propertyGroups = propertyGroups
        self.usesSpringEnvelope = usesSpringEnvelope
        self.energyGate = energyGate
        self.minimumBondStage = minimumBondStage
    }
}

/// The Phase 1 idle-variant catalog (04 §5.2) — data, not code.
public enum MomoIdleVariantCatalog {

    /// The catalog rows, in canonical (draw-scan) order. Weights are
    /// relative and unnormalized.
    public static let phase1: [MomoVariantSpec] = [
        MomoVariantSpec(
            id: .weightShift, selectionWeight: 1.0, holdRange: 0.8...1.6,
            propertyGroups: [.body], usesSpringEnvelope: false),
        MomoVariantSpec(
            id: .singleEarTwitch, selectionWeight: 1.0, holdRange: 0.5...1.1,
            propertyGroups: [.ears], usesSpringEnvelope: true),
        MomoVariantSpec(
            id: .tailFlick, selectionWeight: 0.9, holdRange: 0.5...1.2,
            propertyGroups: [.tail], usesSpringEnvelope: true),
        MomoVariantSpec(
            id: .fullBodyLookAround, selectionWeight: 0.8, holdRange: 1.2...2.4,
            propertyGroups: [.body, .head], usesSpringEnvelope: false),
        MomoVariantSpec(
            id: .cheekPressRest, selectionWeight: 0.7, holdRange: 1.0...2.0,
            propertyGroups: [.body], usesSpringEnvelope: false),
        MomoVariantSpec(
            id: .perEarCuriousAsymmetry, selectionWeight: 0.8, holdRange: 0.7...1.5,
            propertyGroups: [.ears], usesSpringEnvelope: true),
        MomoVariantSpec(
            id: .calmCoexist, selectionWeight: 1.2, holdRange: 2.5...5.0,
            propertyGroups: [.aperture], usesSpringEnvelope: false,
            minimumBondStage: .soulCompanions),
        MomoVariantSpec(
            id: .headNod, selectionWeight: 0.8, holdRange: 0.6...1.2,
            propertyGroups: [.head], usesSpringEnvelope: true,
            energyGate: .drowsy),
    ]

    /// The row for an id (nil for unknown ids — envelope payloads tolerate
    /// forward-compatible catalogs).
    public static func spec(for id: MomoVariantID) -> MomoVariantSpec? {
        phase1.first { $0.id == id }
    }

    /// The selectable rows for a display state: energy and bond gates
    /// filter the catalog; the mood may boost a weight (Joyful's "eager
    /// micro weight-shifts toward user", §3.2 — weightShift draws ×1.5).
    public static func selectableWeights(
        mood: MoodBand, energy: EnergyBand, bondStage: BondStage
    ) -> [(value: MomoVariantID, weight: Double)] {
        phase1.compactMap { spec in
            if let gate = spec.energyGate, energy != gate { return nil }
            if let minimum = spec.minimumBondStage,
               Self.rank(bondStage) < Self.rank(minimum) { return nil }
            let weight: Double =
                (spec.id == .weightShift && mood == .joyful)
                ? spec.selectionWeight * 1.5
                : spec.selectionWeight
            return (spec.id, weight)
        }
    }

    /// Bond stages in ascending order (`BondStage` itself is unordered).
    private static func rank(_ stage: BondStage) -> Int {
        switch stage {
        case .newFriends: 0
        case .gettingClose: 1
        case .bestFriends: 2
        case .soulCompanions: 3
        }
    }
}
