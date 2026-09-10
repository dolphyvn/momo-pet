import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The composite touch beats (TASK-028 R6; 04 §6.1, §2.4, §3.4)

/// The beats that span layers: the long-press whose press-length is INPUT,
/// the bond-gated slow blink-back, the stroke deepening on the second pass
/// of the same touch, the glance-up that lets a tap ride a running meal,
/// and the §2.4 pupil clamp on every touch's gaze.
struct MomoReactionCompositeTests {

    // MARK: Long-press — press-length is input (§6.1)

    /// While the finger is down the head melt develops and saturates (the
    /// ramp caps at 0.8 s); the release runs its beat and the run reports
    /// exactly once — for ANY hold length.
    @Test("The head melt develops with the hold and completes once on release")
    func longPressHoldSweep() {
        let state = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.longPressHead, at: 1.1),
        ])
        // Early in the hold the melt is shallow…
        let early = state.overlay(at: 1.4) // elapsed 0.3
        #expect(early.apertureMultiplier > 0.8)
        #expect(early.headRotationDegrees > 0 && early.headRotationDegrees < 2)
        // …saturated deep by 0.8 s, still holding at 3.0.
        let deep = state.overlay(at: 3.0) // elapsed 1.9 > the 0.8 s ramp
        #expect(deep.apertureMultiplier == 0.6) // 1 − 0.4 saturated
        #expect(deep.headRotationDegrees == 4)
        // The release opens its beat: the spring-back plus the blink.
        let released = ReactionFixtures.fold(
            [.touchEnded(at: 3.1)], into: state)
        let midRelease = released.overlay(at: 3.3)
        #expect(midRelease.headRotationDegrees < deep.headRotationDegrees)
        #expect(midRelease.apertureMultiplier < deep.apertureMultiplier)
        // Any hold length still completes exactly once.
        for hold in [0.1, 0.45, 0.8, 2.0, 5.0] {
            let run = ReactionFixtures.fold([
                .touchBegan(zone: .head, at: 1.0),
                ReactionFixtures.plan(ReactionKeys.longPressHead, at: 1.1),
                .touchEnded(at: 1.1 + hold),
                .displayState(ReactionFixtures.content, at: 1.1 + hold + 2.0),
            ])
            let finishes = ReactionFixtures.reports(
                matching: ReactionFixtures.finished(ReactionKeys.longPressHead),
                in: run)
            #expect(finishes.count == 1, "hold \(hold) lost its report")
        }
    }

    /// §3.4's slow-blink-back dial: the release blink renders at
    /// Best Friends and Soul Companions only — the canonical bond gate
    /// (`MomoExpressions.bondDials`), read through the slot's frozen
    /// context (the band must be set BEFORE the plan mints the slot).
    @Test("The release blink-back renders only at the two highest bond stages")
    func releaseBlinkBondGate() {
        func releaseAperture(bond: BondStage) -> Double {
            let state = ReactionFixtures.fold([
                .displayState(
                    ReactionFixtures.displayState(bond: bond), at: 0.5),
                .touchBegan(zone: .head, at: 1.0),
                ReactionFixtures.plan(ReactionKeys.longPressHead, at: 1.1),
                .touchEnded(at: 3.1),
            ])
            // The release's blink depth: 2.0 s held, + 0.2 into the
            // release beat (the blink's peak).
            return state.overlay(at: 3.3).apertureMultiplier
        }
        let soulmates = releaseAperture(bond: .soulCompanions)
        let bestFriends = releaseAperture(bond: .bestFriends)
        let gettingClose = releaseAperture(bond: .gettingClose)
        let fresh = releaseAperture(bond: .newFriends)
        // The blink deepens the closed eyes at the two unlocked stages…
        #expect(soulmates < 0.6)
        #expect(bestFriends < 0.6)
        // …and stays the plain spring-back below them.
        #expect(gettingClose == 0.6)
        #expect(fresh == 0.6)
    }

    /// MINOR-2: a press whose boundary is LOST (no `touchEnded` ever —
    /// a system-gesture cancellation) resolves as a release at the
    /// authored 5.0 s cap, then behaves exactly like a released press:
    /// the release beat runs, the run reports exactly once at its end,
    /// and GC reaps the slot.
    @Test("A lost press boundary resolves as a release at the authored 5 s cap")
    func pressLostBoundaryResolves() {
        let holding = ReactionFixtures.fold([
            .touchBegan(zone: .belly, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.longPressBelly, at: 1.1),
        ])
        // No boundary ever arrives: the press is still holding (end nil)
        // at the fold that stamps 5.0 s of hold and resolves the release
        // (end = start + 5.0 + the 0.45 release).
        #expect(holding.reactionSlots.count == 1)
        #expect(holding.reactionSlots[0].end == nil)
        let resolved = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 6.5)], into: holding)
        let slot = resolved.reactionSlots[0]
        #expect(abs(slot.holdSeconds! - 5.0) < 1e-9)
        #expect(abs(slot.end! - 6.55) < 1e-9)
        // The end is past this fold, so the run has not reported yet; the
        // next fold past 6.55 lands exactly one report AT the end instant
        // and GC reaps the slot.
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.longPressBelly),
            in: resolved).isEmpty)
        let done = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 7.5)], into: resolved)
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.longPressBelly),
            in: done)
        #expect(finishes.count == 1)
        #expect(abs(finishes[0].at - 6.55) < 1e-9)
        #expect(done.reactionSlots.isEmpty)
    }

    // MARK: Stroke deepening — the 2nd pass of the same touch (§6.1)

    @Test("A second stroke inside the same touch deepens; a new touch restarts")
    func strokeDeepening() {
        let deepened = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 1.1),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 1.7),
        ])
        // The 2nd arrival deepened the running pass instead of cutting it.
        let slots = deepened.reactionSlots.filter { $0.key == .strokeHead }
        #expect(slots.count == 1)
        #expect(slots.first?.deepened == true)
        #expect(slots.first?.supersededAt == nil)
        // The deepened read: fully closed eyes, softer ears (the deepened
        // depths are the authored 1.0 / −7.8 vs 0.85 / −6.0).
        let deepOverlay = deepened.overlay(at: 1.8)
        let normal = MomoReactionChoreography.motion(
            for: .strokeHead, elapsed: 0.7, duration: 1.2, holdSeconds: nil,
            deepened: false, context: MomoReactionContext(
                moodBand: .content, energyBand: .relaxed,
                bondStage: .bestFriends, wakefulness: .awake))
        #expect(deepOverlay.apertureMultiplier < normal.apertureMultiplier)
        #expect(deepOverlay.earLeftDegrees < normal.earLeftDegrees)

        // A stroke arriving AFTER the touch boundary is a new touch: the
        // running pass is cut, the new one runs UNdeepened.
        let freshTouch = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 1.1),
            .touchEnded(at: 1.4),
            .touchBegan(zone: .head, at: 2.0),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 2.1),
        ])
        let runs = freshTouch.reactionSlots.filter { $0.key == .strokeHead }
        #expect(runs.count == 2)
        #expect(runs.last?.deepened == false)
        #expect(runs.last?.supersededAt == nil)
    }

    // MARK: The glance-up — Rule 5's tap-during-meal beat

    @Test("A tap during the meal renders the glance-up; the meal continues")
    func glanceUpDuringMeal() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(activity: .eating), at: 0.5),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 2.0),
        ])
        // The meal still owns the state slot (it never interrupted)…
        guard case .clip(let meal) = state.stateLayer else {
            Issue.record("the meal was interrupted")
            return
        }
        #expect(meal.key == .eating)
        #expect(meal.supersededAt == nil)
        // …and the tap rendered as the glance-up beat on top.
        let glance = state.reactionSlots.filter { $0.glanceUp }
        #expect(glance.count == 1)
        #expect(glance.first?.key == .tapHead)
        #expect(glance.first?.start == 2.0)
        // The glance beats' horizon is the authored ~0.5 s.
        #expect(abs(glance.first!.end! - 2.5) < 1e-9)
        // Both layers read at the fold: at this instant the meal sits
        // between bites (identity), so the fold IS the glance beat —
        // eyes lifting to the touch (its authored shape: +10 % aperture,
        // a −2 unit head raise, the upward glance).
        let overlay = state.overlay(at: 2.2)
        #expect(overlay.pupilOffset == CGPoint(x: 0, y: -8))
        #expect(overlay.apertureMultiplier == 1.1)
        #expect(overlay.headTranslationY == -2)
    }

    /// MAJOR-2's other half: a NON-touch L3 during the meal renders ITSELF
    /// additively over the chewing — no glance-up substitution — and both
    /// runs complete (the polite sigh reports at its own end, the meal at
    /// its own).
    @Test("A non-touch L3 during the meal renders additively; the meal keeps chewing")
    func mealRidesNonTouchReactions() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(activity: .eating), at: 0.5),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.politelyFull, at: 2.0),
        ])
        // No glance-up substitution: the sigh is its own slot.
        #expect(!state.reactionSlots.isEmpty)
        #expect(state.reactionSlots.allSatisfy { !$0.glanceUp })
        guard case .clip(let meal) = state.stateLayer, meal.key == .eating else {
            Issue.record("the meal left the state slot")
            return
        }
        // The fold at the sigh's peak: the meal is mid-bite (its mouth
        // weight and food bob ride UNDER the sigh), the sigh's authored
        // channels render on top.
        let overlay = state.overlay(at: 2.5)
        #expect(abs(overlay.apertureMultiplier - 0.7) < 1e-9)
        #expect(abs((overlay.cheekOpacity ?? 0) - 0.88) < 1e-9)
        #expect((overlay.mouthWeights?.eat ?? 0) > 0.3)
        #expect(overlay.food != .rest)
        // Both runs complete exactly once, each at its own end.
        let done = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 6.0)], into: state)
        let sigh = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.politelyFull), in: done)
        #expect(sigh.count == 1)
        #expect(abs(sigh[0].at - 3.2) < 1e-9)
        let mealReport = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.eating), in: done)
        #expect(mealReport.count == 1)
        #expect(abs(mealReport[0].at - 4.2) < 1e-9)
    }

    /// MAJOR-2 + NOTE-7's window: the glance-up gates on the engine's
    /// ACTIVITY, not the meal clip — a tap after the meal clip completed
    /// but before the engine re-mints still renders the glance-up.
    @Test("The glance-up survives the meal clip's end while the activity says eating")
    func glanceUpLivesOnActivityNotClip() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(activity: .eating), at: 0.5),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.0),
            .displayState(
                ReactionFixtures.displayState(activity: .eating), at: 5.0),
        ])
        // The meal clip completed (4.2) and left the slot; nothing re-minted.
        #expect(state.stateLayer == nil)
        let tap = ReactionFixtures.fold(
            [ReactionFixtures.plan(ReactionKeys.tapHead, at: 5.5)], into: state)
        let glance = tap.reactionSlots.filter { $0.glanceUp }
        #expect(glance.count == 1)
        #expect(glance.first?.key == .tapHead)
        #expect(glance.first?.start == 5.5)
    }

    // MARK: MINOR-1 — the belly press's release meets its slot end

    /// The belly rock's release beat is the AUTHORED 0.45 (× tempo), and
    /// the rendered spring settle lands exactly at the slot end at EVERY
    /// tempo — no dead tail past the render, no report before it.
    @Test("The belly press release lands on the slot end at tempo 1 and drowsy")
    func bellyPressReleaseMeetsSlotEnd() {
        func releaseRun(energy: EnergyBand) -> MomoDirectorState {
            ReactionFixtures.fold([
                .displayState(ReactionFixtures.displayState(energy: energy), at: 0.5),
                .touchBegan(zone: .belly, at: 1.0),
                ReactionFixtures.plan(ReactionKeys.longPressBelly, at: 1.1),
                .touchEnded(at: 3.0),
            ])
        }
        // Tempo 1: hold 1.9 + the 0.45 release → the end is 3.45. The
        // hold's happy squint (0.65) is open again mid-release and the
        // rock has settled at the end (keep ≈ 0).
        let awake = releaseRun(energy: .relaxed)
        #expect(abs(awake.reactionSlots[0].end! - 3.45) < 1e-9)
        #expect(awake.overlay(at: 2.5).apertureMultiplier == 0.65)
        #expect(awake.overlay(at: 3.2).apertureMultiplier > 0.9)
        #expect(abs(awake.overlay(at: 3.45).bodyRotationDegrees) < 1e-3)
        // Drowsy ×1.4: the release is 0.63 → the end is 3.63, settled
        // there too (the time-warped spring preserves the settle).
        let drowsy = releaseRun(energy: .drowsy)
        #expect(abs(drowsy.reactionSlots[0].end! - 3.63) < 1e-9)
        #expect(drowsy.overlay(at: 2.5).apertureMultiplier == 0.65)
        #expect(drowsy.overlay(at: 3.2).apertureMultiplier > 0.9)
        #expect(abs(drowsy.overlay(at: 3.63).bodyRotationDegrees) < 1e-3)
        // Both report exactly once AT the slot end (no dead tail).
        for (run, end) in [(awake, 3.45), (drowsy, 3.63)] {
            let done = ReactionFixtures.fold(
                [.displayState(ReactionFixtures.content, at: end + 1.0)],
                into: run)
            let finishes = ReactionFixtures.reports(
                matching: ReactionFixtures.finished(ReactionKeys.longPressBelly),
                in: done)
            #expect(finishes.count == 1)
            #expect(abs(finishes[0].at - end) < 1e-9)
        }
    }

    /// NOTE-3's edge: a plan minted BETWEEN the end boundary and the next
    /// begin must not misread the fresh touch as the same one. The stroke
    /// at 8.06 starts a touch that ended at 8.05; the 8.07 `touchBegan`
    /// starts a NEW touch — the 8.1 stroke restarts UNdeepened.
    @Test("A begin boundary after the stroke mints resets the same-touch read")
    func strokeBetweenBoundariesIsFresh() {
        let state = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 7.8),
            .touchEnded(at: 8.05),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 8.06),
            .touchBegan(zone: .head, at: 8.07),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 8.1),
        ])
        let runs = state.reactionSlots.filter { $0.key == .strokeHead }
        #expect(runs.count == 2)
        #expect(runs.first?.supersededAt != nil)
        #expect(runs.last?.deepened == false)
        #expect(runs.last?.supersededAt == nil)
    }

    // MARK: The §2.4 pupil clamp on every touch gaze

    @Test("Every touch gaze clamps through the model to 30 % of the eye radius")
    func pupilClamp() {
        let bound = Double(MomoExpressions.eyeRadiusUnits) * 0.30
        // A request far beyond the bound…
        let request = MomoReactionMotion(pupilOffset: CGPoint(x: 200, y: 150))
        let pose = RigMotionModel().pose(
            at: 1.0, displayState: ReactionFixtures.content,
            reactionMotion: request)
        let x = Double(pose.eyeLeft.pupilOffset.x)
        let y = Double(pose.eyeLeft.pupilOffset.y)
        #expect(abs((x * x + y * y).squareRoot() - bound) < 1e-9)
        #expect(pose.eyeRight.pupilOffset == pose.eyeLeft.pupilOffset)
        // …and an in-bound request passes through untouched.
        let small = MomoReactionMotion(pupilOffset: CGPoint(x: 5, y: -3))
        let kept = RigMotionModel().pose(
            at: 1.0, displayState: ReactionFixtures.content,
            reactionMotion: small)
        #expect(kept.eyeLeft.pupilOffset == CGPoint(x: 5, y: -3))
    }
}
