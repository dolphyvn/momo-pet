import CoreGraphics
import MomoCore

// MARK: - The reaction motion vocabulary (04 §4.3 + §2.2 channels; TASK-028 R1)

/// One instant's reaction/state choreography as channel VALUES over the
/// §2.2 rig channels (R1: values only, never geometry). The motion model
/// folds this on top of the idle result — multipliers multiply, additive
/// deltas add, and the accent slots (mouth weights, cheek opacity, props)
/// are last-wins so an upper layer's accent reads over a lower one's.
///
/// `.identity` is the no-op overlay: the pose the model emits with an
/// `.identity` motion is byte-identical to the pre-TASK-028 pose, which is
/// what keeps every TASK-027 pin green (R-B: reactions compose, the idle
/// baseline never moves).
///
/// ADR-011 holds by construction: this struct carries DELTAS. The model
/// composes them onto the breath/posture result and only the model's own
/// channel-value laws (ears ±25°, tail ±10°, body rotation ±5°, head
/// rotation ±10°, translations ±10/±6, pupil ≤ 30 % of the eye radius)
/// bound the result — nothing here re-clamps through the posture band.
public struct MomoReactionMotion: Equatable, Sendable {

    // Multiplicative channels (1 = untouched).

    /// Body scaleY multiplier over the expression base × breath.
    public var bodyScaleYMultiplier: Double
    /// Aperture multiplier over the band's semantic aperture.
    public var apertureMultiplier: Double

    // Additive deltas (degrees / grid units).

    public var bodyRotationDegrees: Double
    public var bodyTranslationX: Double
    public var headRotationDegrees: Double
    public var headTranslationY: Double
    public var earLeftDegrees: Double
    public var earRightDegrees: Double
    public var tailDegrees: Double
    /// Pupil glance delta in grid units — the model re-clamps through
    /// `RigMotionModel.clampedPupilOffset` (§2.4), so any request here is
    /// safe; every touch choreography uses this for the eye-follow glance.
    public var pupilOffset: CGPoint

    // Accent slots (nil = leave at the authored value: neutral mouth,
    // full cheeks). Only reaction/state choreography may touch these — the
    // idle path never does (INV-5 scoping: §4.3 names cheek accents and
    // mouth poses for reactions; §3.2 keeps idle posture-led).

    public var mouthWeights: RigMouthWeights?
    public var cheekOpacity: Double?

    // Props (§2.2's interaction-scoped row). `.rest` = untouched — the
    // exclusivity law (TASK-028 R9) keeps at most one window per prop, so
    // last-wins fold never fights.
    public var food: RigPropPose
    public var blanket: RigPropPose
    public var sparkleA: RigPropPose
    public var sparkleB: RigPropPose

    /// The no-op motion — every channel at its untouched value.
    public static let identity = MomoReactionMotion()

    public init(
        bodyScaleYMultiplier: Double = 1,
        apertureMultiplier: Double = 1,
        bodyRotationDegrees: Double = 0,
        bodyTranslationX: Double = 0,
        headRotationDegrees: Double = 0,
        headTranslationY: Double = 0,
        earLeftDegrees: Double = 0,
        earRightDegrees: Double = 0,
        tailDegrees: Double = 0,
        pupilOffset: CGPoint = .zero,
        mouthWeights: RigMouthWeights? = nil,
        cheekOpacity: Double? = nil,
        food: RigPropPose = .rest,
        blanket: RigPropPose = .rest,
        sparkleA: RigPropPose = .rest,
        sparkleB: RigPropPose = .rest
    ) {
        self.bodyScaleYMultiplier = bodyScaleYMultiplier
        self.apertureMultiplier = apertureMultiplier
        self.bodyRotationDegrees = bodyRotationDegrees
        self.bodyTranslationX = bodyTranslationX
        self.headRotationDegrees = headRotationDegrees
        self.headTranslationY = headTranslationY
        self.earLeftDegrees = earLeftDegrees
        self.earRightDegrees = earRightDegrees
        self.tailDegrees = tailDegrees
        self.pupilOffset = pupilOffset
        self.mouthWeights = mouthWeights
        self.cheekOpacity = cheekOpacity
        self.food = food
        self.blanket = blanket
        self.sparkleA = sparkleA
        self.sparkleB = sparkleB
    }

    // MARK: Fade (the §4.1 coherence envelope)

    /// This motion faded toward `.identity` by `amount` (0 = untouched,
    /// 1 = fully gone): multipliers lerp to 1, deltas to 0, accents to
    /// their authored values, props to `.rest`. The L1/L2/L3 fades of the
    /// coherence matrix are THIS function over time.
    public func faded(_ amount: Double) -> MomoReactionMotion {
        let f = min(max(amount, 0), 1)
        var faded = MomoReactionMotion(
            bodyScaleYMultiplier: 1 + (bodyScaleYMultiplier - 1) * (1 - f),
            apertureMultiplier: 1 + (apertureMultiplier - 1) * (1 - f),
            bodyRotationDegrees: bodyRotationDegrees * (1 - f),
            bodyTranslationX: bodyTranslationX * (1 - f),
            headRotationDegrees: headRotationDegrees * (1 - f),
            headTranslationY: headTranslationY * (1 - f),
            earLeftDegrees: earLeftDegrees * (1 - f),
            earRightDegrees: earRightDegrees * (1 - f),
            tailDegrees: tailDegrees * (1 - f),
            pupilOffset: CGPoint(
                x: pupilOffset.x * (1 - f), y: pupilOffset.y * (1 - f)),
            mouthWeights: mouthWeights.map {
                RigMouthWeights(
                    neutral: $0.neutral + (1 - $0.neutral) * f,
                    eat: $0.eat * (1 - f),
                    refuse: $0.refuse * (1 - f))
            },
            cheekOpacity: cheekOpacity.map { $0 + (1 - $0) * f },
            food: food.faded(f),
            blanket: blanket.faded(f),
            sparkleA: sparkleA.faded(f),
            sparkleB: sparkleB.faded(f))
        if f >= 1 {
            faded.mouthWeights = nil
            faded.cheekOpacity = nil
        }
        return faded
    }

