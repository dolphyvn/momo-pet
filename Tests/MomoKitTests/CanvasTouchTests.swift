import Testing
import Foundation
import MomoCore
@testable import MomoKit

/// The canvas touch vocabulary's suite (TASK-034 R1; 04 §2.3 + §6.1; 03
/// §5.1): the doc-normative zone partition, the pure touch classifier, the
/// pure tap pairing (with the clock-reset guard), the custom actions'
/// pinned vocabulary and zone-less intents, and the UX-8 announcement gate
/// tied to the REAL selected touch key. Behavior tests read the
/// `CanvasTouchLaws` constants; the constants themselves are pinned raw
/// once below (the anti-echo exception) with their authority labels — the
/// two grid numbers are doc-normative, the recognizer timings are
/// presentation-owned tunables.
@Suite("Canvas touch vocabulary — pure layer (TASK-034 R1)")
struct CanvasTouchTests {

    // MARK: The zone partition (04 §2.3)

    @Test("the zone rule: head above the rule line, belly at and below it, total at the extremes")
    func zonePartition() {
        #expect(CanvasZoneHitTest.zone(normalizedY: 0) == .head)
        #expect(CanvasZoneHitTest.zone(normalizedY: 379) == .head, "the head anchor's band (§2.3 y ≈ 380)")
        #expect(CanvasZoneHitTest.zone(normalizedY: 549.999) == .head)
        #expect(CanvasZoneHitTest.zone(normalizedY: 550) == .belly, "the boundary value itself is belly")
        #expect(CanvasZoneHitTest.zone(normalizedY: 760) == .belly, "the belly anchor's band (§2.3 y ≈ 760)")
        #expect(CanvasZoneHitTest.zone(normalizedY: 1000) == .belly)
        // Total: out-of-grid y keeps classifying (INV-2's no-dead-zones
        // reading — a tap in the canvas region's padding above the stage
        // square maps to a negative grid y and still lands in a zone).
        #expect(CanvasZoneHitTest.zone(normalizedY: -120) == .head)
        #expect(CanvasZoneHitTest.zone(normalizedY: 2400) == .belly)
    }

    // MARK: The classifier (§6.1's rows)

