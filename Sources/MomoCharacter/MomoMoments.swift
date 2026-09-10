import CoreGraphics
import Foundation
import MomoCore

// MARK: - L4 moments (04 §4.1 row 4, §4.3's sparkle/celebration; TASK-028 R5)

/// The rare system moments' choreography: quest sparkle, stage
/// celebration, and the four authored greetings. L4 renders OVER whatever
/// else is active (the matrix's top row); it pauses on app-hide and
/// REPLAYS from 0 on return, completing exactly once (ADR-010's
/// replay-from-0 on the L4 row). Dedupe: a persistent `momentRequest`
/// (the display state keeps the last greeting stamp until the next) fires
/// ONCE per request TRANSITION — the director tracks the request it saw
/// last, so a re-delivered identical request re-renders nothing.
public enum MomoMoments {

    // MARK: Durations (§4.3 bands; AUTHORED values cite theirs)

    /// Quest sparkle: §4.3's 0.9–1.2 s band, AUTHORED 1.0.
    public static let questSparkleSeconds: Double = 1.0

    /// Stage celebration: §4.3's 1.6–2.0 s band, AUTHORED 1.8.
    public static let celebrationSeconds: Double = 1.8

    /// The four greetings (§9.2's kinds), each ≤ 2.0 s (§4.3's greeting
    /// band), AUTHORED per kind's read.
    public static func greetingSeconds(for kind: GreetingKind) -> Double {
        switch kind {
        case .freshMorning: 1.6
        case .welcomeBack: 1.2
        case .missedYou: 2.0
        case .nightGlance: 1.4
        }
    }

    /// The moment's duration (the report lands exactly here).
    public static func duration(for moment: CharacterMoment) -> Double {
        switch moment {
        case .greeting(let kind): greetingSeconds(for: kind)
        case .questCompleted: questSparkleSeconds
        case .bondStageReached: celebrationSeconds
        }
    }

    // MARK: Motion

    /// The moment's motion at `elapsed` since its (possibly replayed)
    /// start.
    public static func motion(
        for moment: CharacterMoment, elapsed: Double
    ) -> MomoReactionMotion {
        switch moment {
        case .greeting(let kind):
            return greeting(kind, elapsed: elapsed)
        case .questCompleted:
            return questSparkle(elapsed)
        case .bondStageReached:
            return celebration(elapsed)
        }
    }

    /// The quest sparkle: the A sparkle drifts up and fades while the
    /// mood lifts a touch. No bounce — a sparkle, not a celebration.
    private static func questSparkle(_ elapsed: Double) -> MomoReactionMotion {
        let p = MomoCurves.smoothstep(elapsed / questSparkleSeconds)
        return MomoReactionMotion(
            sparkleA: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 24 * p,
                    translation: CGPoint(x: 6 * p, y: -52 * p)),
                opacity: 1 - 0.6 * p))
    }

    /// The stage celebration: ONE soft overshoot ≤ 8 % on the body, both
    /// sparkles ring, the ears perk and the cheeks pulse — §4.3's "cheek
    /// accents" (the idle path never touches cheeks; INV-5 scopes by
    /// layer, and the TASK-027 idle battery pins stay untouched).
    private static func celebration(_ elapsed: Double) -> MomoReactionMotion {
        let springT = min(elapsed, MomoCurves.touchSpringResponseSeconds * 2)
        let spring = MomoCurves.dampedSpringStep(
            at: springT, damping: MomoReactionChoreography.touchSpringDamping,
            omega: 2 * .pi / MomoCurves.touchSpringResponseSeconds)
        // The bounce DECAYS (the step response holds at 1): one soft
        // overshoot, settled back by the celebration's midpoint.
        let decay = elapsed < MomoCurves.touchSpringResponseSeconds
            ? 1
            : 1 - MomoCurves.smoothstep(
                (elapsed - MomoCurves.touchSpringResponseSeconds) / 1.0)
        let bounce = spring * max(decay, 0)
        let p = MomoCurves.smoothstep(elapsed / celebrationSeconds)
        let ringB = MomoCurves.smoothstep(
            (elapsed - 0.25) / (celebrationSeconds - 0.25))
        let earPerk = MomoReactionChoreography.bump(
            elapsed, duration: celebrationSeconds, attack: 0.3, release: 0.6)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 + MomoHandshakeChoreography.celebrationFraction * bounce,
            earLeftDegrees: 9 * earPerk,
            earRightDegrees: 9 * earPerk,
            cheekOpacity: 1 - 0.18 * p,
            sparkleA: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 20 * p,
                    translation: CGPoint(x: -10 * p, y: -36 * p)),
                opacity: 1 - 0.3 * p),
            sparkleB: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: -18 * ringB,
                    translation: CGPoint(x: 12 * ringB, y: -30 * ringB)),
                opacity: 1 - 0.3 * ringB))
    }

    // MARK: Greetings (§3.4's qualities, authored per kind)

    private static func greeting(
        _ kind: GreetingKind, elapsed: Double
    ) -> MomoReactionMotion {
        let duration = greetingSeconds(for: kind)
        let perk = MomoReactionChoreography.bump(
            elapsed, duration: duration, attack: 0.25, release: 0.45)
        switch kind {
        case .freshMorning:
            // Two-ear perk + a bright open (§3.4's curious look, warmed).
            let bright = MomoCurves.smoothstep(elapsed / (duration * 0.6))
            return MomoReactionMotion(
                apertureMultiplier: 1 + 0.08 * bright,
                earLeftDegrees: 10 * perk,
                earRightDegrees: 10 * perk,
                tailDegrees: 4 * perk)
        case .welcomeBack:
            // One ear leads, the tail answers — the quick happy read.
            let wag = sin(2 * .pi * elapsed / 0.8)
            return MomoReactionMotion(
                apertureMultiplier: 1 + 0.06 * perk,
                earLeftDegrees: 8 * perk,
                earRightDegrees: 3 * perk,
                tailDegrees: 6 * wag * perk)
        case .missedYou:
            // The recognize sequence: perk → soft bounce → wag (≤ 2 s).
            let springT = min(elapsed, MomoCurves.touchSpringResponseSeconds * 2)
            let spring = MomoCurves.dampedSpringStep(
                at: springT, damping: MomoReactionChoreography.touchSpringDamping,
                omega: 2 * .pi / MomoCurves.touchSpringResponseSeconds)
            // The soft bounce decays (the step response holds at 1).
            let decay = elapsed < MomoCurves.touchSpringResponseSeconds
                ? 1
                : 1 - MomoCurves.smoothstep(
                    (elapsed - MomoCurves.touchSpringResponseSeconds) / 1.0)
            let bounce = spring * max(decay, 0)
            let wag = sin(2 * .pi * elapsed / 0.7)
            return MomoReactionMotion(
                bodyScaleYMultiplier:
                    1 + MomoHandshakeChoreography.celebrationFraction * bounce,
                apertureMultiplier: 1 + 0.08 * perk,
                earLeftDegrees: 10 * perk,
                earRightDegrees: 10 * perk,
                tailDegrees: 7 * wag * perk)
        case .nightGlance:
            // The quiet night read: a slow soft close-and-reopen, settled
            // ears — the smallest of the four.
            let softClose = MomoReactionChoreography.bump(
                elapsed, duration: duration, attack: 0.5, release: 0.6)
            return MomoReactionMotion(
                apertureMultiplier: 1 - 0.35 * softClose,
                earLeftDegrees: 3 * perk,
                earRightDegrees: 3 * perk)
        }
    }
}
