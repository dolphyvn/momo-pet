import Foundation
import Testing
@testable import MomoCore

/// The bond-ledger constants pinned to their spec literals — PRD §3.3's
/// earning table (normative) as repeated by 05-technical-architecture §4.6's
/// ledger table, plus the variety trio's membership. TASK-017's anti-echo
/// discipline: this file is the ONLY place the raw award literals may appear;
/// every behavior test references `BondRules` itself, so a spec change
/// surfaces as exactly one pin failure plus one constants edit.
@Suite("BondRules — §4.6 literals pinned")
struct BondRulesPinnedTests {

    // MARK: The earning table (PRD §3.3 — normative)

    @Test("hello: +8, once per dayKey, device-agnostic (UX-6, INV-7)")
    func helloDelta() {
        #expect(BondRules.helloBondDelta == 8)
    }

    @Test("quest: +4 each (PRD §3.3 — max 3/day is TASK-018's detection)")
    func questDelta() {
        #expect(BondRules.questBondDelta == 4)
    }

    @Test("variety: +6 when all three families land in one day (PRD §3.3)")
    func varietyDelta() {
        #expect(BondRules.varietyBondDelta == 6)
    }

    @Test("daily cap: +20 enforced by clamp-at-award (INV-5; PRD §3.3)")
    func dailyCap() {
        #expect(BondRules.dailyBondCap == 20)
    }

    // MARK: Cross-home equality (the InteractionRules.tuckInWindowStartHour
    // discipline — one PRD number, two homes, pinned equal)

    @Test("daily cap equals Thresholds.Bond.dailyCap — the same PRD number, pinned equal")
    func capHomesAgree() {
        #expect(BondRules.dailyBondCap == Thresholds.Bond.dailyCap)
    }

    // MARK: The PRD's own pacing arithmetic (§3.3 / 05 §4.6)

    @Test("a 3-quest varied day reaches the cap exactly: 8 + 4·3 = 20 (variety adds 0)")
    func threeQuestDayArithmetic() {
        #expect(BondRules.helloBondDelta + 3 * BondRules.questBondDelta == BondRules.dailyBondCap)
    }

    @Test("a 2-quest varied day reaches the cap with the +6 truncated: 8 + 4·2 + 6 → 20")
    func twoQuestDayArithmetic() {
        let awards = BondRules.helloBondDelta + 2 * BondRules.questBondDelta + BondRules.varietyBondDelta
        #expect(awards > BondRules.dailyBondCap) // the clamp is what lands it at 20
        #expect(awards - BondRules.varietyBondDelta + (BondRules.dailyBondCap - BondRules.helloBondDelta - 2 * BondRules.questBondDelta) == BondRules.dailyBondCap)
    }

    // MARK: The variety trio (PRD §3.3 — feed/play/care; NOT greet/pet)

    @Test("variety trio is exactly {feed, play, care}")
    func varietyTrioMembership() {
        #expect(BondRules.varietyTrio == [.feed, .play, .care])
        #expect(!BondRules.varietyTrio.contains(.greet))
        #expect(!BondRules.varietyTrio.contains(.pet))
    }
}
