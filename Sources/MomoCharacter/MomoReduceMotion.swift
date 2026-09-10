import CoreGraphics
import MomoCore

// MARK: - Reduce Motion (04 §7.3; TASK-029)

/// The §7.3 Reduce Motion mapping, executable: constants with their doc
/// authority, the authored key instants, and the pure overlay transform.
///
/// THE RENDER-ONLY LAW: Reduce Motion changes how a run MOVES, never which
/// run renders and never what the ENGINE observes. The director fold, the
/// clock, the coherence matrix (§4.1), the slot machinery (coalescer,
/// queue, supersede, hide epochs, exactly-once reports) and the report
/// stream are byte-identical under both flag values (`overlay(at:)` and
/// `reduceMotionOverlay(at:)` read the SAME state; the fold never sees the
/// flag). The row mapping:
///
/// | §7.3 row            | realization                                              |
/// |---------------------|----------------------------------------------------------|
/// | Idle loop           | pose seam: idle events masked, breath sine off (R2)      |
/// | Blink               | pose seam: the band's natural aperture stands (R3)       |
/// | Look-around         | L1 press feedback IS the static touch glance (R4)        |
/// | State changes       | pose seam static↔static crossfade, 0.15 s (R5)           |
/// | Touch reactions     | end-pose swap, 0.15 s crossfade, then hold (R6)          |
/// | Celebrations        | settled/key-instant moment pose, held (R7)               |
/// | Waking/settling     | the handshake's end-state pose, static (R8)              |
/// | Playing             | milestone stills, 0.15 s swaps between them (R9)         |
///
/// Authored choices carry their authority inline and are disclosed in the
/// task file's Implementation Notes.
public enum MomoReduceMotion {

    /// The touch-reaction crossfade — EXACT digit ("04 §7.3 touch
    /// reactions row": end-pose swap with a 150 ms crossfade).
    public static let reactionCrossfadeSeconds: Double = 0.15

    /// The state-change crossfade — AUTHORED at the floor of "04 §7.3
    /// state changes row"'s 0.15–0.20 s band (calm by default; the same
    /// digit paces the play milestone swaps, R9's disclosed choice).
    public static let stateCrossfadeSeconds: Double = 0.15

    /// The invite still's key instant (AUTHORED): inside the perk
    /// plateau's hold (`inviteMotion`'s bump is attack 0.5 / release 0.7
    /// over the 2.4 s invite, so 1 on [0.5, 1.7]) and at the wag sine's
    /// crest (`sin(2π·1.5/1.2) = 1`) — the play-ready pose, held.
    /// "04 §7.3 playing row" (mapping authored + disclosed).
    public static let playInviteKeyInstant: Double = 1.5

    /// The glance-up still's key instant (AUTHORED): the eating
    /// glance-up's plateau (`glanceUpMotion`'s bump is 1 on [0.12, 0.3))
    /// — the "eyes find the touch" posture, held (04 §4.1 rule 5 with
    /// §7.3's look-around row for the in-meal reading).
    public static let glanceUpPlateauInstant: Double = 0.2

    /// The head-melt hold keyframe's instant (AUTHORED): the choreography
    /// own ramp saturates at 0.8 s — the developed lean-in, held while
    /// the finger is down ("the hold keyframe", §7.3 touch reactions row).
    public static let pressHoldKeyInstantHead: Double = 0.8

    /// The belly-rock hold keyframe's instant (AUTHORED): its ramp
    /// saturates at 0.45 s (and the 0.9 s rock's sine crosses zero
    /// there at tempo 1 — the settled lean, no mid-rock frame).
    public static let pressHoldKeyInstantBelly: Double = 0.45

