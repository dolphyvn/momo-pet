import CoreGraphics
import MomoCore

/// The rig's pure motion model (TASK-026 Requirement 2; 04 §2.2 + R1/R2):
/// clock time + display state IN, transform values OUT. No SwiftUI, no
/// `Path`, no per-frame geometry — the generated constants stay the single
/// source of shape, and this model only says where/how they sit (R1). One
/// creature (R2): one pose describes the whole rig.
///
/// TASK-027 completes the model: the pose is the EXPRESSION SYSTEM's band
/// rendering (§3 — aperture/lids/ears/tail/posture/breath) PLUS the idle
/// event log's active events, rendered through the §2.2 channels under the
/// §7.4 arbiter. The pose at T is a pure function of
/// `(idleSeed, displayState, T)`: the schedule is regenerated from the seed
/// (or injected), the arbiter admits the instant's events, and every value
/// is clamped MODEL-SIDE (ears ±25°, tail ±10°, pupil ≤ 30 % of the eye
/// radius; the body/head micro-motion bounds below) so any emitted pose
/// satisfies the channel-value laws. The §3.1 posture band is deliberately
/// NOT one of these model-side clamps: the expression layer pre-clamps the
/// static posture, and motion composes on top unclamped (ADR-011).
/// INV-5 scoping (TASK-028): the IDLE path never modulates `cheekOpacity`
/// and keeps the mouth at the authored neutral (three pre-built poses only
/// — no synthesized shapes); reaction/state choreography carries its own
/// accents through the overlay input (§4.3).
public struct RigMotionModel: Sendable {

    /// Which channels currently contribute to the pose. The default `.all`
    /// is "everything the model knows how to drive"; TASK-029's Reduce
    /// Motion mapping lands as static poses by disabling motion channels.
    public var enabledChannels: RigChannel

    /// The engine-injected idle seed (§5.1): opaque to the character, the
    /// sole source of scheduling randomness. The zero default keeps
    /// seed-less call sites deterministic.
    public var idleSeed: UInt64

    public init(enabledChannels: RigChannel = .all, idleSeed: UInt64 = 0) {
        self.enabledChannels = enabledChannels
        self.idleSeed = idleSeed
    }

    /// The pose at clock time `time` (seconds — `CharacterClock.elapsed()`).
    /// The idle schedule is derived from `idleSeed` for the window ending
    /// at `time`.
    public func pose(
        at time: Double,
        displayState: CharacterDisplayState
    ) -> RigPose {
        pose(
            at: time, displayState: displayState,
            schedule: MomoIdleSequencer.schedule(
                idleSeed: idleSeed, displayState: displayState, windowEnd: time))
    }

    /// The pose with the TASK-028 reaction overlay (the view's path — the
    /// schedule regenerates from the seed exactly as in the two-argument
    /// form).
    public func pose(
        at time: Double,
        displayState: CharacterDisplayState,
        reactionMotion: MomoReactionMotion
    ) -> RigPose {
        pose(
            at: time, displayState: displayState,
            schedule: MomoIdleSequencer.schedule(
                idleSeed: idleSeed, displayState: displayState, windowEnd: time),
            reactionMotion: reactionMotion)
    }

    /// The pose with an explicit schedule — the injection point for a
    /// cached event log (the view regenerating per frame is correct but
    /// wasteful; callers may pass `MomoIdleSequencer.schedule` output for
    /// a window covering their frames).
    public func pose(
        at time: Double,
        displayState: CharacterDisplayState,
        schedule: [MomoIdleEvent]
    ) -> RigPose {
        pose(
            at: time, displayState: displayState, schedule: schedule,
            reactionMotion: .identity)
    }

