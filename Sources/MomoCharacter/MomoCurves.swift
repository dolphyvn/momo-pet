import Foundation

/// The 04-character-system §7.2 curve discipline and §7.1 breath rows, as
/// pinned constants (TASK-026 Requirement 5 — O7). Later curve helpers
/// (TASK-027 idle choreography, TASK-028 reactions) CONSUME these values —
/// they never restate them. The tests carry raw-literal teeth
/// (`MomoCurveRulesTests`); changing a value here without changing the doc
/// (or vice versa) fails the build.
public enum MomoCurves {

    // MARK: - §7.2 damped-spring discipline

    /// Damping band for every spring-driven motion (ears, tail, touch).
    /// The band's soft end allows a single gentle overshoot only — values
    /// below 0.75 produce bouncing-ball motion, which the no-bounce law
    /// forbids outright.
    public static let springDampingRange: ClosedRange<Double> = 0.75...0.85

    /// §7.2: touch reactions may overshoot by at most 15 %.
    public static let touchOvershootMax: Double = 0.15

    /// §7.2: touch spring response ≈ 0.35 s.
    public static let touchSpringResponseSeconds: Double = 0.35

    /// §7.2: celebrations may overshoot by at most 8 % — a single soft
    /// overshoot, never a repeated bounce.
    public static let celebrationOvershootMax: Double = 0.08

    /// The re-cross tolerance below which a spring's decaying re-crossing of
    /// the target counts as SETTLING, not bounce (TASK-027 R2 —
    /// REVIEW-TASK-026 MINOR-2). Expressed as a fraction of the approach.
    /// An in-band spring (ζ = 0.75…0.85) re-crosses with excursions of at
    /// most ~0.081 % of the approach (the ζ = 0.75 worst case), so 1 %
    /// leaves a ≥ 12× margin over legal settling while still rejecting any
    /// visually perceptible second excursion (≥ 1 % = visible motion at rig
    /// scale).
    public static let softCrossingTolerance: Double = 0.01

    /// The absolute no-bounce law (§7.2): no bouncing-ball loops and no
    /// repeated bounce anywhere, in any motion. Carried as a constant so the
    /// rule is a value reviewers and later tasks can reference, and as an
    /// executable predicate below so it can actually reject curves.
    public static let repeatedBounceAllowed: Bool = false

    /// §7.2: "Settle / sleep: ease-in (gravity-like), decelerating into
    /// stillness" (TASK-027 R3 — REVIEW-TASK-026 MINOR-3). The exponent of
    /// the ease-in: 2 is the gravity-like quadratic — constant acceleration
    /// from rest, position ∝ t². The *decelerating into stillness* arrival
    /// envelope composes on top of this shape and is TASK-028's state
    /// choreography; this task lands the curve so the vocabulary exists.
    public static let settleEaseExponent: Double = 2.0

    /// §3.1's posture channel bounds, as body scaleY about the ground line:
    /// +3 % tall … −5 % slouch. The band governs the STATIC posture
    /// channel: the expression layer clamps the band base × energy overlays
    /// into it (`MomoExpressions.expression`), so mood and exhaustion can
    /// never compose the resting posture past it. MOTION composes
    /// multiplicatively on top and is bounded by its own authored
    /// magnitudes — the §7.1 breath amplitude, the §5.2 idle events — and
    /// is deliberately NOT re-clamped into this band (the body-scaleY
    /// composition law, ADR-011).
    public static let postureScaleYRange: ClosedRange<Double> = 0.95...1.03

    /// §3.1: ear rotation range — −25° (droop) … +25° (perk). The motion
    /// model clamps every emitted ear angle into this range (TASK-027 R4).
    public static let earRotationLimitDegrees: ClosedRange<Double> = -25.0...25.0

    /// The tail's rotation bound (REVIEW-TASK-026 item 8b): ±10°. The motion
    /// model clamps every emitted tail angle into this range (TASK-027 R4).
    public static let tailRotationLimitDegrees: ClosedRange<Double> = -10.0...10.0

    /// The damping the idle event springs use (ear twitch, tail flick,
    /// curious asymmetry, head nod) — inside `springDampingRange`, biased
    /// toward the soft end so the idle read stays calm (§7.2: soft overshoot
    /// only; a ζ = 0.78 step overshoots ~2 % once, then settles).
    public static let idleSpringDamping: Double = 0.78

    /// The idle springs' response time (§7.2's gentle-spring order, shared
    /// with the touch reaction's ~0.35 s — the idle read must not feel
    /// snappier than a touch response).
    public static let idleSpringResponseSeconds: Double = 0.35

