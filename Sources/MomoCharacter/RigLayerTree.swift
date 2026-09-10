import CoreGraphics
import SwiftUI

/// One §2.2 channel application: a rig anchor (grid units) and the pose→
/// transform that acts about it. A slot composes stages OUTERMOST-FIRST —
/// `[body, head, ear]` — so a child rides every ancestor's transform (the
/// ears sweep with the head, the head breathes with the body) while still
/// applying its own channel about its own anchor.
public struct RigStage: Sendable {

    /// The anchor in §2.1 grid units (y-down, ground y = 1000).
    public let anchor: CGPoint

    /// The transform value for the anchor to act on.
    public let value: @Sendable (RigPose) -> RigGridTransform

    public init(
        anchor: CGPoint,
        value: @escaping @Sendable (RigPose) -> RigGridTransform
    ) {
        self.anchor = anchor
        self.value = value
    }
}

/// One drawable layer of the rig: a generated constant, its §8.4 token
/// slot, its transform stages, and its opacity channel. THE shared truth —
/// `MomoRigView` renders these slots with SwiftUI and the evidence harness
/// renders the same slots with CoreGraphics, so the committed size-ladder
/// renders and the shipped view are projections of one definition.
public struct RigLayerSlot: Sendable {

    /// The generated constant's §8.4-style name (e.g. `eyeLeftPupil`).
    public let part: String

    /// The TASK-025 generated geometry — never rebuilt, never mutated (R1).
    public let path: Path

    /// The token to paint with (R4: palette slots only, applied statically —
    /// INV-5 keeps state out of color).
    public let token: MomoColorToken

    /// The verbatim §8.4 slot name `token` was read from.
    public let slotName: String

    /// Transform stages, outermost first. Empty for static layers (props).
    public let stages: [RigStage]

    /// The opacity channel (mouth crossfade weights, cheek fade, …).
    public let opacity: @Sendable (RigPose) -> Double

    public init(
        part: String,
        path: Path,
        token: MomoColorToken,
        slotName: String,
        stages: [RigStage] = [],
        opacity: @escaping @Sendable (RigPose) -> Double = { _ in 1 }
    ) {
        self.part = part
        self.path = path
        self.token = token
        self.slotName = slotName
        self.stages = stages
        self.opacity = opacity
    }
}

/// The §2.2 layer tree: TASK-025's pre-built constants composed into the
/// seven layer groups + the interaction-scoped props row, in TASK-025
/// evidence draw order (z-order), token-colored, with exactly the anchors
/// the channel doc comments name (TASK-026 Requirement 3).
///
/// Hierarchy: the body breathes about the ground line; the head rides the
/// body about the neck; the ears/eyes/face ride the head; the tail and paws
/// ride the body. Props carry their OWN single stage about their measured
/// center (no ancestor — the room scene's placement does not breathe with
/// the creature), driven by their pose channels (TASK-028; `.rest` is the
/// identity placement).
public enum RigLayerTree {

    // MARK: - Rig anchors (measured on the TASK-025 constants, grid units)

    private static let groundAnchor = CGPoint(x: 500, y: 1000)
    private static let neckAnchor = CGPoint(x: 500, y: 590)
    private static let earLeftAnchor = CGPoint(x: 424, y: 268.2)
    private static let earRightAnchor = CGPoint(x: 576, y: 268.2)
    private static let tailAnchor = CGPoint(x: 778, y: 796)
    private static let eyeLeftAnchor = CGPoint(x: 430, y: 390)
    private static let eyeRightAnchor = CGPoint(x: 570, y: 390)
    private static let lidLeftAnchor = CGPoint(x: 430, y: 304)
    private static let lidRightAnchor = CGPoint(x: 570, y: 304)
    private static let pawLeftAnchor = CGPoint(x: 447, y: 866)
    private static let pawRightAnchor = CGPoint(x: 553, y: 866)
    // TASK-028's prop anchors — the measured centers of the TASK-025
    // generated constants (MomoProps), so a prop's own rotation/scale acts
    // about itself. Anchors are rig parameters, not new geometry.
    private static let foodAnchor = CGPoint(x: 240, y: 950)
    private static let blanketAnchor = CGPoint(x: 800, y: 940)
    private static let sparkleAAnchor = CGPoint(x: 240, y: 250)
    private static let sparkleBAnchor = CGPoint(x: 712, y: 320)