    // MARK: Layer fold (bottom-first)

    /// Composes `layers` bottom-first: multipliers multiply, deltas add,
    /// pupil glances add, and the accent/prop slots go to the TOPMOST layer
    /// that specifies them (later = rendered over). Folding an empty array
    /// — or only identities — is `.identity`.
    public static func fold(_ layers: [MomoReactionMotion]) -> MomoReactionMotion {
        var folded = MomoReactionMotion.identity
        for layer in layers {
            folded.bodyScaleYMultiplier *= layer.bodyScaleYMultiplier
            folded.apertureMultiplier *= layer.apertureMultiplier
            folded.bodyRotationDegrees += layer.bodyRotationDegrees
            folded.bodyTranslationX += layer.bodyTranslationX
            folded.headRotationDegrees += layer.headRotationDegrees
            folded.headTranslationY += layer.headTranslationY
            folded.earLeftDegrees += layer.earLeftDegrees
            folded.earRightDegrees += layer.earRightDegrees
            folded.tailDegrees += layer.tailDegrees
            folded.pupilOffset = CGPoint(
                x: folded.pupilOffset.x + layer.pupilOffset.x,
                y: folded.pupilOffset.y + layer.pupilOffset.y)
            if let mouth = layer.mouthWeights { folded.mouthWeights = mouth }
            if let cheek = layer.cheekOpacity { folded.cheekOpacity = cheek }
            if layer.food != .rest { folded.food = layer.food }
            if layer.blanket != .rest { folded.blanket = layer.blanket }
            if layer.sparkleA != .rest { folded.sparkleA = layer.sparkleA }
            if layer.sparkleB != .rest { folded.sparkleB = layer.sparkleB }
        }
        return folded
    }

    // MARK: Concurrency bookkeeping

    /// The coarse creature property groups this motion animates right now
    /// (the §7.4 group set). Play's "two moving transform groups max" pin
    /// and the clip budget tests read this — no layer declares its own
    /// groups, the values are the truth.
    public var propertyGroups: MomoPropertyGroup {
        var groups: MomoPropertyGroup = []
        if bodyScaleYMultiplier != 1 || bodyRotationDegrees != 0
            || bodyTranslationX != 0 {
            groups.insert(.body)
        }
        if headRotationDegrees != 0 || headTranslationY != 0 { groups.insert(.head) }
        if earLeftDegrees != 0 || earRightDegrees != 0 { groups.insert(.ears) }
        if tailDegrees != 0 { groups.insert(.tail) }
        if apertureMultiplier != 1 { groups.insert(.aperture) }
        if pupilOffset != .zero { groups.insert(.gaze) }
        return groups
    }
}

// MARK: - Prop fade helper

public extension RigPropPose {

    /// This prop pose faded toward `.rest` by `amount` (0 = untouched,
    /// 1 = fully at rest): opacity and translation shrink to rest, scale
    /// lerps to 1, rotation to 0. The fade envelopes never snap a prop.
    func faded(_ amount: Double) -> RigPropPose {
        let f = min(max(amount, 0), 1)
        guard f > 0 else { return self }
        let keep = 1 - f
        return RigPropPose(
            transform: RigGridTransform(
                scaleX: transform.scaleX + (1 - transform.scaleX) * f,
                scaleY: transform.scaleY + (1 - transform.scaleY) * f,
                rotationDegrees: transform.rotationDegrees * keep,
                translation: CGPoint(
                    x: transform.translation.x * keep,
                    y: transform.translation.y * keep)),
            opacity: opacity * keep)
    }
}

// MARK: - The band tempo law (04 §3.3; TASK-028 R2)

/// The §3.3 band tempo as it applies to the reaction vocabulary. Drowsy's
/// "all scheduler intervals ×1.4" is normative and extends to the sleepy
/// band's reaction pacing (the touch reactions read sleepier, not just
/// rarer); Exhausted's "minimal and slow" inherits the rule at an authored
/// ×1.5. The stir is EXEMPT — it is the asleep beat, and the sleeping body
/// does not take the awake band's tempo. Baseline clip durations stay
/// doc-pinned (§4.3/§6.1/§7.1); the tempo multiplies ON TOP, exactly the
/// reading the idle sequencer already pins for Wistful's ×1.2 blink
/// stretch (bands govern the baseline, tempo multiplies the drawn value).
public enum MomoReactionTempo {

    /// The Drowsy multiplier (doc-literal §3.3).
    public static let drowsyMultiplier: Double = 1.4

    /// The Exhausted multiplier (AUTHORED — §3.3's "minimal and slow" is
    /// slower still than drowsy; 1.5 keeps every stretched baseline's
    /// release beat inside §7.1's reactions row).
    public static let exhaustedMultiplier: Double = 1.5

    /// The reaction tempo for an energy band: drowsy ×1.4, exhausted
    /// ×1.5 (AUTHORED), energetic/relaxed ×1.
    public static func multiplier(for energy: EnergyBand) -> Double {
        switch energy {
        case .energetic, .relaxed: 1.0
        case .drowsy: drowsyMultiplier
        case .exhausted: exhaustedMultiplier
        }
    }
}
