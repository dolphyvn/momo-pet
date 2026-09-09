import Testing
@testable import MomoCore

/// AC-2 anti-regression layer for TASK-013: the `Thresholds` constants are
/// pinned against the PRD's numbers AS LITERALS transcribed from the
/// normative tables (§3.1–3.3) — deliberately NOT compared to themselves or
/// to the derivations, so a silent constant edit fails here even though the
/// constant-fed sweeps (`DomainPropertySweepTests`) would remain
/// self-consistent. The PRD-literal edge-mapping tests go one step further:
/// both the input values and the expected bands are PRD table content, with
/// no constant in between, so a drifted constant cannot hide.
///
/// The PRD table values pinned below (normative source):
/// - §3.1 Mood: scalar 0–100; Low 0–19, Wistful 20–44, Content 45–74,
///   Joyful 75–100 (each range lower-inclusive; a cut-off value belongs to
///   the band above it).
/// - §3.2 Energy: scalar 0–100; Exhausted 0–19, Drowsy 20–44, Relaxed 45–74,
///   Energetic 75–100 (same cut-off triple as mood).
/// - §3.3 Bond: cumulative scalar 0–1000; New Friends 0–149, Getting Close
///   150–399, Best Friends 400–749, Soul Companions 750–1000; daily cap +20.
@Suite("Thresholds pinned to PRD §3.1–3.3 (TASK-013, AC-2)")
struct ThresholdsPinnedToPRDTests {

    // MARK: - Constant values == PRD literals

    @Test("the scalar range is exactly PRD's 0–100 (§3.1–3.2, D10)")
    func scalarRangePinned() {
        #expect(Thresholds.Scalar.lower == 0, "PRD §3.1: internal continuous scalar starts at 0")
        #expect(Thresholds.Scalar.upper == 100, "PRD §3.1: internal continuous scalar ends at 100")
    }

    @Test("the band cut-offs are exactly PRD's 20/45/75 first-values (§3.1–3.2)")
    func bandCutOffsPinned() {
        // The constants are each band's FIRST value (the PRD's lower-inclusive
        // ranges): Wistful/Drowsy 20–44 → 20, Content/Relaxed 45–74 → 45,
        // Joyful/Energetic 75–100 → 75.
        #expect(Thresholds.Band.lowUpperBound == 20, "PRD: Wistful/Drowsy begins at 20 (0–19 is Low/Exhausted)")
        #expect(Thresholds.Band.contentLowerBound == 45, "PRD: Content/Relaxed begins at 45 (20–44 is Wistful/Drowsy)")
        #expect(Thresholds.Band.joyfulLowerBound == 75, "PRD: Joyful/Energetic begins at 75 (45–74 is Content/Relaxed)")
    }

    @Test("the bond stage constants are exactly PRD's 150/400/750 with range 0–1000 and cap +20 (§3.3)")
    func bondConstantsPinned() {
        #expect(Thresholds.Bond.minimum == 0, "PRD §3.3: cumulative scalar starts at 0")
        #expect(Thresholds.Bond.gettingCloseAt == 150, "PRD: Getting Close begins at 150 (0–149 is New Friends)")
        #expect(Thresholds.Bond.bestFriendsAt == 400, "PRD: Best Friends begins at 400 (150–399 is Getting Close)")
        #expect(Thresholds.Bond.soulCompanionsAt == 750, "PRD: Soul Companions begins at 750 (400–749 is Best Friends)")
        #expect(Thresholds.Bond.maximum == 1000, "PRD §3.3: cumulative scalar ends at 1000 (the plateau)")
        #expect(Thresholds.Bond.dailyCap == 20, "PRD §3.3: daily cap +20 (G1)")
    }

    // MARK: - Partition-consistency property (tiling the full domain)

    /// The four band ranges derived from the constants must tile 0…100 with
    /// no gap and no overlap, AND each derived range must equal its PRD table
    /// range verbatim (Low 0–19, Wistful 20–44, Content 45–74, Joyful 75–100).
    @Test("the band ranges derived from the constants tile 0…100 exactly as the PRD tables read (§3.1–3.2)")
    func bandPartitionTiles() {
        // The PRD cut-offs are whole numbers; the integer derivation below is
        // lossless only if the Double constants are integral — asserted, not
        // assumed, so the tiling can never silently use a truncated value.
        for cutOff in [Thresholds.Band.lowUpperBound, Thresholds.Band.contentLowerBound, Thresholds.Band.joyfulLowerBound] {
            #expect(
                cutOff.truncatingRemainder(dividingBy: 1) == 0,
                "band cut-off \(cutOff) is not integral; the PRD's integer partition would not be derivable"
            )
        }
        let wistful = Int(Thresholds.Band.lowUpperBound)
        let content = Int(Thresholds.Band.contentLowerBound)
        let joyful = Int(Thresholds.Band.joyfulLowerBound)

        let derived: [ClosedRange<Int>] = [
            Int(Thresholds.Scalar.lower)...(wistful - 1),
            wistful...(content - 1),
            content...(joyful - 1),
            joyful...Int(Thresholds.Scalar.upper),
        ]