    @Test("movement at/above the threshold is a stroke, whatever the hold")
    func strokeClassification() {
        #expect(CanvasTouchClassifier.completedGesture(
            holdSeconds: 0, maxMovementGrid: CanvasTouchLaws.strokeMovementGrid, zone: .head
        ) == .stroke(.head))
        #expect(CanvasTouchClassifier.completedGesture(
            holdSeconds: 9, maxMovementGrid: CanvasTouchLaws.strokeMovementGrid * 4, zone: .belly
        ) == .stroke(.belly))
    }

    @Test("a still hold at/above the threshold is a long-press; below either threshold is a tap-speed touch")
    func longPressAndTapSpeedClassification() {
        #expect(CanvasTouchClassifier.completedGesture(
            holdSeconds: CanvasTouchLaws.longPressMinimumSeconds, maxMovementGrid: 0, zone: .head
        ) == .longPress(.head))
        #expect(CanvasTouchClassifier.completedGesture(
            holdSeconds: CanvasTouchLaws.longPressMinimumSeconds - 0.001, maxMovementGrid: 0, zone: .belly
        ) == nil, "just under the hold threshold: tap-speed — the SEQUENCE decides")
        #expect(CanvasTouchClassifier.completedGesture(
            holdSeconds: 3, maxMovementGrid: CanvasTouchLaws.strokeMovementGrid - 0.001, zone: .head
        ) == .longPress(.head),
           "under the movement threshold with a long hold is the LONG-PRESS — the stroke bar was missed, the hold was not")
    }

    // MARK: The tap pairing (§6.1's double-tap row)

    @Test("a single tap parks; its window maturing dispatches it; a second tap inside the window pairs")
    func tapPairing() {
        let sequence = CanvasTapSequence()

        // First tap parks — no gesture yet.
        let (parked, none) = sequence.recording(zone: .head, upAt: 10)
        #expect(none == nil)
        #expect(parked.hasPendingTap)

        // The window maturing unclaimed dispatches the parked tap. The
        // probe sits clearly PAST the edge (not on it): `10 + 0.35 - 10`
        // re-rounds a hair below 0.35 in binary, and an edge-exact probe
        // would pin the fp artifact, not the law.
        let (drained, matured) = parked.maturing(now: 10 + CanvasTouchLaws.doubleTapWindowSeconds * 2)
        #expect(matured == .tap(.head))
        #expect(!drained.hasPendingTap)
        #expect(parked.maturing(now: 10 + CanvasTouchLaws.doubleTapWindowSeconds - 0.001).gesture == nil,
                "one tick before the window matures: nothing yet")

        // A second tap inside the window pairs into the zone-less double-tap.
        let (paired, doubled) = parked.recording(zone: .belly, upAt: 10 + CanvasTouchLaws.doubleTapWindowSeconds)
        #expect(doubled == .doubleTap, "the double-tap is one row for both zones")
        #expect(!paired.hasPendingTap, "a pairing drains the state")
        // At exactly the window edge it still pairs (the window is inclusive).
        let (edgePaired, edgeDoubled) = parked.recording(zone: .head, upAt: 10 + CanvasTouchLaws.doubleTapWindowSeconds)
        #expect(edgeDoubled == .doubleTap)
        #expect(!edgePaired.hasPendingTap)
    }

    @Test("a second tap outside the window becomes the new pending tap")
    func lateSecondTapParks() {
        let sequence = CanvasTapSequence()
        let (parked, _) = sequence.recording(zone: .head, upAt: 10)
        let (reParked, gesture) = parked.recording(zone: .belly, upAt: 10 + CanvasTouchLaws.doubleTapWindowSeconds + 0.001)
        #expect(gesture == nil)
        #expect(reParked.hasPendingTap)
    }

    @Test("a clock reset underneath never pairs (the pause-zeroed CharacterClock)")
    func clockResetNeverPairs() {
        let sequence = CanvasTapSequence()
        let (parked, _) = sequence.recording(zone: .head, upAt: 10)
        // The second tap's stamp runs BACKWARD (the clock re-anchored) —
        // pairing demands the second tap to END after the first.
        let (afterReset, gesture) = parked.recording(zone: .belly, upAt: 3)
        #expect(gesture == nil, "a backward stamp is a reset, not a fast pair")
        #expect(afterReset.hasPendingTap, "the tap becomes the new pending one")
    }

    @Test("resetting drops the parked tap (the cancellation seam)")
    func resettingDropsThePendingTap() {
        let sequence = CanvasTapSequence()
        let (parked, _) = sequence.recording(zone: .head, upAt: 10)
        let reset = parked.resetting()
        #expect(!reset.hasPendingTap)
        #expect(reset.maturing(now: 10 + CanvasTouchLaws.doubleTapWindowSeconds).gesture == nil,
                "nothing dispatches from a reset state")
    }

    // MARK: The VoiceOver custom actions (03 §5.1; FR-17)

    @Test("the custom actions are exactly the doc's two labels, in order")
    func customActionVocabularyPinned() {
        #expect(CanvasCustomAction.allCases == [.pat, .cuddle])
        #expect(CanvasCustomAction.pat.rawValue == "Pat")
        #expect(CanvasCustomAction.cuddle.rawValue == "Cuddle")
    }

    @Test("the custom actions route the zone-less convention (no rotor geometry)")
    func customActionIntentsAreZoneless() {
        func isZoneless(_ kind: InteractionIntent.Kind, gesture: PatGesture) -> Bool {
            if case .pat(gesture: gesture, zone: nil) = kind { return true }
            return false
        }
        #expect(isZoneless(CanvasCustomAction.pat.intent, gesture: .tap))
        #expect(isZoneless(CanvasCustomAction.cuddle.intent, gesture: .longPress))
    }

    // MARK: The announcement gate (UX-8 — R7)

    @Test("the gate admits all four react families' keys — including the REAL selected touch one — and refuses every non-react class")
    func announcementGate() {
        let selected = LineSelection.reactLineKey(
            petID: AppModelFixture.petID,
            dayKey: "2026-09-08",
            family: .touch
        )
        #expect(selected == "momo.line.react.touch.02", "the fixture (petID, day) at the current epoch draws .02 (the epoch-4 resalt keeps the touch residue)")
        #expect(SpokenReaction.announcementKey(for: selected) == selected)

        #expect(SpokenReaction.announcementKey(for: "momo.line.react.touch.00") == "momo.line.react.touch.00")
        #expect(SpokenReaction.announcementKey(for: "momo.line.react.feed.00") == "momo.line.react.feed.00",
                "TASK-035 R7 widens the gate to every react family")
        #expect(SpokenReaction.announcementKey(for: "momo.line.react.play.05") == "momo.line.react.play.05")
        #expect(SpokenReaction.announcementKey(for: "momo.line.react.care.03") == "momo.line.react.care.03")
        #expect(SpokenReaction.announcementKey(for: "momo.line.day.02") == nil,
                "visual body-copy keys are never announced by this seam")
        #expect(SpokenReaction.announcementKey(for: "momo.line.care-moment.01") == nil,
                "the care-moment VISUAL class is not a react key")
        #expect(SpokenReaction.announcementKey(for: "momo.line.morning.07") == nil,
                "the ambient slots stay out")
        #expect(SpokenReaction.announcementKey(for: nil) == nil,
                "plans without a line announce nothing")
        #expect(SpokenReaction.announcementKey(for: "momo.line.react.touchX.00") == nil,
                "the prefix includes the family's trailing dot")
        #expect(SpokenReaction.announcementKey(for: "momo.line.reactx.touch.00") == nil,
                "the react prefix carries the trailing dot — lookalike namespaces stay out")
    }

    // MARK: The laws' raw pins (the anti-echo exception)

    @Test("the laws' raw values, each with its authority")
    func lawsPinned() {
        #expect(CanvasTouchLaws.stageGridSide == 1000, "§2.1's normalized grid side (doc-normative)")
        #expect(CanvasTouchLaws.zoneSplitY == 550, "§2.3's zone rule line (doc-normative)")
        #expect(CanvasTouchLaws.strokeMovementGrid == 60, "presentation-owned: the stroke movement threshold")
        #expect(CanvasTouchLaws.longPressMinimumSeconds == 0.5, "presentation-owned: the long-press hold floor")
        #expect(CanvasTouchLaws.doubleTapWindowSeconds == 0.35, "presentation-owned: the double-tap window")
        #expect(CanvasTouchLaws.spokenTouchPrefix == "momo.line.react.touch.", "the UX-8 gate's touch-family namespace")
        #expect(CanvasTouchLaws.spokenReactPrefix == "momo.line.react.", "TASK-035 R7's widened gate namespace")
        #expect(CanvasTouchLaws.spokenFamilies == ["touch", "feed", "play", "care"],
                "the gate's family table mirrors CopyRules.ReactFamily's raw values")
    }
}
