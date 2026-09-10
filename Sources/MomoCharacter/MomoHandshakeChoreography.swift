import CoreGraphics
import Foundation
import MomoCore

// MARK: - The settle/wake/play handshakes (04 §4.3, §6.3, §7.1; TASK-028 R4/R7)

/// The three handshakes' pure choreography and pacing law. Everything here
/// takes elapsed seconds and returns channel values (or resolved instants)
/// — no clock, no randomness, no side effects. The director owns the
/// instances and the reports; this file owns the SHAPES and the ≤ 30 s
/// play bound.
public enum MomoHandshakeChoreography {

    // MARK: Settle (tuck-in; §4.3's 2.5–3.5 s band)

    /// AUTHORED 3.0 — the band mid. Yawn (§7.1's 1.4 s, the authored
    /// 0.45/0.5/0.45 split) → lie down (`settleEase`, §7.2's gravity-like
    /// ease-in) → the blanket settles last. `settleFinished` fires at the
    /// full duration.
    public static let settleDurationSeconds: Double = 3.0

    /// The settle's leading yawn (§7.1's yawn row).
    public static let settleYawnSeconds: Double = MomoCurves.yawnSeconds

    /// The lie-down runs from the yawn's end to the report.
    static let settleLieDownStart: Double = settleYawnSeconds

    /// The blanket's settle drift begins here (the last third).
    static let settleBlanketStart: Double = 2.2

    /// The lie-down sink: an AUTHORED 6 % body scaleY (choreography motion
    /// — ADR-011: the §3.1 band governs the STATIC posture channel, not
    /// the settle beat's motion).
    static let settleSinkFraction: Double = 0.06