    /// A greeting's RM key instant (AUTHORED per kind — the settled
    /// post-overshoot pose of three of the four greetings is `.identity`
    /// (their envelopes close), which would render NOTHING for the
    /// moment and violate §7.3's closing law. Each kind renders its
    /// existing choreography AT its expressive instant instead, held
    /// statically; deviations disclosed in the task file):
    /// - freshMorning 0.88 — mid-plateau (the plateau runs [0.25, 1.15))
    ///   with the bright open ≈ 98 % complete;
    /// - welcomeBack 0.2 — the first wag crest (`sin(2π·0.2/0.8) = 1`);
    /// - missedYou 0.875 — the perk plateau at the second wag crest
    ///   (`sin(2π·0.875/0.7) = 1`);
    /// - nightGlance 0.7 — the soft close's hold (aperture ×0.65, ears
    ///   perked).
    public static func greetingKeyInstant(for kind: GreetingKind) -> Double {
        switch kind {
        case .freshMorning: 0.88
        case .welcomeBack: 0.2
        case .missedYou: 0.875
        case .nightGlance: 0.7
        }
    }
}

// MARK: - The injected state-change transition (R5's crossfade endpoints)

/// One pending state-change crossfade's endpoints: the state the pose
/// fades FROM and the instant the change arrived. Pure values, injected
/// into the pose seam — never ambient state.
public struct MomoReduceMotionTransition: Equatable, Sendable {

    /// The display state the crossfade departs from.
    public let fromState: CharacterDisplayState

    /// The instant the change arrived (character-timeline seconds).
    public let since: Double

    public init(fromState: CharacterDisplayState, since: Double) {
        self.fromState = fromState
        self.since = since
    }
}

/// The pure tracker that produces R5's transitions: a fold of the SAME
/// `.displayState` event stream the director consumes (the session folds
/// both from the one event list; the tracker never reads the director and
/// vice versa). Two state changes inside one crossfade window overwrite
/// the pending transition — the blend then departs from the intermediate
/// state (deterministic; disclosed).
public struct MomoReduceMotionStateTracker: Sendable {

    public private(set) var state: CharacterDisplayState
    private var pending: MomoReduceMotionTransition?

    public init(initial: CharacterDisplayState) {
        self.state = initial
        self.pending = nil
    }

    /// The event fold: a display-state CHANGE opens one crossfade window.
    public mutating func fold(_ event: MomoCharacterEvent) {
        guard case .displayState(let newState, let at) = event,
            newState != state
        else { return }
        pending = MomoReduceMotionTransition(fromState: state, since: at)
        state = newState
    }

    /// The transition still inside its 0.15 s window at `t` (nil after —
    /// the crossfade has landed on the new static pose).
    public func transition(at t: Double) -> MomoReduceMotionTransition? {
        guard let pending, t >= pending.since,
            t < pending.since + MomoReduceMotion.stateCrossfadeSeconds
        else { return nil }
        return pending
    }
}

// MARK: - Motion lerp (the static↔static crossfade primitive)

public extension MomoReactionMotion {

    /// This motion lerped toward `other` by `amount` (0 = self, 1 =
    /// other): multipliers/deltas/pupils lerp coordinate-wise, accents
    /// lerp with a nil pole collapsing only at the endpoints (matching
    /// `faded`'s inverse), props lerp toward each other through `.rest`.
    /// Amounts outside 0…1 clamp; 0 and 1 return the exact endpoint.
    /// TASK-029's use is static↔static: the press release crossfade and
    /// the play milestone swaps.
    func lerped(to other: MomoReactionMotion, amount: Double) -> MomoReactionMotion {
        let p = min(max(amount, 0), 1)
        guard p > 0 else { return self }
        guard p < 1 else { return other }
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * p }
        return MomoReactionMotion(
            bodyScaleYMultiplier: lerp(
                bodyScaleYMultiplier, other.bodyScaleYMultiplier),
            apertureMultiplier: lerp(apertureMultiplier, other.apertureMultiplier),
            bodyRotationDegrees: lerp(bodyRotationDegrees, other.bodyRotationDegrees),
            bodyTranslationX: lerp(bodyTranslationX, other.bodyTranslationX),
            headRotationDegrees: lerp(headRotationDegrees, other.headRotationDegrees),
            headTranslationY: lerp(headTranslationY, other.headTranslationY),
            earLeftDegrees: lerp(earLeftDegrees, other.earLeftDegrees),
            earRightDegrees: lerp(earRightDegrees, other.earRightDegrees),
            tailDegrees: lerp(tailDegrees, other.tailDegrees),
            pupilOffset: CGPoint(
                x: lerp(pupilOffset.x, other.pupilOffset.x),
                y: lerp(pupilOffset.y, other.pupilOffset.y)),
            mouthWeights: MomoReduceMotionShims.lerped(
                mouthWeights, other.mouthWeights, amount: p),
            cheekOpacity: MomoReduceMotionShims.lerped(
                cheekOpacity, other.cheekOpacity, amount: p),
            food: food.lerped(to: other.food, amount: p),
            blanket: blanket.lerped(to: other.blanket, amount: p),
            sparkleA: sparkleA.lerped(to: other.sparkleA, amount: p),
            sparkleB: sparkleB.lerped(to: other.sparkleB, amount: p))
    }
}

