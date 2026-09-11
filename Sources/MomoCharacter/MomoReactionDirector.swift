import Foundation
import MomoCore

// MARK: - The director state + fold

/// The pure coherence director (04 §4.1's L0–L4 matrix, executable;
/// TASK-028 R3/R4). Fold events in order; read `overlay(at:)` per frame;
/// drain `reports` for the engine. All §4.1 timing rules are named
/// constants below with their authority; the structural invariants (the
/// priority table holds for ANY stream) are checked by the property tests
/// through `pendingReactionCount(after:)` and the singular-occupant
/// shape of this state.
public struct MomoDirectorState: Equatable, Sendable {

    // MARK: §4.1 coherence constants (each cites its rule)

    /// Rule 1: L1 (press micro-feedback) fades ≤ 100 ms on reaction arrival.
    public static let l1FadeSeconds: Double = 0.1
    /// Rule 2: L2 replaces L2 through the §7.1 state-crossfade band's
    /// midpoint (300–400 ms).
    public static let l2CrossfadeSeconds: Double = 0.35
    /// Rule 2: L2 preempts L3 with a fade ≤ 120 ms.
    public static let l3PreemptFadeSeconds: Double = 0.12
    /// Rule 3: identical L3s inside this window coalesce.
    public static let coalesceWindowSeconds: Double = 0.5
    /// Rule 3's abbreviated class: 3–4 arrivals run half duration.
    public static let abbreviationFraction: Double = 0.5
    /// Rule 3's coalesced response: one gentle 0.4–0.5 s beat per window.
    public static let coalescedSeconds: Double = 0.45
    /// Rule 5: the tap-during-meal glance-up (AUTHORED ~0.5 s).
    public static let glanceUpSeconds: Double = 0.5
    /// The L3 pending queue bound (drop-oldest past two).
    public static let reactionQueueBound = 2
    /// Cyclical strokes cap at this many cycles (a lost touch boundary —
    /// the zone-less Watch surface cannot send touchEnded — must not run
    /// forever).
    static let strokeCycleCap = 4
    /// Press-shaped rows' lost-boundary cap (the strokeCycleCap analog,
    /// AUTHORED 5.0): an unresolved press — no `touchEnded` ever, e.g. a
    /// system-gesture cancellation — resolves as a release at
    /// `start + 5.0`. §6.1 keeps press-length INPUT for real boundaries,
    /// but a lost boundary must not hold the pose forever (MINOR-2): the
    /// release beat runs, the run reports exactly once, GC reaps it.
    static let pressLostBoundarySeconds: Double = 5.0

    // MARK: State

    public private(set) var displayState: CharacterDisplayState
    var stateLayer: MomoStateInstance?
    var stateFading: MomoStateInstance?
    var stateFadingStart: Double
    var stateEnterStart: Double
    var stateEnterSeconds: Double
    var reactionSlots: [MomoReactionSlot]
    var press: MomoPressState?
    var lastTouchEnded: Double?
    var lastTouchBegan: Double?
    var coalescer: MomoCoalescer?
    var moment: MomoMomentInstance?
    var pendingMomentRequest: CharacterMoment?
    var deferredMoment: CharacterMoment?
    public private(set) var reports: [MomoReportEntry]
    var hidden: Bool

    /// Initial state for a presentation session.
    public init(displayState: CharacterDisplayState) {
        self.displayState = displayState
        self.stateLayer = nil
        self.stateFading = nil
        self.stateFadingStart = 0
        self.stateEnterStart = 0
        self.stateEnterSeconds = 0
        self.reactionSlots = []
        self.press = nil
        self.lastTouchEnded = nil
        self.lastTouchBegan = nil
        self.coalescer = nil
        self.moment = nil
        self.pendingMomentRequest = nil
        self.deferredMoment = nil
        self.reports = []
        self.hidden = false
    }

    // MARK: The fold

