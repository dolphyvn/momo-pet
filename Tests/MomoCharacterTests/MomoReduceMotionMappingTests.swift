import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The §7.3 mapping table, row by row (TASK-029 R1–R9)

/// One test per §7.3 row, digit-pinned with authority labels. The RM flag
/// is a pure injected value here (no environment, no ambient reads): the
/// pose seam and the RM overlay are deterministic functions of
/// `(inputs, reduceMotion)`, and the default flag is an exact no-op.
/// Reports/pacing are covered by the twin suite; per-key end poses by the
/// end-pose suite; this suite pins WHAT each row renders.
@Suite("Reduce Motion mapping — §7.3 rows, digit-pinned")
struct MomoReduceMotionMappingTests {

    private let model = RigMotionModel()
    private let content = ReactionFixtures.displayState()
    private let context = MomoReactionContext(
        moodBand: .content, energyBand: .relaxed, bondStage: .bestFriends,
        wakefulness: .awake)

    private func state(
        _ mood: MoodBand, _ energy: EnergyBand = .relaxed,
        wakefulness: Wakefulness = .awake
    ) -> CharacterDisplayState {
        ReactionFixtures.displayState(
            mood: mood, energy: energy, wakefulness: wakefulness)
    }

    // MARK: The digits (authored, authority-labeled)

    @Test("Digits: 0.15 reaction crossfade (exact row digit); 0.15 state crossfade (AUTHORED band floor)")
    func digits() {
        // 04 §7.3 touch reactions row: end-pose swap with a 150 ms
        // crossfade — the digit is exact, unlike the state band.
        #expect(MomoReduceMotion.reactionCrossfadeSeconds == 0.15)
        // 04 §7.3 state changes row: 0.15–0.20 s (or instant); AUTHORED
        // at the floor, calm by default. The same digit paces the play
        // milestone swaps (R9's disclosed choice).
        #expect(MomoReduceMotion.stateCrossfadeSeconds == 0.15)
        #expect((0.15...0.20).contains(MomoReduceMotion.stateCrossfadeSeconds))
    }

    // MARK: R1 — injected, pure, exact no-op when false

