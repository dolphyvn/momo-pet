import Testing
@testable import MomoCore

/// Exhaustive full-range property sweeps for TASK-013 (AC-1; FR-9 AC-1's
/// "property-style test over the range"): EVERY integer of the PRD domains —
/// 0…100 for both presentation bands, 0…1000 for bond stages — not samples.
///
/// Single-source discipline (Requirement 3): the expected partitions below are
/// computed from the same `Thresholds` constants the derivations read — no
/// re-hardcoded 20/45/75/149/399/749 here. The constants' VALUES are pinned
/// against the PRD literals by `ThresholdsPinnedToPRDTests`, so a silent
/// constant change still fails (the two layers together prove "the domain
/// matches the PRD"). The expected partition is written in a deliberately
/// different formulation than the implementation (ascending integer
/// partial-range switch vs the derivations' descending `Double` comparison
/// cascade) so an off-by-one or case mix-up cannot be mirrored on both sides.
///
/// Determinism (Requirement 5): pure-function sweeps — no clock, no RNG; the
/// idempotence test re-runs each full sweep and requires identical output.
@Suite("Domain property sweeps (TASK-013)")
struct DomainPropertySweepTests {

    // MARK: - Expected partitions (derived from the single-source constants)

    /// PRD §3.1 mood partition expressed as ascending integer partial ranges.
    /// `..<Int(cut-off)` is the PRD's inclusive-range form (Low 0–19, Wistful
    /// 20–44, Content 45–74, Joyful 75–100); lossless only for integral
    /// cut-offs, which `ThresholdsPinnedToPRDTests` asserts explicitly.
    private func prdMoodPartition(_ value: Int) -> MoodBand {
        switch value {
        case ..<Int(Thresholds.Band.lowUpperBound): return .low
        case ..<Int(Thresholds.Band.contentLowerBound): return .wistful
        case ..<Int(Thresholds.Band.joyfulLowerBound): return .content
        default: return .joyful
        }
    }

    /// PRD §3.2 energy partition — same cut-off triple, energy case names.
    private func prdEnergyPartition(_ value: Int) -> EnergyBand {
        switch value {
        case ..<Int(Thresholds.Band.lowUpperBound): return .exhausted
        case ..<Int(Thresholds.Band.contentLowerBound): return .drowsy
        case ..<Int(Thresholds.Band.joyfulLowerBound): return .relaxed
        default: return .energetic
        }
    }

    /// PRD §3.3 stage partition as ascending integer partial ranges
    /// (New Friends 0–149, Getting Close 150–399, Best Friends 400–749,
    /// Soul Companions 750–1000 — the constants are each stage's first value).
    private func prdBondPartition(_ value: Int) -> BondStage {
        switch value {
        case ..<Thresholds.Bond.gettingCloseAt: return .newFriends
        case ..<Thresholds.Bond.bestFriendsAt: return .gettingClose
        case ..<Thresholds.Bond.soulCompanionsAt: return .bestFriends
        default: return .soulCompanions
        }
    }

    // MARK: - Full-range sweeps (AC-1)

    /// All 101 integer mood inputs, PRD §3.1 partition — both edges of every
    /// band included (0/19/20/44/45/74/75/100 all appear as arguments).
    @Test("mood band: every integer 0…100 matches the PRD §3.1 partition", arguments: 0...100)
    func moodBandSweep(value: Int) {
        #expect(makeMoodBand(Double(value)) == prdMoodPartition(value))
    }

    /// All 101 integer energy inputs, PRD §3.2 partition (same cut-off triple).
    @Test("energy band: every integer 0…100 matches the PRD §3.2 partition", arguments: 0...100)
    func energyBandSweep(value: Int) {
        #expect(makeEnergyBand(Double(value)) == prdEnergyPartition(value))
    }

    /// All 1001 integer bond inputs, PRD §3.3 partition — every stage edge
    /// included (0/149/150/399/400/749/750/1000 all appear as arguments).
    @Test("bond stage: every integer 0…1000 matches the PRD §3.3 partition", arguments: 0...1000)
    func bondStageSweep(value: Int) {
        #expect(makeBondStage(value) == prdBondPartition(value))
    }

    // MARK: - Determinism (Requirement 5)

    @Test("sweeps are deterministic: two full passes over each domain produce identical outputs")
    func sweepsAreIdempotent() {
        let moodFirst = (0...100).map { makeMoodBand(Double($0)) }
        let moodSecond = (0...100).map { makeMoodBand(Double($0)) }
        #expect(moodFirst == moodSecond, "makeMoodBand is not deterministic over 0…100")

        let energyFirst = (0...100).map { makeEnergyBand(Double($0)) }
        let energySecond = (0...100).map { makeEnergyBand(Double($0)) }
        #expect(energyFirst == energySecond, "makeEnergyBand is not deterministic over 0…100")

        let bondFirst = (0...1000).map(makeBondStage)
        let bondSecond = (0...1000).map(makeBondStage)
        #expect(bondFirst == bondSecond, "makeBondStage is not deterministic over 0…1000")
    }
}
