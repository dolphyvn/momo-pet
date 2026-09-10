import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - Per-key end-pose law + the static pose set's distinguishability

/// R6 per key: under Reduce Motion every reaction run renders as its END
/// POSE — the choreography's own channel values AT the director-resolved
/// end — behind a 0.15 s crossfade, and the slot machinery (coalescer,
/// supersede, abbreviation, glance-up routing) runs unchanged. The
/// expected pose is computed by the test through the SAME choreography
/// dispatch (`motion(for:elapsed:...)` at the slot's resolved end), so a
/// drift between the RM transform and the choreography fails here.
///
/// R11/R12: the RM static pose set — the four mood-band poses, the energy
/// overlays, the asleep pose, and the reactions' end poses — stays
/// pairwise distinguishable over pose VALUES, with the ONE disclosed
/// collision (Content+Energetic == Content+Relaxed: Energetic's only
/// rendered deltas are its breath cycle and scheduler intervals, both
/// masked; full-motion divergence is pinned so the collision is RM-only).
/// Grayscale PNG evidence of these poses lives in
/// `docs/evidence/character/rm-*.png` (the render script discloses
/// exactly what it proves).
@Suite("Reduce Motion end poses — per-key R6, distinguishability R11/R12")
struct MomoReduceMotionEndPoseTests {

    private let model = RigMotionModel()

    /// The 17 L3 keys (settling/playReady route to the L2 handshakes and
    /// eating/sleepyNibbles to the L2 clips — their RM renderings are the
    /// §7.3 waking/settling and playing rows, pinned in the mapping suite).
    private static let l3Keys: [MomoReactionKey] = [
        .tapHead, .tapBelly, .tap, .doubleTap, .longPressHead,
        .longPressBelly, .longPress, .strokeHead, .strokeBelly, .stroke,
        .stir, .politelyFull, .gentleDecline, .nibble, .cheer, .decline,
        .blanketAdjust,
    ]
    private static let pressKeys: [MomoReactionKey] = [.longPressHead, .longPressBelly]

    /// The end pose of a one-shot slot, through the choreography itself.
    private func endPose(of slot: MomoReactionSlot) -> MomoReactionMotion {
        let spec = MomoReactionClips.spec(for: slot.key)
        let duration = spec.duration(tempo: slot.tempo)
            * (slot.abbreviated ? MomoDirectorState.abbreviationFraction : 1)
        return MomoReactionChoreography.motion(
            for: slot.key, elapsed: slot.end! - slot.start, duration: duration,
            holdSeconds: slot.holdSeconds, deepened: slot.deepened,
            context: slot.context)
    }

    /// The two poses agree on every channel within FP noise: the RM
    /// render re-derives elapsed through the slot's clock
    /// (`slot.start + key − slot.start`), so the cyclical rock's sine
    /// carries ~1e-15 ulp dust at its zero crossings.
    private func approxEqual(
        _ a: MomoReactionMotion, _ b: MomoReactionMotion
    ) -> Bool {
        abs(a.bodyScaleYMultiplier - b.bodyScaleYMultiplier) < 1e-9
            && abs(a.apertureMultiplier - b.apertureMultiplier) < 1e-9
            && abs(a.bodyRotationDegrees - b.bodyRotationDegrees) < 1e-9
            && abs(a.bodyTranslationX - b.bodyTranslationX) < 1e-9
            && abs(a.headRotationDegrees - b.headRotationDegrees) < 1e-9
            && abs(a.headTranslationY - b.headTranslationY) < 1e-9
            && abs(a.earLeftDegrees - b.earLeftDegrees) < 1e-9
            && abs(a.earRightDegrees - b.earRightDegrees) < 1e-9
            && abs(a.tailDegrees - b.tailDegrees) < 1e-9
            && abs(a.pupilOffset.x - b.pupilOffset.x) < 1e-9
            && abs(a.pupilOffset.y - b.pupilOffset.y) < 1e-9
            && a.mouthWeights == b.mouthWeights
            && a.cheekOpacity == b.cheekOpacity
            && a.food == b.food && a.blanket == b.blanket
            && a.sparkleA == b.sparkleA && a.sparkleB == b.sparkleB
    }