    public mutating func apply(_ event: MomoCharacterEvent) {
        switch event {
        case .plan(let plan, let at):
            applyPlan(plan, at: at)
        case .displayState(let state, let at):
            applyDisplayState(state, at: at)
        case .touchBegan(let zone, let at):
            lastTouchBegan = at
            press = MomoPressState(zone: zone, start: at, fadingSince: nil)
        case .touchEnded(let at):
            applyTouchEnded(at: at)
        case .fingertip(let offset, let moving, let at):
            applyFingertip(offset: offset, moving: moving, at: at)
        case .appHidden(let at):
            applyHidden(at: at)
        case .appShown(let at):
            applyShown(at: at)
        case .playStopped(let at):
            applyPlayStopped(at: at)
        }
        pruneCompleteLayers(around: eventTime(of: event))
    }

    /// TASK-035 R1: the app model's exactly-once report drain. The log is
    /// append-only (each emission site is guarded by its instance's
    /// `reported` flag), so draining hands the caller the entries AND clears
    /// them — a drained report can never be re-delivered, and entries
    /// emitted after the drain simply accumulate for the next one. Order is
    /// emission order (the causal fold order).
    public mutating func drainReports() -> [MomoReportEntry] {
        let drained = reports
        reports = []
        return drained
    }

    // MARK: Plans (§9.2)

    private mutating func applyPlan(_ plan: ResponsePlan, at t: Double) {
        guard let key = MomoReactionKey(plan.reaction) else {
            return // unminted key: the vocabulary fails loud in the tests
        }
        // Handshake-class plans route to the L2 slot.
        switch key {
        case .settling:
            startSettle(at: t)
            return
        case .playReady:
            startPlay(at: t)
            return
        case .eating, .sleepyNibbles:
            startL2Clip(key, at: t)
            return
        case .tapHead, .tapBelly, .tap, .doubleTap, .longPressHead,
            .longPressBelly, .longPress, .strokeHead, .strokeBelly,
            .stroke, .stir, .politelyFull, .gentleDecline, .nibble,
            .cheer, .decline, .blanketAdjust:
            // blanketAdjust is the doc's L3 care beat (04 :308): during a
            // running settle it plays ADDITIVELY over the handshake (the
            // engine's warm-reaffirm mint keeps "settle still completes")
            // and over sleep it renders as the L3 beat — MAJOR-1.
            break // L3 vocabulary, below
        }

        // Rule 1: a reaction arrival fades the L1 press feedback.
        if press != nil, press?.fadingSince == nil {
            press?.fadingSince = t
        }

        // Composite: the 2nd stroke in the same touch deepens the running
        // stroke (§6.1's contentment deepens) instead of restarting it.
        // "Same touch" = the touch that started the running stroke has
        // seen no boundary of EITHER kind since — an ended boundary OR a
        // new `touchBegan` (a plan can mint between the two, so the ended
        // stamp alone misreads a fresh touch; NOTE-3).
        if isStroke(key),
            let index = reactionSlots.lastIndex(where: {
                $0.key == key && $0.supersededAt == nil && !$0.glanceUp
            }) {
            let sameTouch = isUnboundaryed(since: reactionSlots[index].start)
            if sameTouch {
                reactionSlots[index].deepened = true
                return
            }
        }

        // Rule 5: while the engine's read-model says eating, TOUCH
        // reactions render as the glance-up beat — the eating choreography
        // never interrupts. Non-touch L3s (the polite sigh, the declines…)
        // render themselves additively over the meal; the activity key
        // (not the clip slot) keeps glance-ups live in the window where
        // the meal clip completed but the engine has not re-minted it yet
        // (MAJOR-2 + NOTE-7).
        if displayState.activity == .eating, isTouchFamily(key) {
            startGlanceUp(for: key, at: t)
            return
        }

        // Rule 3: identical reactions inside the window coalesce.
        if let window = coalescer, window.id == key.rawValue,
            t - window.windowStart < Self.coalesceWindowSeconds {
            coalescer?.count += 1
            let count = coalescer?.count ?? 1
            if count <= 2 {
                startReaction(key, at: t, abbreviated: false)
            } else if count <= 4 {
                startReaction(key, at: t, abbreviated: true)
            } else if coalescer?.coalescedIssued != true {
                coalescer?.coalescedIssued = true
                startCoalesced(key, at: t)
            } // 5+: further arrivals in the window are absorbed.
            return
        }
        coalescer = MomoCoalescer(
            id: key.rawValue, windowStart: t, count: 1, coalescedIssued: false)
        // MINOR-3, the bounded one-shot queue (the tightened law; 04
        // :265/:268): while a one-shot run is visible, a one-shot arrival
        // QUEUES at the chain's end instead of superseding — at most two
        // pending (drop-oldest past the bound: a dropped arrival never
        // rendered, so it never reports — absorbed). Press-shaped and
        // stroke arrivals are LIVE-INPUT semantics and supersede as
        // before (a held press or in-progress stroke cannot meaningfully
        // wait in a queue).
        if isOneShot(key), let runner = visibleReaction(at: t),
            isOneShot(runner.key), !runner.glanceUp {
            queueReaction(key, after: runner, at: t)
            return
        }
        startReaction(key, at: t, abbreviated: false)
    }