    public static func settleMotion(elapsed: Double) -> MomoReactionMotion {
        // Phase 1: the yawn (eyes close, small nod).
        let yawnE = min(elapsed, settleYawnSeconds)
        let yawn = MomoReactionChoreography.bump(
            yawnE, duration: settleYawnSeconds, attack: 0.45, release: 0.45)
        // Phase 2: the lie-down — ease-in into stillness.
        let lieP = (elapsed - settleLieDownStart)
            / (settleDurationSeconds - settleLieDownStart)
        let lie = MomoCurves.settleEase(at: lieP)
        // Phase 3: the blanket settles over the sleeping form.
        let blanketP = (elapsed - settleBlanketStart)
            / (settleDurationSeconds - settleBlanketStart)
        let blanketShape = MomoCurves.smoothstep(blanketP)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 - settleSinkFraction * lie,
            apertureMultiplier: 1 - yawn,
            headRotationDegrees: 3 * yawn,
            blanket: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 3 * blanketShape,
                    translation: CGPoint(x: 0, y: -14 * blanketShape))))
    }

    // MARK: Wake (§7.1's 1.8–2.5 s waking row)

    /// AUTHORED 2.0 — the band mid. The stretch rises, the ears perk in
    /// the second half, the aperture opens last; `wakeFinished` at the
    /// full duration. Never cancelled (§9.2) — hide pauses, return
    /// replays from 0 (ADR-010).
    public static let wakeDurationSeconds: Double = 2.0

    public static func wakeMotion(elapsed: Double) -> MomoReactionMotion {
        let stretch = MomoReactionChoreography.bump(
            elapsed, duration: wakeDurationSeconds, attack: 0.5, release: 1.0)
        let earPerk = MomoReactionChoreography.bump(
            elapsed, duration: wakeDurationSeconds, attack: 1.2, release: 0.5)
        // The aperture opens across the second half (0.7× → 1.0× of the
        // band base — the sleepy eye clears).
        let opening = MomoCurves.smoothstep((elapsed - 1.0) / 1.0)
        return MomoReactionMotion(
            bodyScaleYMultiplier: 1 + 0.05 * stretch,
            apertureMultiplier: 0.7 + 0.3 * opening,
            earLeftDegrees: 8 * earPerk,
            earRightDegrees: 8 * earPerk)
    }

    // MARK: Play (§6.3; §7.1's 15–30 s round row; TASK-028 R7)

    /// Phase 1 — the invite beat (§6.3's "play-ready perk"): ≤ 3 s,
    /// AUTHORED 2.4. The SAME motion the `react.playReady` clip renders.
    public static let inviteSeconds: Double = 2.4

    /// Phase 2 — the follow: the character tracks the fingertip. AUTHORED
    /// baseline 12.0 (inside §7.1's 10–20 s band); Drowsy's round is
    /// shorter (8.0) and ends in a yawn. The pacer's rest rule and the
    /// hard deadline resolve the actual cease (below).
    public static let followBaselineSeconds: Double = 12.0
    public static let drowsyFollowSeconds: Double = 8.0

    /// The rest rule: once the fingertip has been still this long, the
    /// character finishes the round solo — the follow ends at
    /// `max(restSoloFloor, restStart + restSoloTail)`, capped by the
    /// deadline.
    public static let restGraceSeconds: Double = 2.0
    public static let restSoloFloorSeconds: Double = 10.0
    public static let restSoloTailSeconds: Double = 3.0

    /// The follow's hard deadline (the round must ALWAYS stay ≤ 30 s —
    /// 2.4 + 16 + 4 = 22.4 even in the worst case).
    public static let followDeadlineSeconds: Double = 16.0

    /// Phase 3 — the payoff (≤ 5 s, AUTHORED 4.0): the happy bounce and
    /// the sparkle ring, one soft overshoot.
    public static let payoffSeconds: Double = 4.0

    /// The Drowsy wind-down yawn rides the follow's last stretch.
    public static let drowsyYawnSeconds: Double = MomoCurves.yawnSeconds

    /// The worst-case round, for the ≤ 30 s pin (invite + deadline follow
    /// + payoff).
    public static var maxRoundSeconds: Double {
        inviteSeconds + followDeadlineSeconds + payoffSeconds
    }

    /// The follow's cease for a round starting `followStart`, given the
    /// pacer's rest state: `restStart` (when stillness began) or nil while
    /// the fingertip moves. Pure — the director calls it at every pacer
    /// sample; the first non-nil answer is the round's cease.
    public static func followCease(
        followStart: Double, restStart: Double?, drowsy: Bool
    ) -> Double {
        if drowsy {
            // Drowsy: the short follow ALWAYS ends at 8.0 (the yawn rides
            // 6.6 → 8.0); stillness cannot extend it.
            return drowsyFollowSeconds
        }
        guard let restStart else { return followBaselineSeconds }
        let solo = max(restSoloFloorSeconds, restStart + restSoloTailSeconds)
        return min(max(solo, 0), followDeadlineSeconds)
    }

    /// The invite motion (also the `react.playReady` clip's body): the
    /// play-ready perk — ears and tail only, the round's first two-group
    /// phase (§7.4 rule 4: playing animates TWO transform groups max).
    public static func inviteMotion(elapsed: Double) -> MomoReactionMotion {
        let shape = MomoReactionChoreography.bump(
            elapsed, duration: inviteSeconds, attack: 0.5, release: 0.7)
        let wag = sin(2 * .pi * elapsed / 1.2)
        return MomoReactionMotion(
            earLeftDegrees: 10 * shape,
            earRightDegrees: 10 * shape,
            tailDegrees: 6 * wag * shape)
    }

    /// The follow motion: head and eyes track the fingertip (offset in
    /// grid units, from the stage center). TWO moving transform groups
    /// max — head + gaze; the body holds still so the read stays calm.
    public static func followMotion(fingertipOffset: CGPoint) -> MomoReactionMotion {
        let normX = max(-1, min(1, fingertipOffset.x / 300))
        let normY = max(-1, min(1, fingertipOffset.y / 300))
        return MomoReactionMotion(
            headRotationDegrees: 3 * normX,
            headTranslationY: 2 * normY,
            pupilOffset: CGPoint(x: 10 * normX, y: 8 * normY))
    }

    /// The payoff motion: one soft spring bounce (≤ 8 % — the celebration
    /// cap; ζ = 0.8 gives ~4.6 %) and the two-sparkle ring with a cheek
    /// accent — the body is the round's one moving group here. The Drowsy
    /// wind-down's aperture close composes without adding a third group.
    public static func payoffMotion(
        elapsed: Double, yawn: Bool
    ) -> MomoReactionMotion {
        let springT = min(elapsed, MomoCurves.touchSpringResponseSeconds * 2)
        let spring = MomoCurves.dampedSpringStep(
            at: springT, damping: MomoReactionChoreography.touchSpringDamping,
            omega: 2 * .pi / MomoCurves.touchSpringResponseSeconds)
        // The bounce DECAYS — the step response is held at 1, so it rides
        // out to zero by the payoff's midpoint (one bounce, then rest).
        let decay = elapsed < MomoCurves.touchSpringResponseSeconds
            ? 1
            : 1 - MomoCurves.smoothstep(
                (elapsed - MomoCurves.touchSpringResponseSeconds) / 1.3)
        let bounce = spring * max(decay, 0)
        let p = min(elapsed / payoffSeconds, 1)
        let drift = MomoCurves.smoothstep(p)
        let ringB = MomoCurves.smoothstep((elapsed - 0.3) / (payoffSeconds - 0.3))
        var motion = MomoReactionMotion(
            bodyScaleYMultiplier: 1 + celebrationFraction * bounce,
            cheekOpacity: 1 - 0.15 * drift,
            sparkleA: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 20 * drift,
                    translation: CGPoint(x: 0, y: -40 * drift)),
                opacity: 1 - 0.25 * drift),
            sparkleB: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: -16 * ringB,
                    translation: CGPoint(x: 8 * ringB, y: -28 * ringB)),
                opacity: 1 - 0.25 * ringB))
        if yawn {
            let yawnE = min(elapsed, drowsyYawnSeconds)
            let yawn = MomoReactionChoreography.bump(
                yawnE, duration: drowsyYawnSeconds, attack: 0.45, release: 0.45)
            motion.apertureMultiplier *= 1 - yawn
        }
        return motion
    }

    /// The celebration bounce fraction (≤ 8 %, §7.2's celebration cap —
    /// shared by the payoff and the L4 bond celebration).
    static let celebrationFraction: Double = MomoCurves.celebrationOvershootMax
}