    @Test("R1: the default flag is an exact no-op over a full live schedule")
    func defaultFlagIsExactNoOp() {
        let schedule = MomoIdleSequencer.schedule(
            idleSeed: 7, displayState: content, windowEnd: 30)
        #expect(!schedule.isEmpty) // the schedule is live, not empty
        for t in samples(until: 30, count: 60) {
            #expect(
                model.pose(
                    at: t, displayState: content, schedule: schedule,
                    reactionMotion: .identity)
                    == model.pose(
                        at: t, displayState: content, schedule: schedule,
                        reactionMotion: .identity,
                        reduceMotion: false, staticPoseTransition: nil),
                "default-flag divergence at t=\(t)")
        }
    }

    // MARK: R2 — idle row: the static pose per state

    @Test("R2: idle renders the static band pose at every t (breath and wag off, t-invariant)")
    func idleIsTheStaticBandPose() {
        for band in [state(.joyful), state(.content), state(.wistful), state(.low)] {
            let expression = MomoExpressions.expression(for: band)
            let schedule = MomoIdleSequencer.schedule(
                idleSeed: 3, displayState: band, windowEnd: 40)
            var poses: [RigPose] = []
            for t in samples(until: 40, count: 41) {
                let pose = model.pose(
                    at: t, displayState: band, schedule: schedule,
                    reactionMotion: .identity, reduceMotion: true)
                // The static base exactly: breath sine off (amplitude 0 →
                // breathScaleY == 1), Joyful's wag sine off, the band's
                // own aperture/ears/lids standing.
                #expect(pose.body.scaleY == CGFloat(expression.postureScaleY))
                #expect(
                    pose.eyeLeft.lidScaleY
                        == MomoExpressions.lidScaleY(forAperture: expression.aperture))
                #expect(pose.eyeLeft.pupilOffset == .zero)
                #expect(
                    pose.earLeft.rotationDegrees
                        == MomoCurves.clampedEarRotation(expression.earDegrees))
                #expect(
                    pose.earRight.rotationDegrees
                        == MomoCurves.clampedEarRotation(expression.earDegrees))
                #expect(pose.tail.rotationDegrees == 0)
                poses.append(pose)
            }
            // t-invariance: every frame of the quiescent character is THE
            // SAME pose (the observable static law).
            #expect(poses.allSatisfy { $0 == poses[0] })
        }
    }

    @Test("R2 non-vacuity: with the flag off the same schedule moves")
    func idleFullMotionMoves() {
        let schedule = MomoIdleSequencer.schedule(
            idleSeed: 3, displayState: content, windowEnd: 40)
        let still = model.pose(
            at: 0.5, displayState: content, schedule: schedule,
            reactionMotion: .identity, reduceMotion: true)
        let moved = samples(until: 40, count: 80).contains { t in
            model.pose(
                at: t, displayState: content, schedule: schedule,
                reactionMotion: .identity) != still
        }
        #expect(moved, "full motion never diverged from the static pose")
    }

    // MARK: R3 — blink row: the natural aperture stands

    @Test("R3: the blink substream never displaces the band's natural aperture")
    func blinkNeverClosesTheEye() {
        let blink = MomoIdleEvent(
            kind: .blink, start: 1.0, duration: 0.27,
            payload: .blink(MomoBlinkEnvelope(
                isDouble: false, closeSeconds: 0.15, openSeconds: 0.12,
                interBlinkGapSeconds: 0.09)))
        let aperture = MomoExpressions.expression(for: content).aperture
        // The instant of FULL closure (the close phase's end).
        let closed = model.pose(
            at: 1.15, displayState: content, schedule: [blink],
            reactionMotion: .identity, reduceMotion: true)
        #expect(
            closed.eyeLeft.lidScaleY
                == MomoExpressions.lidScaleY(forAperture: aperture))
        #expect(
            closed.eyeRight.lidScaleY
                == MomoExpressions.lidScaleY(forAperture: aperture))
        // Non-vacuity: the same schedule with the flag off closes the eye.
        let full = model.pose(
            at: 1.15, displayState: content, schedule: [blink],
            reactionMotion: .identity)
        #expect(
            full.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0),
            "the full-motion blink did not close the eye at its midpoint")
    }

    // MARK: R4 — look-around row: wander suppressed, static touch glance

    @Test("R4: idle gaze wander is suppressed; the touch glance is static and released")
    func gazeWanderSuppressedTouchGlanceStands() {
        // The wander: an up-toward-user gaze event rides the schedule —
        // masked under RM (the eyes hold the band's centered gaze).
        let gaze = MomoIdleEvent(
            kind: .gaze, start: 1.0, duration: 1.9,
            payload: .gaze(MomoGazeEnvelope(
                target: .upTowardUser, shiftSeconds: 0.25,
                holdSeconds: 1.0, returnSeconds: 0.65)))
        let rm = model.pose(
            at: 2.0, displayState: content, schedule: [gaze],
            reactionMotion: .identity, reduceMotion: true)
        #expect(rm.eyeLeft.pupilOffset == .zero)
        let full = model.pose(
            at: 2.0, displayState: content, schedule: [gaze],
            reactionMotion: .identity)
        #expect(full.eyeLeft.pupilOffset != .zero)

        // The replacement: the L1 press feedback IS the touch glance —
        // static ears +2°, pupils up — so the RM overlay renders it
        // UNCHANGED (flag-invariant), and the touch end releases it.
        let press = ReactionFixtures.fold([.touchBegan(zone: .head, at: 0.5)])
        #expect(press.reduceMotionOverlay(at: 0.7) == press.overlay(at: 0.7))
        let glance = press.reduceMotionOverlay(at: 0.7)
        #expect(glance.earLeftDegrees == 2)
        #expect(glance.earRightDegrees == 2)
        #expect(glance.pupilOffset == CGPoint(x: 0, y: -4))
        // Released on touch end (the Rule-1 fade, both flags).
        let released = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 0.5), .touchEnded(at: 1.0),
        ])
        #expect(released.reduceMotionOverlay(at: 1.3) == .identity)
        #expect(released.overlay(at: 1.3) == .identity)
    }

    // MARK: R5 — state changes: static↔static crossfade

    @Test("R5: the tracker opens one 0.15 s crossfade window per state change")
    func transitionWindow() {
        var tracker = MomoReduceMotionStateTracker(initial: content)
        #expect(tracker.transition(at: 10) == nil)
        tracker.fold(.displayState(state(.joyful), at: 5.0))
        #expect(tracker.state == state(.joyful))
        #expect(tracker.transition(at: 4.99) == nil) // before the change
        #expect(tracker.transition(at: 5.0) == MomoReduceMotionTransition(
            fromState: content, since: 5.0))
        #expect(tracker.transition(at: 5.14) != nil)
        #expect(tracker.transition(at: 5.15) == nil) // window closed (0.15)
        // A non-change (identical state) opens nothing.
        tracker.fold(.displayState(state(.joyful), at: 6.0))
        #expect(tracker.transition(at: 6.01) == nil)
    }

    @Test("R5: the pose crossfades between the two STATIC poses — endpoints exact, path monotone")
    func stateChangeCrossfadesStatics() {
        var tracker = MomoReduceMotionStateTracker(initial: content)
        tracker.fold(.displayState(state(.joyful), at: 5.0))
        let contentStatic = model.pose(
            at: 5.0, displayState: content, schedule: [],
            reactionMotion: .identity, reduceMotion: true)
        let joyfulStatic = model.pose(
            at: 5.0, displayState: state(.joyful), schedule: [],
            reactionMotion: .identity, reduceMotion: true)
        #expect(contentStatic != joyfulStatic) // the states ARE distinct

        func pose(at t: Double) -> RigPose {
            model.pose(
                at: t, displayState: state(.joyful), schedule: [],
                reactionMotion: .identity, reduceMotion: true,
                staticPoseTransition: tracker.transition(at: t))
        }
        // Endpoints: the OLD static exactly at the change, the NEW static
        // exactly one crossfade later.
        #expect(pose(at: 5.0) == contentStatic)
        #expect(pose(at: 5.15) == joyfulStatic)
        #expect(pose(at: 5.4) == joyfulStatic)
        // The path: monotone in the ear channel (0° content → 16.5°
        // joyful), never overshooting the endpoints — posture never
        // animates through intermediate motion, only the crossfade.
        let ears = [5.03, 5.06, 5.09, 5.12].map { pose(at: $0).earLeft.rotationDegrees }
        #expect(ears[0] < ears[1])
        #expect(ears[1] < ears[2])
        #expect(ears[2] < ears[3])
        for ear in ears {
            #expect(ear > contentStatic.earLeft.rotationDegrees)
            #expect(ear < joyfulStatic.earLeft.rotationDegrees)
        }
        // Asleep lands closed: the settle-adjacent band change reads.
        var toAsleep = MomoReduceMotionStateTracker(initial: content)
        toAsleep.fold(.displayState(state(.content, wakefulness: .asleep), at: 2.0))
        let asleepPose = model.pose(
            at: 2.2, displayState: state(.content, wakefulness: .asleep),
            schedule: [], reactionMotion: .identity, reduceMotion: true,
            staticPoseTransition: toAsleep.transition(at: 2.2))
        #expect(asleepPose.eyeLeft.lidScaleY == MomoExpressions.lidScaleY(forAperture: 0))
    }

    @Test("R5: a second state change inside the window overwrites — the blend snaps to the intermediate static")
    func secondChangeInsideTheWindowOverwrites() {
        // Two CHANGES inside one 0.15 s window (5.0, then 5.05): the fold
        // REPLACES the pending transition — it departs from the
        // intermediate state (joyful) at the second change's own instant.
        var tracker = MomoReduceMotionStateTracker(initial: content)
        tracker.fold(.displayState(state(.joyful), at: 5.0))
        // The live render just before the overwrite: mid-window, blending
        // content → joyful (≈ 75 % of the way back to the content static).
        let before = model.pose(
            at: 5.049, displayState: state(.joyful), schedule: [],
            reactionMotion: .identity, reduceMotion: true,
            staticPoseTransition: tracker.transition(at: 5.049))
        tracker.fold(.displayState(state(.wistful), at: 5.05))
        #expect(tracker.state == state(.wistful))
        #expect(tracker.transition(at: 5.05) == MomoReduceMotionTransition(
            fromState: state(.joyful), since: 5.05))

        func pose(at t: Double) -> RigPose {
            model.pose(
                at: t, displayState: state(.wistful), schedule: [],
                reactionMotion: .identity, reduceMotion: true,
                staticPoseTransition: tracker.transition(at: t))
        }
        let joyfulStatic = model.pose(
            at: 5.05, displayState: state(.joyful), schedule: [],
            reactionMotion: .identity, reduceMotion: true)
        let wistfulStatic = model.pose(
            at: 5.05, displayState: state(.wistful), schedule: [],
            reactionMotion: .identity, reduceMotion: true)
        #expect(joyfulStatic != wistfulStatic) // the states ARE distinct

        // The snap: at the overwrite instant the blend's amount resets to 1
        // toward the NEW from-state — the pose IS the intermediate (joyful)
        // static exactly, and just before it was not (the ear channel jumps
        // > 5°; ≈ 12° by the blend arithmetic).
        #expect(pose(at: 5.05) == joyfulStatic)
        #expect(
            joyfulStatic.earLeft.rotationDegrees
                - before.earLeft.rotationDegrees > 5)
        // The overwritten window then resolves to the FINAL state: past
        // 5.05 + 0.15 the pose is the wistful static, t-invariant.
        #expect(pose(at: 5.2) == wistfulStatic)
        #expect(pose(at: 5.4) == wistfulStatic)
    }

    @Test("R5 primitives: blend and lerped hit their exact endpoints")
    func crossfadePrimitives() {
        let a = MomoReactionMotion(
            apertureMultiplier: 0.8, headRotationDegrees: 4,
            cheekOpacity: 0.7,
            sparkleA: RigPropPose(
                transform: RigGridTransform(rotationDegrees: 12), opacity: 0.5))
        let b = MomoReactionMotion(
            apertureMultiplier: 1.1, tailDegrees: -3,
            mouthWeights: RigMouthWeights(neutral: 0.4, eat: 0.6, refuse: 0))
        #expect(a.lerped(to: b, amount: 0) == a)
        #expect(a.lerped(to: b, amount: 1) == b)
        #expect(a.lerped(to: b, amount: -2) == a)
        #expect(a.lerped(to: b, amount: 9) == b)
        let mid = a.lerped(to: b, amount: 0.5)
        // The midpoint pins the coordinate-wise lerp arithmetic (the same
        // `a + (b - a) * p` shape the transform implements), not a
        // decimal literal.
        #expect(mid.apertureMultiplier == 0.8 + (1.1 - 0.8) * 0.5)
        #expect(mid.headRotationDegrees == 2)
        #expect(mid.tailDegrees == -1.5)
        // The nil accent poles collapse only at the endpoint that owns
        // them (mid-flight reads the numeric blend).
        #expect(mid.cheekOpacity == 0.85)
        #expect(mid.mouthWeights?.neutral == 0.7)

        let poseA = RigPose(
            body: RigGridTransform(scaleY: 1.03, rotationDegrees: 2),
            earLeft: RigRotationScale(rotationDegrees: 16.5))
        let poseB = RigPose(earLeft: RigRotationScale(rotationDegrees: -17.5))
        #expect(poseA.blend(poseB, amount: 0) == poseA)
        #expect(poseA.blend(poseB, amount: 1) == poseB)
        let poseMid = poseA.blend(poseB, amount: 0.5)
        #expect(
            poseMid.body.scaleY
                == CGFloat(1.03) + (CGFloat(1.0) - CGFloat(1.03)) * CGFloat(0.5))
        #expect(poseMid.earLeft.rotationDegrees == -0.5)
    }

    // MARK: R6 — touch reactions: end-pose swap, 150 ms, then hold

    @Test("R6: a reaction crossfades to its END POSE over 0.15 s and holds it")
    func reactionIsAnEndPoseSwap() {
        let slotState = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.0),
        ])
        let slot = slotState.reactionSlots[0]
        let endPose = MomoReactionChoreography.motion(
            for: slot.key, elapsed: slot.end! - slot.start,
            duration: 0.4, holdSeconds: slot.holdSeconds,
            deepened: slot.deepened, context: slot.context)
        #expect(endPose != .identity) // the head tap's spring is held at 1
        let rm = slotState.reduceMotionOverlay(at: 1.3)
        // Before the arrival: nothing. Mid-crossfade: strictly between.
        #expect(slotState.reduceMotionOverlay(at: 0.9) == .identity)
        let mid = slotState.reduceMotionOverlay(at: 1.08)
        #expect(mid != .identity)
        #expect(mid != endPose)
        // Arrived: the END POSE exactly, held until the slot resolves.
        #expect(slotState.reduceMotionOverlay(at: 1.15) == endPose)
        #expect(rm == endPose)
        #expect(slotState.reduceMotionOverlay(at: 1.399) == endPose)
        // Non-vacuity: the full-motion render at the same instants differs
        // (the live choreography is mid-flight there).
        #expect(slotState.overlay(at: 1.08) != mid)
        #expect(slotState.overlay(at: 1.3) != rm)
    }

    // MARK: R7 — celebrations/sparkles: the static moment pose

    @Test("R7: quest and celebration render their settled pose for the full window")
    func momentsAreStatic() {
        let quest = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 1.0),
        ])
        let settled = MomoMoments.motion(for: .questCompleted, elapsed: 1.0)
        #expect(settled != .identity)
        for t in [1.15, 1.5, 1.99] {
            #expect(quest.reduceMotionOverlay(at: t) == settled,
                    "quest static diverged at t=\(t)")
        }
        #expect(quest.reduceMotionOverlay(at: 2.0) == .identity) // window over
        #expect(quest.overlay(at: 1.5) != settled) // full motion flies it

        let celebration = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(
                    momentRequest: .bondStageReached(.soulCompanions)),
                at: 1.0),
        ])
        let celebrated = MomoMoments.motion(
            for: .bondStageReached(.soulCompanions), elapsed: 1.8)
        #expect(celebrated != .identity)
        #expect(celebration.reduceMotionOverlay(at: 1.5) == celebrated)
        #expect(celebration.reduceMotionOverlay(at: 2.79) == celebrated)
    }

    @Test("R7: greetings render their authored key-instant pose (disclosed deviation)")
    func greetingsRenderKeyInstants() {
        // (GreetingKind is not CaseIterable; the four kinds are pinned
        // explicitly so a fifth cannot slip past this row silently.)
        for kind in [GreetingKind.freshMorning, .welcomeBack, .missedYou, .nightGlance] {
            let greeting = ReactionFixtures.fold([
                .displayState(
                    ReactionFixtures.displayState(momentRequest: .greeting(kind)),
                    at: 1.0),
            ])
            let keyPose = MomoMoments.motion(
                for: .greeting(kind),
                elapsed: MomoReduceMotion.greetingKeyInstant(for: kind))
            #expect(keyPose != .identity, "\(kind) key pose is empty")
            let duration = MomoMoments.greetingSeconds(for: kind)
            #expect(greeting.reduceMotionOverlay(at: 1.0 + duration / 2) == keyPose)
            #expect(greeting.reduceMotionOverlay(at: 1.0 + duration - 0.01) == keyPose)
        }
    }

    // MARK: R8 — waking/settling: the static END-state pose

    @Test("R8: settle renders the sleeping end pose; the fold still lands the report")
    func settleIsTheEndStatePose() {
        // The snapshot DURING the settle (a fold past 4.0 completes and
        // prunes the layer — the state renders "now", not history).
        let settle = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
        ])
        // `settleFinished` at the full 3.0 s — pacing untouched (the fold
        // is flag-blind; the twin suite pins stream equality).
        let completed = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
            .touchBegan(zone: .head, at: 5.0), // a fold past 4.0 lands it
        ])
        #expect(ReactionFixtures.reports(matching: "settle", in: completed)
            == [MomoReportEntry(report: .settleFinished, at: 4.0)])
        // The rendered run: the END pose, statically — the lie-down sink
        // (×0.94) and the settled blanket; no yawn, no nod.
        let endPose = MomoReactionMotion(
            bodyScaleYMultiplier: 0.94,
            blanket: RigPropPose(
                transform: RigGridTransform(
                    rotationDegrees: 3, translation: CGPoint(x: 0, y: -14))))
        for t in [1.3, 2.5, 3.9] {
            #expect(settle.reduceMotionOverlay(at: t) == endPose,
                    "settle static diverged at t=\(t)")
        }
        // Non-vacuity: the full choreography is mid-yawn early on.
        #expect(settle.overlay(at: 1.3) != endPose)
    }

    @Test("R8: wake renders the awake end pose (identity overlay); wakeFinished unchanged")
    func wakeIsTheEndStatePose() {
        // The snapshot during the wake (2.0 → 4.0).
        let wake = ReactionFixtures.fold([
            .displayState(ReactionFixtures.displayState(wakefulness: .waking), at: 2.0),
        ])
        let completed = ReactionFixtures.fold([
            .displayState(ReactionFixtures.displayState(wakefulness: .waking), at: 2.0),
            .touchBegan(zone: .head, at: 6.0), // a fold past 4.0 lands it
        ])
        #expect(ReactionFixtures.reports(matching: "wake", in: completed)
            == [MomoReportEntry(report: .wakeFinished, at: 4.0)])
        // The waking choreography's END pose is the identity — under RM
        // the awake band's static pose renders (the state change stays
        // legible: asleep ≠ awake, R11).
        for t in [2.3, 3.0, 3.9] {
            #expect(wake.reduceMotionOverlay(at: t) == .identity,
                    "wake static diverged at t=\(t)")
        }
        // Non-vacuity: the full stretch/perk is mid-flight early on.
        #expect(wake.overlay(at: 2.3) != .identity)
    }

    // MARK: R9 — playing: milestone stills, round completes

    @Test("R9: play renders invite → follow → payoff stills; the round completes identically")
    func playRendersMilestoneStills() {
        // The snapshot mid-round (the last fold at 16.0 resolves the
        // cease at the 15.4 deadline; a fold past payoffEnd 19.4 would
        // complete and prune the layer).
        let play = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: CGPoint(x: 40, y: 0), moving: true, at: 1.5),
            .fingertip(offset: CGPoint(x: 60, y: -30), moving: false, at: 16.0),
        ])
        // The round completed at payoffEnd = followStart(3.4) + 12 + 4.
        let completed = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: CGPoint(x: 40, y: 0), moving: true, at: 1.5),
            .fingertip(offset: CGPoint(x: 60, y: -30), moving: false, at: 16.0),
            .fingertip(offset: CGPoint(x: 60, y: -30), moving: false, at: 20.0),
        ])
        #expect(ReactionFixtures.reports(matching: "playRound", in: completed)
            == [MomoReportEntry(report: .playRoundFinished, at: 19.4)])

        // Invite still (start pose): the play-ready perk at its plateau —
        // ears +10°, tail +6° (wag crest), held.
        let inviteStill = MomoHandshakeChoreography.inviteMotion(
            elapsed: MomoReduceMotion.playInviteKeyInstant)
        #expect(inviteStill.earLeftDegrees == 10)
        #expect(inviteStill.tailDegrees == 6)
        #expect(play.reduceMotionOverlay(at: 2.0) == inviteStill)

        // Follow still (mid pose): input-coupled, reads the last offset.
        let followStill = MomoHandshakeChoreography.followMotion(
            fingertipOffset: CGPoint(x: 60, y: -30))
        #expect(play.reduceMotionOverlay(at: 6.0) == followStill)
        // The invite→follow swap crossfades over the state digit.
        let swap = play.reduceMotionOverlay(at: 3.475)
        #expect(swap != inviteStill)
        #expect(swap != followStill)

        // Payoff still (end pose): the settled celebration — sparkles at
        // their drift, the cheek accent — held from the crossfade's end.
        let payoffStill = MomoHandshakeChoreography.payoffMotion(
            elapsed: MomoHandshakeChoreography.payoffSeconds, yawn: false)
        #expect(payoffStill.cheekOpacity == 0.85)
        #expect(play.reduceMotionOverlay(at: 19.39) == payoffStill)
        // The follow→payoff swap crossfades too.
        let payoffSwap = play.reduceMotionOverlay(at: 15.475)
        #expect(payoffSwap != followStill)
        #expect(payoffSwap != payoffStill)
    }

    @Test("R9: the Drowsy wind-down yawn is suppressed in the follow still (disclosed)")
    func drowsyYawnSuppressed() {
        // The snapshot before the drowsy deadline (followStart 3.4 + 8.0
        // = 11.4; the yawn rides its last 1.4 s in the full render).
        let play = ReactionFixtures.fold([
            .displayState(ReactionFixtures.displayState(energy: .drowsy), at: 0.5),
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: .zero, moving: false, at: 5.0),
            .fingertip(offset: .zero, moving: false, at: 7.5),
        ])
        // The drowsy round completes at 11.4 + 4 = 15.4, identically.
        let completed = ReactionFixtures.fold([
            .displayState(ReactionFixtures.displayState(energy: .drowsy), at: 0.5),
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
            .fingertip(offset: .zero, moving: false, at: 5.0),
            .fingertip(offset: .zero, moving: false, at: 7.5),
            .fingertip(offset: .zero, moving: false, at: 16.0),
        ])
        #expect(ReactionFixtures.reports(matching: "playRound", in: completed)
            == [MomoReportEntry(report: .playRoundFinished, at: 15.4)])
        // RM holds the plain follow still; the full choreography yawns
        // through it.
        let followStill = MomoHandshakeChoreography.followMotion(fingertipOffset: .zero)
        #expect(play.reduceMotionOverlay(at: 11.2) == followStill)
        #expect(play.reduceMotionOverlay(at: 11.2).apertureMultiplier == 1)
        #expect(play.overlay(at: 11.2) != followStill)
        #expect(play.overlay(at: 11.2).apertureMultiplier < 1)
    }
}