    // MARK: - §7.1 breath rows

    /// Breath cycle bands by mood band (seconds). Drowsy-asleep breaths are
    /// the slowest and pair with the sleep amplitude reduction below.
    public static let breathCycleJoyful: ClosedRange<Double> = 3.8...4.2
    public static let breathCycleContent: ClosedRange<Double> = 4.6...5.2
    public static let breathCycleWistful: ClosedRange<Double> = 5.8...6.4
    public static let breathCycleDrowsyAsleep: ClosedRange<Double> = 6.5...8.0

    /// Breath amplitude band, as body scaleY about the ground line (§7.1:
    /// 1.5–2.5 %). Bottom-anchored: the feet stay planted.
    public static let breathAmplitudeScaleY: ClosedRange<Double> = 0.015...0.025

    /// Asleep breaths run at −30 % of the band amplitude (§7.1).
    public static let sleepAmplitudeReduction: Double = 0.30

    // MARK: - §7.1 idle-event timing rows (TASK-027)

    /// §7.1 blink row: close 140–180 ms. The sequencer draws inside the band
    /// (Wistful blinks run ~1.2× slower — a duration multiplier, not a band
    /// change).
    public static let blinkCloseSeconds: ClosedRange<Double> = 0.14...0.18

    /// §7.1 blink row: open 100–160 ms.
    public static let blinkOpenSeconds: ClosedRange<Double> = 0.10...0.16

    /// §7.1 gaze row: 220–320 ms out, ease-out.
    public static let gazeShiftSeconds: ClosedRange<Double> = 0.22...0.32

    /// §7.1 gaze row: 600–900 ms back.
    public static let gazeReturnSeconds: ClosedRange<Double> = 0.60...0.90

    /// §7.1 yawn row: 1.4 s total.
    public static let yawnSeconds: Double = 1.4

    /// §7.1 state-crossfade row: 300–400 ms — the entry/exit envelope for
    /// the L2-accent idle variants that are not spring-driven.
    public static let stateCrossfadeSeconds: ClosedRange<Double> = 0.3...0.4

    // MARK: - Canonical breath driver (TASK-026's reference channel)

    /// The one channel TASK-026 drives end-to-end: the Content breath at the
    /// band's midpoint — inside `breathCycleContent`, pure sine per §7.2
    /// ("breathing = pure sine, no easing artifacts across the loop
    /// boundary"). Band-specific rates and all other choreography are
    /// TASK-027+; they must pick their cycle from the §7.1 rows above.
    public static let breathCycleSeconds: Double = 4.9
    public static let breathAmplitude: Double = 0.02

    /// Bottom-anchored body scaleY at clock time `time` (seconds) for an
    /// arbitrary §7.1 row: `1 + amplitude · sin(2π·time / cycle)`. Pure
    /// sine — value and slope match exactly at t and t + cycle, so the loop
    /// boundary is invisible. The band drivers (TASK-027 expression system)
    /// pass their row's cycle/amplitude; the canonical overload below
    /// delegates here.
    public static func breathScaleY(
        at time: Double, cycle: Double, amplitude: Double
    ) -> Double {
        1 + amplitude * sin(2 * .pi * time / cycle)
    }

    /// Bottom-anchored body scaleY at clock time `time` (seconds) on the
    /// canonical Content driver (`breathCycleSeconds` / `breathAmplitude`).
    public static func breathScaleY(at time: Double) -> Double {
        breathScaleY(at: time, cycle: breathCycleSeconds, amplitude: breathAmplitude)
    }

    // MARK: - §7.2 shape helpers (TASK-027)

    /// The standard smooth Hermite step ("smoothstep"): a 0→1 ease-in-out
    /// with zero slope at both ends. The authored envelope for blink lids,
    /// gaze return, and the crossfade-family idle variants — the §7.2
    /// curves table names the families (spring, ease-in-out) without
    /// pinning their interpolation, so the helpers live here once and every
    /// consumer shares them.
    public static func smoothstep(_ t: Double) -> Double {
        let clamped = min(max(t, 0), 1)
        return clamped * clamped * (3 - 2 * clamped)
    }

    /// The settle/sleep ease-in envelope (§7.2, R3): progress `p` in 0…1
    /// (values outside clamp) maps to `p^settleEaseExponent` — the
    /// gravity-like quadratic. Slow start, accelerating coverage; the
    /// "decelerating into stillness" arrival composes on top (TASK-028).
    public static func settleEase(at progress: Double) -> Double {
        let p = min(max(progress, 0), 1)
        return pow(p, settleEaseExponent)
    }

