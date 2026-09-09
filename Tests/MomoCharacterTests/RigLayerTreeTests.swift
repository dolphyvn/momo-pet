import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import MomoCharacter

/// TASK-026 Requirement 3 / 04 §2.2: the layer tree — z-ordered, token-colored
/// slots shared by the SwiftUI view AND the evidence harness. Pins: exact draw
/// order (INV-2 topology), §8.4 token slots per part (R4/INV-5), rest ==
/// identity, the anchor math (bottom-anchored breath, ear/tail roots, lid
/// tops, pupil offsets), and the head→ears/eyes hierarchy.
@Suite("RigLayerTree — z-order, tokens, anchors, hierarchy, rest identity")
struct RigLayerTreeTests {

    /// The Content breath inhale instant (T/4).
    private var inhale: Double { MomoCurves.breathCycleSeconds / 4 }

    private func slot(_ part: String, tier: RigLODTier = .full) throws -> RigLayerSlot {
        let slots = RigLayerTree.slots(for: tier)
        guard let match = slots.first(where: { $0.part == part }) else {
            Issue.record("no slot named \(part) in \(tier)")
            throw NSError(domain: "RigLayerTreeTests", code: 1)
        }
        return match
    }

    private func pose(_ mutate: (inout RigPose) -> Void) -> RigPose {
        var pose = RigPose.rest
        mutate(&pose)
        return pose
    }

    /// Applies a composed transform to a grid point (tiny helper — the tests
    /// reason about where anchors land, which is the legible form of the math).
    private func apply(_ t: CGAffineTransform, to p: CGPoint) -> CGPoint {
        p.applying(t)
    }

    // MARK: - Tier inventories and z-order