public extension RigPropPose {

    /// This prop pose lerped toward `other` by `amount` (0 = self, 1 =
    /// other): transform channels and opacity lerp coordinate-wise.
    func lerped(to other: RigPropPose, amount: Double) -> RigPropPose {
        let p = min(max(amount, 0), 1)
        guard p > 0 else { return self }
        guard p < 1 else { return other }
        return RigPropPose(
            transform: RigGridTransform(
                scaleX: transform.scaleX
                    + (other.transform.scaleX - transform.scaleX) * CGFloat(p),
                scaleY: transform.scaleY
                    + (other.transform.scaleY - transform.scaleY) * CGFloat(p),
                rotationDegrees: transform.rotationDegrees
                    + (other.transform.rotationDegrees - transform.rotationDegrees) * p,
                translation: CGPoint(
                    x: transform.translation.x
                        + (other.transform.translation.x - transform.translation.x) * CGFloat(p),
                    y: transform.translation.y
                        + (other.transform.translation.y - transform.translation.y) * CGFloat(p))),
            opacity: opacity + (other.opacity - opacity) * p)
    }
}

/// Accent-slot lerp shims (file-scoped): a nil accent participates as its
/// neutral and the nil survives only at the endpoint that owns it — the
/// exact inverse of `faded`'s accent arithmetic.
enum MomoReduceMotionShims {

    static func lerped(
        _ from: RigMouthWeights?, _ to: RigMouthWeights?, amount p: Double
    ) -> RigMouthWeights? {
        switch (from, to) {
        case (nil, nil): return nil
        case (let a?, nil): return p < 1 ? lerped(a, .neutral, p) : nil
        case (nil, let b?): return p > 0 ? lerped(.neutral, b, p) : nil
        case (let a?, let b?): return lerped(a, b, p)
        }
    }

    private static func lerped(
        _ a: RigMouthWeights, _ b: RigMouthWeights, _ p: Double
    ) -> RigMouthWeights {
        RigMouthWeights(
            neutral: a.neutral + (b.neutral - a.neutral) * p,
            eat: a.eat + (b.eat - a.eat) * p,
            refuse: a.refuse + (b.refuse - a.refuse) * p)
    }

    static func lerped(
        _ from: Double?, _ to: Double?, amount p: Double
    ) -> Double? {
        switch (from, to) {
        case (nil, nil): return nil
        case (let a?, nil): return p < 1 ? a + (1 - a) * p : nil
        case (nil, let b?): return p > 0 ? 1 + (b - 1) * p : nil
        case (let a?, let b?): return a + (b - a) * p
        }
    }
}

// MARK: - The pose crossfade (R5's static↔static blend)

public extension RigPose {

