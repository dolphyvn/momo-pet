import Foundation
import Testing

@testable import MomoCharacter

/// TASK-026 Requirement 5 (O7): the 04-character-system §7.2 curve
/// discipline and the §7.1 breath rows, pinned as raw literals so the values
/// have teeth independent of any doc drift. TASK-027/028 curve helpers
/// consume these constants — they never restate them. The no-bounce law is
/// carried by an executable predicate so a reviewer can demonstrate exactly
/// what rejects a bouncing curve.
@Suite("MomoCurves — §7.2 discipline constants + §7.1 breath rows (O7)")
struct MomoCurveRulesTests {

    // MARK: - §7.2 raw-literal pins

    @Test("Damped-spring damping band is 0.75–0.85 (soft overshoot only)")
    func springDampingBand() {
        #expect(MomoCurves.springDampingRange == 0.75...0.85)
        #expect(MomoCurves.springDampingRange.lowerBound == 0.75)
        #expect(MomoCurves.springDampingRange.upperBound == 0.85)
    }

    @Test("Touch-reaction overshoot cap is 15 % with a ~0.35 s spring response")
    func touchCurveCaps() {
        #expect(MomoCurves.touchOvershootMax == 0.15)
        #expect(MomoCurves.touchSpringResponseSeconds == 0.35)
    }

    @Test("Celebration overshoot cap is 8 % — single overshoot, no repeated bounce")
    func celebrationCurveCaps() {
        #expect(MomoCurves.celebrationOvershootMax == 0.08)
        #expect(MomoCurves.repeatedBounceAllowed == false)
    }

    // MARK: - §7.1 breath rows (raw literals)

    @Test("Breath cycle bands per mood band, digit-for-digit from §7.1")
    func breathCycleBands() {
        #expect(MomoCurves.breathCycleJoyful == 3.8...4.2)
        #expect(MomoCurves.breathCycleContent == 4.6...5.2)
        #expect(MomoCurves.breathCycleWistful == 5.8...6.4)
        #expect(MomoCurves.breathCycleDrowsyAsleep == 6.5...8.0)
    }

    @Test("Breath amplitude band 1.5–2.5 % scaleY; sleep reduction −30 %")
    func breathAmplitudeRows() {
        #expect(MomoCurves.breathAmplitudeScaleY == 0.015...0.025)
        #expect(MomoCurves.sleepAmplitudeReduction == 0.30)
    }

    @Test("The canonical Content breath driver sits inside its §7.1 band")
    func canonicalDriverInsideBand() {
        #expect(MomoCurves.breathCycleContent.contains(MomoCurves.breathCycleSeconds))
        #expect(MomoCurves.breathAmplitudeScaleY.contains(MomoCurves.breathAmplitude))
        #expect(MomoCurves.breathCycleSeconds == 4.9)
        #expect(MomoCurves.breathAmplitude == 0.02)
    }

    // MARK: - Pure-sine breath (§7.2: no easing artifacts across the loop)

    @Test("Breath scaleY is a pure sine: rest at 0, peak at T/4, trough at 3T/4")
    func breathIsPureSine() {
        let t = MomoCurves.breathCycleSeconds
        let a = MomoCurves.breathAmplitude

        #expect(MomoCurves.breathScaleY(at: 0) == 1.0)
        #expect(MomoCurves.breathScaleY(at: t / 4) == 1.0 + a)  // inhale peak
        #expect(MomoCurves.breathScaleY(at: t / 2) == 1.0)
        #expect(MomoCurves.breathScaleY(at: 3 * t / 4) == 1.0 - a) // exhale trough

        // Formula equality at arbitrary samples (not just the landmarks).
        for fraction in [0.1, 0.23, 0.51, 0.77, 0.9] {
            let expected = 1.0 + a * sin(2.0 * .pi * fraction)
            #expect(abs(MomoCurves.breathScaleY(at: fraction * t) - expected) < 1e-12)
        }
    }