    private func isStroke(_ key: MomoReactionKey) -> Bool {
        key == .strokeHead || key == .strokeBelly || key == .stroke
    }

    /// The one-shot family (the queue law): non-press, non-cyclical keys.
    /// The glance-up beat is Rule 5's own shape and never queues (the
    /// slot-side check above).
    private func isOneShot(_ key: MomoReactionKey) -> Bool {
        let spec = MomoReactionClips.spec(for: key)
        return !spec.pressShaped && !spec.cyclical
    }

    /// The §6.1 touch family: exactly the tempo-scaled keys — the 10
    /// touch clips. The stir is the asleep beat and is NOT a touch
    /// arrival (MAJOR-2's gate scoping).
    private func isTouchFamily(_ key: MomoReactionKey) -> Bool {
        MomoReactionClips.spec(for: key).tempoScaled
    }

    /// No touch boundary of EITHER kind since `instant` (the same-touch
    /// predicate; NOTE-3).
    private func isUnboundaryed(since instant: Double) -> Bool {
        (lastTouchEnded ?? -.infinity) < instant
            && (lastTouchBegan ?? -.infinity) < instant
    }

    /// The queue's append: the queued slot's start is its predecessor's
    /// END (the runner's end, or the last pending slot's end — chained),
    /// so pending runs render in turn and each reports exactly once at
    /// its own end. Past the bound the OLDEST pending is dropped
    /// (absorbed — never rendered, never reported).
    private mutating func queueReaction(
        _ key: MomoReactionKey, after runner: MomoReactionSlot, at t: Double
    ) {
        var pending = reactionSlots.filter {
            $0.supersededAt == nil && $0.start > t
        }
        if pending.count >= Self.reactionQueueBound, let oldest = pending.first,
            let index = reactionSlots.firstIndex(where: {
                $0.start == oldest.start && $0.supersededAt == nil
            }) {
            reactionSlots.remove(at: index)
            pending.removeFirst()
            // Re-chain the survivors: the dropped slot's time reservation
            // vanishes with it, so the remaining pending shift earlier to
            // the vacated start — no dead air opens between the runner's
            // end and the next turn.
            var cursor = oldest.start
            for index in reactionSlots.indices
            where reactionSlots[index].supersededAt == nil
                && reactionSlots[index].start > t {
                let duration = reactionSlots[index].end! - reactionSlots[index].start
                reactionSlots[index].start = cursor
                reactionSlots[index].end = cursor + duration
                cursor += duration
            }
            pending = reactionSlots.filter {
                $0.supersededAt == nil && $0.start > t
            }
        }
        let spec = MomoReactionClips.spec(for: key)
        let tempo = MomoReactionTempo.multiplier(for: displayState.energyBand)
        let duration = spec.duration(tempo: tempo)
        let start = pending.last?.end ?? runner.end ?? t
        reactionSlots.append(
            MomoReactionSlot(
                key: key, start: start, end: start + duration, tempo: tempo,
                context: context, holdSeconds: nil, deepened: false,
                abbreviated: false, glanceUp: false, supersededAt: nil,
                fadeOutSeconds: 0, reported: false, touchResolved: false))
    }

    // MARK: L2 slot (Rule 2)

    private mutating func startL2Clip(_ key: MomoReactionKey, at t: Double) {
        // An L2 arrival preempts any visible L3 (fade ≤ 120 ms).
        preemptVisibleReactions(at: t)
        let spec = MomoReactionClips.spec(for: key)
        let slot = MomoReactionSlot(
            key: key, start: t, end: t + spec.baselineSeconds,
            tempo: 1, context: context, holdSeconds: nil, deepened: false,
            abbreviated: false, glanceUp: false, supersededAt: nil,
            fadeOutSeconds: 0, reported: false, touchResolved: false)
        enter(stateLayer: .clip(slot), at: t)
    }