    /// This pose lerped toward `other` by `amount` (0 = self, 1 = other).
    /// Every continuous channel lerps coordinate-wise; the ONE discrete
    /// channel (`lowerLid`) steps at the midpoint. TASK-029's use is the
    /// §7.3 state-changes row: the previous static pose crossfades to the
    /// new static pose — posture never animates through intermediate
    /// motion, the endpoints are statics and the blend is the crossfade.
    func blend(_ other: RigPose, amount: Double) -> RigPose {
        let p = min(max(amount, 0), 1)
        guard p > 0 else { return self }
        guard p < 1 else { return other }
        func lerp(_ a: Double, _ b: Double) -> Double { a + (b - a) * p }
        func lerp(_ a: CGFloat, _ b: CGFloat) -> CGFloat { a + (b - a) * p }
        func lerpPoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: a.x + (b.x - a.x) * p, y: a.y + (b.y - a.y) * p)
        }
        func lerpTransform(_ a: RigGridTransform, _ b: RigGridTransform) -> RigGridTransform {
            RigGridTransform(
                scaleX: lerp(a.scaleX, b.scaleX),
                scaleY: lerp(a.scaleY, b.scaleY),
                rotationDegrees: lerp(a.rotationDegrees, b.rotationDegrees),
                translation: lerpPoint(a.translation, b.translation))
        }
        func lerpAppendage(_ a: RigRotationScale, _ b: RigRotationScale) -> RigRotationScale {
            RigRotationScale(
                rotationDegrees: lerp(a.rotationDegrees, b.rotationDegrees),
                scaleY: lerp(a.scaleY, b.scaleY))
        }
        func lerpEye(_ a: RigEyePose, _ b: RigEyePose) -> RigEyePose {
            RigEyePose(
                lidScaleY: lerp(a.lidScaleY, b.lidScaleY),
                pupilOffset: lerpPoint(a.pupilOffset, b.pupilOffset),
                lowerLid: p < 0.5 ? a.lowerLid : b.lowerLid)
        }
        return RigPose(
            body: lerpTransform(body, other.body),
            head: lerpTransform(head, other.head),
            earLeft: lerpAppendage(earLeft, other.earLeft),
            earRight: lerpAppendage(earRight, other.earRight),
            tail: lerpAppendage(tail, other.tail),
            eyeLeft: lerpEye(eyeLeft, other.eyeLeft),
            eyeRight: lerpEye(eyeRight, other.eyeRight),
            mouth: RigMouthWeights(
                neutral: lerp(mouth.neutral, other.mouth.neutral),
                eat: lerp(mouth.eat, other.mouth.eat),
                refuse: lerp(mouth.refuse, other.mouth.refuse)),
            cheekOpacity: lerp(cheekOpacity, other.cheekOpacity),
            pawLeft: lerpTransform(pawLeft, other.pawLeft),
            pawRight: lerpTransform(pawRight, other.pawRight),
            food: food.lerped(to: other.food, amount: p),
            blanket: blanket.lerped(to: other.blanket, amount: p),
            sparkleA: sparkleA.lerped(to: other.sparkleA, amount: p),
            sparkleB: sparkleB.lerped(to: other.sparkleB, amount: p))
    }
}

// MARK: - The RM overlay transform (the same state, rendered still)

extension MomoDirectorState {

    /// The §7.3 projection: the SAME director state `overlay(at:)` reads,
    /// with every rendered run transformed to its static reading. Layer
    /// structure and visibility are IDENTICAL to `overlay(at:)` (§4.1
    /// governs WHAT renders under RM too); only the layer motions differ.
    public func reduceMotionOverlay(at t: Double) -> MomoReactionMotion {
        var layers: [MomoReactionMotion] = []

        // L1 press feedback: already a static glance posture (ears +2°,
        // pupils up) — the §7.3 look-around row's touch glance. Its
        // micro-eases (0.08 s in, the 0.1 s Rule-1 fade) stay: they are
        // the coherence envelope, not sustained motion.
        if let press {
            layers.append(pressMotion(press, at: t))
        }
        // The outgoing L2's crossfade half — the envelope runs at the
        // state digit (0.15) instead of the fold's 0.35; the fold's own
        // timing is untouched (it paces the reports, never the render).
        if let fading = stateFading {
            let fraction = MomoCurves.smoothstep(
                (t - stateFadingStart) / MomoReduceMotion.stateCrossfadeSeconds)
            layers.append(reduceMotionStateMotion(fading, at: t).faded(fraction))
        }
        // The incoming L2: the static end-state pose entering over 0.15.
        if let layer = stateLayer {
            let entered = stateEnterSeconds > 0
                ? MomoCurves.smoothstep(
                    (t - stateEnterStart) / MomoReduceMotion.stateCrossfadeSeconds)
                : 1
            layers.append(reduceMotionStateMotion(layer, at: t).faded(1 - entered))
        }
        // The L3 slots: end-pose swaps (below), supersede fades unchanged.
        for slot in reactionSlots where isVisible(slot, at: t) {
            let motion = reduceMotionSlotMotion(slot, at: t)
            guard let superseded = slot.supersededAt else {
                layers.append(motion)
                continue
            }
            let fraction = (t - superseded) / slot.fadeOutSeconds
            layers.append(motion.faded(fraction))
        }
        // L4: the moment's static pose, held.
        if let moment,
            t >= moment.start,
            t < moment.start + MomoMoments.duration(for: moment.moment) {
            layers.append(reduceMotionMomentMotion(moment))
        }
        return MomoReactionMotion.fold(layers)
    }