    @Test("Breath loops seamlessly: scaleY(0) == scaleY(T) and scaleY(t) == scaleY(t + T)")
    func breathIsContinuousAcrossTheLoopBoundary() {
        let t = MomoCurves.breathCycleSeconds
        #expect(MomoCurves.breathScaleY(at: 0) == MomoCurves.breathScaleY(at: t))
        for fraction in [0.13, 0.4, 0.66, 0.95] {
            #expect(MomoCurves.breathScaleY(at: fraction * t)
                    == MomoCurves.breathScaleY(at: fraction * t + t))
        }
    }

    @Test("Breath amplitude peaks inside the §7.1 band (1.5–2.5 %)")
    func breathStaysInsideBand() {
        let steps = 200
        let deviations = (0...steps).map { step in
            abs(MomoCurves.breathScaleY(
                at: MomoCurves.breathCycleSeconds * Double(step) / Double(steps)) - 1.0)
        }
        // No sample ever exceeds the band's ceiling…
        #expect(deviations.allSatisfy { $0 <= MomoCurves.breathAmplitudeScaleY.upperBound })
        // …and the cycle's PEAK lands inside the band — the band constrains
        // the amplitude (peak deviation), not each instantaneous sample (a
        // sine spends most of the cycle below 1.5 %).
        let peak = deviations.max() ?? 0
        #expect(MomoCurves.breathAmplitudeScaleY.contains(peak))
    }

    // MARK: - The no-bounce law, executable

    @Test("overshootFraction measures excursion beyond the target relative to the approach")
    func overshootFractionBasics() {
        // Start 0, target 1: value 1.08 is an 8 % overshoot.
        #expect(MomoCurves.overshootFraction(of: 1.08, target: 1, start: 0)
                .isApproximatelyEqual(to: 0.08))
        // Still approaching (0.5) has overshot nothing.
        #expect(MomoCurves.overshootFraction(of: 0.5, target: 1, start: 0) == 0)
        // Degenerate approach distance: fraction stays 0 rather than dividing by zero.
        #expect(MomoCurves.overshootFraction(of: 1.1, target: 1, start: 1) == 0)
    }

    @Test("A single soft overshoot inside the cap is legal")
    func singleSoftOvershootAccepted() {
        // Celebration-style settle: approach 1, one 5 % overshoot, ease back.
        let samples: [Double] = [0, 0.3, 0.7, 0.95, 1.05, 1.02, 1.0]
        #expect(MomoCurves.isSingleSoftOvershoot(
            samples, target: 1, cap: MomoCurves.celebrationOvershootMax))
    }

    @Test("A monotonic approach with no crossing is legal (zero overshoot)")
    func monotoneApproachAccepted() {
        let samples: [Double] = [0, 0.25, 0.5, 0.75, 0.9, 0.99, 1]
        #expect(MomoCurves.isSingleSoftOvershoot(
            samples, target: 1, cap: MomoCurves.touchOvershootMax))
    }

    @Test("Overshoot beyond the cap is rejected, even when single")
    func overshootBeyondCapRejected() {
        // A 15 % excursion against the celebration cap.
        let samples: [Double] = [0, 0.5, 1.15, 1.05, 1]
        #expect(!MomoCurves.isSingleSoftOvershoot(
            samples, target: 1, cap: MomoCurves.celebrationOvershootMax))
        // The same curve against the (looser) touch cap is fine.
        #expect(MomoCurves.isSingleSoftOvershoot(
            samples, target: 1, cap: MomoCurves.touchOvershootMax))
    }

    @Test("A bouncing-ball curve (repeated crossing) is rejected by the law")
    func bouncingCurveRejected() {
        // Up past 1, back under, up again, under again — classic bounce.
        let bounce: [Double] = [0, 0.6, 1.1, 0.9, 1.08, 0.95, 1.02, 1]
        #expect(!MomoCurves.isSingleSoftOvershoot(
            bounce, target: 1, cap: MomoCurves.celebrationOvershootMax))
        #expect(!MomoCurves.isSingleSoftOvershoot(
            bounce, target: 1, cap: MomoCurves.touchOvershootMax))
    }
}

extension Double {
    /// Test-local epsilon comparison for the fraction math.
    fileprivate func isApproximatelyEqual(to other: Double) -> Bool {
        abs(self - other) < 1e-12
    }
}
