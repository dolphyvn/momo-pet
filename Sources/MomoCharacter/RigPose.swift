import CoreGraphics

/// The transform values ONE channel application can carry, in 04 §2.1's
/// 1000×1000 grid space (y-down, ground y = 1000). Scale and rotation act
/// about the part's rig anchor; translation is applied last (TASK-026
/// Requirement 2 — R1: values only, never geometry).
public struct RigGridTransform: Equatable, Sendable {

    public var scaleX: CGFloat
    public var scaleY: CGFloat
    public var rotationDegrees: Double
    public var translation: CGPoint

    public init(
        scaleX: CGFloat = 1,
        scaleY: CGFloat = 1,
        rotationDegrees: Double = 0,
        translation: CGPoint = .zero
    ) {
        self.scaleX = scaleX
        self.scaleY = scaleY
        self.rotationDegrees = rotationDegrees
        self.translation = translation
    }

    /// The authored geometry, untouched.
    public static let identity = RigGridTransform()
}

/// The rotation/scaleY pair §2.2 gives the appendages (ears, tail).
public struct RigRotationScale: Equatable, Sendable {

    public var rotationDegrees: Double
    public var scaleY: Double

    public init(rotationDegrees: Double = 0, scaleY: Double = 1) {
        self.rotationDegrees = rotationDegrees
        self.scaleY = scaleY
    }

    public static let identity = RigRotationScale()

    /// As a full grid transform (no translation).
    public var gridTransform: RigGridTransform {
        RigGridTransform(scaleX: 1, scaleY: CGFloat(scaleY),
                         rotationDegrees: rotationDegrees)
    }
}

/// The §3.1 lower-lid pose slots. The pose SHAPES are TASK-027 (O6
/// routing) — TASK-026 ships the slot so the crossfade destination exists.
public enum RigLowerLidPose: Equatable, Sendable {
    case relaxed
    case upturned
    case flattened
}

/// One eye's channels (§2.2 Eyes group, mirrored left/right).
public struct RigEyePose: Equatable, Sendable {

    /// Lid coverage as a scaleY about the lid's top anchor: 1 = the
    /// authored rest geometry; smaller values LIFT the lid bottom (the eye
    /// reads more open — 0 leaves no lid coverage at all); larger values
    /// lower it (more closed).
    public var lidScaleY: Double

    /// Gaze offset in grid units — the MODEL clamps it to ≤ 30 % of the eye
    /// radius (§2.4's clamp law); the layer tree applies it verbatim.
    public var pupilOffset: CGPoint

    /// The §3.1 lower-lid pose slot (shapes are TASK-027).
    public var lowerLid: RigLowerLidPose

    public init(
        lidScaleY: Double = 1,
        pupilOffset: CGPoint = .zero,
        lowerLid: RigLowerLidPose = .relaxed
    ) {
        self.lidScaleY = lidScaleY
        self.pupilOffset = pupilOffset
        self.lowerLid = lowerLid
    }

    public static let rest = RigEyePose()
}

/// Weights across the three pre-built mouth poses (§2.2 FaceDetails). At
/// rest the authored neutral mouth is fully visible.
public struct RigMouthWeights: Equatable, Sendable {

    public var neutral: Double
    public var eat: Double
    public var refuse: Double

    public init(neutral: Double, eat: Double, refuse: Double) {
        self.neutral = neutral
        self.eat = eat
        self.refuse = refuse
    }

    public static let neutral = RigMouthWeights(neutral: 1, eat: 0, refuse: 0)
    public static let eat = RigMouthWeights(neutral: 0, eat: 1, refuse: 0)
    public static let refuse = RigMouthWeights(neutral: 0, eat: 0, refuse: 1)
}

/// A prop's channels (position/rotation via the transform + opacity).
public struct RigPropPose: Equatable, Sendable {

    public var transform: RigGridTransform
    public var opacity: Double

    public init(transform: RigGridTransform = .identity, opacity: Double = 1) {
        self.transform = transform
        self.opacity = opacity
    }

    public static let rest = RigPropPose()
}

/// The full pose of ONE creature (R2) at a clock instant: every §2.2
/// channel's current value. Constructed by `RigMotionModel`; consumed by
/// `RigLayerTree` (which both the SwiftUI view and the evidence harness
/// render). `.rest` is the authored geometry defaults — what a stopped
/// clock shows.
public struct RigPose: Equatable, Sendable {

    public var body: RigGridTransform
    public var head: RigGridTransform
    public var earLeft: RigRotationScale
    public var earRight: RigRotationScale
    public var tail: RigRotationScale
    public var eyeLeft: RigEyePose
    public var eyeRight: RigEyePose
    public var mouth: RigMouthWeights
    public var cheekOpacity: Double
    public var pawLeft: RigGridTransform
    public var pawRight: RigGridTransform
    public var food: RigPropPose
    public var blanket: RigPropPose
    public var sparkleA: RigPropPose
    public var sparkleB: RigPropPose

    public init(
        body: RigGridTransform = .identity,
        head: RigGridTransform = .identity,
        earLeft: RigRotationScale = .identity,
        earRight: RigRotationScale = .identity,
        tail: RigRotationScale = .identity,
        eyeLeft: RigEyePose = .rest,
        eyeRight: RigEyePose = .rest,
        mouth: RigMouthWeights = .neutral,
        cheekOpacity: Double = 1,
        pawLeft: RigGridTransform = .identity,
        pawRight: RigGridTransform = .identity,
        food: RigPropPose = .rest,
        blanket: RigPropPose = .rest,
        sparkleA: RigPropPose = .rest,
        sparkleB: RigPropPose = .rest
    ) {
        self.body = body
        self.head = head
        self.earLeft = earLeft
        self.earRight = earRight
        self.tail = tail
        self.eyeLeft = eyeLeft
        self.eyeRight = eyeRight
        self.mouth = mouth
        self.cheekOpacity = cheekOpacity
        self.pawLeft = pawLeft
        self.pawRight = pawRight
        self.food = food
        self.blanket = blanket
        self.sparkleA = sparkleA
        self.sparkleB = sparkleB
    }

    /// The authored geometry defaults: every channel zeroed. The pause
    /// contract made visible — a stopped clock renders exactly this.
    public static let rest = RigPose()
}