    private mutating func startSettle(at t: Double) {
        if case .settle = stateLayer { return } // already settling
        if case .play(var play) = stateLayer {
            // A newer L2 handshake preempts the round (§9.2 cancellation).
            if !play.reported {
                report(.handshakeCancelled(.play), at: t)
                play.reported = true
            }
            replaceStateLayer(with: .settle(start: t, reported: false), at: t)
            return
        }
        if case .wake = stateLayer { return } // wake is never cancelled
        preemptVisibleReactions(at: t)
        enter(stateLayer: .settle(start: t, reported: false), at: t)
    }

    private mutating func startPlay(at t: Double) {
        if case .play = stateLayer { return } // Rule 6: no reset mid-round
        if case .settle = stateLayer { return } // settling owns the slot
        if case .wake = stateLayer { return } // waking owns the slot
        preemptVisibleReactions(at: t)
        let drowsy = displayState.energyBand == .drowsy
            || displayState.energyBand == .exhausted
        let followStart = t + MomoHandshakeChoreography.inviteSeconds
        let play = MomoPlayInstance(
            start: t, drowsy: drowsy, followStart: followStart,
            followCease: nil, payoffEnd: nil, restStart: nil,
            lastOffset: .zero, reported: false)
        enter(stateLayer: .play(play), at: t)
    }

    private mutating func enter(stateLayer new: MomoStateInstance, at t: Double) {
        if let old = stateLayer {
            // A displaced handshake that will now never complete reports
            // its cancellation at the cut (§9.2, R4's exactly-once
            // handshake accounting); wake is never cancelled — hide
            // pauses it, return replays it from 0 (ADR-010).
            switch old {
            case .clip(let slot):
                // A state clip the new L2 displaced still completes: its
                // rendered run reports at the cut (exactly-once).
                if !slot.reported {
                    report(.reactionFinished(planReactionID(slot.key)), at: t)
                }
            case .settle(_, let reported):
                if !reported { report(.handshakeCancelled(.settle), at: t) }
            case .play(var play):
                if !play.reported {
                    report(.handshakeCancelled(.play), at: t)
                    play.reported = true
                }
            case .wake:
                break
            }
            stateFading = old
            stateFadingStart = t
        }
        stateLayer = new
        stateEnterStart = t
        // Rule 2: L2 replaces L2 through the crossfade band's midpoint;
        // entering an empty slot uses the same gentle entry.
        stateEnterSeconds = Self.l2CrossfadeSeconds
    }

    private mutating func replaceStateLayer(
        with new: MomoStateInstance, at t: Double
    ) {
        if let old = stateLayer {
            stateFading = old
            stateFadingStart = t
        }
        stateLayer = new
        stateEnterStart = t
        // NOTE-2: this is an L2→L2 handoff (settle displacing play) — BOTH
        // halves crossfade at the §7.1 state band, exactly as enter().
        stateEnterSeconds = Self.l2CrossfadeSeconds
    }

    // MARK: L3 timeline

    private mutating func startReaction(
        _ key: MomoReactionKey, at t: Double, abbreviated: Bool
    ) {
        let spec = MomoReactionClips.spec(for: key)
        let tempo = MomoReactionTempo.multiplier(for: displayState.energyBand)
        var duration = spec.duration(tempo: tempo)
        if abbreviated { duration *= Self.abbreviationFraction }
        let superseding = visibleReaction(at: t)
        if superseding != nil {
            // Newest wins: the running reaction yields with the preempt
            // fade (Rule 2's L3 fade; identical-ID restarts use it too —
            // Rule 3's arrival replaces the running instance). The cut
            // carries the running instance's completion report.
            supersedeVisible(at: t, fade: Self.l3PreemptFadeSeconds)
        }
        // Ends: press-shaped resolves at touchEnded (press-length is
        // input); cyclical strokes are capped at the cycle cap and resolve
        // earlier at the touch boundary; everything else is fixed. Every
        // completion REPORT fires at the fold that observes the end (the
        // prune), never queued here — exactly-once by construction.
        let end: Double?
        if spec.pressShaped {
            end = nil
        } else if spec.cyclical {
            end = t + duration * Double(Self.strokeCycleCap)
        } else {
            end = t + duration
        }
        let slot = MomoReactionSlot(
            key: key, start: t, end: end,
            tempo: tempo, context: context, holdSeconds: nil, deepened: false,
            abbreviated: abbreviated, glanceUp: false, supersededAt: nil,
            fadeOutSeconds: 0, reported: false, touchResolved: false)
        reactionSlots.append(slot)
    }

