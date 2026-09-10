import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

/// The motion model's idle rendering (04 §5 + §7.4): each event kind's
/// channel signature, the INV-5 quiet law (cheek/mouth untouched), the
/// aliveness floor, and the model-side channel-value clamps. Poses here are
/// built from HAND-CONSTRUCTED schedules so each rendering rule is isolated
/// from the scheduler's randomness; the vector pins in MomoIdleSequencerTests
/// tie the whole pipeline back to the seed.
@Suite("RigMotionModel idle rendering — events through channels, INV-5, clamps")
struct MomoIdleRenderTests {

    // MARK: - Fixtures

    private let content = CharacterDisplayState(
        moodBand: .content, energyBand: .relaxed, bondStage: .gettingClose,
        wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)

    private let soulCompanions = CharacterDisplayState(
        moodBand: .content, energyBand: .relaxed, bondStage: .soulCompanions,
        wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)

    private let drowsy = CharacterDisplayState(
        moodBand: .content, energyBand: .drowsy, bondStage: .gettingClose,
        wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)

    private let model = RigMotionModel()

    private func blink(
        at start: Double = 0, close: Double = 0.15, open: Double = 0.12,
        double: Bool = false
    ) -> MomoIdleEvent {
        MomoIdleEvent(
            kind: .blink, start: start, duration: close + open,
            payload: .blink(MomoBlinkEnvelope(
                isDouble: double, closeSeconds: close, openSeconds: open,
                interBlinkGapSeconds: 0.09)))
    }

    private func gaze(
        _ target: MomoGazeTarget, at start: Double = 0,
        shift: Double = 0.25, hold: Double = 1.0, back: Double = 0.65
    ) -> MomoIdleEvent {
        MomoIdleEvent(
            kind: .gaze, start: start, duration: shift + hold + back,
            payload: .gaze(MomoGazeEnvelope(
                target: target, shiftSeconds: shift, holdSeconds: hold,
                returnSeconds: back)))
    }

    private func variant(
        _ id: MomoVariantID, mirrored: Bool, at start: Double = 0,
        inSeconds: Double, hold: Double
    ) -> MomoIdleEvent {
        let spring = MomoIdleVariantCatalog.spec(for: id)?.usesSpringEnvelope ?? false
        let fadeIn = spring ? MomoCurves.idleSpringResponseSeconds : inSeconds
        let fadeOut = fadeIn
        return MomoIdleEvent(
            kind: .variant, start: start, duration: fadeIn + hold + fadeOut,
            payload: .variant(MomoVariantEnvelope(
                id: id, mirrored: mirrored, inSeconds: fadeIn,
                holdSeconds: hold, outSeconds: fadeOut)))
    }

    private func yawn(at start: Double = 0) -> MomoIdleEvent {
        MomoIdleEvent(
            kind: .yawn, start: start, duration: 1.4,
            payload: .yawn(MomoYawnEnvelope(
                closeSeconds: 0.45, holdSeconds: 0.5, openSeconds: 0.45)))
    }

    /// The idle spring's bump at a hold-mid sample (release not yet reached):
    /// the private `springBump` reduces to the capped step response.
    private func springHoldValue(elapsed: Double) -> Double {
        max(0, MomoCurves.dampedSpringStep(
            at: min(elapsed, MomoCurves.idleSpringResponseSeconds * 2),
            damping: MomoCurves.idleSpringDamping,
            omega: 2 * .pi / MomoCurves.idleSpringResponseSeconds))
    }

    // MARK: - Blink rendering

    @Test("A blink multiplies the aperture by its closure: mid-close lands on the half lid")
    func blinkClosureDrivesTheLid() {
        let pose = model.pose(
            at: 0.075, displayState: content, schedule: [blink()])
        // smoothstep(0.5) = 0.5 → aperture 0.9 × 0.5 = 0.45.
        let expected = MomoExpressions.lidScaleY(
            forAperture: 0.9 * (1 - MomoCurves.smoothstep(0.075 / 0.15)))
        #expect(pose.eyeLeft.lidScaleY == expected)
        #expect(pose.eyeLeft.lidScaleY == pose.eyeRight.lidScaleY)
        #expect(pose.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0.45))
    }