    /// The full pose: the idle result PLUS the reaction/state overlay
    /// (TASK-028). The overlay composes on top of the breath/idle result —
    /// multipliers multiply, deltas add — and the model-side channel-value
    /// laws below bound every write, so any emitted pose still satisfies
    /// them. `.identity` is the exact pre-TASK-028 pose (the TASK-027 pins
    /// stay green untouched).
    public func pose(
        at time: Double,
        displayState: CharacterDisplayState,
        schedule: [MomoIdleEvent],
        reactionMotion: MomoReactionMotion
    ) -> RigPose {
        var pose = RigPose.rest
        let expression = MomoExpressions.expression(for: displayState)
        let active = MomoIdleArbiter.admitted(schedule: schedule, at: time)

        // MARK: Body — posture × breath (§3.2 + §7.1), bottom-anchored

        let asleep = displayState.wakefulness == .asleep
        let breathAmplitude = expression.breathAmplitude
            * (asleep ? 1 - MomoCurves.sleepAmplitudeReduction : 1)
        var bodyScaleY = expression.postureScaleY
            * MomoCurves.breathScaleY(
                at: time, cycle: expression.breathCycleSeconds,
                amplitude: breathAmplitude)

        var bodyRotation = 0.0
        var bodyTranslationX = 0.0
        var headRotation = 0.0
        var headTranslationY = 0.0
        var earLeftDegrees = MomoCurves.clampedEarRotation(expression.earDegrees)
        var earRightDegrees = MomoCurves.clampedEarRotation(expression.earDegrees)
        var tailDegrees = 0.0

        // Joyful's slow wag (§3.2): a pure sine like the breath, inside the
        // ±10° tail bound; every other band's tail is still.
        if expression.tail == .slowWag, enabledChannels.contains(.tailRotation) {
            tailDegrees += MomoExpressions.tailWagAmplitudeDegrees
                * sin(2 * .pi * time / MomoExpressions.tailWagPeriodSeconds)
        }

        // MARK: Events — blink/gaze closures multiply the aperture; motion
        // events add deltas to their channels (each clamped below).

        var aperture = expression.aperture
        var pupilOffsetX = 0.0
        var pupilOffsetY = 0.0

        for event in active {
            let progress = elapsed(of: event, at: time)
            switch event.payload {
            case .blink(let envelope):
                aperture *= 1 - blinkClosure(envelope, elapsed: progress)

            case .gaze(let envelope):
                let shape = envelopeProgress(
                    in: envelope.shiftSeconds, hold: envelope.holdSeconds,
                    out: envelope.returnSeconds, elapsed: progress)
                if envelope.target == .eyesCloseMoment {
                    // The close-moment "look" IS a slow close and reopen.
                    aperture *= 1 - shape
                } else {
                    let offset = envelope.target.pupilOffset
                    pupilOffsetX += offset.x * shape
                    pupilOffsetY += offset.y * shape
                }

            case .variant(let envelope):
                render(
                    variant: envelope, progress: progress, time: time,
                    into: &bodyScaleY, bodyRotation: &bodyRotation,
                    bodyTranslationX: &bodyTranslationX,
                    headRotation: &headRotation,
                    headTranslationY: &headTranslationY,
                    earLeftDegrees: &earLeftDegrees,
                    earRightDegrees: &earRightDegrees,
                    tailDegrees: &tailDegrees, aperture: &aperture)

            case .yawn(let envelope):
                let shape = envelopeProgress(
                    in: envelope.closeSeconds, hold: envelope.holdSeconds,
                    out: envelope.openSeconds, elapsed: progress)
                aperture *= 1 - shape
                // The yawn's small head nod rides the same envelope.
                headRotation += 3.0 * shape
            }
        }

        // MARK: Reaction/state overlay (TASK-028) — composes on the idle
        // result. Deltas ADD to the same accumulators; every write below
        // still passes the model-side channel-value laws, and nothing
        // re-clamps through the posture band (ADR-011 — reactions compose
        // multiplicatively/additively on top, exactly like idle motion).

        if reactionMotion != .identity {
            bodyScaleY *= reactionMotion.bodyScaleYMultiplier
            bodyRotation += reactionMotion.bodyRotationDegrees
            bodyTranslationX += reactionMotion.bodyTranslationX
            headRotation += reactionMotion.headRotationDegrees
            headTranslationY += reactionMotion.headTranslationY
            earLeftDegrees += reactionMotion.earLeftDegrees
            earRightDegrees += reactionMotion.earRightDegrees
            tailDegrees += reactionMotion.tailDegrees
            aperture *= reactionMotion.apertureMultiplier
            pupilOffsetX += reactionMotion.pupilOffset.x
            pupilOffsetY += reactionMotion.pupilOffset.y
        }

        // MARK: Gate + write (model-side channel-value laws; body scaleY
        // composes unclamped — ADR-011)

        if enabledChannels.contains(.bodyScale) {
            // ADR-011: the static posture was already pre-clamped in the
            // expression layer (§3.1's band governs the posture channel);
            // the breath (§7.1) and idle-event motion (§5.2) compose
            // multiplicatively on top, each bounded by its own authored
            // magnitudes and never re-clamped here, so the §7.2 breath
            // stays a pure sine on every band.
            pose.body.scaleY = CGFloat(bodyScaleY)
        }
        if enabledChannels.contains(.bodyRotation) {
            pose.body.rotationDegrees =
                clampSymmetric(bodyRotation, limit: 5.0)
        }
        if enabledChannels.contains(.bodyPosition) {
            pose.body.translation.x = CGFloat(clampSymmetric(bodyTranslationX, limit: 10.0))
        }
        if enabledChannels.contains(.headRotation) {
            pose.head.rotationDegrees = clampSymmetric(headRotation, limit: 10.0)
        }
        if enabledChannels.contains(.headPosition) {
            pose.head.translation.y = CGFloat(clampSymmetric(headTranslationY, limit: 6.0))
        }
        if enabledChannels.contains(.earLeftRotation) {
            pose.earLeft.rotationDegrees = MomoCurves.clampedEarRotation(earLeftDegrees)
        }
        if enabledChannels.contains(.earRightRotation) {
            pose.earRight.rotationDegrees = MomoCurves.clampedEarRotation(earRightDegrees)
        }
        if enabledChannels.contains(.tailRotation) {
            pose.tail.rotationDegrees = MomoCurves.clampedTailRotation(tailDegrees)
        }

        if enabledChannels.contains(.eyeLeftLidScaleY) {
            pose.eyeLeft.lidScaleY = MomoExpressions.lidScaleY(forAperture: aperture)
        }
        if enabledChannels.contains(.eyeRightLidScaleY) {
            pose.eyeRight.lidScaleY = MomoExpressions.lidScaleY(forAperture: aperture)
        }
        let clampedPupil = Self.clampedPupilOffset(
            CGPoint(x: pupilOffsetX, y: pupilOffsetY),
            eyeRadius: CGFloat(MomoExpressions.eyeRadiusUnits))
        if enabledChannels.contains(.eyeLeftPupilOffset) {
            pose.eyeLeft.pupilOffset = clampedPupil
        }
        if enabledChannels.contains(.eyeRightPupilOffset) {
            pose.eyeRight.pupilOffset = clampedPupil
        }
        if enabledChannels.contains(.eyeLeftLowerLid) {
            pose.eyeLeft.lowerLid = expression.lowerLid
        }
        if enabledChannels.contains(.eyeRightLowerLid) {
            pose.eyeRight.lowerLid = expression.lowerLid
        }

        // INV-5 scoping (TASK-028 R9/R10): the IDLE path never modulates
        // cheekOpacity or the mouth — the authored neutral stands. Reaction
        // and state choreography MAY (§4.3 names cheek accents and the
        // mouth poses for reactions); their accents arrive through the
        // overlay and gate on the same channels.
        if reactionMotion == .identity {
            pose.mouth = .neutral
            pose.cheekOpacity = 1
        } else {
            if enabledChannels.contains(.mouthPose) {
                pose.mouth = reactionMotion.mouthWeights ?? .neutral
            }
            if enabledChannels.contains(.cheekOpacity) {
                pose.cheekOpacity = reactionMotion.cheekOpacity ?? 1
            }
            if enabledChannels.contains(.propFood) {
                pose.food = reactionMotion.food
            }
            if enabledChannels.contains(.propBlanket) {
                pose.blanket = reactionMotion.blanket
            }
            if enabledChannels.contains(.propSparkleA) {
                pose.sparkleA = reactionMotion.sparkleA
            }
            if enabledChannels.contains(.propSparkleB) {
                pose.sparkleB = reactionMotion.sparkleB
            }
        }

        return pose
    }