    private mutating func startCoalesced(
        _ key: MomoReactionKey, at t: Double
    ) {
        supersedeVisible(at: t, fade: Self.l3PreemptFadeSeconds)
        let slot = MomoReactionSlot(
            key: key, start: t, end: t + Self.coalescedSeconds,
            tempo: 1, context: context, holdSeconds: nil, deepened: false,
            abbreviated: false, glanceUp: false, supersededAt: nil,
            fadeOutSeconds: 0, reported: false, touchResolved: false)
        reactionSlots.append(slot)
    }

    private mutating func startGlanceUp(for key: MomoReactionKey, at t: Double) {
        supersedeVisible(at: t, fade: Self.l3PreemptFadeSeconds)
        let slot = MomoReactionSlot(
            key: key, start: t, end: t + Self.glanceUpSeconds,
            tempo: 1, context: context, holdSeconds: nil, deepened: false,
            abbreviated: false, glanceUp: true, supersededAt: nil,
            fadeOutSeconds: 0, reported: false, touchResolved: false)
        reactionSlots.append(slot)
    }

    /// Cuts the visible reaction at `t`: its completion report fires at the
    /// cut instant (exactly once — a slot the fold already completed
    /// reports at its own end instead), then the fade begins. Any one-shots
    /// queued behind the cut runner are absorbed silently (they chained to
    /// a run that is now gone; they never rendered, so they never report —
    /// the queue law; this also keeps the active set at one for ANY stream).
    private mutating func supersedeVisible(at t: Double, fade seconds: Double) {
        guard let old = visibleReaction(at: t),
            let index = reactionSlots.firstIndex(where: { $0.start == old.start })
        else { return }
        if !reactionSlots[index].reported {
            report(.reactionFinished(planReactionID(reactionSlots[index].key)), at: t)
            reactionSlots[index].reported = true
        }
        reactionSlots[index].supersededAt = t
        reactionSlots[index].fadeOutSeconds = seconds
        reactionSlots.removeAll { $0.supersededAt == nil && $0.start > t }
    }

    /// The L2 paths' L3 sweep: cut the visible reaction (≤ 120 ms) and
    /// clear the pending queue SILENTLY — an L2 change absorbs queued
    /// one-shots whether or not a visible run is being cut (the law;
    /// never rendered → never reports).
    private mutating func preemptVisibleReactions(at t: Double) {
        supersedeVisible(at: t, fade: Self.l3PreemptFadeSeconds)
        reactionSlots.removeAll { $0.supersededAt == nil && $0.start > t }
    }

    private func visibleReaction(at t: Double) -> MomoReactionSlot? {
        reactionSlots.last {
            $0.supersededAt == nil && $0.start <= t
                && ($0.end == nil || t < $0.end!)
        }
    }

    /// The pending (queued, not yet started) one-shot count at `t` — the
    /// ≤ 2 bound the tightened queue law enforces and the property tests
    /// check on any stream (MINOR-3: live machinery, not a vacuous pin).
    public func pendingReactionCount(after t: Double) -> Int {
        reactionSlots.filter { $0.supersededAt == nil && $0.start > t }.count
    }

    private func planReactionID(_ key: MomoReactionKey) -> ReactionID {
        ReactionID(rawValue: key.rawValue)
    }

    private var context: MomoReactionContext {
        MomoReactionContext(
            moodBand: displayState.moodBand,
            energyBand: displayState.energyBand,
            bondStage: displayState.bondStage,
            wakefulness: displayState.wakefulness)
    }

    // MARK: Display state (§9.3) — wakefulness + moments

