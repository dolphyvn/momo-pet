import CoreGraphics
import Foundation
import MomoCore

// MARK: - Choreography context (what a clip may read)

/// The state context a clip's choreography may read (§9.3: the character
/// renders the state it is given). Frozen at plan time by the director so
/// a band change mid-clip never warps a running reaction.
public struct MomoReactionContext: Equatable, Sendable {
    public let moodBand: MoodBand
    public let energyBand: EnergyBand
    public let bondStage: BondStage
    public let wakefulness: Wakefulness

    public init(
        moodBand: MoodBand, energyBand: EnergyBand,
        bondStage: BondStage, wakefulness: Wakefulness
    ) {
        self.moodBand = moodBand
        self.energyBand = energyBand
        self.bondStage = bondStage
        self.wakefulness = wakefulness
    }
}

// MARK: - The clip choreography (04 §4.3/§6.1 rows, rendered)

/// Turns `(key, elapsed, touch shape)` into channel values. PURE — no
/// clock, no randomness; every input arrives from the director's fold. The
/// switch is EXHAUSTIVE over `MomoReactionKey` (a new key without motion
/// fails the build). The settling and playReady rows delegate to their
/// handshakes (`MomoHandshakeChoreography`) — those plans ARE the state
/// choreography, not separate clips.
public enum MomoReactionChoreography {

    // MARK: Authored touch-spring constants (§7.2's touch family)

    /// The touch springs' damping (inside §7.2's 0.75…0.85 band; ~4.6 %
    /// single soft overshoot, well under the 15 % touch cap).
    static let touchSpringDamping: Double = 0.8

    // MARK: The entry point

    /// - Parameters:
    ///   - elapsed: seconds since the instance started (director-supplied).
    ///   - duration: the effective one-shot duration (tempo-scaled);
    ///     for `pressShaped` keys this is the release-beat length.
    ///   - holdSeconds: press-shaped keys — the input hold length
    ///     (press-length is input, §6.1); `nil` = still holding.
    ///   - deepened: the stroke deepening (2nd stroke in the same touch).
    ///   - context: the frozen state context.
    static func motion(
        for key: MomoReactionKey,
        elapsed: Double,
        duration: Double,
        holdSeconds: Double?,
        deepened: Bool,
        context: MomoReactionContext
    ) -> MomoReactionMotion {
        switch key {
        case .tapHead:
            return tapHead(elapsed, context: context)
        case .tapBelly:
            return tapBelly(elapsed, context: context)
        case .tap:
            return tap(elapsed)
        case .doubleTap:
            return doubleTap(elapsed, context: context)
        case .longPressHead:
            return longPressHead(
                elapsed: elapsed, holdSeconds: holdSeconds ?? elapsed,
                releaseSeconds: duration, context: context)
        case .longPressBelly:
            // MINOR-1: the row's two roles split — `duration` is the §6.1
            // rock cycle (0.9 × tempo); the release beat arrives from its
            // own spec field (AUTHORED 0.45, × tempo), so the rendered
            // release meets the slot end at EVERY tempo (no min-clamp).
            let spec = MomoReactionClips.spec(for: key)
            let tempo = duration / spec.baselineSeconds
            let release = (spec.pressReleaseSeconds ?? spec.baselineSeconds)
                * tempo
            return longPressBelly(
                elapsed: elapsed, holdSeconds: holdSeconds ?? elapsed,
                cycle: duration, releaseSeconds: release)
        case .longPress:
            return bumpMelt(elapsed, duration: duration)
        case .strokeHead:
            return strokeHead(
                elapsed: elapsed, cycle: duration, deepened: deepened,
                context: context)
        case .strokeBelly:
            return strokeBelly(elapsed, cycle: duration)
        case .stroke:
            return stroke(elapsed, cycle: duration)
        case .stir:
            return stir(elapsed)
        case .politelyFull:
            return politelyFull(elapsed)
        case .gentleDecline:
            return gentleDecline(elapsed)
        case .sleepyNibbles:
            return sleepyNibbles(elapsed)
        case .settling:
            return MomoHandshakeChoreography.settleMotion(elapsed: elapsed)
        case .blanketAdjust:
            return blanketAdjust(elapsed)
        case .eating:
            return eating(elapsed)
        case .nibble:
            return nibble(elapsed)
        case .playReady:
            return MomoHandshakeChoreography.inviteMotion(elapsed: elapsed)
        case .cheer:
            return cheer(elapsed)
        case .decline:
            return decline(elapsed)
        }
    }

    // MARK: Shared shapes