    // MARK: - Variant rendering (catalog-driven, additive)

    /// One variant's contribution to the channel accumulators. Motion
    /// magnitudes are authored per row here; adding a variant means adding
    /// a catalog row (MomoIdleVariants) plus a case here — the schedulers
    /// never change.
    private func render(
        variant envelope: MomoVariantEnvelope,
        progress: Double,
        time: Double,
        into bodyScaleY: inout Double,
        bodyRotation: inout Double,
        bodyTranslationX: inout Double,
        headRotation: inout Double,
        headTranslationY: inout Double,
        earLeftDegrees: inout Double,
        earRightDegrees: inout Double,
        tailDegrees: inout Double,
        aperture: inout Double
    ) {
        let mirror: Double = envelope.mirrored ? -1 : 1
        // The crossfade family rides the §7.2 fade-in/hold/fade-out shape;
        // the spring family reads `progress` (raw elapsed) through
        // springBump instead.
        let shape = envelopeProgress(
            in: envelope.inSeconds, hold: envelope.holdSeconds,
            out: envelope.outSeconds, elapsed: progress)

        switch envelope.id {
        case .weightShift:
            // The eager sideways weight-shift with a hint of lean (§3.2).
            bodyTranslationX += 8.0 * mirror * shape
            bodyRotation += 2.5 * mirror * shape

        case .singleEarTwitch:
            // Mirrored == true lifts the LEFT ear (pinned convention).
            if envelope.mirrored {
                earLeftDegrees += 12.0 * springBump(progress, of: envelope)
            } else {
                earRightDegrees += 12.0 * springBump(progress, of: envelope)
            }

        case .tailFlick:
            tailDegrees += 7.0 * mirror * springBump(progress, of: envelope)

        case .fullBodyLookAround:
            // The whole body slowly looks around (§5.2): body then head.
            bodyRotation += 4.0 * mirror * shape
            headRotation += 3.0 * mirror * shape

        case .cheekPressRest:
            // Settles onto one cheek: a slight sink (+ rotation).
            bodyScaleY *= 1 - 0.015 * shape
            bodyRotation += 1.5 * mirror * shape

        case .perEarCuriousAsymmetry:
            // Opposite angles for a beat — the "asymmetric = curious" read.
            if envelope.mirrored {
                earLeftDegrees += -10.0 * springBump(progress, of: envelope)
                earRightDegrees += 10.0 * springBump(progress, of: envelope)
            } else {
                earLeftDegrees += 10.0 * springBump(progress, of: envelope)
                earRightDegrees += -10.0 * springBump(progress, of: envelope)
            }

        case .calmCoexist:
            // §3.4's calm coexist: the eyes soften to ~55 % of the band's
            // aperture while the variant holds.
            aperture *= 1 - 0.45 * shape

        case .headNod:
            // Drowsy's micro-nod: a small rotation + downward drift.
            let bump = springBump(progress, of: envelope)
            headRotation += 2.5 * bump
            headTranslationY += 3.0 * bump
        }
    }