    private mutating func applyDisplayState(
        _ state: CharacterDisplayState, at t: Double
    ) {
        displayState = state
        // L4 moments fire on request TRANSITIONS (the display state keeps
        // the last greeting stamp until the next — the transition IS the
        // dedupe). While hidden, defer the render to appShown.
        if state.momentRequest != pendingMomentRequest {
            pendingMomentRequest = state.momentRequest
            if let request = state.momentRequest {
                if hidden {
                    deferredMoment = request
                } else {
                    startMoment(request, at: t)
                }
            }
        }
        // Wakefulness-driven choreography starts (state-driven paths).
        if !hidden {
            switch state.wakefulness {
            case .waking:
                if case .wake = stateLayer {} else { startWake(at: t) }
            case .settling:
                if case .settle = stateLayer {} else { startSettle(at: t) }
            case .asleep, .awake:
                break
            }
        }
    }

    private mutating func startWake(at t: Double) {
        preemptVisibleReactions(at: t)
        enter(stateLayer: .wake(start: t), at: t)
    }

    private mutating func startMoment(_ moment: CharacterMoment, at t: Double) {
        self.moment = MomoMomentInstance(moment: moment, start: t, reported: false)
    }

    // MARK: Touch boundaries (§6.1 press-length; strokes end whole)

    private mutating func applyTouchEnded(at t: Double) {
        lastTouchEnded = t
        // The L1 press feedback fades (≤ 100 ms — Rule 1).
        if press?.fadingSince == nil { press?.fadingSince = t }

        // Resolve the press-shaped holds: the release beat runs from now,
        // its completion report lands at the fold that sees the end. The
        // release length is the row's own AUTHORED release (0.45 for the
        // belly, 0.6 for the head — the baseline), tempo-scaled WITH the
        // rock cycle so the rendered release meets the slot end at every
        // tempo (MINOR-1).
        for index in reactionSlots.indices {
            guard reactionSlots[index].supersededAt == nil,
                reactionSlots[index].holdSeconds == nil,
                reactionSlots[index].end == nil,
                isPressShaped(reactionSlots[index].key)
            else { continue }
            let hold = t - reactionSlots[index].start
            reactionSlots[index].holdSeconds = hold
            let spec = MomoReactionClips.spec(for: reactionSlots[index].key)
            let releaseSeconds = spec.pressReleaseSeconds
                ?? spec.baselineSeconds
            let release = spec.tempoScaled
                ? releaseSeconds * reactionSlots[index].tempo : releaseSeconds
            reactionSlots[index].end = t + release
        }

        // Cyclical strokes finish their CURRENT cycle (capped); their
        // report was already emitted at the cap — the touch boundary only
        // pulls the end earlier.
        for index in reactionSlots.indices {
            guard reactionSlots[index].supersededAt == nil,
                !reactionSlots[index].touchResolved,
                reactionSlots[index].end != nil,
                isStroke(reactionSlots[index].key)
            else { continue }
            let spec = MomoReactionClips.spec(for: reactionSlots[index].key)
            let cycle = spec.duration(tempo: reactionSlots[index].tempo)
            let elapsed = t - reactionSlots[index].start
            let cycles = max((elapsed / cycle).rounded(.up), 1)
            let naturalEnd = reactionSlots[index].start
                + cycles * cycle
            reactionSlots[index].end = min(reactionSlots[index].end!, naturalEnd)
            reactionSlots[index].touchResolved = true
        }
    }

    private func isPressShaped(_ key: MomoReactionKey) -> Bool {
        key == .longPressHead || key == .longPressBelly
    }

    // MARK: App hide/show (§7.4 rule 8; §4.1 rule 7; ADR-010)

    private mutating func applyHidden(at t: Double) {
        hidden = true
        press = nil
        lastTouchEnded = nil
        lastTouchBegan = nil
        coalescer = nil
        // L3s stop rendering; the visible one reports its cut instant.
        supersedeVisible(at: t, fade: Self.l3PreemptFadeSeconds)
        reactionSlots.removeAll { $0.supersededAt == nil && $0.start > t }
        // Handshake/L2 slots per the matrix: settle and play cancel with
        // their exactly-once cancellation report; a running meal stops
        // (the state restarts it on return); wake and the L4 moment
        // PAUSE — they replay from 0 on return (ADR-010).
        switch stateLayer {
        case .settle(let start, let reported):
            if !reported {
                report(.handshakeCancelled(.settle), at: t)
            }
            stateLayer = nil
            stateFading = nil
            _ = start
        case .play(var play):
            if !play.reported {
                report(.handshakeCancelled(.play), at: t)
                play.reported = true
            }
            stateLayer = nil
            stateFading = nil
        case .clip(var slot):
            if !slot.reported {
                report(.reactionFinished(planReactionID(slot.key)), at: t)
                slot.reported = true
            }
            stateLayer = nil
            stateFading = nil
        case .wake, .none:
            break // paused, replayed from 0 on return
        }
    }

