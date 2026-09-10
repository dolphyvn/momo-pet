import Foundation
import Testing

@testable import MomoCharacter

/// TASK-027's additions to the §7.2/§7.1 curve vocabulary: the R2
/// tolerance-filtered no-bounce predicate, the R3 settle ease-in, the R4
/// appendage clamps, the §7.1 idle-event timing rows, and the shared shape
/// helpers (smoothstep, spring step). Raw-literal teeth throughout — a value
/// changed without its doc line fails here.
@Suite("MomoCurves TASK-027 — R2 predicate, R3 ease-in, R4 clamps, §7.1 rows, helpers")
struct MomoCurvesTask027Tests {

    // MARK: - R2: the tolerance-filtered single-soft-overshoot predicate

    /// Samples an analytic damped-spring step (the same closed form the
    /// curves implement) toward 1 from 0.
    private func springSamples(
        zeta: Double, omega: Double = 2 * Double.pi / 0.35,
        to seconds: Double = 2.0, step: Double = 0.001
    ) -> [Double] {
        stride(from: 0.0, through: seconds, by: step).map {
            MomoCurves.dampedSpringStep(at: $0, damping: zeta, omega: omega)
        }
    }

    @Test("R2: every in-band spring (ζ = 0.75…0.85) passes — settling is not bounce")
    func inBandSpringsPass() {
        // REVIEW-TASK-026 MINOR-2's failing case: ζ = 0.75 re-crosses its
        // target with a ~0.08 % excursion — legal settling under §7.2's
        // "soft overshoot only" law.
        for zeta in stride(from: 0.75, through: 0.85, by: 0.01) {
            #expect(
                MomoCurves.isSingleSoftOvershoot(
                    springSamples(zeta: zeta), target: 1, cap: MomoCurves.touchOvershootMax),
                "ζ = \(zeta) rejected — the predicate now calls in-band settling bounce")
            #expect(
                MomoCurves.isSingleSoftOvershoot(
                    springSamples(zeta: zeta), target: 1, cap: MomoCurves.celebrationOvershootMax),
                "ζ = \(zeta) rejected under the tighter celebration cap")
        }
    }

    @Test("R2: a genuine bounce still fails — comparable-magnitude re-excursions")
    func genuineBounceFails() {
        // Approach with 5 % overshoot, then re-crossings at comparable
        // magnitude (3 %, 1.5 %): two significant crossings → bounce.
        let bounce: [Double] = [0, 0.5, 0.95, 1.05, 0.97, 1.03, 0.985, 1.015, 1.0]
        #expect(!MomoCurves.isSingleSoftOvershoot(bounce, target: 1, cap: 0.15))

        // Even two 2 %-excursion re-crossings fail (above the 1 %
        // tolerance twice).
        let perceptibleDouble: [Double] = [0, 0.98, 1.02, 0.98, 1.02, 1.0]
        #expect(!MomoCurves.isSingleSoftOvershoot(perceptibleDouble, target: 1, cap: 0.15))
    }

    @Test("R2: sub-tolerance settling passes; a single over-tolerance re-cross fails")
    func toleranceBandSemantics() {
        // Re-crossings within ±1 % of the approach are settling: accepted.
        let settling: [Double] = [0, 1.008, 0.996, 1.004, 0.998, 1.0]
        #expect(MomoCurves.isSingleSoftOvershoot(settling, target: 1, cap: 0.15))

        // One significant crossing (the overshoot), one back — accepted.
        let singleSoft: [Double] = [0, 0.9, 1.05, 0.995, 1.0]
        #expect(MomoCurves.isSingleSoftOvershoot(singleSoft, target: 1, cap: 0.15))

        // A second significant crossing — rejected.
        let secondCross: [Double] = [0, 1.05, 0.9, 1.02, 1.0]
        #expect(!MomoCurves.isSingleSoftOvershoot(secondCross, target: 1, cap: 0.15))
    }

    @Test("R2: the cap law is unchanged — beyond-cap excursions fail either way")
    func capSemanticsUnchanged() {
        #expect(!MomoCurves.isSingleSoftOvershoot([0, 1.2, 1.0], target: 1, cap: 0.15))
        #expect(!MomoCurves.isSingleSoftOvershoot([0, 1.1, 1.0], target: 1, cap: 0.08))
        #expect(MomoCurves.isSingleSoftOvershoot([0, 1.1, 1.0], target: 1, cap: 0.15))

        // Approaching from above works identically (the start sits away
        // from the target — a curve beginning ON the target has no approach
        // and the predicate is vacuously true): mirror of `singleSoft`
        // around the target, one soft dip past it, in-band settle.
        #expect(MomoCurves.isSingleSoftOvershoot([3, 2.9, 1.95, 2.005, 2.0], target: 2, cap: 0.15))
        // A from-above dip past the cap is rejected by the cap, unchanged.
        #expect(!MomoCurves.isSingleSoftOvershoot([3, 1.75, 2.0], target: 2, cap: 0.15))
    }

    @Test("R2: degenerate inputs — empty, flat, and already-settled curves pass")
    func degenerateInputsPass() {
        #expect(MomoCurves.isSingleSoftOvershoot([], target: 1, cap: 0.15))
        #expect(MomoCurves.isSingleSoftOvershoot([1, 1, 1], target: 1, cap: 0.15))
        #expect(MomoCurves.isSingleSoftOvershoot([0.5], target: 1, cap: 0.15))
    }

    // MARK: - R3: the settle/sleep ease-in

    @Test("R3: the settle ease exponent is the gravity-like quadratic (raw pin)")
    func settleExponentPin() {
        #expect(MomoCurves.settleEaseExponent == 2.0)
    }

    @Test("R3: settleEase is p² — slow start, accelerating coverage, clamped")
    func settleEaseShape() {
        #expect(MomoCurves.settleEase(at: 0) == 0)
        #expect(MomoCurves.settleEase(at: 0.5) == 0.25) // digit-exact: 0.5²
        #expect(MomoCurves.settleEase(at: 1) == 1)
        #expect(MomoCurves.settleEase(at: -1) == 0)  // clamped below
        #expect(MomoCurves.settleEase(at: 2) == 1)   // clamped above

        // Gravity-like: always accelerating (second difference positive),
        // never ahead of linear time.
        var previous = 0.0
        var slope = 0.0
        for step in 1...10 {
            let p = Double(step) / 10
            let value = MomoCurves.settleEase(at: p)
            #expect(value <= p + 1e-12)
            let newSlope = value - previous
            #expect(newSlope >= slope - 1e-12)
            slope = newSlope
            previous = value
        }
    }

    // MARK: - R4: the appendage rotation clamps

    @Test("R4: the clamp constants are §3.1/§8b raw (ears ±25°, tail ±10°)")
    func clampConstantPins() {
        #expect(MomoCurves.earRotationLimitDegrees == -25.0...25.0)
        #expect(MomoCurves.tailRotationLimitDegrees == -10.0...10.0)
        #expect(MomoCurves.postureScaleYRange == 0.95...1.03)
    }

    @Test("R4: the clamp functions bound the range and pass in-band values through")
    func clampFunctions() {
        #expect(MomoCurves.clampedEarRotation(30) == 25)
        #expect(MomoCurves.clampedEarRotation(-40) == -25)
        #expect(MomoCurves.clampedEarRotation(16.5) == 16.5)
        #expect(MomoCurves.clampedEarRotation(-25) == -25)
        #expect(MomoCurves.clampedEarRotation(0) == 0)

        #expect(MomoCurves.clampedTailRotation(15) == 10)
        #expect(MomoCurves.clampedTailRotation(-15) == -10)
        #expect(MomoCurves.clampedTailRotation(7) == 7)
        #expect(MomoCurves.clampedTailRotation(-4) == -4)

        #expect(MomoCurves.clampedPostureScaleY(1.2) == 1.03)
        #expect(MomoCurves.clampedPostureScaleY(0.9) == 0.95)
        #expect(MomoCurves.clampedPostureScaleY(0.985) == 0.985)
    }

    // MARK: - §7.1 idle-event timing rows (raw pins)

    @Test("§7.1 idle-event rows land digit-for-digit")
    func eventTimingRowPins() {
        #expect(MomoCurves.blinkCloseSeconds == 0.14...0.18)
        #expect(MomoCurves.blinkOpenSeconds == 0.10...0.16)
        #expect(MomoCurves.gazeShiftSeconds == 0.22...0.32)
        #expect(MomoCurves.gazeReturnSeconds == 0.60...0.90)
        #expect(MomoCurves.yawnSeconds == 1.4)
        #expect(MomoCurves.stateCrossfadeSeconds == 0.3...0.4)
    }

    // MARK: - Shared shape helpers

    @Test("The parameterized breath generalizes the canonical driver exactly")
    func parameterizedBreath() {
        for step in 0...48 {
            let time = Double(step) / 10
            #expect(
                MomoCurves.breathScaleY(at: time, cycle: 4.9, amplitude: 0.02)
                    == MomoCurves.breathScaleY(at: time))
        }
        // Quarter cycle is the inhale peak; the loop boundary is invisible.
        #expect(MomoCurves.breathScaleY(at: 1.225, cycle: 4.9, amplitude: 0.02) == 1.02)
        #expect(abs(MomoCurves.breathScaleY(at: 0, cycle: 4.9, amplitude: 0.02)
                - MomoCurves.breathScaleY(at: 4.9, cycle: 4.9, amplitude: 0.02)) < 1e-12)
    }

    @Test("smoothstep: 0→0, 1→1, symmetric, clamped, zero end-slopes")
    func smoothstepShape() {
        #expect(MomoCurves.smoothstep(0) == 0)
        #expect(MomoCurves.smoothstep(1) == 1)
        #expect(MomoCurves.smoothstep(0.5) == 0.5)
        #expect(MomoCurves.smoothstep(-3) == 0)
        #expect(MomoCurves.smoothstep(7) == 1)
        #expect(MomoCurves.smoothstep(0.25) + MomoCurves.smoothstep(0.75) == 1)
        #expect(MomoCurves.smoothstep(0.9) == 0.972) // 3t²−2t³ at t = 0.9
    }

    @Test("The unit spring step: zero at rest, soft ~2 % overshoot at ζ = 0.78, settles to 1")
    func springStepLandmarks() {
        #expect(MomoCurves.dampedSpringStep(at: 0, damping: 0.78, omega: 2 * .pi / 0.35) == 0)

        let omega = 2 * Double.pi / 0.35
        var peak = 0.0
        for step in 0...2000 {
            let value = MomoCurves.dampedSpringStep(
                at: Double(step) / 1000, damping: 0.78, omega: omega)
            peak = max(peak, value)
        }
        #expect(peak > 1.01 && peak < 1.03) // the authored soft overshoot
        #expect(abs(MomoCurves.dampedSpringStep(at: 5, damping: 0.78, omega: omega) - 1) < 1e-6)
    }

    @Test("The idle spring's constants sit in §7.2's bands (damping in range, response = touch)")
    func idleSpringConstants() {
        #expect(MomoCurves.springDampingRange.contains(MomoCurves.idleSpringDamping))
        #expect(MomoCurves.idleSpringResponseSeconds == MomoCurves.touchSpringResponseSeconds)
        #expect(MomoCurves.idleSpringResponseSeconds == 0.35)
    }
}