    @Test("Full tier: 25 slots (21 rig + 4 props) in the composed draw order")
    func fullTierOrder() {
        let order = RigLayerTree.slots(for: .full).map(\.part)
        #expect(order == [
            // Props row behind the creature (TASK-025 room-scene order).
            "food", "blanket",
            // The §2.2 seven-group rig (TASK-025 rig-full draw order).
            "tail", "hindFootLeft", "hindFootRight", "body", "bellyPatch",
            "head", "earLeft", "earRight", "cheekLeft", "cheekRight",
            "mouthNeutral", "mouthEat", "mouthRefuse",
            "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
            "eyeRightBase", "eyeRightPupil", "eyeRightLid",
            "pawLeft", "pawRight",
            // Sparkles in front.
            "sparkleA", "sparkleB",
        ])
        #expect(order.count == 25)
        #expect(Set(order).count == order.count) // one creature: no duplicate parts
    }

    @Test("Glance tier: 11 lod slots in the composed draw order")
    func glanceTierOrder() {
        let order = RigLayerTree.slots(for: .glance).map(\.part)
        #expect(order == [
            "lodTail", "lodHindFootLeft", "lodHindFootRight", "lodBody",
            "lodBellyPatch", "lodHead", "lodEarLeft", "lodEarRight",
            "lodEyeLeft", "lodEyeRight", "lodPawPair",
        ])
    }

    @Test("Glyph tier: 3 static slots")
    func glyphTierOrder() {
        let order = RigLayerTree.slots(for: .glyph).map(\.part)
        #expect(order == ["glyphSilhouette", "glyphEyeLeft", "glyphEyeRight"])
    }

    @Test("Props appear only in the full tier (interaction-scoped row)")
    func propsOnlyInFullTier() {
        for tier in [RigLODTier.glance, .glyph] {
            let parts = Set(RigLayerTree.slots(for: tier).map(\.part))
            #expect(parts.isDisjoint(with: ["food", "blanket", "sparkleA", "sparkleB"]))
        }
    }

    @Test("Every slot's path is exactly the named generated constant")
    func slotPathsAreTheGeneratedConstants() throws {
        for tier in RigLODTier.allCases {
            for slot in RigLayerTree.slots(for: tier) {
                let generated = try #require(GeneratedRigCatalog.constant[slot.part])
                #expect(slot.path == generated, "\(slot.part) does not draw its constant")
            }
        }
    }

    // MARK: - Topology (INV-1 / INV-2)

    @Test("INV-2: head above body; INV-1: eyes upper-forward on the head")
    func topologyInvariants() throws {
        let slots = RigLayerTree.slots(for: .full)
        let index = Dictionary(uniqueKeysWithValues: slots.enumerated().map { ($0.element.part, $0.offset) })

        // INV-2: the head is drawn above (after) the body and sits above it.
        #expect(index["head"]! > index["body"]!)
        let headAnchor = try slot("head").stages.last!.anchor
        let bodyAnchor = try slot("body").stages.first!.anchor
        #expect(headAnchor.y < bodyAnchor.y)

        // INV-1: both eyes drawn on/above the head, upper on the face (the
        // §5.2 layout keeps the gaze readable); their centers mirror about
        // the x = 500 axis. The eye-center anchors ride the eye's own
        // (pupil) stage — the base slot's last stage is the head's.
        for eye in ["eyeLeftBase", "eyeRightBase"] {
            #expect(index[eye]! > index["head"]!)
        }
        let leftEye = try slot("eyeLeftPupil").stages.last!.anchor
        let rightEye = try slot("eyeRightPupil").stages.last!.anchor
        #expect(leftEye.y == 390)
        #expect(rightEye.y == 390)
        #expect(leftEye.x < rightEye.x) // left/right never swapped
        #expect(abs((leftEye.x + rightEye.x) / 2 - 500) < 0.001) // symmetric axis
    }

    // MARK: - Token application (R4 / §8.4)

    @Test("Every slot names a verbatim §8.4 slot and carries exactly that palette token")
    func slotsCarryPaletteTokens() throws {
        let palette = Dictionary(uniqueKeysWithValues: MomoCharacterPalette.allSlots.map { ($0.slot, $0.token) })

        for tier in RigLODTier.allCases {
            for slot in RigLayerTree.slots(for: tier) {
                let token = try #require(palette[slot.slotName],
                                         "\(slot.part): \(slot.slotName) is not a §8.4 slot")
                #expect(slot.slotName == slot.slotName.lowercased())
                #expect(slot.token.light == token.light,
                        "\(slot.part) light variant does not match the palette")
                #expect(slot.token.dark == token.dark,
                        "\(slot.part) dark variant does not match the palette")
            }
        }
    }

    @Test("The part→token mapping is the designed static application (state never by color)")
    func partTokenMapping() throws {
        let expected: [String: String] = [
            // Body group: coat + shade modeling (palette: furShade = form/shadow).
            "body": "momo.fur.base",
            "bellyPatch": "momo.fur.shade",
            "hindFootLeft": "momo.fur.shade",
            "hindFootRight": "momo.fur.shade",
            // Head group.
            "head": "momo.fur.base",
            "earLeft": "momo.fur.base",
            "earRight": "momo.fur.base",
            // Tail.
            "tail": "momo.fur.shade",
            // Eyes: near-black base + light glint pupil.
            "eyeLeftBase": "momo.eye.base",
            "eyeRightBase": "momo.eye.base",
            "eyeLeftPupil": "momo.eye.highlight",
            "eyeRightPupil": "momo.eye.highlight",
            "eyeLeftLid": "momo.fur.base",
            "eyeRightLid": "momo.fur.base",
            // Face details.
            "mouthNeutral": "momo.eye.base",
            "mouthEat": "momo.eye.base",
            "mouthRefuse": "momo.eye.base",
            "cheekLeft": "momo.cheek",
            "cheekRight": "momo.cheek",
            // Front paws.
            "pawLeft": "momo.fur.shade",
            "pawRight": "momo.fur.shade",
            // Props.
            "food": "momo.fur.shade",
            "blanket": "momo.blanket",
            "sparkleA": "momo.sparkle",
            "sparkleB": "momo.sparkle",
            // Glance tier mirrors the full mapping.
            "lodBody": "momo.fur.base",
            "lodBellyPatch": "momo.fur.shade",
            "lodHead": "momo.fur.base",
            "lodEarLeft": "momo.fur.base",
            "lodEarRight": "momo.fur.base",
            "lodTail": "momo.fur.shade",
            "lodHindFootLeft": "momo.fur.shade",
            "lodHindFootRight": "momo.fur.shade",
            "lodEyeLeft": "momo.eye.base",
            "lodEyeRight": "momo.eye.base",
            "lodPawPair": "momo.fur.shade",
            // Glyph.
            "glyphSilhouette": "momo.fur.shade",
            "glyphEyeLeft": "momo.eye.base",
            "glyphEyeRight": "momo.eye.base",
        ]

        for tier in RigLODTier.allCases {
            for slot in RigLayerTree.slots(for: tier) {
                #expect(slot.slotName == expected[slot.part],
                        "\(slot.part) maps to \(slot.slotName), expected \(expected[slot.part] ?? "nil")")
            }
        }
    }

    // MARK: - Rest == identity

    @Test("At rest every slot's composed transform is identity (authored pose)")
    func restTransformsAreIdentity() {
        for tier in RigLODTier.allCases {
            for slot in RigLayerTree.slots(for: tier) {
                #expect(RigLayerTree.affineTransform(of: slot, at: .rest)
                        == CGAffineTransform.identity,
                        "\(tier)/\(slot.part) is not identity at rest")
                #expect(slot.opacity(RigPose.rest) == 1
                        || slot.part.hasPrefix("mouthEat")
                        || slot.part.hasPrefix("mouthRefuse"),
                        "\(tier)/\(slot.part) is not fully visible at rest")
            }
        }
    }

    // MARK: - Anchor math (the §2.2 channel applications)

    @Test("Breath is bottom-anchored at the ground line: ground fixed, top rises")
    func breathAnchorMath() throws {
        let body = try slot("body")
        let breathPose = RigMotionModel().pose(
            at: inhale, displayState: CharacterClockTests.contentState)
        let t = RigLayerTree.affineTransform(of: body, at: breathPose)

        #expect(apply(t, to: CGPoint(x: 500, y: 1000)) == CGPoint(x: 500, y: 1000))
        let top = apply(t, to: CGPoint(x: 500, y: 428))
        let expectedTopY = 1000.0 - (1.0 + MomoCurves.breathAmplitude) * (1000.0 - 428.0)
        #expect(abs(top.y - expectedTopY) < 1e-9)
        #expect(abs(top.x - 500) < 1e-9) // scaleY only: no sideways shear
    }

    @Test("The head rides the body breath; the props do not")
    func headRidesBreathPropsDoNot() throws {
        let breathPose = RigMotionModel().pose(
            at: inhale, displayState: CharacterClockTests.contentState)

        let headT = RigLayerTree.affineTransform(of: try slot("head"), at: breathPose)
        let neck = apply(headT, to: CGPoint(x: 500, y: 590))
        let expectedNeckY = 1000.0 - (1.0 + MomoCurves.breathAmplitude) * (1000.0 - 590.0)
        #expect(abs(neck.y - expectedNeckY) < 1e-9)

        for part in ["food", "blanket", "sparkleA", "sparkleB"] {
            let propT = RigLayerTree.affineTransform(of: try slot(part), at: breathPose)
            #expect(propT == CGAffineTransform.identity)
        }
    }

    @Test("Pupil offset translates the pupil within the clamped eye, base stays")
    func pupilOffsetMath() throws {
        let eyePose = pose { $0.eyeLeft.pupilOffset = CGPoint(x: 10, y: -5) }

        let pupilT = RigLayerTree.affineTransform(of: try slot("eyeLeftPupil"), at: eyePose)
        #expect(apply(pupilT, to: CGPoint(x: 430, y: 390)) == CGPoint(x: 440, y: 385))

        let baseT = RigLayerTree.affineTransform(of: try slot("eyeLeftBase"), at: eyePose)
        #expect(apply(baseT, to: CGPoint(x: 430, y: 390)) == CGPoint(x: 430, y: 390))
    }

    @Test("Lid scaleY is anchored at the lid's top: smaller scales lift the lid bottom (more open)")
    func lidAnchorMath() throws {
        let halfLifted = pose { $0.eyeLeft.lidScaleY = 0.5 }
        let lidT = RigLayerTree.affineTransform(of: try slot("eyeLeftLid"), at: halfLifted)

        #expect(apply(lidT, to: CGPoint(x: 430, y: 304)) == CGPoint(x: 430, y: 304))
        let bottom = apply(lidT, to: CGPoint(x: 430, y: 360))
        #expect(abs(bottom.y - (304.0 + 0.5 * 56.0)) < 1e-9)
        #expect(abs(bottom.x - 430) < 1e-9)
    }

    @Test("Ear rotation turns about the ear root; +90° moves an upper point rightward")
    func earRotationMath() throws {
        let rotated = pose { $0.earLeft.rotationDegrees = 90 }
        let earT = RigLayerTree.affineTransform(of: try slot("earLeft"), at: rotated)

        let root = CGPoint(x: 424, y: 268.2)
        let pinned = apply(earT, to: root)
        // The anchor is pinned to within composed-matrix rounding (the
        // +90° angle rounds to 1 ulp off π/2) — same tolerance as every
        // other anchor-math check in this file.
        #expect(abs(pinned.x - root.x) < 1e-9)
        #expect(abs(pinned.y - root.y) < 1e-9)
        let tip = apply(earT, to: CGPoint(x: 424, y: 68.2))
        #expect(abs(tip.x - 624) < 1e-9) // above → rightward: clockwise-positive
        #expect(abs(tip.y - 268.2) < 1e-9)
    }

    @Test("Tail rotation and scaleY act about the tail anchor")
    func tailMath() throws {
        let anchor = CGPoint(x: 778, y: 796)

        let counter = pose { $0.tail.rotationDegrees = -90 }
        let counterT = RigLayerTree.affineTransform(of: try slot("tail"), at: counter)
        #expect(apply(counterT, to: anchor) == anchor)
        let swung = apply(counterT, to: CGPoint(x: 778, y: 740))
        #expect(abs(swung.x - 722) < 1e-9) // top → leftward: counterclockwise
        #expect(abs(swung.y - 796) < 1e-9)

        let raised = pose { $0.tail.scaleY = 1.5 }
        let raisedT = RigLayerTree.affineTransform(of: try slot("tail"), at: raised)
        let lifted = apply(raisedT, to: CGPoint(x: 778, y: 740))
        #expect(abs(lifted.y - (796.0 - 1.5 * 56.0)) < 1e-9)
        #expect(abs(lifted.x - 778) < 1e-9)
    }

    @Test("Head position carries the ears and eyes with it (the §2.2 hierarchy)")
    func headPositionCarriesChildren() throws {
        let shifted = pose { $0.head.translation = CGPoint(x: 20, y: 0) }

        let headT = RigLayerTree.affineTransform(of: try slot("head"), at: shifted)
        #expect(apply(headT, to: CGPoint(x: 500, y: 590)) == CGPoint(x: 520, y: 590))

        let earT = RigLayerTree.affineTransform(of: try slot("earLeft"), at: shifted)
        let earRoot = apply(earT, to: CGPoint(x: 424, y: 268.2))
        #expect(abs(earRoot.x - 444) < 1e-9) // rode the head
        #expect(abs(earRoot.y - 268.2) < 1e-9)

        let eyeT = RigLayerTree.affineTransform(of: try slot("eyeLeftBase"), at: shifted)
        let eye = apply(eyeT, to: CGPoint(x: 430, y: 390))
        #expect(abs(eye.x - 450) < 1e-9)
        #expect(abs(eye.y - 390) < 1e-9)

        // The body itself does not move with the head.
        let bodyT = RigLayerTree.affineTransform(of: try slot("body"), at: shifted)
        #expect(bodyT == CGAffineTransform.identity)
    }

    // MARK: - Opacity channels

    @Test("Mouth slots crossfade by the pose weights: neutral at rest")
    func mouthWeightsDriveOpacity() throws {
        #expect(try slot("mouthNeutral").opacity(RigPose.rest) == 1)
        #expect(try slot("mouthEat").opacity(RigPose.rest) == 0)
        #expect(try slot("mouthRefuse").opacity(RigPose.rest) == 0)

        let eating = pose { $0.mouth = RigMouthWeights(neutral: 0, eat: 1, refuse: 0) }
        #expect(try slot("mouthNeutral").opacity(eating) == 0)
        #expect(try slot("mouthEat").opacity(eating) == 1)
        #expect(try slot("mouthRefuse").opacity(eating) == 0)
    }

    @Test("Cheek opacity follows the pose's cheekOpacity channel")
    func cheekOpacityFollowsTheChannel() throws {
        let faded = pose { $0.cheekOpacity = 0.25 }
        #expect(abs(try slot("cheekLeft").opacity(faded) - 0.25) < 1e-12)
        #expect(abs(try slot("cheekRight").opacity(faded) - 0.25) < 1e-12)
    }
}