        // Tiling property from the constants alone: contiguous, covering,
        // gap-free and overlap-free (total size == domain size).
        #expect(derived.first?.lowerBound == Int(Thresholds.Scalar.lower), "the partition must start at the scalar floor")
        #expect(derived.last?.upperBound == Int(Thresholds.Scalar.upper), "the partition must end at the scalar ceiling")
        for (lower, upper) in zip(derived, derived.dropFirst()) {
            #expect(upper.lowerBound == lower.upperBound + 1, "gap/overlap between \(lower) and \(upper)")
        }
        #expect(
            derived.map(\.count).reduce(0, +) == Int(Thresholds.Scalar.upper) - Int(Thresholds.Scalar.lower) + 1,
            "the derived ranges must cover the scalar domain exactly once"
        )

        // Cross-check against the PRD tables verbatim (mood and energy share
        // one cut-off triple, so one integer tiling serves both §3.1 and §3.2).
        #expect(derived == [0...19, 20...44, 45...74, 75...100])
    }

    /// The four stage ranges derived from the constants must tile 0…1000 with
    /// no gap and no overlap, AND each derived range must equal its PRD table
    /// range verbatim (0–149, 150–399, 400–749, 750–1000).
    @Test("the bond stage ranges derived from the constants tile 0…1000 exactly as the PRD table reads (§3.3)")
    func bondStagePartitionTiles() {
        let derived: [ClosedRange<Int>] = [
            Thresholds.Bond.minimum...(Thresholds.Bond.gettingCloseAt - 1),
            Thresholds.Bond.gettingCloseAt...(Thresholds.Bond.bestFriendsAt - 1),
            Thresholds.Bond.bestFriendsAt...(Thresholds.Bond.soulCompanionsAt - 1),
            Thresholds.Bond.soulCompanionsAt...Thresholds.Bond.maximum,
        ]

        // Tiling property from the constants alone.
        #expect(derived.first?.lowerBound == Thresholds.Bond.minimum, "the stage partition must start at the bond floor")
        #expect(derived.last?.upperBound == Thresholds.Bond.maximum, "the stage partition must end at the bond plateau")
        for (lower, upper) in zip(derived, derived.dropFirst()) {
            #expect(upper.lowerBound == lower.upperBound + 1, "gap/overlap between \(lower) and \(upper)")
        }
        #expect(
            derived.map(\.count).reduce(0, +) == Thresholds.Bond.maximum - Thresholds.Bond.minimum + 1,
            "the derived stage ranges must cover the bond domain exactly once"
        )

        // Cross-check against the PRD §3.3 table verbatim.
        #expect(derived == [0...149, 150...399, 400...749, 750...1000])
    }

    // MARK: - PRD-literal edge mapping (no constant in between)

    /// At every PRD §3.1 range edge, the mood derivation returns the PRD's
    /// named band — inputs and expectations are both table content, so this
    /// fails if either the constants or the derivation drift from the PRD.
    @Test("at every PRD table edge the mood derivation returns the PRD's named band (§3.1)")
    func prdMoodEdgeMapping() {
        #expect(makeMoodBand(0) == .low)
        #expect(makeMoodBand(19) == .low)
        #expect(makeMoodBand(20) == .wistful)
        #expect(makeMoodBand(44) == .wistful)
        #expect(makeMoodBand(45) == .content)
        #expect(makeMoodBand(74) == .content)
        #expect(makeMoodBand(75) == .joyful)
        #expect(makeMoodBand(100) == .joyful)
    }

    @Test("at every PRD table edge the energy derivation returns the PRD's named band (§3.2)")
    func prdEnergyEdgeMapping() {
        #expect(makeEnergyBand(0) == .exhausted)
        #expect(makeEnergyBand(19) == .exhausted)
        #expect(makeEnergyBand(20) == .drowsy)
        #expect(makeEnergyBand(44) == .drowsy)
        #expect(makeEnergyBand(45) == .relaxed)
        #expect(makeEnergyBand(74) == .relaxed)
        #expect(makeEnergyBand(75) == .energetic)
        #expect(makeEnergyBand(100) == .energetic)
    }

    @Test("at every PRD table edge the stage derivation returns the PRD's named stage (§3.3)")
    func prdBondEdgeMapping() {
        #expect(makeBondStage(0) == .newFriends)
        #expect(makeBondStage(149) == .newFriends)
        #expect(makeBondStage(150) == .gettingClose)
        #expect(makeBondStage(399) == .gettingClose)
        #expect(makeBondStage(400) == .bestFriends)
        #expect(makeBondStage(749) == .bestFriends)
        #expect(makeBondStage(750) == .soulCompanions)
        #expect(makeBondStage(1000) == .soulCompanions)
    }

    // MARK: - Greeting thresholds (TASK-019; Thresholds.Greeting)

    @Test("the greeting thresholds are exactly the 5-minute regreet floor and the 36-hour missed-you bound (TASK-019)")
    func greetingThresholdsPinned() {
        // FR-12 AC-2's normative absence bound: 36 hours ⇒ .missedYou.
        #expect(Thresholds.Greeting.missedYouAfterHours == 36,
                "FR-12 AC-2: an absence of 36 h or more greets .missedYou — changing it is a spec change")
        // The engine-owned re-greet floor (an in-session re-evaluation is not
        // an arrival; scenePhase flapping must not re-greet). Not PRD text —
        // a TASK-019 tunable, pinned so a silent edit still bites.
        #expect(Thresholds.Greeting.regreetFloorMinutes == 5,
                "the re-greet floor is the engine-owned 5-minute starting value; retune deliberately, not silently")
    }
}