    @Test("Outside a blink's window the lids sit on the band aperture")
    func blinkOutsideWindowLeavesBandLids() {
        let pose = model.pose(at: 5, displayState: content, schedule: [blink()])
        #expect(pose.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0.9))
        #expect(pose.eyeLeft.lidScaleY == 0.7357142857142855)
    }

    // MARK: - Gaze rendering

    @Test("Gaze hold lands each target's pupil offset; eyes-close-moment closes instead")
    func gazeTargetsLandTheirOffsets() {
        // Hold-phase sample: the shift's shape is fully 1.
        let left = model.pose(at: 1, displayState: content, schedule: [gaze(.left)])
        #expect(left.eyeLeft.pupilOffset == CGPoint(x: -15, y: 0))
        #expect(left.eyeRight.pupilOffset == CGPoint(x: -15, y: 0))

        let right = model.pose(at: 1, displayState: content, schedule: [gaze(.right)])
        #expect(right.eyeLeft.pupilOffset == CGPoint(x: 15, y: 0))

        let up = model.pose(
            at: 1, displayState: content, schedule: [gaze(.upTowardUser)])
        #expect(up.eyeLeft.pupilOffset == CGPoint(x: 0, y: -11))

        let atUser = model.pose(at: 1, displayState: content, schedule: [gaze(.atUser)])
        #expect(atUser.eyeLeft.pupilOffset == .zero)
        // Meeting the user's eyes moves nothing else.
        #expect(atUser.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0.9))

        // The close-moment's "look" IS a slow close: fully closed at hold.
        let close = model.pose(
            at: 1, displayState: content, schedule: [gaze(.eyesCloseMoment)])
        #expect(close.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0))
        #expect(close.eyeLeft.pupilOffset == .zero)
    }

    @Test("Mid-shift the gaze offset tracks the smoothstep shape")
    func gazeShiftShape() {
        let pose = model.pose(at: 0.125, displayState: content, schedule: [gaze(.left)])
        #expect(pose.eyeLeft.pupilOffset == CGPoint(x: -15 * MomoCurves.smoothstep(0.5), y: 0))
    }

    // MARK: - Variant rendering (each catalog row's channel signature)

    @Test("singleEarTwitch lifts ONE ear by ~12° — the mirror flips the ear")
    func earTwitchRenders() {
        let rightEar = model.pose(
            at: 0.85, displayState: content,
            schedule: [variant(.singleEarTwitch, mirrored: false, inSeconds: 0.35, hold: 1.0)])
        #expect(abs(rightEar.earRight.rotationDegrees - 12 * springHoldValue(elapsed: 0.85)) < 1e-9)
        #expect(rightEar.earLeft.rotationDegrees == 0)

        let leftEar = model.pose(
            at: 0.85, displayState: content,
            schedule: [variant(.singleEarTwitch, mirrored: true, inSeconds: 0.35, hold: 1.0)])
        #expect(abs(leftEar.earLeft.rotationDegrees - 12 * springHoldValue(elapsed: 0.85)) < 1e-9)
        #expect(leftEar.earRight.rotationDegrees == 0)
    }

    @Test("tailFlick swings ±7° inside the ±10° tail bound; the mirror flips the sign")
    func tailFlickRenders() {
        let right = model.pose(
            at: 0.85, displayState: content,
            schedule: [variant(.tailFlick, mirrored: false, inSeconds: 0.35, hold: 1.0)])
        #expect(abs(right.tail.rotationDegrees - 7 * springHoldValue(elapsed: 0.85)) < 1e-9)

        let left = model.pose(
            at: 0.85, displayState: content,
            schedule: [variant(.tailFlick, mirrored: true, inSeconds: 0.35, hold: 1.0)])
        #expect(abs(left.tail.rotationDegrees + 7 * springHoldValue(elapsed: 0.85)) < 1e-9)
        #expect(abs(left.tail.rotationDegrees) <= MomoCurves.tailRotationLimitDegrees.upperBound)
    }