    /// The unit damped-spring STEP response for §7.2's spring family:
    /// `1 − e^(−ζωn·t)(cos ωd·t + (ζ/√(1−ζ²))·sin ωd·t)` with
    /// `ωd = ωn·√(1−ζ²)`. A step from 0 to 1 at t = 0; soft single
    /// overshoot for ζ in `springDampingRange`. Callers pick ζ from
    /// `springDampingRange` (the idle springs use `idleSpringDamping`) and
    /// `ωn = 2π / responseSeconds`.
    public static func dampedSpringStep(
        at time: Double, damping zeta: Double, omega: Double
    ) -> Double {
        let root = (1 - zeta * zeta).squareRoot()
        let dampedOmega = omega * root
        let decay = exp(-zeta * omega * time)
        return 1 - decay
            * (cos(dampedOmega * time) + zeta / root * sin(dampedOmega * time))
    }

    // MARK: - The no-bounce law, executable

    /// How far `value` has gone past `target`, as a fraction of the approach
    /// from `start` (§7.2's "overshoot ≤ N %" semantics). Still approaching
    /// the target yields 0; a degenerate (zero-length) approach yields 0.
    /// Sign-symmetric: approaching from above works identically.
    public static func overshootFraction(
        of value: Double, target: Double, start: Double
    ) -> Double {
        let approach = target - start
        guard abs(approach) > 0 else { return 0 }
        return max(0, (value - target) / approach)
    }

    /// The no-bounce law as a predicate: a sampled curve toward `target` is
    /// a legal "single soft overshoot" exactly when it makes at most one
    /// SIGNIFICANT crossing of the target and its peak excursion stays
    /// within `cap`.
    ///
    /// "Significant" is the R2 refinement (REVIEW-TASK-026 MINOR-2): a
    /// crossing counts only when the curve leaves the ±
    /// `softCrossingTolerance` band around the target (as a fraction of the
    /// approach). An underdamped in-band spring (ζ = 0.75…0.85) re-crosses
    /// its target with excursions of at most ~0.081 % of the approach —
    /// those are the damped spring's *settling*, which §7.2's "soft
    /// overshoot only" law explicitly allows, and this predicate accepts
    /// them; a genuine bounce (comparable-magnitude repeated excursions)
    /// still fails. The `cap` semantics are unchanged: pass
    /// `celebrationOvershootMax` or `touchOvershootMax`.
    public static func isSingleSoftOvershoot(
        _ samples: [Double], target: Double, cap: Double
    ) -> Bool {
        guard let start = samples.first else { return true }
        let approach = abs(target - start)
        guard approach > 0 else { return true }
        let threshold = softCrossingTolerance * approach

        // Significant crossings: sign changes between deviations large
        // enough to leave the tolerance band. Everything inside the band is
        // settling. A sample exactly on the target is a settle, not a
        // crossing.
        let significant = samples
            .map { $0 - target }
            .filter { abs($0) > threshold }
        var crossings = 0
        for (before, after) in zip(significant, significant.dropFirst())
        where (before < 0) != (after < 0) {
            crossings += 1
        }
        guard crossings <= 1 else { return false }

        return samples.allSatisfy {
            overshootFraction(of: $0, target: target, start: start) <= cap
        }
    }

    // MARK: - Channel-value clamps (model-side laws)

    /// Clamps a posture scaleY into §3.1's `postureScaleYRange` (+3 % …
    /// −5 %). The EXPRESSION layer applies this to the band base × energy
    /// overlays, so the static posture every pose carries satisfies the
    /// bound; motion (breath, idle events) composes on top unclamped
    /// (ADR-011).
    public static func clampedPostureScaleY(_ scaleY: Double) -> Double {
        min(max(scaleY, postureScaleYRange.lowerBound), postureScaleYRange.upperBound)
    }

    /// Clamps an ear angle into §3.1's −25° (droop) … +25° (perk). The
    /// MODEL applies this (TASK-027 R4) so every emitted pose satisfies the
    /// bound, regardless of what an event requests.
    public static func clampedEarRotation(_ degrees: Double) -> Double {
        min(max(degrees, earRotationLimitDegrees.lowerBound), earRotationLimitDegrees.upperBound)
    }

    /// Clamps a tail angle into ±10° (REVIEW-TASK-026 item 8b; TASK-027 R4).
    public static func clampedTailRotation(_ degrees: Double) -> Double {
        min(max(degrees, tailRotationLimitDegrees.lowerBound), tailRotationLimitDegrees.upperBound)
    }
}
