import Foundation

// MARK: - Band and stage types (PRD §3; 05-technical-architecture §3.1)

/// Mood presentation bands (PRD §3.1 — normative band names; 04 §3.2).
public enum MoodBand: Equatable, Sendable {
    case joyful
    case content
    case wistful
    case low
}

/// Energy presentation bands (PRD §3.2 — normative band names; 04 §3.3).
public enum EnergyBand: Equatable, Sendable {
    case energetic
    case relaxed
    case drowsy
    case exhausted
}

/// Bond relationship stages (PRD §3.3 — normative stage names; 04 §3.4).
public enum BondStage: Equatable, Sendable, Codable {
    case newFriends
    case gettingClose
    case bestFriends
    case soulCompanions
}

// MARK: - Pure derivations (05 §3.1: PRD §3 tables are the single source)

/// Derives the mood band from the mood scalar (PRD §3.1). Pure: no hidden
/// state, no clock, no RNG. Values at a cut-off belong to the band above it;
/// out-of-range input (including NaN — every comparison is false) deterministically
/// maps to `low`. Valid inputs are guaranteed by INV-2 at `PetState`; TASK-013
/// property-sweeps the full 0...100 range against the PRD tables.
public func makeMoodBand(_ mood: Double) -> MoodBand {
    if mood >= Thresholds.Band.joyfulLowerBound { return .joyful }
    if mood >= Thresholds.Band.contentLowerBound { return .content }
    if mood >= Thresholds.Band.lowUpperBound { return .wistful }
    return .low
}

/// Derives the energy band from the energy scalar (PRD §3.2). Pure; same
/// cut-off and totality rules as `makeMoodBand` (the two PRD tables share one
/// cut-off triple — `Thresholds.Band`).
public func makeEnergyBand(_ energy: Double) -> EnergyBand {
    if energy >= Thresholds.Band.joyfulLowerBound { return .energetic }
    if energy >= Thresholds.Band.contentLowerBound { return .relaxed }
    if energy >= Thresholds.Band.lowUpperBound { return .drowsy }
    return .exhausted
}

/// Derives the bond stage from the cumulative bond (PRD §3.3). Pure. Inputs
/// below 0 deterministically map to `newFriends`; the INV-3 range at
/// `PetState` keeps real values inside 0...1000 (the 1000 plateau is
/// Soul Companions — FR-10 AC-2, PRD §3.3). TASK-013 property-sweeps the
/// range against the PRD tables (stage thresholds 149/399/749 as upper
/// bounds; first-value constants in `Thresholds.Bond`).
public func makeBondStage(_ bond: Int) -> BondStage {
    if bond >= Thresholds.Bond.soulCompanionsAt { return .soulCompanions }
    if bond >= Thresholds.Bond.bestFriendsAt { return .bestFriends }
    if bond >= Thresholds.Bond.gettingCloseAt { return .gettingClose }
    return .newFriends
}