    @Test("weightShift translates ±8 and leans ±2.5° — exactly, at hold")
    func weightShiftRenders() {
        let right = model.pose(
            at: 0.6, displayState: content,
            schedule: [variant(.weightShift, mirrored: false, inSeconds: 0.3, hold: 0.8)])
        #expect(right.body.translation.x == 8)
        #expect(right.body.rotationDegrees == 2.5)

        let left = model.pose(
            at: 0.6, displayState: content,
            schedule: [variant(.weightShift, mirrored: true, inSeconds: 0.3, hold: 0.8)])
        #expect(left.body.translation.x == -8)
        #expect(left.body.rotationDegrees == -2.5)
    }

    @Test("weightShift mid-fade tracks the smoothstep envelope, not raw elapsed")
    func weightShiftMidFadeTracksTheEnvelope() {
        let schedule = [variant(.weightShift, mirrored: false, inSeconds: 0.3, hold: 0.8)]

        // Mid-fade (the review's NOTE-3 sample): halfway in, the shape is
        // 0.5 — a raw-elapsed regression (×0.15 here) cannot pass. (Types
        // follow the rig's channels — translation is CGFloat, rotation
        // Double; a syntactically mixed CGFloat == Double capture
        // mis-evaluates inside #expect, TASK-026 notes.)
        let mid = model.pose(at: 0.15, displayState: content, schedule: schedule)
        #expect(mid.body.translation.x == CGFloat(8 * MomoCurves.smoothstep(0.15 / 0.3)))
        #expect(mid.body.rotationDegrees == 2.5 * MomoCurves.smoothstep(0.15 / 0.3))

        // Quarter-fade: smoothstep(0.25) = 0.15625, where a LINEAR fade
        // (0.25) diverges — the midpoint alone cannot catch that variant.
        let quarter = model.pose(at: 0.075, displayState: content, schedule: schedule)
        #expect(quarter.body.translation.x == CGFloat(8 * MomoCurves.smoothstep(0.075 / 0.3)))
        #expect(quarter.body.rotationDegrees == 2.5 * MomoCurves.smoothstep(0.075 / 0.3))
    }

    @Test("fullBodyLookAround turns the body ±4° then the head ±3° at hold")
    func fullBodyLookAroundRenders() {
        let pose = model.pose(
            at: 0.6, displayState: content,
            schedule: [variant(.fullBodyLookAround, mirrored: false, inSeconds: 0.3, hold: 1.2)])
        #expect(pose.body.rotationDegrees == 4)
        #expect(pose.head.rotationDegrees == 3)

        let mirrored = model.pose(
            at: 0.6, displayState: content,
            schedule: [variant(.fullBodyLookAround, mirrored: true, inSeconds: 0.3, hold: 1.2)])
        #expect(mirrored.body.rotationDegrees == -4)
        #expect(mirrored.head.rotationDegrees == -3)
    }

    @Test("cheekPressRest sinks the body ×0.985 (about the breath) and leans ±1.5°")
    func cheekPressRestRenders() {
        let time = 0.6
        let pose = model.pose(
            at: time, displayState: content,
            schedule: [variant(.cheekPressRest, mirrored: false, inSeconds: 0.3, hold: 1.0)])
        let breath = MomoCurves.breathScaleY(at: time, cycle: 4.9, amplitude: 0.02)
        #expect(pose.body.scaleY == CGFloat(MomoCurves.clampedPostureScaleY(breath * (1 - 0.015))))
        #expect(pose.body.rotationDegrees == 1.5)
    }

    @Test("perEarCuriousAsymmetry splays the ears opposite; the mirror swaps the sides")
    func perEarCuriousAsymmetryRenders() {
        let bump = springHoldValue(elapsed: 0.85)
        let plain = model.pose(
            at: 0.85, displayState: content,
            schedule: [variant(.perEarCuriousAsymmetry, mirrored: false, inSeconds: 0.35, hold: 1.0)])
        #expect(abs(plain.earLeft.rotationDegrees - 10 * bump) < 1e-9)
        #expect(abs(plain.earRight.rotationDegrees + 10 * bump) < 1e-9)

        let mirrored = model.pose(
            at: 0.85, displayState: content,
            schedule: [variant(.perEarCuriousAsymmetry, mirrored: true, inSeconds: 0.35, hold: 1.0)])
        #expect(abs(mirrored.earLeft.rotationDegrees + 10 * bump) < 1e-9)
        #expect(abs(mirrored.earRight.rotationDegrees - 10 * bump) < 1e-9)
    }

