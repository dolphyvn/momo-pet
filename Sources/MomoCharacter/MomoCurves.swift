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

    /// The absolute no-bounce law (§7.2): no bouncing-ball loops and no
    /// repeated bounce anywhere, in any motion. Carried as a constant so the
    /// rule is a value reviewers and later tasks can reference, and as an
    /// executable predicate below so it can actually reject curves.
    public static let repeatedBounceAllowed: Bool = false

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

    // MARK: - Canonical breath driver (TASK-026's reference channel)

    /// The one channel TASK-026 drives end-to-end: the Content breath at the
    /// band's midpoint — inside `breathCycleContent`, pure sine per §7.2
    /// ("breathing = pure sine, no easing artifacts across the loop
    /// boundary"). Band-specific rates and all other choreography are
    /// TASK-027+; they must pick their cycle from the §7.1 rows above.
    public static let breathCycleSeconds: Double = 4.9
    public static let breathAmplitude: Double = 0.02

    /// Bottom-anchored body scaleY at clock time `time` (seconds):
    /// `1 + amplitude · sin(2π·time / cycle)`. Pure sine — value and slope
    /// match exactly at t and t + cycle, so the loop boundary is invisible.
    public static func breathScaleY(at time: Double) -> Double {
        1 + breathAmplitude * sin(2 * .pi * time / breathCycleSeconds)
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
    /// a legal "single soft overshoot" exactly when it crosses the target at
    /// most once (approach → settle, with at most one excursion past it —
    /// repeated crossings are the bouncing-ball motion §7.2 forbids) and its
    /// peak excursion stays within `cap`. Pass `celebrationOvershootMax` or
    /// `touchOvershootMax`; a curve that satisfies the tighter cap also
    /// satisfies the discipline's intent.
    public static func isSingleSoftOvershoot(
        _ samples: [Double], target: Double, cap: Double
    ) -> Bool {
        guard let start = samples.first else { return true }
        let deviations = samples.map { $0 - target }

        // Count full crossings (one side of the target to the other). A
        // sample exactly on the target is a settle, not a crossing.
        var crossings = 0
        for (before, after) in zip(deviations, deviations.dropFirst())
        where before != 0 && after != 0 && (before < 0) != (after < 0) {
            crossings += 1
        }
        guard crossings <= 1 else { return false }

        return samples.allSatisfy {
            overshootFraction(of: $0, target: target, start: start) <= cap
        }
    }
}
