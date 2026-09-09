import Foundation
import Testing
@testable import MomoCore

/// The fold constants pinned to their spec literals — 05-technical-architecture
/// §4.3 (fold table) and the PRD-normative values it cites (§3.1 attractor/
/// coupling/floor, §3.2 night restore + wake clamp). TASK-013's anti-echo
/// discipline: this file is the ONLY place the raw literals may appear in
/// tests; every other test references `FoldRules` itself, so a spec change
/// surfaces as exactly one pin failure plus one constants edit.
@Suite("FoldRules — §4.3 literals pinned")
struct FoldRulesPinnedTests {

    @Test("night window bounds: 22:00 onset, 07:00 wake (D11 / §4.3)")
    func nightBounds() {
        #expect(FoldRules.nightOnsetHour == 22)
        #expect(FoldRules.morningWakeHour == 7)
    }

    @Test("waking energy decline is −1.5 pts/h (§4.3)")
    func wakingDecline() {
        #expect(FoldRules.wakingEnergyDeclinePerHour == -1.5)
    }

    @Test("night restore 85 = engine-owned starting value (PRD §3.2); wake clamp ≥ 75 = PRD-normative")
    func nightRestoreAndWakeClamp() {
        #expect(FoldRules.nightRestoreTarget == 85)
        #expect(FoldRules.wakeEnergyClamp == 75)
    }

    @Test("mood attractor: target 60, τ = 3 h (PRD §3.1, normative)")
    func attractor() {
        #expect(FoldRules.moodAttractorTarget == 60)
        #expect(FoldRules.moodAttractorTauHours == 3)
    }

    @Test("mood coupling target 35 and floor 25 (PRD §3.1, normative)")
    func couplingAndFloor() {
        #expect(FoldRules.moodCoupledTarget == 35)
        #expect(FoldRules.moodFloor == 25)
    }

    @Test("nap restore +20 = engine-owned starting value (PRD §3.2 care anchor)")
    func napRestore() {
        #expect(FoldRules.napRestoreEnergy == 20)
    }

    @Test("the coupling trigger really is the Drowsy/Exhausted band (§4.3 ties to PRD §3.2 bands)")
    func couplingBandTies() {
        // The bands the coupling reads: 20–44 Drowsy, 0–19 Exhausted —
        // confirming the FoldRules coupling actually fires for a test energy
        // of 10 and does NOT fire at 80 (Energetic; band cut-offs are
        // Thresholds' pins).
        #expect(makeEnergyBand(10) == .exhausted)
        #expect(makeEnergyBand(80) == .energetic)
    }
}