    // MARK: - Stage builders (outermost-first composition)

    private static let bodyStage = RigStage(anchor: groundAnchor) { $0.body }
    private static let headStage = RigStage(anchor: neckAnchor) { $0.head }
    private static let tailStage = RigStage(anchor: tailAnchor) { $0.tail.gridTransform }

    private static func earStage(left: Bool) -> RigStage {
        RigStage(anchor: left ? earLeftAnchor : earRightAnchor) { pose in
            (left ? pose.earLeft : pose.earRight).gridTransform
        }
    }

    private static func pupilStage(left: Bool) -> RigStage {
        RigStage(anchor: left ? eyeLeftAnchor : eyeRightAnchor) {
            RigGridTransform(
                translation: left ? $0.eyeLeft.pupilOffset : $0.eyeRight.pupilOffset)
        }
    }

    private static func lidStage(left: Bool) -> RigStage {
        RigStage(anchor: left ? lidLeftAnchor : lidRightAnchor) {
            RigGridTransform(
                scaleY: CGFloat(left ? $0.eyeLeft.lidScaleY : $0.eyeRight.lidScaleY))
        }
    }

    private static func pawStage(left: Bool) -> RigStage {
        RigStage(anchor: left ? pawLeftAnchor : pawRightAnchor) {
            left ? $0.pawLeft : $0.pawRight
        }
    }

    /// TASK-028: each prop reads its own pose channels about its measured
    /// center — identity + full opacity at `.rest` (the pre-TASK-028 pins
    /// stay valid), animated only inside its reaction windows.
    private static func propStage(
        _ pose: @escaping @Sendable (RigPose) -> RigPropPose, anchor: CGPoint
    ) -> RigStage {
        RigStage(anchor: anchor) { pose($0).transform }
    }

    // MARK: - Slot builder

    private static func slot(
        _ part: String,
        _ path: Path,
        _ slotName: String,
        token: MomoColorToken,
        stages: [RigStage] = [],
        opacity: @escaping @Sendable (RigPose) -> Double = { _ in 1 }
    ) -> RigLayerSlot {
        RigLayerSlot(
            part: part, path: path, token: token, slotName: slotName,
            stages: stages, opacity: opacity)
    }

    // MARK: - The §2.2 groups, token-mapped (R4)

