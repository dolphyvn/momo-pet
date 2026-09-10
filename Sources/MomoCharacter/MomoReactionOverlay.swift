import CoreGraphics
import Foundation
import MomoCore

// MARK: - The overlay projection (state → channel values at an instant)

/// The director state's pure time projection: what the coherence layers
/// render at `t` (character-timeline seconds). Bottom-first fold order is
/// the §4.1 matrix read downward: L1 press feedback, the outgoing L2 (its
/// crossfade half), the current L2, the L3 slots (current + any still
/// fading after a cut), and L4 over everything.
extension MomoDirectorState {

    public func overlay(at t: Double) -> MomoReactionMotion {
        var layers: [MomoReactionMotion] = []

        if let press {
            layers.append(pressMotion(press, at: t))
        }
        if let fading = stateFading {
            let fraction = MomoCurves.smoothstep(
                (t - stateFadingStart) / Self.l2CrossfadeSeconds)
            layers.append(stateMotion(fading, at: t).faded(fraction))
        }
        if let layer = stateLayer {
            let progress = stateEnterSeconds > 0
                ? (t - stateEnterStart) / stateEnterSeconds : 1
            let entered = MomoCurves.smoothstep(progress)
            layers.append(stateMotion(layer, at: t).faded(1 - entered))
        }
        for slot in reactionSlots where isVisible(slot, at: t) {
            let motion = reactionMotion(slot, at: t)
            guard let superseded = slot.supersededAt else {
                layers.append(motion)
                continue
            }
            let fraction = (t - superseded) / slot.fadeOutSeconds
            layers.append(motion.faded(fraction))
        }
        if let moment,
            t >= moment.start,
            t < moment.start + MomoMoments.duration(for: moment.moment) {
            layers.append(
                MomoMoments.motion(for: moment.moment, elapsed: t - moment.start))
        }
        return MomoReactionMotion.fold(layers)
    }

    // MARK: Layer motion

    private func stateMotion(
        _ layer: MomoStateInstance, at t: Double
    ) -> MomoReactionMotion {
        switch layer {
        case .clip(let slot):
            return reactionMotion(slot, at: t)
        case .settle(let start, _):
            return MomoHandshakeChoreography.settleMotion(elapsed: t - start)
        case .wake(let start):
            return MomoHandshakeChoreography.wakeMotion(elapsed: t - start)
        case .play(let play):
            return playMotion(play, at: t)
        }
    }

    private func playMotion(
        _ play: MomoPlayInstance, at t: Double
    ) -> MomoReactionMotion {
        if t < play.followStart {
            return MomoHandshakeChoreography.inviteMotion(elapsed: t - play.start)
        }
        if let cease = play.followCease, t >= cease, t < play.payoffEnd ?? .infinity {
            return MomoHandshakeChoreography.payoffMotion(
                elapsed: t - cease, yawn: false)
        }
        // The follow: head + eyes track the fingertip; the Drowsy round's
        // last stretch rides the wind-down yawn.
        var motion = MomoHandshakeChoreography.followMotion(
            fingertipOffset: play.lastOffset)
        if play.drowsy, let cease = play.followCease ?? deadlineCease(play),
            t >= cease - MomoHandshakeChoreography.drowsyYawnSeconds {
            let elapsed = t - (cease - MomoHandshakeChoreography.drowsyYawnSeconds)
            let yawn = MomoReactionChoreography.bump(
                elapsed, duration: MomoHandshakeChoreography.drowsyYawnSeconds,
                attack: 0.45, release: 0.45)
            motion.apertureMultiplier *= 1 - yawn
            motion.headRotationDegrees += 3 * yawn
        }
        return motion
    }

    /// The cease an un-resolved pacer would get (no rest) — the overlay's
    /// read-only view of the deadline; the STATE resolves the real cease
    /// in its fold.
    private func deadlineCease(_ play: MomoPlayInstance) -> Double? {
        let baseline = play.drowsy
            ? MomoHandshakeChoreography.drowsyFollowSeconds
            : MomoHandshakeChoreography.followBaselineSeconds
        return play.followStart + baseline
    }

    private func reactionMotion(
        _ slot: MomoReactionSlot, at t: Double
    ) -> MomoReactionMotion {
        if slot.glanceUp {
            return glanceUpMotion(at: t - slot.start)
        }
        let spec = MomoReactionClips.spec(for: slot.key)
        let duration = spec.duration(tempo: slot.tempo)
            * (slot.abbreviated ? Self.abbreviationFraction : 1)
        return MomoReactionChoreography.motion(
            for: slot.key, elapsed: t - slot.start, duration: duration,
            holdSeconds: slot.holdSeconds, deepened: slot.deepened,
            context: slot.context)
    }

    /// Rule 5's glance-up: the meal keeps chewing while the eyes find the
    /// touch (AUTHORED ~0.5 s).
    private func glanceUpMotion(at elapsed: Double) -> MomoReactionMotion {
        let shape = MomoReactionChoreography.bump(
            elapsed, duration: Self.glanceUpSeconds, attack: 0.12, release: 0.2)
        return MomoReactionMotion(
            apertureMultiplier: 1 + 0.10 * shape,
            headTranslationY: -2 * shape,
            pupilOffset: CGPoint(x: 0, y: -8 * shape))
    }

    /// The L1 press micro-feedback: a whisper of ear lift and an upward
    /// glance while the finger is down; Rule 1 fades it on reaction
    /// arrival.
    private func pressMotion(_ press: MomoPressState, at t: Double) -> MomoReactionMotion {
        let alive = press.fadingSince == nil || t < press.fadingSince! + Self.l1FadeSeconds
        guard alive, t >= press.start else { return .identity }
        let presence: Double
        if let fading = press.fadingSince {
            presence = 1 - min(max((t - fading) / Self.l1FadeSeconds, 0), 1)
        } else {
            presence = MomoCurves.smoothstep((t - press.start) / 0.08)
        }
        return MomoReactionMotion(
            earLeftDegrees: 2 * presence,
            earRightDegrees: 2 * presence,
            pupilOffset: CGPoint(x: 0, y: -4 * presence))
    }

    // MARK: Visibility

    private func isVisible(_ slot: MomoReactionSlot, at t: Double) -> Bool {
        guard slot.start <= t else { return false }
        if let superseded = slot.supersededAt {
            return t < superseded + slot.fadeOutSeconds
        }
        guard let end = slot.end else { return true } // press-shaped, holding
        return t < end
    }
}