    /// TASK-035 R6: the early-exit stop event (UX-3's "Done" pill). An
    /// in-flight round cancels through the SAME displacement-cancel
    /// machinery `applyHidden`'s play branch uses — the exactly-once
    /// `handshakeCancelled(.play)`, the layer cleared, the underlying state
    /// showing through — and a no-round fold is a tolerated no-op (the
    /// event is never a lie: no hide semantics fire, no L3 is disturbed).
    private mutating func applyPlayStopped(at t: Double) {
        if case .play(var play) = stateLayer {
            if !play.reported {
                report(.handshakeCancelled(.play), at: t)
                play.reported = true
            }
            stateLayer = nil
            stateFading = nil
        }
    }

    private mutating func applyShown(at t: Double) {
        hidden = false
        reactionSlots.removeAll()
        stateFading = nil
        // The new epoch: nothing retained is time-comparable — suspended
        // choreography RESTARTS FROM 0 (ADR-010), or drops if the state
        // moved on while hidden. The latest deferred request supersedes
        // any interrupted moment.
        if let request = deferredMoment {
            deferredMoment = nil
            moment = nil
            startMoment(request, at: t)
        } else if moment != nil {
            moment?.start = t // replay the interrupted moment from 0
        }
        switch displayState.wakefulness {
        case .waking:
            stateLayer = .wake(start: t)
        case .settling:
            stateLayer = .settle(start: t, reported: false)
        case .asleep, .awake:
            stateLayer = nil
        }
        // The meal is state-backed: restart it if the engine still says
        // eating and nothing owns the state slot.
        if stateLayer == nil, displayState.wakefulness == .awake,
            displayState.activity == .eating {
            let spec = MomoReactionClips.spec(for: .eating)
            let slot = MomoReactionSlot(
                key: .eating, start: t, end: t + spec.baselineSeconds,
                tempo: 1, context: context, holdSeconds: nil, deepened: false,
                abbreviated: false, glanceUp: false, supersededAt: nil,
                fadeOutSeconds: 0, reported: false, touchResolved: false)
            stateLayer = .clip(slot)
        }
        stateEnterStart = t
        stateEnterSeconds = 0
    }

    // MARK: Completions + GC (folds resolve what time resolved)

