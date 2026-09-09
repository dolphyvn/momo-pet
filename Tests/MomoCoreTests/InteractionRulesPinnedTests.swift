import Foundation
import Testing
@testable import MomoCore

/// The interaction-semantics constants pinned to their spec literals —
/// 05-technical-architecture §4.4 (numeric effects) and §4.5 (satiety window,
/// repetition curve), the PRD-normative values they cite (§3.1 ceiling,
/// FR-8 AC-1 window), and the reaction keys' raw strings (04 §8.4 namespace;
/// INV-11). TASK-016's anti-echo discipline: this file is the ONLY place the
/// raw literals may appear in tests; every behavior test references
/// `InteractionRules` / `ReactionKeys` themselves, so a spec change surfaces
/// as exactly one pin failure plus one constants edit.
@Suite("InteractionRules + ReactionKeys — §4.4/§4.5 literals pinned")
struct InteractionRulesPinnedTests {

    // MARK: Numeric effects (05 §4.4 — engine-owned starting values)

    @Test("play round: −10 energy, +6 mood, at the cease (§4.4)")
    func playDeltas() {
        #expect(InteractionRules.playRoundEnergyDelta == -10)
        #expect(InteractionRules.playRoundMoodDelta == 6)
    }

    @Test("meal: +6 energy, +4 mood (§4.4); nibble class ×0.25 (I-2)")
    func mealDeltas() {
        #expect(InteractionRules.mealEnergyDelta == 6)
        #expect(InteractionRules.mealMoodDelta == 4)
        #expect(InteractionRules.nibbleEffectMultiplier == 0.25)
    }

    @Test("touch +2 mood in every state; past the day's hello, bond never moves (G2 — petting VOLUME banks nothing; title corrected per REVIEW-TASK-017 NITPICK-3)")
    func touchDelta() {
        #expect(InteractionRules.touchMoodDelta == 2)
    }

    @Test("tuck-in: +3 mood, +2 energy (§4.4, no repetition multiplier — care)")
    func tuckInDeltas() {
        #expect(InteractionRules.tuckInMoodDelta == 3)
        #expect(InteractionRules.tuckInEnergyDelta == 2)
    }

    // MARK: Ceiling + windows

    @Test("interaction mood ceiling 92 (PRD §3.1, normative)")
    func ceiling() {
        #expect(InteractionRules.interactionMoodCeiling == 92)
    }

    @Test("satiety window 90 min, split 30 min; the split is interior to the window (§4.5)")
    func satietyWindows() {
        #expect(InteractionRules.satietyWindowMinutes == 90)
        #expect(InteractionRules.satietySplitMinutes == 30)
        #expect(InteractionRules.satietySplitMinutes < InteractionRules.satietyWindowMinutes)
    }

    // MARK: Repetition curve (05 §4.5)

    @Test("repetition curve is exactly 1.0 / 0.6 / 0.25 / 0.0 (§4.5 starting curve)")
    func curve() {
        #expect(InteractionRules.repetitionMultipliers == [1.0, 0.6, 0.25, 0.0])
    }

    @Test("repetitionMultiplier clamps: 4th+ shares 0.0, a negative index reads instance 1")
    func curveClamping() {
        #expect(InteractionRules.repetitionMultiplier(instanceIndex: 0) == 1.0)
        #expect(InteractionRules.repetitionMultiplier(instanceIndex: 2) == 0.25)
        #expect(InteractionRules.repetitionMultiplier(instanceIndex: 3) == 0.0)
        #expect(InteractionRules.repetitionMultiplier(instanceIndex: 100) == 0.0)
        #expect(InteractionRules.repetitionMultiplier(instanceIndex: -1) == 1.0)
    }

    // MARK: Tuck-in window (FR-8 AC-1)

    @Test("tuck-in window opens at 20:00 — the same PRD hour as Q6's window start, pinned equal")
    func tuckInWindowHour() {
        #expect(InteractionRules.tuckInWindowStartHour == 20)
        #expect(InteractionRules.tuckInWindowStartHour == Thresholds.Quest.q6WindowStartHour)
    }

    @Test("isTuckInWindow: [20:00, 07:00) local — exact hour bounds on a UTC calendar")
    func tuckInWindowBounds() {
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = TimeZone(identifier: "UTC")!
        func at(_ iso: String) -> Instant { ISO8601DateFormatter().date(from: iso)! }
        let day = "2026-09-08"
        #expect(!InteractionRules.isTuckInWindow(at("\(day)T19:00:00Z"), calendar: utc))
        #expect(InteractionRules.isTuckInWindow(at("\(day)T20:00:00Z"), calendar: utc))
        #expect(InteractionRules.isTuckInWindow(at("\(day)T23:00:00Z"), calendar: utc))
        #expect(InteractionRules.isTuckInWindow(at("\(day)T00:00:00Z"), calendar: utc))
        #expect(InteractionRules.isTuckInWindow(at("\(day)T06:00:00Z"), calendar: utc))
        #expect(!InteractionRules.isTuckInWindow(at("\(day)T07:00:00Z"), calendar: utc))
    }

    // MARK: Reaction keys (INV-11 — the catalog manifest enumerates these)

    @Test("touch keys carry 04 §8.4's dot-namespace exactly (gesture[.zone])")
    func touchKeys() {
        #expect(ReactionKeys.tapHead.rawValue == "react.tap.head")
        #expect(ReactionKeys.tapBelly.rawValue == "react.tap.belly")
        #expect(ReactionKeys.tap.rawValue == "react.tap")
        #expect(ReactionKeys.doubleTap.rawValue == "react.doubleTap")
        #expect(ReactionKeys.longPressHead.rawValue == "react.longPress.head")
        #expect(ReactionKeys.longPressBelly.rawValue == "react.longPress.belly")
        #expect(ReactionKeys.longPress.rawValue == "react.longPress")
        #expect(ReactionKeys.strokeHead.rawValue == "react.stroke.head")
        #expect(ReactionKeys.strokeBelly.rawValue == "react.stroke.belly")
        #expect(ReactionKeys.stroke.rawValue == "react.stroke")
    }

    @Test("sleep/meal/play beats carry their §8.4 keys exactly (incl. the state. convention)")
    func beatKeys() {
        #expect(ReactionKeys.stir.rawValue == "react.stir")
        #expect(ReactionKeys.politelyFull.rawValue == "react.politelyFull")
        #expect(ReactionKeys.gentleDecline.rawValue == "react.gentleDecline")
        #expect(ReactionKeys.sleepyNibbles.rawValue == "react.sleepyNibbles")
        #expect(ReactionKeys.settling.rawValue == "react.settling")
        #expect(ReactionKeys.blanketAdjust.rawValue == "react.blanketAdjust")
        #expect(ReactionKeys.eating.rawValue == "state.eating")
        #expect(ReactionKeys.nibble.rawValue == "react.nibble")
        #expect(ReactionKeys.playReady.rawValue == "react.playReady")
        #expect(ReactionKeys.cheer.rawValue == "react.cheer")
        #expect(ReactionKeys.decline.rawValue == "react.decline")
    }
}