    /// The attack/hold/release bump in 0…1 (smoothstep both ends) — the
    /// one-shot envelope most clips ride.
    static func bump(
        _ elapsed: Double, duration: Double, attack: Double, release: Double
    ) -> Double {
        guard elapsed > 0, elapsed < duration, attack > 0, release > 0 else {
            return elapsed <= 0 ? 0 : 0
        }
        let hold = max(duration - attack - release, 0)
        if elapsed < attack { return MomoCurves.smoothstep(elapsed / attack) }
        if elapsed < attack + hold { return 1 }
        return 1 - MomoCurves.smoothstep((elapsed - attack - hold) / release)
    }

    /// The §7.2 touch spring's unit step response, held at 1 after two
    /// response times (the single soft overshoot ≤ 15 % lives inside).
    static func spring(_ elapsed: Double) -> Double {
        guard elapsed > 0 else { return 0 }
        let t = min(elapsed, MomoCurves.touchSpringResponseSeconds * 2)
        return MomoCurves.dampedSpringStep(
            at: t, damping: touchSpringDamping,
            omega: 2 * .pi / MomoCurves.touchSpringResponseSeconds)
    }

    /// The eye-follow glance (TASK-028 R6): every touch clip carries this
    /// pupil delta toward the touched zone, eased in 0.1 s, held, eased
    /// back. The model re-clamps through `clampedPupilOffset` (§2.4).
    static func glance(_ elapsed: Double, toward target: CGPoint) -> CGPoint {
        let shape = bump(elapsed, duration: 0.4, attack: 0.1, release: 0.18)
        return CGPoint(x: target.x * shape, y: target.y * shape)
    }

    // MARK: Tap family (§6.1)

    private static func tapHead(
        _ elapsed: Double, context: MomoReactionContext
    ) -> MomoReactionMotion {
        let lift = spring(elapsed)
        let halfBlink = bump(elapsed, duration: 0.4, attack: 0.1, release: 0.2)
        return MomoReactionMotion(
            apertureMultiplier: 1 - 0.5 * halfBlink,
            earLeftDegrees: 5 * lift,
            earRightDegrees: 5 * lift,
            pupilOffset: glance(elapsed, toward: CGPoint(x: 0, y: -6)))
    }