    /// Every completion REPORT is emitted HERE (or at a cut, in
    /// `supersedeVisible`/`applyHidden`) — never queued at creation — so
    /// exactly-once is structural: each append site is guarded by the
    /// owning instance's `reported` flag, and each instance has exactly
    /// one completion site.
    private mutating func pruneCompleteLayers(around t: Double) {
        // The hidden app is fully paused (§7.4 rule 8): retained choreography
        // (a paused wake, a paused moment) may not complete on a fold that
        // arrives while hidden — the return replays it from 0 (ADR-010).
        guard !hidden else { return }
        // MINOR-2: a press whose boundary was LOST resolves as a release
        // at the authored cap — it then behaves exactly like a released
        // press (release beat, exactly-once report at its end, normal GC).
        for index in reactionSlots.indices {
            guard reactionSlots[index].supersededAt == nil,
                reactionSlots[index].holdSeconds == nil,
                reactionSlots[index].end == nil,
                isPressShaped(reactionSlots[index].key),
                t >= reactionSlots[index].start + Self.pressLostBoundarySeconds
            else { continue }
            reactionSlots[index].holdSeconds = Self.pressLostBoundarySeconds
            let spec = MomoReactionClips.spec(for: reactionSlots[index].key)
            let releaseSeconds = spec.pressReleaseSeconds
                ?? spec.baselineSeconds
            let release = spec.tempoScaled
                ? releaseSeconds * reactionSlots[index].tempo : releaseSeconds
            reactionSlots[index].end =
                reactionSlots[index].start
                + Self.pressLostBoundarySeconds + release
        }
        // The pacer's sample-less deadline FIRST: a round whose follow
        // never resolved by input still ceases at the first fold past its
        // deadline — the pacer's own answer at that instant (the recorded
        // rest shortens into the solo finish; drowsy is fixed; otherwise
        // the baseline) — so the ≤ 30 s bound holds for ANY input stream.
        if case .play(var play) = stateLayer, play.followCease == nil {
            let resting = play.restStart.map {
                t - $0 >= MomoHandshakeChoreography.restGraceSeconds
            } ?? false
            let baseline = play.drowsy
                ? MomoHandshakeChoreography.drowsyFollowSeconds
                : MomoHandshakeChoreography.followBaselineSeconds
            if t >= play.followStart + baseline {
                let cease = MomoHandshakeChoreography.followCease(
                    followStart: play.followStart,
                    restStart: resting ? play.restStart : nil,
                    drowsy: play.drowsy)
                play.followCease = play.followStart + cease
                play.payoffEnd = play.followCease!
                    + MomoHandshakeChoreography.payoffSeconds
                stateLayer = .play(play)
            }
        }
        // Handshake completions fire at the first fold past their end.
        if case .play(var play) = stateLayer, let payoffEnd = play.payoffEnd,
            t >= payoffEnd {
            if !play.reported {
                report(.playRoundFinished, at: payoffEnd)
                play.reported = true
            }
            stateLayer = nil
        }
        if case .settle(let start, _) = stateLayer,
            t >= start + MomoHandshakeChoreography.settleDurationSeconds {
            report(
                .settleFinished,
                at: start + MomoHandshakeChoreography.settleDurationSeconds)
            stateLayer = nil
        }
        if case .wake(let start) = stateLayer,
            t >= start + MomoHandshakeChoreography.wakeDurationSeconds {
            report(
                .wakeFinished,
                at: start + MomoHandshakeChoreography.wakeDurationSeconds)
            stateLayer = nil
        }
        // An L2 state clip completes exactly once, then leaves the slot.
        if case .clip(var slot) = stateLayer, let end = slot.end, t >= end {
            if !slot.reported {
                report(.reactionFinished(planReactionID(slot.key)), at: end)
                slot.reported = true
            }
            stateLayer = nil
        }
        // The L4 moment completes exactly once.
        if var moment, t >= moment.start + MomoMoments.duration(for: moment.moment) {
            if !moment.reported {
                report(.momentFinished(moment.moment),
                       at: moment.start + MomoMoments.duration(for: moment.moment))
                moment.reported = true
            }
            self.moment = nil
        }
        // L3 completions: every resolved slot reports once at its own end.
        for index in reactionSlots.indices {
            guard !reactionSlots[index].reported,
                reactionSlots[index].supersededAt == nil,
                let end = reactionSlots[index].end, t >= end
            else { continue }
            report(.reactionFinished(planReactionID(reactionSlots[index].key)),
                   at: end)
            reactionSlots[index].reported = true
        }
        // The L2 crossfade's outgoing layer is gone once its fade ends.
        if let fading = stateFading {
            let seconds = fadeSeconds(for: fading)
            if t >= stateFadingStart + seconds { stateFading = nil }
        }
        // Reaction GC: finished + faded out, or a spent coalescing window.
        reactionSlots.removeAll { slot in
            let fadeEnd: Double
            if let supersededAt = slot.supersededAt {
                fadeEnd = supersededAt + slot.fadeOutSeconds
            } else {
                fadeEnd = slot.end ?? .infinity // no fade: end + 0
            }
            let end = slot.end ?? .infinity
            return slot.reported && t >= end && t >= fadeEnd
        }
        if let window = coalescer,
            t - window.windowStart >= Self.coalesceWindowSeconds {
            coalescer = nil
        }
    }

    private func fadeSeconds(for layer: MomoStateInstance) -> Double {
        Self.l2CrossfadeSeconds
    }

    // MARK: Reports

    mutating func report(_ report: CharacterReport, at t: Double) {
        reports.append(MomoReportEntry(report: report, at: t))
    }
}