    // MARK: L2 statics

    /// The state layer's static reading: each handshake renders its END
    /// state's pose; an L2 state-beat clip renders like any slot.
    private func reduceMotionStateMotion(
        _ layer: MomoStateInstance, at t: Double
    ) -> MomoReactionMotion {
        switch layer {
        case .clip(let slot):
            return reduceMotionSlotMotion(slot, at: t)
        case .settle:
            // The sleeping end pose: the lie-down sink and the settled
            // blanket, no yawn/lie-down choreography visible (§7.3
            // waking/settling row). The fold still runs the full 3.0 s —
            // `settleFinished` lands unchanged.
            return MomoHandshakeChoreography.settleMotion(
                elapsed: MomoHandshakeChoreography.settleDurationSeconds)
        case .wake:
            // The waking end pose: the handshake's motion at its end is
            // the identity (stretch/ear-perk bump closed, aperture
            // settled at 1.0) — the AWAKE band's static pose renders, so
            // the state change stays legible (R11).
            return MomoHandshakeChoreography.wakeMotion(
                elapsed: MomoHandshakeChoreography.wakeDurationSeconds)
        case .play(let play):
            return reduceMotionPlayMotion(play, at: t)
        }
    }

    /// The play round's milestone stills (§7.3 playing row): invite ≈
    /// start, follow ≈ mid, payoff ≈ end; the round's fold and reports
    /// are untouched (FR-7 AC-1/2). Phase swaps crossfade over the state
    /// digit (R9's disclosed choice). The Drowsy wind-down yawn is
    /// SUPPRESSED — it is animation; the follow still reads the
    /// fingertip's last offset statically.
    private func reduceMotionPlayMotion(
        _ play: MomoPlayInstance, at t: Double
    ) -> MomoReactionMotion {
        let inviteStill = MomoHandshakeChoreography.inviteMotion(
            elapsed: MomoReduceMotion.playInviteKeyInstant)
        let followStill = MomoHandshakeChoreography.followMotion(
            fingertipOffset: play.lastOffset)
        if t < play.followStart {
            return inviteStill
        }
        if let cease = play.followCease, t >= cease,
            t < play.payoffEnd ?? .infinity {
            let payoffStill = MomoHandshakeChoreography.payoffMotion(
                elapsed: MomoHandshakeChoreography.payoffSeconds, yawn: false)
            let s = MomoCurves.smoothstep(
                (t - cease) / MomoReduceMotion.stateCrossfadeSeconds)
            return followStill.lerped(to: payoffStill, amount: s)
        }
        let s = MomoCurves.smoothstep(
            (t - play.followStart) / MomoReduceMotion.stateCrossfadeSeconds)
        return inviteStill.lerped(to: followStill, amount: s)
    }

    // MARK: L3 end-pose swaps

    /// One slot's RM render: crossfade to the run's END POSE over the
    /// reaction digit, then hold it until the slot resolves; the normal
    /// exit (end/supersede/hide) applies untouched.
    private func reduceMotionSlotMotion(
        _ slot: MomoReactionSlot, at t: Double
    ) -> MomoReactionMotion {
        if slot.glanceUp {
            // Rule 5's glance-up: its plateau posture, held.
            return glanceUpMotion(at: MomoReduceMotion.glanceUpPlateauInstant)
                .faded(1 - entranceFraction(slot, at: t))
        }
        let spec = MomoReactionClips.spec(for: slot.key)
        if spec.pressShaped {
            return reduceMotionPressSlotMotion(slot, spec: spec, at: t)
        }
        // The end pose is the CHOREOGRAPHY evaluated AT the resolved end
        // (director-owned instant — cycle boundary for strokes, duration
        // for one-shots, resolved hold+release for presses): the run's
        // meaning carries in the pose the full motion ends on.
        let endPose = slot.end.map { reactionMotion(slot, at: $0) }
            ?? reactionMotion(
                slot, at: slot.start + spec.duration(tempo: slot.tempo))
        return endPose.faded(1 - entranceFraction(slot, at: t))
    }