    // MARK: - Envelope shapes (§7.2 families)

    /// The crossfade-family envelope progress in 0…1: smoothstep up over
    /// `in`, hold, smoothstep down over `out` (yawn uses the same shape).
    private func envelopeProgress(
        in inSeconds: Double, hold holdSeconds: Double,
        out outSeconds: Double, elapsed: Double
    ) -> Double {
        if elapsed < inSeconds {
            return MomoCurves.smoothstep(elapsed / inSeconds)
        }
        let holdEnd = inSeconds + holdSeconds
        if elapsed < holdEnd {
            return 1
        }
        return 1 - MomoCurves.smoothstep((elapsed - holdEnd) / outSeconds)
    }

    /// The blink's closure in 0…1: smoothstep down (close) then up (open);
    /// a double blink repeats the pair after the authored gap.
    private func blinkClosure(_ envelope: MomoBlinkEnvelope, elapsed: Double) -> Double {
        let pair = envelope.closeSeconds + envelope.openSeconds
        let phase = elapsed.truncatingRemainder(dividingBy: pair + envelope.interBlinkGapSeconds)
        if envelope.isDouble, phase >= pair {
            return 0 // the authored gap between the two closings
        }
        if phase < envelope.closeSeconds {
            return MomoCurves.smoothstep(phase / envelope.closeSeconds)
        }
        return 1 - MomoCurves.smoothstep(
            (phase - envelope.closeSeconds) / envelope.openSeconds)
    }

    /// The spring-family bump (§7.2's spring discipline for ears/tail/nod):
    /// the idle spring's step response in, held, and the mirrored step out.
    /// Continuous everywhere, never negative, and each approach makes at
    /// most one soft overshoot (ζ = `MomoCurves.idleSpringDamping`).
    private func springBump(_ elapsed: Double, of envelope: MomoVariantEnvelope) -> Double {
        let response = MomoCurves.idleSpringResponseSeconds
        let omega = 2 * .pi / response
        let holdEnd = envelope.inSeconds + envelope.holdSeconds
        let release = elapsed - holdEnd
        let stepIn = elapsed <= 0
            ? 0
            : MomoCurves.dampedSpringStep(
                at: min(elapsed, response * 2), damping: MomoCurves.idleSpringDamping,
                omega: omega)
        let stepOut = release <= 0
            ? 0
            : MomoCurves.dampedSpringStep(
                at: min(release, response * 2), damping: MomoCurves.idleSpringDamping,
                omega: omega)
        return max(0, stepIn * (1 - stepOut))
    }

    /// An event's time since its start (negative before the window opens —
    /// harmless for admitted events, which are active by construction).
    private func elapsed(of event: MomoIdleEvent, at time: Double) -> Double {
        time - event.start
    }

    /// Clamps into ±`limit` (authored micro-motion bounds for the body/head
    /// channels; ears/tail/posture/pupil have their own named laws).
    private func clampSymmetric(_ value: Double, limit: Double) -> Double {
        min(max(value, -limit), limit)
    }

    /// §2.4's pupil clamp: gaze offsets never exceed 30 % of the eye radius.
    /// Magnitude is capped to the bound; direction is preserved exactly.
    /// The MODEL applies this (a channel-value law), so any pose the model
    /// emits satisfies the bound.
    public static func clampedPupilOffset(
        _ offset: CGPoint, eyeRadius: CGFloat
    ) -> CGPoint {
        let bound = eyeRadius * 0.30
        let magnitude = (offset.x * offset.x + offset.y * offset.y).squareRoot()
        guard magnitude > bound, magnitude > 0 else { return offset }
        let scale = bound / magnitude
        return CGPoint(x: offset.x * scale, y: offset.y * scale)
    }
}
