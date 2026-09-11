import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The handshakes (TASK-028 R4/R7; 04 §4.3, §6.3, §7.1, §9.2)

/// Settle/wake/play as behavior pins over the pure fold: exactly-once
/// completion reports, the cancellation matrix, wake's never-cancel +
/// replay-from-0 law, and the play round's ≤ 30 s bound under adversarial
/// fingertip pacing. All instants explicit; no clock, no RNG.
struct MomoHandshakeTests {

    // MARK: Settle (§4.3's 2.5–3.5 s tuck-in)

    @Test("Settle completes once at its authored 3.0 s and reports settleFinished")
    func settleCompletes() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
        ])
        // Not yet at the duration…
        let early = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 3.9)], into: state)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: early).isEmpty)
        // …the first fold past 4.0 resolves the report at the end instant.
        let done = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 4.0)], into: state)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: done)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 4.0) < 1e-9)
        #expect(done.stateLayer == nil)
    }

    @Test("App hide during settle cancels exactly once (no settleFinished)")
    func settleCancelledByHide() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
            .appHidden(at: 2.0),
        ])
        let cancels = ReactionFixtures.reports(
            matching: ReactionFixtures.settleCancelled, in: state)
        #expect(cancels.count == 1)
        #expect(cancels.first?.at == 2.0)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: state).isEmpty)
        // The settle left the slot; the return does not resurrect it.
        let shown = ReactionFixtures.fold(
            [.appShown(at: 3.0), .displayState(ReactionFixtures.content, at: 9.0)],
            into: state)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: shown).isEmpty)
    }

    @Test("A newer L2 clip preempts a running settle and cancels it exactly once")
    func settleCancelledByNewerL2() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.eating, at: 2.0),
        ])
        let cancels = ReactionFixtures.reports(
            matching: ReactionFixtures.settleCancelled, in: state)
        #expect(cancels.count == 1)
        #expect(cancels.first?.at == 2.0)
        // The meal owns the slot now and completes on its own clock.
        if case .clip(let slot) = state.stateLayer {
            #expect(slot.key == .eating)
        } else {
            Issue.record("the meal did not take the state slot")
        }
    }

    /// L3 touches ride OVER the settle (Rule 5's additive read) — the
    /// settle keeps the slot and still completes.
    @Test("An L3 touch during settle never cancels it")
    func settleSurvivesL3() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.5),
            .displayState(ReactionFixtures.content, at: 9.0),
        ])
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleCancelled, in: state).isEmpty)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: state).count == 1)
    }

    /// MAJOR-1: blanketAdjust is the doc's L3 care beat — during a running
    /// settle it plays ADDITIVELY over the yawn (no `handshakeCancelled`;
    /// `settleFinished` fires exactly once at its 3.0 s) while the nudge
    /// runs its own 1.5 s L3 clock.
    @Test("blanketAdjust during settle rides additively; the settle still completes")
    func settleSurvivesBlanketAdjust() {
        let run = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.blanketAdjust, at: 2.0),
        ])
        // The additive read at 2.3: the nudge's blanket pose rides over
        // the settle (whose blanket is still at rest at elapsed 1.3) while
        // the yawn's lids are still dipping — both shapes read at once.
        let overlay = run.overlay(at: 2.3)
        #expect(overlay.blanket.transform.rotationDegrees == 4)
        #expect(overlay.apertureMultiplier < 1)
        // Fold past everything: zero cancellations; each beat reported
        // once on its own clock — the nudge at 3.5, the settle at 4.0.
        let state = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 9.0)], into: run)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleCancelled, in: state).isEmpty)
        let nudge = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.blanketAdjust),
            in: state)
        #expect(nudge.count == 1)
        #expect(abs(nudge.first!.at - 3.5) < 1e-9)
        let settle = ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: state)
        #expect(settle.count == 1)
        #expect(abs(settle.first!.at - 4.0) < 1e-9)
    }

    /// NOTE-2: the settle displacing a running play is an L2→L2 handoff —
    /// BOTH halves ride the §7.1 state crossfade band (the invite fades
    /// out as the yawn fades in), not a snap.
    @Test("Settle displacing play crossfades both halves over the state band")
    func settleDisplacesPlayThroughCrossfade() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.settling, at: 2.0),
        ])
        // The displaced round cancelled exactly once at the cut…
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playCancelled, in: state).count == 1)
        // …and the handoff crossfades: at the cut instant the incoming
        // yawn contributes nothing (the invite's perk is all that shows);
        // at the band's midpoint the invite's ears are half-faded while
        // the yawn's lids are half-in; past the band only the settle
        // remains.
        #expect(state.overlay(at: 2.0).apertureMultiplier == 1)
        #expect(state.overlay(at: 2.0).earLeftDegrees == 10)
        let mid = state
            .overlay(at: 2.0 + MomoDirectorState.l2CrossfadeSeconds / 2)
        #expect(mid.earLeftDegrees > 0 && mid.earLeftDegrees < 10)
        #expect(mid.apertureMultiplier < 1)
        let full = state
            .overlay(at: 2.0 + MomoDirectorState.l2CrossfadeSeconds + 0.01)
        #expect(full.earLeftDegrees == 0)
        #expect(full.apertureMultiplier < 1)
    }

    // MARK: Wake (§7.1's waking row; §9.2 never-cancel; ADR-010)

    @Test("Wake completes once at its authored 2.0 s and reports wakeFinished")
    func wakeCompletes() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(wakefulness: .waking), at: 1.0),
            .displayState(
                ReactionFixtures.displayState(wakefulness: .waking), at: 3.0),
        ])
        // The repeat waking stamp does not restart or double-report.
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.wakeFinished, in: state)
        #expect(finishes.count == 1)
        #expect(finishes.first?.at == 3.0)
    }

    @Test("Hide pauses a running wake; the return replays it from 0 (ADR-010)")
    func wakeReplaysFromZero() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(wakefulness: .waking), at: 1.0),
            .appHidden(at: 1.5),
            .appShown(at: 5.0),
        ])
        // No cancellation report exists for wake — hide is a pause.
        #expect(state.reports.isEmpty)
        // The replay restarted the clock: the 2.0 s stretch runs from 5.0.
        let mid = state.overlay(at: 5.5)
        #expect(mid.bodyScaleYMultiplier > 1) // mid-stretch
        let done = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(wakefulness: .waking), at: 7.0)],
            into: state)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.wakeFinished, in: done)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 7.0) < 1e-9) // 5.0 + 2.0
    }

    // MARK: Play (§6.3; §7.1's 15–30 s round; R7's ≤ 30 s law)

    /// The worst-case bound is authored arithmetic: invite + deadline
    /// follow + payoff.
    @Test("The authored worst-case round is 22.4 s, inside §7.1's 30 s cap")
    func roundBound() {
        #expect(MomoHandshakeChoreography.maxRoundSeconds == 22.4)
        #expect(MomoHandshakeChoreography.inviteSeconds == 2.4)
        #expect(MomoHandshakeChoreography.followDeadlineSeconds == 16.0)
        #expect(MomoHandshakeChoreography.payoffSeconds == 4.0)
    }

    @Test("A round with no fingertip input still ceases at the baseline and pays off")
    func playNeverMoves() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .displayState(ReactionFixtures.content, at: 30.0),
        ])
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state)
        #expect(finishes.count == 1)
        // followStart 3.4 + baseline 12.0 = 15.4 cease; + payoff 4.0.
        #expect(abs(finishes.first!.at - 19.4) < 1e-9)
        if case .play = state.stateLayer { Issue.record("the round never ended") }
    }

    @Test("Always-moving input resolves the baseline; the report is exactly-once")
    func playAlwaysMoving() {
        var events: [MomoCharacterEvent] = [
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        ]
        for step in 0..<30 {
            events.append(.fingertip(
                offset: CGPoint(x: CGFloat(step) * 7 - 100, y: 40),
                moving: true, at: 3.5 + 0.5 * Double(step)))
        }
        events.append(.displayState(ReactionFixtures.content, at: 30.0))
        let state = ReactionFixtures.fold(events)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 19.4) < 1e-9)
    }

    /// The pacer's rest rule: stillness held for the grace ends the follow
    /// at max(solo floor, restStart + tail) — SHORTER than the baseline.
    @Test("A fingertip that rests mid-round shortens the follow (solo finish)")
    func playRestMidRound() {
        var events: [MomoCharacterEvent] = [
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        ]
        // Moving to the rest spot, then still — samples every 0.5 s.
        for step in 0..<6 {
            events.append(.fingertip(
                offset: CGPoint(x: 80, y: 0), moving: step < 2,
                at: 3.5 + 0.5 * Double(step)))
        }
        events.append(.displayState(ReactionFixtures.content, at: 30.0))
        let state = ReactionFixtures.fold(events)
        // Still from 4.5; grace resolves at 6.5; solo = max(10, 4.5 + 3)
        // = 10 → cease 3.4 + 10 = 13.4; payoff end 17.4.
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 17.4) < 1e-9)
    }

    @Test("A still fingertip inside its rest grace does not freeze the baseline")
    func playStillInsideGrace() {
        var events: [MomoCharacterEvent] = [
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        ]
        // One still sample inside the grace, then moving again: the round
        // must still run its full baseline (the stillness was provisional).
        events.append(.fingertip(offset: .zero, moving: false, at: 5.0))
        events.append(.fingertip(offset: CGPoint(x: 60, y: 0), moving: true, at: 5.5))
        events.append(.displayState(ReactionFixtures.content, at: 30.0))
        let state = ReactionFixtures.fold(events)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 19.4) < 1e-9)
    }

    @Test("Drowsy's follow is the authored short 8.0 s and ends in a yawn")
    func playDrowsy() {
        // Mid-round state (the follow resolved at 11.4, payoff not yet).
        let mid = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(energy: .drowsy), at: 0.5),
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: CGPoint(x: 50, y: 0), moving: true, at: 4.0),
            .displayState(
                ReactionFixtures.displayState(energy: .drowsy), at: 12.0),
        ])
        // The wind-down yawn rides the follow's last 1.4 s (10.0 → 11.4).
        #expect(mid.overlay(at: 10.7).apertureMultiplier < 1)
        // The payoff opens the eyes again (no yawn composition there).
        #expect(mid.overlay(at: 11.6).apertureMultiplier == 1)
        // Stillness cannot shorten the drowsy round: fixed 8.0 follow.
        let done = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(energy: .drowsy), at: 30.0)],
            into: mid)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: done)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 15.4) < 1e-9) // 3.4 + 8.0 + 4.0
    }

    /// Rule 6: the cheer rides the round without resetting its clock.
    @Test("Cheer during play never resets the round (Rule 6)")
    func cheerDuringPlay() {
        var events: [MomoCharacterEvent] = [
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.cheer, at: 5.0),
        ]
        for step in 0..<20 {
            events.append(.fingertip(
                offset: CGPoint(x: CGFloat(step) * 9, y: 0), moving: true,
                at: 5.5 + 0.5 * Double(step)))
        }
        events.append(.displayState(ReactionFixtures.content, at: 30.0))
        let state = ReactionFixtures.fold(events)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 19.4) < 1e-9) // the un-reset timeline
        // The cheer rendered as an L3 run (its completion reported once).
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.cheer),
            in: state).count == 1)
    }

    @Test("App hide during play cancels exactly once (no playRoundFinished)")
    func playCancelledByHide() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: CGPoint(x: 40, y: 0), moving: true, at: 3.5),
            .appHidden(at: 6.0),
        ])
        let cancels = ReactionFixtures.reports(
            matching: ReactionFixtures.playCancelled, in: state)
        #expect(cancels.count == 1)
        #expect(cancels.first?.at == 6.0)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state).isEmpty)
        // The return does not resurrect the round (the engine re-invites).
        let shown = ReactionFixtures.fold(
            [.appShown(at: 7.0), .displayState(ReactionFixtures.content, at: 30.0)],
            into: state)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: shown).isEmpty)
    }

    /// TASK-035 R6: the Done pill's `.playStopped` rides the SAME
    /// displacement-cancel machinery as hide — the round's report is the
    /// exactly-once `handshakeCancelled(.play)`, the slot empties (no
    /// fading remnant), and the underlying state shows through.
    @Test("The Done stop cancels a running round exactly once (same machinery as hide)")
    func playStoppedByDone() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: CGPoint(x: 40, y: 0), moving: true, at: 3.5),
            .playStopped(at: 6.0),
        ])
        let cancels = ReactionFixtures.reports(
            matching: ReactionFixtures.playCancelled, in: state)
        #expect(cancels.count == 1)
        #expect(cancels.first?.at == 6.0)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: state).isEmpty)
        // The slot is empty and clean: the pet renders its underlying
        // state with no fading remnant of the round.
        #expect(state.stateLayer == nil)
        #expect(state.overlay(at: 7.0) == .identity)
    }

    @Test("A stop with no round in flight is a tolerated no-op")
    func playStoppedWithoutRound() {
        // Bare stop on an idle pet: nothing reports, nothing renders.
        let idle = ReactionFixtures.fold([.playStopped(at: 1.0)])
        #expect(idle.reports.isEmpty)
        #expect(idle.overlay(at: 2.0) == .identity)
        // A stop against a CLIP (an L3 reaction owns the slot) never
        // touches it: no cancel is reported, and the tap completes on its
        // own clock.
        let withClip = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.0),
            .playStopped(at: 1.5),
        ])
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playCancelled, in: withClip
        ).isEmpty)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.tapHead),
            in: withClip
        ).count == 1)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.tapHead),
            in: ReactionFixtures.fold(
                [.displayState(ReactionFixtures.content, at: 5.0)], into: withClip)
        ).count == 1)
    }

    @Test("A stop after the round already resolved reports nothing new")
    func playStoppedAfterResolution() {
        let resolved = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .displayState(ReactionFixtures.content, at: 30.0),
        ])
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: resolved).count == 1)
        // The late Done tap (round long gone) is a no-op: no cancel, no
        // second completion.
        let late = ReactionFixtures.fold(
            [.playStopped(at: 40.0)], into: resolved)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playRound, in: late).count == 1)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playCancelled, in: late).isEmpty)
    }

    @Test("A stop never cancels a settle (the play-only seam)")
    func playStoppedNeverCancelsSettle() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
            .playStopped(at: 2.0),
            .displayState(ReactionFixtures.content, at: 9.0),
        ])
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.playCancelled, in: state).isEmpty)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.settleCancelled, in: state).isEmpty)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.settleFinished, in: state)
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 4.0) < 1e-9)
    }

    /// The invite is the round's phase 1 and shares its motion with the
    /// `react.playReady` clip (§6.3).
    @Test("The play invite is 2.4 s of ears-and-tail perk (two-group cap)")
    func invitePhase() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        ])
        // Mid-invite: the perk lives on the ears and the tail; the body
        // holds (§7.4 rule 4 — playing animates two transform groups max,
        // and the invite spends them on ears + tail).
        let invite = state.overlay(at: 2.0)
        #expect(invite.earLeftDegrees != 0 || invite.tailDegrees != 0)
        #expect(invite.bodyScaleYMultiplier == 1)
        #expect(invite.headRotationDegrees == 0)
        // Past the invite the follow owns the motion (head + gaze).
        let follow = state.overlay(at: 3.4)
        #expect(follow.earLeftDegrees == 0)
        #expect(follow.tailDegrees == 0)
    }

    @Test("The follow motion tracks the fingertip on head + gaze only")
    func followPhase() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: CGPoint(x: 150, y: 0), moving: true, at: 5.0),
        ])
        let follow = state.overlay(at: 5.5)
        #expect(follow.headRotationDegrees > 0)
        #expect(follow.pupilOffset.x > 0)
        // The two-group cap: body and ears/tail stay out of the follow.
        #expect(follow.bodyScaleYMultiplier == 1)
        #expect(follow.earLeftDegrees == 0 && follow.tailDegrees == 0)
    }

    @Test("The payoff is one soft spring bounce with the two-sparkle ring")
    func payoffPhase() {
        // A round frozen mid-payoff (the cease resolved at 15.4, the
        // payoff runs to 19.4).
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .displayState(ReactionFixtures.content, at: 16.0),
        ])
        // The bounce peaks inside §7.2's ≤ 8 % celebration cap; the
        // sparkle ring drifts and fades.
        let peak = state.overlay(at: 15.5)
        #expect(peak.bodyScaleYMultiplier > 1)
        #expect(peak.bodyScaleYMultiplier
            <= 1 + MomoCurves.celebrationOvershootMax)
        #expect(peak.sparkleA != .rest || peak.sparkleB != .rest)
        let late = state.overlay(at: 19.0)
        #expect(late.sparkleA.opacity < 1)
        #expect(late.bodyScaleYMultiplier == 1) // the bounce has decayed
    }
}