    /// Press-shaped runs: the hold keyframe while the finger is down;
    /// on resolution, a crossfade from the hold pose to the release end
    /// pose across the release boundary (the slot's own resolved end
    /// minus its release beat — every tempo). A press released BEFORE the
    /// keyframe never renders the saturation pose it didn't reach: its
    /// hold pose is the choreography at the touch's own end.
    private func reduceMotionPressSlotMotion(
        _ slot: MomoReactionSlot, spec: MomoReactionClipSpec, at t: Double
    ) -> MomoReactionMotion {
        let entered = entranceFraction(slot, at: t)
        guard let end = slot.end else {
            // Still holding: the ramp saturates at the keyframe.
            let holdPose = reactionMotion(
                slot, at: slot.start + holdKeyInstant(slot.key))
            return .identity.lerped(to: holdPose, amount: entered)
        }
        let hold = slot.holdSeconds ?? (end - slot.start)
        let holdElapsed = min(holdKeyInstant(slot.key), hold)
        let holdPose = reactionMotion(slot, at: slot.start + holdElapsed)
        let releaseSeconds = (spec.pressReleaseSeconds ?? spec.baselineSeconds)
            * (spec.tempoScaled ? slot.tempo : 1)
        let boundary = end - releaseSeconds
        let endPose = reactionMotion(slot, at: end)
        let released = MomoCurves.smoothstep(
            (t - boundary) / MomoReduceMotion.reactionCrossfadeSeconds)
        return .identity
            .lerped(to: holdPose, amount: entered)
            .lerped(to: endPose, amount: released)
    }

    /// The press-down hold keyframe's instant per key — the
    /// choreography's own ramp saturations (no new poses). Exhaustive
    /// with no `default` (a future key fails the build).
    private func holdKeyInstant(_ key: MomoReactionKey) -> Double {
        switch key {
        case .longPressHead: MomoReduceMotion.pressHoldKeyInstantHead
        case .longPressBelly: MomoReduceMotion.pressHoldKeyInstantBelly
        case .tapHead, .tapBelly, .tap, .doubleTap, .longPress,
            .strokeHead, .strokeBelly, .stroke, .stir, .politelyFull,
            .gentleDecline, .sleepyNibbles, .settling, .blanketAdjust,
            .eating, .nibble, .playReady, .cheer, .decline:
            0
        }
    }

    /// The slot's 0.15 entrance (1 = fully arrived).
    private func entranceFraction(
        _ slot: MomoReactionSlot, at t: Double
    ) -> Double {
        MomoCurves.smoothstep(
            (t - slot.start) / MomoReduceMotion.reactionCrossfadeSeconds)
    }

    // MARK: L4 statics

    /// The moment's static pose: the settled post-overshoot pose for the
    /// sparkle and the celebration (the default — both are non-identity
    /// settled), and each greeting's authored key-instant pose (the
    /// disclosed deviation — see `MomoReduceMotion.greetingKeyInstant`).
    /// The pose appears with the moment and holds for its duration; the
    /// fold's duration (and the moment report) is untouched.
    private func reduceMotionMomentMotion(
        _ moment: MomoMomentInstance
    ) -> MomoReactionMotion {
        switch moment.moment {
        case .greeting(let kind):
            return MomoMoments.motion(
                for: moment.moment,
                elapsed: MomoReduceMotion.greetingKeyInstant(for: kind))
        case .questCompleted, .bondStageReached:
            return MomoMoments.motion(
                for: moment.moment,
                elapsed: MomoMoments.duration(for: moment.moment))
        }
    }
}