// MARK: - The pacer's fold (§6.3; lives beside the pacing law it resolves)

extension MomoDirectorState {

    /// The play pacer's sample fold: stillness evidence and the baseline
    /// resolve the follow's cease exactly once (the ≤ 30 s bound).
    mutating func applyFingertip(
        offset: CGPoint, moving: Bool, at t: Double
    ) {
        guard case .play(var play) = stateLayer, play.followCease == nil,
            t >= play.followStart
        else {
            if case .play(var active) = stateLayer {
                active.lastOffset = offset
                stateLayer = .play(active)
            }
            return
        }
        play.lastOffset = offset
        if moving {
            play.restStart = nil
        } else if play.restStart == nil {
            play.restStart = t
        }
        // The cease resolves once, and only on EVIDENCE: stillness held
        // for the rest grace (the solo wind-down), or the baseline already
        // due. A still finger inside its grace must not freeze the round
        // at the baseline — stillness may still shorten it.
        let resting = play.restStart.map { t - $0 >= MomoHandshakeChoreography.restGraceSeconds } ?? false
        let baselineDue = t >= play.followStart
            + MomoHandshakeChoreography.followBaselineSeconds
        guard resting || baselineDue else { stateLayer = .play(play); return }
        let cease = MomoHandshakeChoreography.followCease(
            followStart: play.followStart,
            restStart: resting ? play.restStart : nil,
            drowsy: play.drowsy)
        let absoluteCease = play.followStart + cease
        play.followCease = absoluteCease
        play.payoffEnd = absoluteCease + MomoHandshakeChoreography.payoffSeconds
        stateLayer = .play(play)
    }
}