    // MARK: R6 — every one-shot key lands on its choreography's end pose

    @Test("R6 per key: the RM render at the resolved end IS the choreography's end pose")
    func oneShotKeysEndOnTheirChoreography() {
        for key in Self.l3Keys where !Self.pressKeys.contains(key) {
            let state = ReactionFixtures.fold([ReactionFixtures.plan(ReactionID(rawValue: key.rawValue), at: 1.0)])
            guard let slot = state.reactionSlots.first else {
                Issue.record("\(key) produced no slot")
                continue
            }
            guard let end = slot.end else {
                Issue.record("\(key) did not resolve its end")
                continue
            }
            #expect(slot.start == 1.0, "\(key) started off-plan")
            let expected = endPose(of: slot)
            #expect(
                state.reduceMotionOverlay(at: end - 0.001) == expected,
                "\(key) did not render its end pose")
            // The crossfade arrived: nothing of the entrance remains.
            #expect(
                state.reduceMotionOverlay(at: end - 0.001)
                    == state.reduceMotionOverlay(at: end - 0.01),
                "\(key) still moving inside its settled tail")
            // Non-vacuity: the full choreography is visibly different
            // somewhere in the run (the flag does real work per key).
            let diverges = samples(until: end, count: 60).contains { t in
                t >= slot.start
                    && state.reduceMotionOverlay(at: t) != state.overlay(at: t)
            }
            #expect(diverges, "\(key) renders identically under both flags")
        }
    }

    @Test("R6: the end poses split into a pinned identity/non-identity partition")
    func endPosePartition() {
        // The end pose is the choreography AT the resolved end — for most
        // one-shots the choreography has settled back to rest there (the
        // RM render is then a calm settle-back, nothing more — §7.3's row
        // taken literally); six keys end mid-decay or on a held accent
        // and keep their expression.
        var identityEnds: [MomoReactionKey] = []
        var expressedEnds: [MomoReactionKey] = []
        for key in Self.l3Keys where !Self.pressKeys.contains(key) {
            let state = ReactionFixtures.fold([ReactionFixtures.plan(ReactionID(rawValue: key.rawValue), at: 1.0)])
            let slot = state.reactionSlots.first!
            if endPose(of: slot) == .identity {
                identityEnds.append(key)
            } else {
                expressedEnds.append(key)
            }
        }
        #expect(Set(identityEnds) == [
            .tapBelly, .longPress, .strokeHead, .strokeBelly, .stroke,
            .stir, .gentleDecline, .nibble, .blanketAdjust,
        ])
        // The partition is STRUCTURAL (the end motion != .identity). Of the
        // six: tapHead/tap/doubleTap/cheer end on a visible accent (mid-decay
        // ear/tail/posture values); decline and politelyFull end at
        // EXPLICITLY NEUTRAL values — non-identity only because the
        // choreography still carries its mouth/cheek field at the end — so
        // their RENDERED ends match the band static. That is the
        // choreography's own authored decay (the full-motion render settles
        // to the same neutral by its end), not a transform choice; disclosed
        // in the R12 evidence digest.
        #expect(Set(expressedEnds) == [
            .tapHead, .tap, .doubleTap, .cheer, .decline, .politelyFull,
        ])
    }

    // MARK: R6 — press-shaped keys: hold keyframe, release crossfade

    @Test("R6 press: the hold keyframe stands while down; the release crossfades to the end pose")
    func pressHoldAndRelease() {
        // Head: touch 1.0, plan 1.2, release at 2.5 (hold 1.3 s past the
        // keyframe instant 0.8); end = 2.5 + 0.6 release = 3.1.
        let head = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.longPressHead, at: 1.2),
            .touchEnded(at: 2.5),
        ])
        guard let headSlot = head.reactionSlots.first,
            let headEnd = headSlot.end else {
            Issue.record("the head press produced no resolved slot")
            return
        }
        #expect(headSlot.holdSeconds == 1.3)
        #expect(headEnd == 3.1)
        let headSpec = MomoReactionClips.spec(for: .longPressHead)
        let headHold = MomoReactionChoreography.motion(
            for: .longPressHead, elapsed: 0.8,
            duration: headSpec.duration(tempo: headSlot.tempo),
            holdSeconds: headSlot.holdSeconds, deepened: headSlot.deepened,
            context: headSlot.context)
        // Past the keyframe + crossfade, before the release boundary: the
        // developed lean-in, held.
        for t in [2.2, 2.4, 2.49] {
            #expect(head.reduceMotionOverlay(at: t) == headHold,
                    "head hold pose diverged at t=\(t)")
        }
        // The end pose: the choreography at the resolved end.
        #expect(head.reduceMotionOverlay(at: headEnd - 0.001) == endPose(of: headSlot))

        // Belly: keyframe 0.45, release 0.45; touch 1.0, plan 1.2,
        // release 2.0 (hold 0.8); end = 2.45.
        let belly = ReactionFixtures.fold([
            .touchBegan(zone: .belly, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.longPressBelly, at: 1.2),
            .touchEnded(at: 2.0),
        ])
        guard let bellySlot = belly.reactionSlots.first,
            let bellyEnd = bellySlot.end else {
            Issue.record("the belly press produced no resolved slot")
            return
        }
        let bellySpec = MomoReactionClips.spec(for: .longPressBelly)
        let bellyHold = MomoReactionChoreography.motion(
            for: .longPressBelly, elapsed: 0.45,
            duration: bellySpec.duration(tempo: bellySlot.tempo),
            holdSeconds: bellySlot.holdSeconds, deepened: bellySlot.deepened,
            context: bellySlot.context)
        // Past the keyframe (0.45) + crossfade, before the release
        // boundary (2.45 − 0.45 = 2.0): the settled lean, held (the rock
        // sine's zero crossing carries ulp dust — approx).
        for t in [1.5, 1.8, 2.0] {
            #expect(approxEqual(belly.reduceMotionOverlay(at: t), bellyHold),
                    "belly hold pose diverged at t=\(t)")
        }
        #expect(belly.reduceMotionOverlay(at: bellyEnd - 0.001) == endPose(of: bellySlot))
    }

    @Test("R6 press: a short release crossfades from the pose the touch EARNED (no jump)")
    func shortPressIsContinuous() {
        // Released at 1.4 — hold 0.2 s, well short of the 0.8 keyframe.
        let short = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.longPressHead, at: 1.2),
            .touchEnded(at: 1.4),
        ])
        guard let slot = short.reactionSlots.first, let end = slot.end else {
            Issue.record("the short press produced no resolved slot")
            return
        }
        // The hold pose is the choreography AT the hold's end (0.2), not
        // the 0.8 saturation.
        let earned = MomoReactionChoreography.motion(
            for: .longPressHead, elapsed: 0.2,
            duration: MomoReactionClips.spec(for: .longPressHead)
                .duration(tempo: slot.tempo),
            holdSeconds: slot.holdSeconds, deepened: slot.deepened,
            context: slot.context)
        #expect(short.reduceMotionOverlay(at: 1.35) == earned)
        // Continuity across the release boundary (1.4): no pose jump.
        let before = short.reduceMotionOverlay(at: 1.399)
        let after = short.reduceMotionOverlay(at: 1.401)
        #expect(abs(before.apertureMultiplier - after.apertureMultiplier) < 0.02)
        #expect(abs(before.earLeftDegrees - after.earLeftDegrees) < 0.5)
        #expect(abs(before.headRotationDegrees - after.headRotationDegrees) < 0.5)
        #expect(before.pupilOffset ~= after.pupilOffset)
        // And the run still lands on the resolved end pose.
        #expect(short.reduceMotionOverlay(at: end - 0.001) == endPose(of: slot))
    }

    @Test("R6 press: the LOST boundary (no touchEnded) resolves the same end-pose law")
    func lostBoundaryPress() {
        // The press is abandoned: the director resolves the slot at
        // start + 5.0 + release. Fold INSIDE the resolution window
        // (6.2 ≤ fold < 6.65) so the resolved slot is still alive.
        let lost = ReactionFixtures.fold([
            .touchBegan(zone: .belly, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.longPressBelly, at: 1.2),
            .displayState(ReactionFixtures.content, at: 6.3),
        ])
        guard let slot = lost.reactionSlots.first, let end = slot.end else {
            Issue.record("the lost press never resolved")
            return
        }
        #expect(end == 1.2 + MomoDirectorState.pressLostBoundarySeconds + 0.45)
        let spec = MomoReactionClips.spec(for: .longPressBelly)
        let hold = MomoReactionChoreography.motion(
            for: .longPressBelly, elapsed: 0.45,
            duration: spec.duration(tempo: slot.tempo),
            holdSeconds: slot.holdSeconds, deepened: slot.deepened,
            context: slot.context)
        #expect(approxEqual(lost.reduceMotionOverlay(at: 3.0), hold))
        #expect(lost.reduceMotionOverlay(at: end - 0.001) == endPose(of: slot))
    }

    @Test("R6: the abbreviation machinery is unchanged — the third tap renders its shortened end")
    func abbreviatedThirdTap() {
        let taps = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 0.5),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.05),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.1),
        ])
        guard let third = taps.reactionSlots.first(where: { $0.abbreviated }) else {
            Issue.record("no abbreviated slot in the triple tap")
            return
        }
        guard let end = third.end else {
            Issue.record("the abbreviated slot never resolved")
            return
        }
        let spec = MomoReactionClips.spec(for: .tapHead)
        #expect(end == third.start + spec.duration(tempo: third.tempo)
            * MomoDirectorState.abbreviationFraction)
        let expected = MomoReactionChoreography.motion(
            for: .tapHead, elapsed: end - third.start,
            duration: spec.duration(tempo: third.tempo)
                * MomoDirectorState.abbreviationFraction,
            holdSeconds: third.holdSeconds, deepened: third.deepened,
            context: third.context)
        #expect(taps.reduceMotionOverlay(at: end - 0.001) == expected)
    }

    @Test("R6: the in-meal touch renders the glance-up plateau, held (Rule 5 under RM)")
    func glanceUpHeld() {
        let meal = ReactionFixtures.fold([
            .displayState(ReactionFixtures.displayState(activity: .eating), at: 0.5),
            .touchBegan(zone: .head, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.2),
        ])
        guard let slot = meal.reactionSlots.first else {
            Issue.record("the in-meal touch produced no glance-up slot")
            return
        }
        #expect(slot.glanceUp)
        let end = slot.end!
        #expect(end == slot.start + MomoDirectorState.glanceUpSeconds)
        // The plateau posture, held (the choreography's own authored
        // shape at its 0.2 s plateau — no new pose).
        let plateau = MomoReactionMotion(
            apertureMultiplier: 1.10,
            headTranslationY: -2,
            pupilOffset: CGPoint(x: 0, y: -8))
        #expect(meal.reduceMotionOverlay(at: end - 0.05) == plateau)
        // Non-vacuity: the full render sweeps through the glance.
        #expect(meal.overlay(at: end - 0.05) != plateau)
    }

    // MARK: R11/R12 — the static pose set stays distinguishable

    /// The RM static pose for a state (no schedule, no overlay — the
    /// quiescent band pose the idle row renders).
    private func staticPose(_ state: CharacterDisplayState) -> RigPose {
        model.pose(
            at: 3.0, displayState: state, schedule: [],
            reactionMotion: .identity, reduceMotion: true)
    }

    @Test("R11: the RM static pose set is pairwise distinct over pose values")
    func staticPosesArePairwiseDistinct() {
        let joyful = ReactionFixtures.displayState(mood: .joyful)
        let content = ReactionFixtures.displayState(mood: .content)
        let wistful = ReactionFixtures.displayState(mood: .wistful)
        let low = ReactionFixtures.displayState(mood: .low)
        let energetic = ReactionFixtures.displayState(energy: .energetic)
        let drowsy = ReactionFixtures.displayState(energy: .drowsy)
        let exhausted = ReactionFixtures.displayState(energy: .exhausted)
        let asleep = ReactionFixtures.displayState(wakefulness: .asleep)
        let poses: [(String, RigPose)] = [
            ("joyful", staticPose(joyful)),
            ("content", staticPose(content)),
            ("wistful", staticPose(wistful)),
            ("low", staticPose(low)),
            ("energetic", staticPose(energetic)),
            ("drowsy", staticPose(drowsy)),
            ("exhausted", staticPose(exhausted)),
            ("asleep", staticPose(asleep)),
        ]
        // Every pose reads on the R12 numeric channels: lids, ears,
        // posture, pupils, lower lid. All pairs distinct, EXCEPT the one
        // disclosed collision (checked separately below).
        for (i, a) in poses.enumerated() {
            for b in poses[(i + 1)...] {
                let collides = a.0 == "content" && b.0 == "energetic"
                if collides { continue }
                #expect(a.1 != b.1, "the RM statics of \(a.0) and \(b.0) collide")
            }
        }
        // The disclosed collision: Content+Energetic renders EXACTLY the
        // Content+Relaxed static. Energetic's only expression-layer
        // deltas are the breath cycle (×0.96) and the scheduler
        // intervals — both masked under RM — so its static IS the
        // Relaxed static of the same mood. This is an expression-design
        // gap, not a transform bug; routed to the owner (expression
        // design is owner-domain; a future Energetic static accent fixes
        // it without touching TASK-029's transform).
        #expect(poses[1].1 == poses[4].1, "the disclosed collision moved")
        // …and the collision is RM-ONLY: with motion on, the two states
        // render differently (the breath cycle is visible).
        let scheduleE = MomoIdleSequencer.schedule(
            idleSeed: 5, displayState: energetic, windowEnd: 30)
        let scheduleR = MomoIdleSequencer.schedule(
            idleSeed: 5, displayState: content, windowEnd: 30)
        let fullMoveDiffer = samples(until: 30, count: 60).contains { t in
            model.pose(
                at: t, displayState: energetic, schedule: scheduleE,
                reactionMotion: .identity)
                != model.pose(
                    at: t, displayState: content, schedule: scheduleR,
                    reactionMotion: .identity)
        }
        #expect(fullMoveDiffer, "Energetic never diverged even with motion on")
    }

    @Test("R11: the reactions' expressed end poses are pairwise distinct")
    func endPosesArePairwiseDistinct() {
        // The five one-shot keys whose end motion is a visible accent plus
        // decline (whose end motion is distinct as a MOTION — its explicit
        // neutral mouth-reset — while its rendered end matches the band
        // static; see the partition note above).
        let keys: [MomoReactionKey] = [.tapHead, .tap, .doubleTap, .cheer, .decline]
        var poses: [MomoReactionMotion] = []
        for key in keys {
            let state = ReactionFixtures.fold([ReactionFixtures.plan(ReactionID(rawValue: key.rawValue), at: 1.0)])
            let slot = state.reactionSlots.first!
            poses.append(endPose(of: slot))
        }
        for (i, a) in poses.enumerated() {
            for b in poses[(i + 1)...] {
                #expect(a != b, "two expressed end poses collide")
            }
        }
    }
}