    private static func tapBelly(
        _ elapsed: Double, context: MomoReactionContext
    ) -> MomoReactionMotion {
        let squash = bump(elapsed, duration: 0.45, attack: 0.1, release: 0.25)
        let widen = bump(elapsed, duration: 0.45, attack: 0.08, release: 0.3)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.05 * squash,
            apertureMultiplier: 1 + 0.08 * widen,
            pupilOffset: glance(elapsed, toward: CGPoint(x: 0, y: 6)))
    }

    private static func tap(_ elapsed: Double) -> MomoReactionMotion {
        let s = spring(elapsed)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 + 0.04 * s,
            headRotationDegrees: 2 * s,
            tailDegrees: 5 * s)
    }

    private static func doubleTap(
        _ elapsed: Double, context: MomoReactionContext
    ) -> MomoReactionMotion {
        // §3.4's tail-double-wag unlocks at Getting Close; below it the
        // beat softens to a single small wag (D18: repetition only
        // softens, never refuses).
        let unlocked = MomoExpressions.bondDials(for: context.bondStage)
            .unlocked.contains(.tailDoubleWag)
        let first = spring(elapsed)
        let second = elapsed > 0.22 ? spring(elapsed - 0.22) : 0
        let wag = unlocked ? max(first, second) * 6 : first * 3
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 + 0.03 * first,
            earLeftDegrees: 6 * first,
            earRightDegrees: 6 * first,
            tailDegrees: wag)
    }

    // MARK: Long-press family (§6.1 — press-length is input)

    /// The head melt: the lean-in develops over the hold (the ramp
    /// saturates at 0.8 s), the release springs back with the touch
    /// spring's single soft overshoot and — at Best Friends and above
    /// (§3.4's slow-blink-back dial) — the slow contented blink. While
    /// the finger is still down, `holdSeconds` trails `elapsed` (the
    /// director passes the live hold), so the release branch only opens
    /// once the boundary resolves.
    private static func longPressHead(
        elapsed: Double, holdSeconds: Double, releaseSeconds: Double,
        context: MomoReactionContext
    ) -> MomoReactionMotion {
        let holdRamp = MomoCurves.smoothstep(min(holdSeconds, 0.8) / 0.8)
        let inRelease = elapsed > holdSeconds
        let back = inRelease ? spring(elapsed - holdSeconds) : 0
        let keep = 1 - back
        let blinkBackUnlocked = MomoExpressions.bondDials(for: context.bondStage)
            .unlocked.contains(.slowBlinkBack)
        let releaseBlink: Double =
            inRelease && blinkBackUnlocked
            ? bump(elapsed - holdSeconds, duration: releaseSeconds,
                   attack: 0.2, release: 0.35)
            : 0
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.03 * holdRamp * keep,
            apertureMultiplier: (1 - 0.4 * holdRamp) * (1 - 0.5 * releaseBlink),
            headRotationDegrees: 4 * holdRamp * keep,
            headTranslationY: 3 * holdRamp * keep,
            tailDegrees: 3 * holdRamp * keep)
    }

    /// The belly rock: side-to-side through the hold (`cycle` — the §6.1
    /// 0.9 s row, tempo-scaled), a spring settle on release whose settle
    /// lands exactly at `releaseSeconds` (the slot end, at every tempo —
    /// MINOR-1; time-warping preserves the spring's single soft overshoot,
    /// only the axis stretches), happy squint throughout.
    private static func longPressBelly(
        elapsed: Double, holdSeconds: Double, cycle: Double,
        releaseSeconds: Double
    ) -> MomoReactionMotion {
        let holdRamp = MomoCurves.smoothstep(min(holdSeconds, 0.45) / 0.45)
        let rock = sin(2 * .pi * min(elapsed, holdSeconds) / cycle)
        let inRelease = elapsed > holdSeconds
        let warp = 2 * MomoCurves.touchSpringResponseSeconds / releaseSeconds
        let back = inRelease ? spring((elapsed - holdSeconds) * warp) : 0
        let keep = 1 - back
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.02 * holdRamp * keep,
            apertureMultiplier: 1 - 0.35 * holdRamp * keep,
            bodyRotationDegrees: 2.5 * rock * holdRamp * keep,
            bodyTranslationX: 3 * rock * holdRamp * keep)
    }

    /// The zone-less Watch melt: one fixed gentle sink (no touch tracking
    /// on the single surface — FR-17).
    private static func bumpMelt(
        _ elapsed: Double, duration: Double
    ) -> MomoReactionMotion {
        let shape = bump(elapsed, duration: duration, attack: 0.25, release: 0.35)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.025 * shape,
            apertureMultiplier: 1 - 0.3 * shape,
            headRotationDegrees: 3 * shape)
    }

    // MARK: Stroke family (§6.1 — cyclical; the director ends the clip)

    private static func strokeHead(
        elapsed: Double, cycle: Double, deepened: Bool,
        context: MomoReactionContext
    ) -> MomoReactionMotion {
        let e = elapsed.truncatingRemainder(dividingBy: cycle)
        let shape = bump(e, duration: cycle, attack: 0.45, release: 0.5)
        // The deepening: the 2nd stroke in the same touch closes the eyes
        // fully and softens the ears further (§6.1's contentment deepens).
        let depth: Double = deepened ? 1.0 : 0.85
        let earSoften: Double = deepened ? -7.8 : -6.0
        return MomoReactionMotion(
            apertureMultiplier: 1 - depth * shape,
            earLeftDegrees: earSoften * shape,
            earRightDegrees: earSoften * shape,
            tailDegrees: 3 * shape,
            pupilOffset: glance(elapsed, toward: CGPoint(x: 0, y: -8)))
    }

    private static func strokeBelly(
        _ elapsed: Double, cycle: Double
    ) -> MomoReactionMotion {
        let e = elapsed.truncatingRemainder(dividingBy: cycle)
        let shape = bump(e, duration: cycle, attack: 0.3, release: 0.4)
        let rock = sin(2 * .pi * e / cycle)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.015 * shape,
            apertureMultiplier: 1 + 0.10 * shape,
            bodyRotationDegrees: 2 * rock * shape,
            bodyTranslationX: 2.5 * rock * shape,
            pupilOffset: glance(elapsed, toward: CGPoint(x: 0, y: 6)))
    }

    private static func stroke(
        _ elapsed: Double, cycle: Double
    ) -> MomoReactionMotion {
        let e = elapsed.truncatingRemainder(dividingBy: cycle)
        let shape = bump(e, duration: cycle, attack: 0.35, release: 0.45)
        let rock = sin(2 * .pi * e / cycle)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.015 * shape,
            apertureMultiplier: 1 - 0.4 * shape,
            bodyRotationDegrees: 1.5 * rock * shape)
    }

    // MARK: Sleep-adjacent beats (§4.3; eyes stay closed — the aperture
    // multiplies, so the asleep base of 0 can never reopen)

    private static func stir(_ elapsed: Double) -> MomoReactionMotion {
        let shape = bump(elapsed, duration: 1.0, attack: 0.3, release: 0.4)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.02 * shape,
            headRotationDegrees: 2 * shape,
            tailDegrees: 3 * shape)
    }

    private static func politelyFull(_ elapsed: Double) -> MomoReactionMotion {
        let sigh = bump(elapsed, duration: 1.2, attack: 0.5, release: 0.6)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.04 * sigh,
            apertureMultiplier: 1 - 0.3 * sigh,
            headRotationDegrees: 3 * sigh,
            cheekOpacity: 1 - 0.12 * sigh)
    }

    private static func gentleDecline(_ elapsed: Double) -> MomoReactionMotion {
        let shape = bump(elapsed, duration: 1.0, attack: 0.25, release: 0.35)
        return MomoReactionMotion(
            apertureMultiplier: 1 - 0.2 * shape,
            bodyRotationDegrees: 3.5 * shape,
            headRotationDegrees: 5 * shape)
    }

    // MARK: Meal beats (§4.2/§4.3/§4.5; §7.1's 2–3 bites)

    /// One bite window: mouth.eat weight, a food bob toward the mouth, a
    /// small chew sink.
    private static func bite(
        _ elapsed: Double, start: Double, length: Double
    ) -> Double {
        guard elapsed >= start, elapsed < start + length else { return 0 }
        return bump(elapsed - start, duration: length, attack: 0.25, release: 0.35)
    }

    private static func mealMotion(
        bites: [(start: Double, length: Double)], elapsed: Double,
        sink: Double
    ) -> MomoReactionMotion {
        var weight = 0.0
        for window in bites {
            weight = max(weight, bite(elapsed, start: window.start, length: window.length))
        }
        guard weight > 0 else { return MomoReactionMotion.identity }
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - sink * weight,
            headRotationDegrees: 2 * weight,
            mouthWeights: RigMouthWeights(neutral: 1 - weight, eat: weight, refuse: 0),
            food: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 6 * weight,
                    translation: CGPoint(x: 0, y: -12 * weight))))
    }

    /// Sleepy nibbles: heavy-lidded, two small bites (§4.3's L2-variant).
    private static func sleepyNibbles(_ elapsed: Double) -> MomoReactionMotion {
        var motion = mealMotion(
            bites: [(0.5, 0.9), (1.9, 0.9)], elapsed: elapsed, sink: 0.015)
        let heavy = bump(elapsed, duration: 3.5, attack: 0.3, release: 0.5)
        motion.apertureMultiplier = 1 - 0.5 * heavy
        return motion
    }

    /// The full meal: three bites in §7.1's 2–3 band (§4.2's eating state).
    private static func eating(_ elapsed: Double) -> MomoReactionMotion {
        mealMotion(
            bites: [(0.4, 0.8), (1.4, 0.8), (2.4, 0.8)], elapsed: elapsed,
            sink: 0.012)
    }

    /// The contented nibble: one shortened bite (05 §4.5's satiety window,
    /// the I-2 shortened eating animation of 02-mvp-prd §4).
    private static func nibble(_ elapsed: Double) -> MomoReactionMotion {
        mealMotion(bites: [(0.3, 0.8)], elapsed: elapsed, sink: 0.012)
    }

    // MARK: State/decline beats

    private static func blanketAdjust(_ elapsed: Double) -> MomoReactionMotion {
        let nudge = bump(elapsed, duration: 1.5, attack: 0.3, release: 0.4)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - 0.02 * nudge,
            headRotationDegrees: 2 * nudge,
            tailDegrees: 2 * nudge,
            blanket: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 4 * nudge,
                    translation: CGPoint(x: 0, y: -8 * nudge))))
    }

    private static func cheer(_ elapsed: Double) -> MomoReactionMotion {
        let s = spring(elapsed)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 + 0.04 * s,
            headRotationDegrees: 2 * s,
            earLeftDegrees: 8 * s,
            earRightDegrees: 8 * s)
    }

    private static func decline(_ elapsed: Double) -> MomoReactionMotion {
        let shape = bump(elapsed, duration: 1.0, attack: 0.2, release: 0.3)
        let shake = sin(2 * .pi * elapsed / 0.5)
        let refuse = bump(elapsed, duration: 1.0, attack: 0.25, release: 0.4)
        return MomoReactionMotion(
            bodyRotationDegrees: 1.5 * shape,
            headRotationDegrees: 3 * shake * shape,
            earLeftDegrees: -4 * shape,
            earRightDegrees: -4 * shape,
            mouthWeights: RigMouthWeights(
                neutral: 1 - refuse, eat: 0, refuse: refuse))
    }
}