    @Test("calmCoexist softens the aperture to 55 % of the band's while it holds")
    func calmCoexistRenders() {
        let pose = model.pose(
            at: 0.6, displayState: soulCompanions,
            schedule: [variant(.calmCoexist, mirrored: false, inSeconds: 0.3, hold: 3.0)])
        #expect(
            pose.eyeLeft.lidScaleY
                == MomoExpressions.lidScaleY(forAperture: 0.9 * (1 - 0.45)))
    }

    @Test("headNod dips the head ~2.5° and ~3 units while it holds (Drowsy state)")
    func headNodRenders() {
        let pose = model.pose(
            at: 0.85, displayState: drowsy,
            schedule: [variant(.headNod, mirrored: false, inSeconds: 0.35, hold: 0.9)])
        let bump = springHoldValue(elapsed: 0.85)
        #expect(abs(pose.head.rotationDegrees - 2.5 * bump) < 1e-9)
        #expect(abs(Double(pose.head.translation.y) - 3 * bump) < 1e-9)
    }

    // MARK: - Yawn rendering

    @Test("The yawn closes the eyes fully and nods the head 3° at its hold")
    func yawnRenders() {
        let closed = model.pose(at: 0.45, displayState: drowsy, schedule: [yawn()])
        #expect(closed.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0))
        #expect(closed.eyeLeft.lidScaleY == 142.0 / 56.0)

        let holding = model.pose(at: 0.7, displayState: drowsy, schedule: [yawn()])
        #expect(holding.head.rotationDegrees == 3.0)
        #expect(holding.eyeLeft.lidScaleY == 142.0 / 56.0)

        // After the yawn the band expression returns (drowsy half-lid).
        let after = model.pose(at: 2.0, displayState: drowsy, schedule: [yawn()])
        #expect(
            after.eyeLeft.lidScaleY
                == MomoExpressions.lidScaleY(forAperture: 0.9 * MomoExpressions.drowsyApertureMultiplier))
    }

    // MARK: - Wakefulness rows through the model

    @Test("Asleep renders closed lids, the damped breath, the kept band, and no events")
    func asleepRenders() {
        let joyfulAsleep = CharacterDisplayState(
            moodBand: .joyful, energyBand: .relaxed, bondStage: .gettingClose,
            wakefulness: .asleep, activity: nil, satietyHint: nil, momentRequest: nil)
        let closedLid = MomoExpressions.lidScaleY(forAperture: 0)

        let atRest = model.pose(at: 0, displayState: joyfulAsleep)
        #expect(atRest.eyeLeft.lidScaleY == closedLid)
        #expect(atRest.eyeLeft.pupilOffset == .zero)
        #expect(atRest.earLeft.rotationDegrees == 16.5) // the band keeps its ears
        #expect(atRest.tail.rotationDegrees == 0) // but the tail is still
        #expect(atRest.body.scaleY == 1.03) // breath(0) = 1 exactly

        // The breath rides the Drowsy/asleep row at −30 % amplitude, and
        // the composition is UNCLAMPED (ADR-011): the band's 1.03 posture
        // sits at §3.1's ceiling, so the sine's peaks ride past it — §7.1's
        // amplitude row and §7.2's pure-sine law govern the motion channel.
        let amplitude = 0.022 * (1 - MomoCurves.sleepAmplitudeReduction)
        let peak = model.pose(at: 1.8, displayState: joyfulAsleep)
        #expect(
            peak.body.scaleY
                == CGFloat(1.03 * MomoCurves.breathScaleY(
                    at: 1.8, cycle: 7.2, amplitude: amplitude)))
        let trough = model.pose(at: 5.4, displayState: joyfulAsleep)
        #expect(
            trough.body.scaleY
                == CGFloat(1.03 * MomoCurves.breathScaleY(
                    at: 5.4, cycle: 7.2, amplitude: amplitude)))
        // Non-vacuous: the peak really does leave §3.1's posture band.
        #expect(peak.body.scaleY > MomoCurves.postureScaleYRange.upperBound)
    }

    // MARK: - Breath purity (the composition law, ADR-011)

    /// The analytic body scaleY the composition law (ADR-011) demands: the
    /// pre-clamped static posture (§3.1's band, applied in the expression
    /// layer) × the band's pure sine (§7.1 amplitude, §7.2 "pure sine"),
    /// with the asleep −30 % reduction keyed off the WAKEFULNESS exactly as
    /// the model keys it (the Drowsy/exhausted cycle override already sits
    /// in the expression).
    private func analyticBodyScaleY(
        display: CharacterDisplayState, expression: MomoExpressions.MomoExpression,
        time: Double
    ) -> Double {
        let amplitude = expression.breathAmplitude
            * (display.wakefulness == .asleep ? 1 - MomoCurves.sleepAmplitudeReduction : 1)
        return expression.postureScaleY
            * MomoCurves.breathScaleY(
                at: time, cycle: expression.breathCycleSeconds, amplitude: amplitude)
    }

    @Test("Breath purity: every band renders posture × sine digit-for-digit, never clamped")
    func breathSinePuritySweep() {
        let moods: [MoodBand] = [.joyful, .content, .wistful, .low]
        let energies: [EnergyBand] = [.energetic, .relaxed, .drowsy, .exhausted]
        let wakefulnesses: [Wakefulness] = [.awake, .settling, .asleep, .waking]
        let samples = 720 // half-degree steps over one full cycle
        var bandTopExits = 0
        var bandBottomExits = 0

        for mood in moods {
            for energy in energies {
                for wakefulness in wakefulnesses {
                    let display = CharacterDisplayState(
                        moodBand: mood, energyBand: energy, bondStage: .gettingClose,
                        wakefulness: wakefulness, activity: nil, satietyHint: nil,
                        momentRequest: nil)
                    let expression = MomoExpressions.expression(for: display)
                    let cycle = expression.breathCycleSeconds
                    let band = MomoCurves.postureScaleYRange

                    // Empty schedule: the sweep isolates the standing breath.
                    var previous: CGFloat?
                    var flatSamples = 0
                    var diverged: String?
                    var renderedMin = Double.infinity
                    var renderedMax = -Double.infinity
                    var analyticMin = Double.infinity
                    var analyticMax = -Double.infinity
                    for i in 0..<samples {
                        let t = cycle * Double(i) / Double(samples)
                        let analytic = analyticBodyScaleY(
                            display: display, expression: expression, time: t)
                        let rendered = Double(
                            model.pose(at: t, displayState: display, schedule: [])
                                .body.scaleY)
                        if diverged == nil, rendered != analytic {
                            diverged = "sample \(i) (t = \(t)): \(rendered) vs \(analytic)"
                        }
                        if let previous, rendered == previous { flatSamples += 1 }
                        previous = CGFloat(rendered)
                        renderedMin = min(renderedMin, rendered)
                        renderedMax = max(renderedMax, rendered)
                        analyticMin = min(analyticMin, analytic)
                        analyticMax = max(analyticMax, analytic)
                    }

                    let label = "\(mood)/\(energy)/\(wakefulness)"
                    // (a) Zero flat samples: consecutive samples of a pure
                    // sine never coincide (a clamp freezes runs of them),
                    // and the render matches the analytic composition at
                    // EVERY sample — digit-for-digit.
                    #expect(
                        diverged == nil,
                        "\(label): rendered breath diverged from the analytic composition (\(diverged ?? "unavailable"))")
                    #expect(
                        flatSamples == 0,
                        "\(label): \(flatSamples) flat samples — the breath is being clamped")
                    // (b) The cycle's extremes ARE the analytic extremes.
                    #expect(
                        renderedMin == analyticMin && renderedMax == analyticMax,
                        "\(label): rendered extremes (\(renderedMin)…\(renderedMax)) miss the analytic (\(analyticMin)…\(analyticMax))")
                    // Non-vacuity per row: wherever the analytic sine leaves
                    // §3.1's posture band, the render must follow it out —
                    // the re-introduction of any composed clamp fails here.
                    if analyticMax > band.upperBound {
                        bandTopExits += 1
                        #expect(
                            renderedMax > band.upperBound,
                            "\(label): analytic peak \(analyticMax) exceeds the posture band but the render never did")
                    }
                    if analyticMin < band.lowerBound {
                        bandBottomExits += 1
                        #expect(
                            renderedMin < band.lowerBound,
                            "\(label): analytic trough \(analyticMin) undercuts the posture band but the render never did")
                    }
                }
            }
        }

        // Battery-level non-vacuity: the sweep exercises BOTH band edges
        // (Joyful rides past the ceiling; Wistful/Low undercut the floor;
        // Content — the canonical row — stays inside, which is why the old
        // clamp was invisible there).
        #expect(bandTopExits > 0)
        #expect(bandBottomExits > 0)
    }

    // MARK: - INV-5 + the aliveness floor

    @Test("INV-5: no idle rendering ever touches cheekOpacity or the mouth")
    func invFiveBattery() {
        let states = [content, drowsy, soulCompanions]
        for seed: UInt64 in 0..<40 {
            for display in states {
                let log = MomoIdleSequencer.schedule(
                    idleSeed: seed, displayState: display, windowEnd: 30)
                var time = 0.0
                while time < 30 {
                    let pose = model.pose(
                        at: time, displayState: display, schedule: log)
                    #expect(pose.mouth == .neutral)
                    #expect(pose.cheekOpacity == 1)
                    time += 1
                }
            }
        }
    }

    @Test("An empty schedule still renders the living band (the aliveness floor)")
    func alivenessFloor() {
        let pose = model.pose(at: 5, displayState: content, schedule: [])
        #expect(pose.eyeLeft.lidScaleY == 0.7357142857142855)
        #expect(pose.eyeLeft.pupilOffset == .zero)
        #expect(pose.earLeft.rotationDegrees == 0)
        #expect(pose.tail.rotationDegrees == 0)
        #expect(
            pose.body.scaleY
                == CGFloat(MomoCurves.clampedPostureScaleY(
                    MomoCurves.breathScaleY(at: 5, cycle: 4.9, amplitude: 0.02))))
        #expect(pose.body.scaleY != 1) // breathing
    }

    // MARK: - Gating + symmetry + the seed-derived convenience path

    @Test("Gating the lid channels leaves the eyes at rest mid-blink")
    func lidGatingIsNoop() {
        let gated = RigMotionModel(
            enabledChannels: .all.subtracting([.eyeLeftLidScaleY, .eyeRightLidScaleY]))
        let pose = gated.pose(at: 0.075, displayState: content, schedule: [blink()])
        #expect(pose.eyeLeft.lidScaleY == RigEyePose.rest.lidScaleY)
        #expect(pose.eyeRight == .rest)
    }

    @Test("Disabling the tail channel silences the Joyful wag")
    func tailGatingStopsTheWag() {
        let joyful = CharacterDisplayState(
            moodBand: .joyful, energyBand: .relaxed, bondStage: .gettingClose,
            wakefulness: .awake, activity: nil, satietyHint: nil, momentRequest: nil)
        let gated = RigMotionModel(enabledChannels: .all.subtracting(.tailRotation))
        let pose = gated.pose(at: 0.8, displayState: joyful, schedule: [])
        #expect(pose.tail.rotationDegrees == 0)

        let full = model.pose(at: 0.8, displayState: joyful, schedule: [])
        #expect(full.tail.rotationDegrees != 0)
        #expect(abs(full.tail.rotationDegrees) <= 10)
    }

    @Test("The pose's seed-derived schedule equals the injected one")
    func conveniencePathMatchesInjection() {
        let seeded = RigMotionModel(idleSeed: 42)
        let log = MomoIdleSequencer.schedule(
            idleSeed: 42, displayState: content, windowEnd: 30)
        #expect(
            seeded.pose(at: 17, displayState: content)
                == seeded.pose(at: 17, displayState: content, schedule: log))
    }

    @Test("Lids and pupils are always left/right symmetric")
    func eyeSymmetry() {
        let log = [
            blink(close: 0.5, open: 0.5), gaze(.left),
            variant(.tailFlick, mirrored: false, inSeconds: 0.35, hold: 1.0),
        ]
        let pose = model.pose(at: 0.4, displayState: content, schedule: log)
        #expect(pose.eyeLeft.lidScaleY == pose.eyeRight.lidScaleY)
        #expect(pose.eyeLeft.pupilOffset == pose.eyeRight.pupilOffset)
        #expect(pose.eyeLeft.lowerLid == pose.eyeRight.lowerLid)
    }
}