    private static func fullRigSlots() -> [RigLayerSlot] {
        // Body group: breath about the ground line (hind feet included —
        // they compress with the torso, keeping the ground contact). The
        // TASK-025 evidence z-order draws the hind feet BEHIND the torso.
        let body = [
            slot("hindFootLeft", MomoRig.hindFootLeft, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
            slot("hindFootRight", MomoRig.hindFootRight, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
            slot("body", MomoRig.body, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage]),
            slot("bellyPatch", MomoRig.bellyPatch, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
        ]
        // Tail: body's appendage, then its own §2.2 channels.
        let tail = [
            slot("tail", MomoRig.tail, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage, tailStage]),
        ]
        // Head group: rides the body about the neck.
        let head = [
            slot("head", MomoRig.head, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage]),
        ]
        // Ears: ride the head, then their own root-anchored channels.
        let ears = [
            slot("earLeft", MomoRig.earLeft, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage, earStage(left: true)]),
            slot("earRight", MomoRig.earRight, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage, earStage(left: false)]),
        ]
        // Face details: cheeks fade, mouths crossfade — all on the head.
        let faceDetails = [
            slot("cheekLeft", MomoRig.cheekLeft, "momo.cheek", token: MomoCharacterPalette.cheek,
                 stages: [bodyStage, headStage], opacity: { $0.cheekOpacity }),
            slot("cheekRight", MomoRig.cheekRight, "momo.cheek", token: MomoCharacterPalette.cheek,
                 stages: [bodyStage, headStage], opacity: { $0.cheekOpacity }),
            slot("mouthNeutral", MomoRig.mouthNeutral, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage], opacity: { $0.mouth.neutral }),
            slot("mouthEat", MomoRig.mouthEat, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage], opacity: { $0.mouth.eat }),
            slot("mouthRefuse", MomoRig.mouthRefuse, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage], opacity: { $0.mouth.refuse }),
        ]
        // Eyes: base on the head; pupil and lid add their own anchors.
        let eyes = [
            slot("eyeLeftBase", MomoRig.eyeLeftBase, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage]),
            slot("eyeLeftPupil", MomoRig.eyeLeftPupil, "momo.eye.highlight", token: MomoCharacterPalette.eyeHighlight,
                 stages: [bodyStage, headStage, pupilStage(left: true)]),
            slot("eyeLeftLid", MomoRig.eyeLeftLid, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage, lidStage(left: true)]),
            slot("eyeRightBase", MomoRig.eyeRightBase, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage]),
            slot("eyeRightPupil", MomoRig.eyeRightPupil, "momo.eye.highlight", token: MomoCharacterPalette.eyeHighlight,
                 stages: [bodyStage, headStage, pupilStage(left: false)]),
            slot("eyeRightLid", MomoRig.eyeRightLid, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage, lidStage(left: false)]),
        ]
        // Front paws: body's children with wrist-anchored channels.
        let paws = [
            slot("pawLeft", MomoRig.pawLeft, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage, pawStage(left: true)]),
            slot("pawRight", MomoRig.pawRight, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage, pawStage(left: false)]),
        ]
        return tail + body + head + ears + faceDetails + eyes + paws
    }

    /// The interaction-scoped props row (§2.2): each prop reads its own
    /// §2.2 channels about its measured center — `.rest` renders exactly
    /// the TASK-025 room-scene placement, and only the reaction/state
    /// windows (TASK-028's exclusivity law) animate them.
    private static func propSlots() -> [RigLayerSlot] {
        [
            slot("food", MomoProps.food, "momo.fur.shade",
                 token: MomoCharacterPalette.furShade,
                 stages: [propStage({ $0.food }, anchor: foodAnchor)],
                 opacity: { $0.food.opacity }),
            slot("blanket", MomoProps.blanket, "momo.blanket",
                 token: MomoCharacterPalette.blanket,
                 stages: [propStage({ $0.blanket }, anchor: blanketAnchor)],
                 opacity: { $0.blanket.opacity }),
            slot("sparkleA", MomoProps.sparkleA, "momo.sparkle",
                 token: MomoCharacterPalette.sparkle,
                 stages: [propStage({ $0.sparkleA }, anchor: sparkleAAnchor)],
                 opacity: { $0.sparkleA.opacity }),
            slot("sparkleB", MomoProps.sparkleB, "momo.sparkle",
                 token: MomoCharacterPalette.sparkle,
                 stages: [propStage({ $0.sparkleB }, anchor: sparkleBAnchor)],
                 opacity: { $0.sparkleB.opacity }),
        ]
    }

    private static func glanceSlots() -> [RigLayerSlot] {
        [
            slot("lodTail", MomoRig.lodTail, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage, tailStage]),
            slot("lodHindFootLeft", MomoRig.lodHindFootLeft, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
            slot("lodHindFootRight", MomoRig.lodHindFootRight, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
            slot("lodBody", MomoRig.lodBody, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage]),
            slot("lodBellyPatch", MomoRig.lodBellyPatch, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
            slot("lodHead", MomoRig.lodHead, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage]),
            slot("lodEarLeft", MomoRig.lodEarLeft, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage, earStage(left: true)]),
            slot("lodEarRight", MomoRig.lodEarRight, "momo.fur.base", token: MomoCharacterPalette.furBase,
                 stages: [bodyStage, headStage, earStage(left: false)]),
            slot("lodEyeLeft", MomoRig.lodEyeLeft, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage]),
            slot("lodEyeRight", MomoRig.lodEyeRight, "momo.eye.base", token: MomoCharacterPalette.eyeBase,
                 stages: [bodyStage, headStage]),
            slot("lodPawPair", MomoRig.lodPawPair, "momo.fur.shade", token: MomoCharacterPalette.furShade,
                 stages: [bodyStage]),
        ]
    }

    private static func glyphSlots() -> [RigLayerSlot] {
        [
            slot("glyphSilhouette", MomoRig.glyphSilhouette, "momo.fur.shade", token: MomoCharacterPalette.furShade),
            slot("glyphEyeLeft", MomoRig.glyphEyeLeft, "momo.eye.base", token: MomoCharacterPalette.eyeBase),
            slot("glyphEyeRight", MomoRig.glyphEyeRight, "momo.eye.base", token: MomoCharacterPalette.eyeBase),
        ]
    }

    // MARK: - Composition order (z-order, INV-1/INV-2)

    /// The tier's draw order: first = farthest back. Full tier: props row
    /// (food/blanket behind the creature, sparkles in front) around the
    /// TASK-025 rig draw order — tail, hind feet, body, belly, head, ears,
    /// cheeks, mouths, eyes, paws.
    public static func slots(for tier: RigLODTier) -> [RigLayerSlot] {
        switch tier {
        case .full:
            let props = propSlots()
            return Array(props.prefix(2)) + fullRigSlots() + Array(props.suffix(2))
        case .glance:
            return glanceSlots()
        case .glyph:
            return glyphSlots()
        }
    }

    // MARK: - Composed transform (shared by the view and the evidence harness)

    /// The slot's full transform at a pose, composed in grid space: each
    /// stage pivots about its anchor — scale, then rotate, then translate,
    /// i.e. per stage (p − anchor)·S·R·T·(+anchor) in row-vector form — and
    /// child stages apply before ancestors (the §2.2 hierarchy: the head
    /// rides the body). THIS matrix is the normative §2.2 composition —
    /// `MomoRigView` composes exactly this matrix per slot inside its
    /// Canvas (one `drawLayer` per slot; TASK-027's R1 reconciliation —
    /// point-probe- and pixel-probe-verified in `R1CompositionTests`), and
    /// the evidence harness renders it in its y-flipped CGContext, positive
    /// rotations staying clockwise-on-screen. At `.rest` this is exactly
    /// identity.
    public static func affineTransform(
        of slot: RigLayerSlot, at pose: RigPose
    ) -> CGAffineTransform {
        var result = CGAffineTransform.identity
        for stage in slot.stages {
            let t = stage.value(pose)
            let anchor = CGAffineTransform(
                translationX: stage.anchor.x, y: stage.anchor.y)
            // Row-vector composition: the LEFTMOST matrix applies first —
            // scale → rotate → translate per stage, child-local ahead of
            // ancestors'. (The SwiftUI view chain's order differs — see the
            // composition note above.)
            let local = CGAffineTransform(scaleX: t.scaleX, y: t.scaleY)
                .concatenating(CGAffineTransform(
                    rotationAngle: CGFloat(t.rotationDegrees * Double.pi / 180)))
                .concatenating(CGAffineTransform(
                    translationX: t.translation.x, y: t.translation.y))
            // Pivot about the anchor — (p − anchor)·Local·(+anchor) — and
            // PREPEND: stages listed outermost-first then apply child-local
            // before ancestor, which is the hierarchy's meaning.
            result = anchor.inverted()
                .concatenating(local)
                .concatenating(anchor)
                .concatenating(result)
        }
        return result
    }
}
