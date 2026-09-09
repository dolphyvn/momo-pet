import Foundation
import MomoCore
import SwiftUI
import Testing

@testable import MomoCharacter

/// TASK-026 Requirement 2 (R1/R2, 04 §2.2): the pure transform-only motion
/// model — every §2.2 channel present (name-for-name), rest pose == zero
/// transforms, per-channel gating, the §2.4 pupil clamp, and the single
/// reference breath channel driving bottom-anchored body scaleY (§7.1).
@Suite("RigMotionModel — §2.2 channels, rest pose, gating, breath, clamp")
struct RigMotionModelTests {

    /// The Content breath cycle (the canonical driver, §7.1 mid-band).
    private var breathT: Double { MomoCurves.breathCycleSeconds }
    /// Inhale-peak instant (T/4): maximal scaleY.
    private var inhale: Double { breathT / 4 }

    /// The joyful state (contrast sample for the display-state pin).
    private static let joyfulState = CharacterDisplayState(
        moodBand: .joyful, energyBand: .energetic, bondStage: .bestFriends,
        wakefulness: .awake, activity: .playing, satietyHint: nil,
        momentRequest: nil)

    // MARK: - §2.2 channel inventory (name-for-name)

    @Test("Channel inventory matches §2.2 name-for-name, group by group")
    func channelInventoryMatchesSectionTwoTwo() {
        let expected: [(group: String, names: [String])] = [
            ("Body", ["bodyScale", "bodyRotation", "bodyPosition"]),
            ("Head", ["headRotation", "headPosition", "headScaleY"]),
            ("Ears", ["earLeftRotation", "earLeftScaleY",
                      "earRightRotation", "earRightScaleY"]),
            ("Tail", ["tailRotation", "tailScaleY"]),
            ("Eyes", ["eyeLeftLidScaleY", "eyeLeftPupilOffset", "eyeLeftLowerLid",
                      "eyeRightLidScaleY", "eyeRightPupilOffset", "eyeRightLowerLid"]),
            ("FaceDetails", ["mouthPose", "cheekOpacity"]),
            ("FrontPaws", ["pawLeftPosition", "pawLeftRotation",
                           "pawRightPosition", "pawRightRotation"]),
            ("Props", ["propFood", "propBlanket", "propSparkleA", "propSparkleB"]),
        ]

        var cursor = 0
        let order = RigChannel.canonicalOrder
        for (group, names) in expected {
            for name in names {
                #expect(cursor < order.count, "missing channel \(group).\(name)")
                guard cursor < order.count else { return }
                #expect(order[cursor].name == name,
                        "channel \(cursor): expected \(name), got \(order[cursor].name)")
                cursor += 1
            }
        }
        #expect(cursor == order.count, "more channels than §2.2 names: \(order.count) > \(cursor)")
    }

    @Test("The canonical channels tile .all exactly — nothing ungated, nothing extra")
    func channelsTileAll() {
        let union = RigChannel.canonicalOrder.reduce(RigChannel()) { $0.union($1.channel) }
        #expect(union == .all)
    }

    // MARK: - Rest pose == zero transforms

    @Test("RigPose.rest is the authored geometry defaults: every channel zeroed")
    func restPoseIsAllIdentity() {
        let rest = RigPose.rest

        #expect(rest.body == .identity)
        #expect(rest.head == .identity)
        #expect(rest.earLeft == .identity)
        #expect(rest.earRight == .identity)
        #expect(rest.tail == .identity)

        #expect(rest.eyeLeft.lidScaleY == 1)
        #expect(rest.eyeLeft.pupilOffset == .zero)
        #expect(rest.eyeLeft.lowerLid == .relaxed)
        #expect(rest.eyeRight.lidScaleY == 1)
        #expect(rest.eyeRight.pupilOffset == .zero)
        #expect(rest.eyeRight.lowerLid == .relaxed)

        #expect(rest.mouth == .neutral)
        #expect(rest.mouth.neutral == 1)
        #expect(rest.mouth.eat == 0)
        #expect(rest.mouth.refuse == 0)

        #expect(rest.cheekOpacity == 1)
        #expect(rest.pawLeft == .identity)
        #expect(rest.pawRight == .identity)

        for prop in [rest.food, rest.blanket, rest.sparkleA, rest.sparkleB] {
            #expect(prop.transform == .identity)
            #expect(prop.opacity == 1)
        }
    }

    @Test("The model at t = 0 renders the rest pose (resumed-but-unaged)")
    func modelAtZeroIsRest() {
        let model = RigMotionModel()
        #expect(model.pose(at: 0, displayState: CharacterClockTests.contentState) == .rest)
    }

    // MARK: - The reference breath channel (§7.1 Content row)

    @Test("Breath drives bottom-anchored body scaleY only: peak 1 + amplitude at T/4")
    func breathDrivesBodyScaleYOnly() {
        let model = RigMotionModel()
        let state = CharacterClockTests.contentState
        let pose = model.pose(at: inhale, displayState: state)

        // CGFloat on both sides: a syntactically mixed CGFloat == Double
        // capture mis-evaluates inside #expect (TASK-026 notes).
        #expect(pose.body.scaleY == CGFloat(1.0 + MomoCurves.breathAmplitude))
        #expect(pose.body.scaleX == 1.0)              // §7.1: scaleY, not width
        #expect(pose.body.rotationDegrees == 0)
        #expect(pose.body.translation == .zero)

        // One reference channel: nothing else moves under breath today.
        #expect(pose.head == .identity)
        #expect(pose.earLeft == .identity)
        #expect(pose.earRight == .identity)
        #expect(pose.tail == .identity)
        #expect(pose.eyeLeft == RigEyePose.rest)
        #expect(pose.eyeRight == RigEyePose.rest)
        #expect(pose.mouth == .neutral)
        #expect(pose.cheekOpacity == 1)
        #expect(pose.pawLeft == .identity)
        #expect(pose.pawRight == .identity)
        for prop in [pose.food, pose.blanket, pose.sparkleA, pose.sparkleB] {
            #expect(prop.transform == .identity)
            #expect(prop.opacity == 1)
        }
    }

    @Test("Breath peaks inside the §7.1 amplitude band across the cycle")
    func breathSamplesStayInsideBand() {
        let model = RigMotionModel()
        let state = CharacterClockTests.contentState
        let steps = 120
        let deviations = (0...steps).map { step -> Double in
            let pose = model.pose(
                at: breathT * Double(step) / Double(steps), displayState: state)
            return abs(Double(pose.body.scaleY) - 1.0)
        }
        // The band constrains the AMPLITUDE (the peak deviation), not each
        // instantaneous sample — a sine spends most of the cycle below 1.5 %.
        #expect(deviations.allSatisfy { $0 <= MomoCurves.breathAmplitudeScaleY.upperBound })
        #expect(MomoCurves.breathAmplitudeScaleY.contains(deviations.max() ?? 0))
    }

    @Test("The pose is independent of display state today — band mapping is TASK-027")
    func displayStateDoesNotAlterThePoseYet() {
        let model = RigMotionModel()
        let low = CharacterDisplayState(
            moodBand: .low, energyBand: .exhausted, bondStage: .newFriends,
            wakefulness: .asleep, activity: nil, satietyHint: nil, momentRequest: nil)

        #expect(model.pose(at: inhale, displayState: Self.joyfulState)
                == model.pose(at: inhale, displayState: low))
    }

    // MARK: - Per-channel gating

    @Test("Disabling bodyScale stops the breath exactly: rest at every instant")
    func disablingBodyScaleStopsBreathExactly() {
        let gated = RigMotionModel(enabledChannels: .all.subtracting(.bodyScale))
        let state = CharacterClockTests.contentState

        for fraction in [0.0, 0.125, 0.25, 0.5, 0.75, 1.0] {
            #expect(gated.pose(at: fraction * breathT, displayState: state) == .rest,
                    "breath leaked at t = \(fraction)·T with bodyScale disabled")
        }
    }

    @Test("Enabling only bodyScale still breathes — the gate is per-channel")
    func bodyScaleAloneBreathes() {
        let alone = RigMotionModel(enabledChannels: .bodyScale)
        let state = CharacterClockTests.contentState
        let pose = alone.pose(at: inhale, displayState: state)

        // Same-type comparison — see the breathDrivesBodyScaleYOnly note.
        #expect(pose.body.scaleY == CGFloat(1.0 + MomoCurves.breathAmplitude))
        #expect(pose.tail == .identity) // never driven today, never moved
    }

    @Test("Gating an un-driven channel is a no-op today (TASK-027 supplies the bite)")
    func gatingUndrivenChannelIsNoop() {
        let full = RigMotionModel()
        let gated = RigMotionModel(enabledChannels: .all.subtracting(.tailRotation))
        let state = CharacterClockTests.contentState

        #expect(gated.pose(at: inhale, displayState: state)
                == full.pose(at: inhale, displayState: state))
    }

    // MARK: - §2.4 pupil clamp

    @Test("Pupil offset clamps to 30 % of eye radius, direction preserved")
    func pupilClampBoundsAndDirection() {
        let radius = CGFloat(50) // measured eye base half-width (bbox 100 × 112)
        let maxOffset = CGFloat(0.30) * radius

        // Inside the bound: untouched.
        #expect(RigMotionModel.clampedPupilOffset(CGPoint(x: 10, y: -5), eyeRadius: radius)
                == CGPoint(x: 10, y: -5))
        #expect(RigMotionModel.clampedPupilOffset(.zero, eyeRadius: radius) == .zero)

        // Exactly at the bound: untouched (clamp is a ceiling, not a margin).
        #expect(RigMotionModel.clampedPupilOffset(CGPoint(x: maxOffset, y: 0), eyeRadius: radius)
                == CGPoint(x: maxOffset, y: 0))

        // Beyond the bound: magnitude capped, direction preserved.
        let clampedX = RigMotionModel.clampedPupilOffset(CGPoint(x: 40, y: 0), eyeRadius: radius)
        #expect(clampedX == CGPoint(x: maxOffset, y: 0))

        let diagonal = RigMotionModel.clampedPupilOffset(CGPoint(x: 30, y: 40), eyeRadius: radius)
        let magnitude = (diagonal.x * diagonal.x + diagonal.y * diagonal.y).squareRoot()
        #expect(abs(magnitude - maxOffset) < 1e-9)
        #expect(abs(diagonal.y / diagonal.x - 40.0 / 30.0) < 1e-9) // same slope
    }

    @Test("The pose's pupil offset never exceeds 30 % of the eye radius")
    func posePupilOffsetRespectsClamp() {
        let model = RigMotionModel()
        let state = CharacterClockTests.contentState
        let radius = CGFloat(50)

        // Today's drivers produce no gaze offset; the clamp contract is that
        // ANY pose the model emits satisfies the bound. Sample the cycle and
        // assert the invariant — TASK-027's gaze work inherits the pin.
        for step in 0...12 {
            let pose = model.pose(at: breathT * Double(step) / 12, displayState: state)
            for eye in [pose.eyeLeft, pose.eyeRight] {
                let magnitude = (eye.pupilOffset.x * eye.pupilOffset.x
                                 + eye.pupilOffset.y * eye.pupilOffset.y).squareRoot()
                #expect(magnitude <= CGFloat(0.30) * radius + 1e-9)
            }
        }
    }

    // MARK: - Transform-only surface (R1)

    @Test("The pose tree carries only value transforms — no Path anywhere (R1)")
    func poseSurfaceIsTransformOnly() {
        var typeNames: Set<String> = []
        func walk(_ mirror: Mirror) {
            typeNames.insert("\(mirror.subjectType)")
            for child in mirror.children {
                walk(Mirror(reflecting: child.value))
            }
        }
        walk(Mirror(reflecting: RigPose.rest))

        let offenders = typeNames.filter { $0.contains("Path") }
        #expect(offenders.isEmpty, "Path-like values leaked into the pose: \(offenders)")

        let knownValueTypes: Set<String> = [
            "CGFloat", "Double", "CGPoint", "Bool", "RigLowerLidPose",
            "RigGridTransform", "RigRotationScale", "RigEyePose",
            "RigMouthWeights", "RigPropPose", "RigPose",
        ]
        let unknown = typeNames.subtracting(knownValueTypes)
        #expect(unknown.isEmpty,
                "unexpected types in the pose surface (keep this pin current): \(unknown)")
    }
}
