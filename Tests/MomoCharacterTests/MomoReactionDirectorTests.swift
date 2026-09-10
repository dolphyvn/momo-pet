import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The coherence director (TASK-028 R3; 04 §4.1's L0–L4 matrix)

/// The §4.1 rules as behavior pins over the pure fold: Rule 1's L1 fade,
/// Rule 2's crossfade/preemption, Rule 3's identical-reaction coalescing,
/// the L3 queue bound, and the structural priority-table property under an
/// adversarial event storm. All instants are explicit; no clock, no RNG.
struct MomoReactionDirectorTests {

    // MARK: The named constants cite their rules

    @Test("The coherence constants pin their doc bands")
    func constantPins() {
        #expect(MomoDirectorState.l1FadeSeconds == 0.1) // Rule 1: ≤ 100 ms
        #expect(MomoCurves.stateCrossfadeSeconds.contains(
            MomoDirectorState.l2CrossfadeSeconds)) // Rule 2: §7.1's 300–400 ms
        #expect(MomoDirectorState.l3PreemptFadeSeconds <= 0.12) // Rule 2: ≤ 120 ms
        #expect(MomoDirectorState.coalesceWindowSeconds == 0.5) // Rule 3
        #expect((0.4...0.5).contains(MomoDirectorState.coalescedSeconds))
        #expect(MomoDirectorState.reactionQueueBound == 2)
        #expect(MomoDirectorState.pressLostBoundarySeconds == 5.0) // MINOR-2
    }

    // MARK: Rule 1 — the L1 press feedback fades on reaction arrival

    /// While the finger is down the press feedback lifts the ears; a
    /// reaction arrival fades it across exactly 100 ms. Tap·belly animates
    /// no ear channel, so the press is the only ear contributor and the
    /// fade reads cleanly.
    @Test("Rule 1: the press feedback fades ≤ 100 ms once a reaction arrives")
    func rule1PressFade() {
        let state = ReactionFixtures.fold([
            .touchBegan(zone: .belly, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.2),
        ])
        // Full presence just before the arrival.
        #expect(state.overlay(at: 1.19).earLeftDegrees == 2)
        // Linear fade across the 100 ms: half at +50 ms, gone at +100 ms.
        #expect(abs(state.overlay(at: 1.25).earLeftDegrees - 1) < 1e-9)
        #expect(state.overlay(at: 1.3).earLeftDegrees == 0)
        #expect(state.overlay(at: 1.4).earLeftDegrees == 0)
    }

    /// A touch boundary alone also fades the feedback (Rule 1's release).
    @Test("Rule 1: the touch boundary fades the press feedback too")
    func rule1ReleaseFade() {
        let state = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 1.0),
            .touchEnded(at: 1.1),
        ])
        #expect(state.overlay(at: 1.1).earLeftDegrees == 2)
        // Gone at the fade's end (to folding precision) and after it.
        #expect(abs(state.overlay(at: 1.2).earLeftDegrees) < 1e-9)
        #expect(state.overlay(at: 1.25).earLeftDegrees == 0)
    }

    // MARK: Rule 2 — L2 crossfade + L2 preempts L3

    /// L2 replaces L2 through the state crossfade: the outgoing meal's
    /// motion fades out while the incoming beat fades in, meeting at the
    /// midpoint and completing within the 300–400 ms band.
    /// L2 replaces L2 through the state crossfade: the outgoing meal's
    /// motion fades out while the incoming beat fades in, meeting at the
    /// midpoint and completing within the 300–400 ms band. The only
    /// remaining L2-clip pair (MAJOR-1 moved blanketAdjust into the L3
    /// vocabulary) is the meal → sleepy-nibbles handoff; the observable is
    /// the incoming beat's always-on heavy-lids aperture.
    @Test("Rule 2: L2 replaces L2 through the state crossfade")
    func rule2L2Crossfade() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.sleepyNibbles, at: 2.5),
        ])
        let crossfade = MomoDirectorState.l2CrossfadeSeconds
        // The incoming beat contributes nothing at its start instant: the
        // outgoing meal's mid-bite bob is all that shows, with no aperture
        // dip yet.
        #expect(state.overlay(at: 2.5).apertureMultiplier == 1)
        #expect(state.overlay(at: 2.5).food != .rest)
        // The heavy lids are half-in at the midpoint (the outgoing meal
        // carries no aperture motion, so the dip is entirely the
        // fade-in's).
        let mid = state.overlay(at: 2.5 + crossfade / 2)
        #expect(mid.apertureMultiplier < 1)
        // The full beat stands after the band: the heavy-lids base, with
        // the outgoing bob fully faded to invisible.
        let full = state.overlay(at: 2.5 + crossfade + 0.01)
        #expect(abs(full.apertureMultiplier - 0.5) < 1e-9)
        #expect(full.food.opacity == 0)
    }

    /// An L2 arrival cuts the visible L3 with the ≤ 120 ms preempt fade.
    @Test("Rule 2: an L2 arrival preempts the visible L3 in ≤ 120 ms")
    func rule2L3Preempt() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.2),
        ])
        let fade = MomoDirectorState.l3PreemptFadeSeconds
        // The squash was live just before the cut…
        #expect(state.overlay(at: 1.19).bodyScaleYMultiplier < 1)
        // …half gone mid-fade, fully gone at the fade's end (linear).
        let mid = state.overlay(at: 1.2 + fade / 2).bodyScaleYMultiplier
        #expect(mid > 1 - 0.05 && mid < 1)
        #expect(state.overlay(at: 1.2 + fade).bodyScaleYMultiplier == 1)
    }

    // MARK: Rule 3 — identical reactions coalesce inside 500 ms

    @Test("Rule 3: two identical arrivals run full; 3–4 run abbreviated; 5+ coalesce once per window")
    func rule3Classes() {
        // Five identical taps inside the 500 ms window (80 ms apart), then
        // a sixth that must be absorbed.
        let taps = (0..<6).map { ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.0 + 0.08 * Double($0)) }
        let state = ReactionFixtures.fold(taps)

        // Class shapes: the first two full (0.45 s), the next two
        // abbreviated (half), the fifth the single coalesced beat (the
        // gentle 0.45 s response), the sixth absorbed (no new slot). The
        // census reads the RETAINED slots — the GC has already collected
        // the first abbreviated run's fully faded shell, so the report
        // log below carries the whole sequence. Durations carry folding
        // residue — compared with tolerance.
        let belly = state.reactionSlots.filter { $0.key == .tapBelly }
        #expect(belly.count == 4)
        #expect(belly.filter {
            !$0.abbreviated && abs($0.end! - $0.start - 0.45) < 1e-9
        }.count == 3) // the two fulls + the coalesced beat
        #expect(belly.filter {
            $0.abbreviated && abs($0.end! - $0.start - 0.225) < 1e-9
        }.count == 1) // the later abbreviated run
        // The window tracked every arrival; the sixth was still counted.
        #expect(state.coalescer?.count == 6)
        #expect(state.coalescer?.coalescedIssued == true)

        // Fold past everything: exactly one report per rendered run — the
        // four cut runs report at their cuts (newest wins), the coalesced
        // beat at its end; the absorbed arrival never rendered and never
        // reports.
        let done = ReactionFixtures.fold(taps + [.displayState(ReactionFixtures.content, at: 5.0)])
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.tapBelly), in: done)
        #expect(finishes.count == 5)
        #expect(abs(finishes[0].at - 1.08) < 1e-9)
        #expect(abs(finishes[1].at - 1.16) < 1e-9)
        #expect(abs(finishes[2].at - 1.24) < 1e-9)
        #expect(abs(finishes[3].at - 1.32) < 1e-9)
        #expect(abs(finishes[4].at - 1.77) < 1e-9) // 1.32 + the coalesced beat
    }

    @Test("Rule 3: identical arrivals past the window never coalesce")
    func rule3WindowExpiry() {
        // The first tap finished (0.45 s) before the second arrives 0.6 s
        // later: fresh window, both full, no cut between them. The first
        // run completed at its own end (reported by the second arrival's
        // resolving fold) and was collected — the report log carries it.
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.6),
        ])
        let finishes = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.tapBelly), in: state)
        #expect(finishes.count == 1)
        #expect(abs(finishes[0].at - 1.45) < 1e-9)
        // The second is the only retained slot, and it was never cut.
        #expect(state.reactionSlots.count == 1)
        #expect(state.reactionSlots.allSatisfy { $0.supersededAt == nil })
        // The expired window was replaced, not extended.
        #expect(state.coalescer?.windowStart == 1.6)
        #expect(state.coalescer?.count == 1)
    }

    @Test("Rule 3: different reactions never coalesce each other")
    func rule3Identity() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.1),
        ])
        // MINOR-3's queue law: a DIFFERENT one-shot does not cut the
        // runner — it queues at the runner's end. The new window still
        // tracks only react.tap.belly (identity is per-key).
        #expect(state.reactionSlots.count == 2)
        #expect(state.coalescer?.id == "react.tap.belly")
        #expect(state.coalescer?.count == 1)
        #expect(state.reactionSlots.allSatisfy { $0.supersededAt == nil })
        let head = state.reactionSlots.first { $0.key == .tapHead }
        let belly = state.reactionSlots.first { $0.key == .tapBelly }
        #expect(abs(head!.end! - 1.4) < 1e-9)
        #expect(abs(belly!.start - 1.4) < 1e-9)
    }

    // MARK: MINOR-3 — the bounded one-shot queue

    /// A one-shot arriving while a one-shot run is visible queues at the
    /// chain's end (the runner's end, or the last pending slot's end);
    /// at most two pending — past the bound the OLDEST is dropped,
    /// absorbed (it never rendered, so it never reports). Each rendered
    /// run reports exactly once at its own end.
    @Test("The queue: one-shot arrivals chain in turn; the 4th drops the oldest silently")
    func queueFormationAndBound() {
        let events = [
            ReactionFixtures.plan(ReactionKeys.cheer, at: 1.0),         // 0.6 s
            ReactionFixtures.plan(ReactionKeys.politelyFull, at: 1.1),  // 1.2 s
            ReactionFixtures.plan(ReactionKeys.gentleDecline, at: 1.2), // 1.0 s
            ReactionFixtures.plan(ReactionKeys.nibble, at: 1.3),        // 1.6 s
        ]
        var state = MomoDirectorState(displayState: ReactionFixtures.content)
        for event in events { state.apply(event) }
        // One visible runner + exactly two pending: the politelyFull
        // arrival was the 4th and dropped the OLDEST pending (itself)…
        #expect(state.reactionSlots.count == 3)
        #expect(!state.reactionSlots.contains { $0.key == .politelyFull })
        #expect(state.pendingReactionCount(after: 1.3) == 2)
        // …and the survivors chain: cheer runs 1.0–1.6, then the decline
        // runs at the vacated start 1.6–2.6 (re-chained to the runner's
        // end — no dead air), then the nibble 2.6–4.2.
        let cheer = state.reactionSlots.first { $0.key == .cheer }
        let decline = state.reactionSlots.first { $0.key == .gentleDecline }
        let nibble = state.reactionSlots.first { $0.key == .nibble }
        #expect(abs(cheer!.end! - 1.6) < 1e-9)
        #expect(abs(decline!.start - cheer!.end!) < 1e-9)
        #expect(abs(decline!.end! - 2.6) < 1e-9)
        #expect(abs(nibble!.start - decline!.end!) < 1e-9)
        // Fold past everything: each rendered run reported exactly once
        // at its own end; the absorbed arrival never reported.
        state.apply(.displayState(ReactionFixtures.content, at: 6.0))
        let finishes: [(MomoReactionKey, Double)] = [
            (.cheer, 1.6), (.gentleDecline, 2.6), (.nibble, 4.2),
        ]
        for (key, end) in finishes {
            let reports = ReactionFixtures.reports(
                matching: ReactionFixtures.finished(ReactionID(rawValue: key.rawValue)),
                in: state)
            #expect(reports.count == 1, "\(key.rawValue) reported \(reports.count)×")
            #expect(abs(reports[0].at - end) < 1e-9)
        }
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.politelyFull),
            in: state).isEmpty)
    }

    /// An L2 arrival clears the queue SILENTLY — queued one-shots are
    /// absorbed whether or not a visible run is being cut (they never
    /// rendered, so they never report); the visible runner reports its
    /// cut, the L2 clip its own end.
    @Test("The queue: an L2 arrival clears pending silently")
    func queueClearedByL2() {
        let state = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.cheer, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.politelyFull, at: 1.1),
            ReactionFixtures.plan(ReactionKeys.gentleDecline, at: 1.2),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.3),
            .displayState(ReactionFixtures.content, at: 6.0),
        ])
        // The runner reported its cut; the meal its end; pending: nothing.
        let cheer = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.cheer), in: state)
        #expect(cheer.count == 1)
        #expect(abs(cheer[0].at - 1.3) < 1e-9)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.politelyFull),
            in: state).isEmpty)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.gentleDecline),
            in: state).isEmpty)
        let meal = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.eating), in: state)
        #expect(meal.count == 1)
        #expect(abs(meal[0].at - 4.5) < 1e-9)
        #expect(state.pendingReactionCount(after: 1.3) == 0)
    }

    /// Press and stroke arrivals stay LIVE-INPUT semantics: a stroke
    /// supersedes the running one-shot (its queue is absorbed) and runs
    /// at once — it cannot meaningfully wait behind a queue.
    @Test("The queue: a stroke supersedes live and absorbs pending")
    func queueClearedByLiveInput() {
        let run = ReactionFixtures.fold([
            ReactionFixtures.plan(ReactionKeys.cheer, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.politelyFull, at: 1.1),
            ReactionFixtures.plan(ReactionKeys.gentleDecline, at: 1.2),
            ReactionFixtures.plan(ReactionKeys.strokeBelly, at: 1.3),
            .touchEnded(at: 2.0),
        ])
        // The stroke is running (the belly rock renders at once)…
        #expect(run.overlay(at: 1.5).bodyRotationDegrees != 0)
        // …then fold past everything: the runner reported its cut, the
        // stroke its cycle end (the touch boundary pulled 5.3's cap in to
        // 2.3), pending: nothing.
        let state = ReactionFixtures.fold(
            [.displayState(ReactionFixtures.content, at: 6.0)], into: run)
        let cheer = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.cheer), in: state)
        #expect(cheer.count == 1)
        #expect(abs(cheer[0].at - 1.3) < 1e-9)
        let stroke = ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.strokeBelly), in: state)
        #expect(stroke.count == 1)
        #expect(abs(stroke[0].at - 2.3) < 1e-9)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.politelyFull),
            in: state).isEmpty)
        #expect(ReactionFixtures.reports(
            matching: ReactionFixtures.finished(ReactionKeys.gentleDecline),
            in: state).isEmpty)
    }

    // MARK: The L3 structural bound (priority table, any stream)

    /// An adversarial storm — every event kind interleaved — may never
    /// violate the §4.1 priority table's SHAPE: one L2 occupant, one L4
    /// moment, at most one ACTIVE L3 (cut reactions may still fade), the
    /// L1 press at most one, and the pending queue at most two. The storm
    /// is a fixed list — determinism, no RNG.
    @Test("The priority table's shape holds across an adversarial event storm")
    func structuralPropertyUnderStorm() {
        var storm: [MomoCharacterEvent] = [
            .touchBegan(zone: .head, at: 0.5),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 0.6),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 0.7),
            ReactionFixtures.plan(ReactionKeys.strokeHead, at: 0.9),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.0),
            ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.1),
            ReactionFixtures.plan(ReactionKeys.sleepyNibbles, at: 1.2),
            ReactionFixtures.plan(ReactionKeys.playReady, at: 1.3),
            .fingertip(offset: CGPoint(x: 40, y: -20), moving: true, at: 1.4),
            ReactionFixtures.plan(ReactionKeys.cheer, at: 1.5),
            ReactionFixtures.plan(ReactionKeys.settling, at: 1.6),
            .displayState(
                ReactionFixtures.displayState(wakefulness: .settling), at: 1.7),
            ReactionFixtures.plan(ReactionKeys.stir, at: 1.8),
            .touchEnded(at: 1.9),
            .appHidden(at: 2.0),
            .appShown(at: 2.1),
            .displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 2.2),
            ReactionFixtures.plan(ReactionKeys.politelyFull, at: 2.3),
            ReactionFixtures.plan(ReactionKeys.decline, at: 2.35),
            ReactionFixtures.plan(ReactionKeys.doubleTap, at: 2.4),
            .displayState(
                ReactionFixtures.displayState(
                    wakefulness: .waking,
                    momentRequest: .greeting(.freshMorning)), at: 2.5),
            .appHidden(at: 2.6),
            .appShown(at: 2.7),
            ReactionFixtures.plan(ReactionKeys.longPressHead, at: 2.8),
            .touchBegan(zone: .head, at: 2.85),
            ReactionFixtures.plan(ReactionKeys.longPressHead, at: 2.9),
            .touchEnded(at: 3.0),
            .fingertip(offset: CGPoint(x: 0, y: 0), moving: false, at: 3.1),
        ]
        // Close the storm with coarse folds so every completion has a
        // resolving fold, then sweep every sampled instant.
        storm.append(.displayState(ReactionFixtures.content, at: 60))

        var state = MomoDirectorState(displayState: ReactionFixtures.content)
        for event in storm { state.apply(event) }

        for t in samples(until: 60, count: 400) {
            // L2: one occupant by type; the ACTIVE L3 set is at most one
            // (cut reactions may still fade, and are counted out here by
            // their supersede stamp).
            let activeL3 = state.reactionSlots.filter {
                $0.supersededAt == nil
                    && ($0.end == nil || t < $0.end!) && t >= $0.start
            }
            #expect(activeL3.count <= 1, "two active L3s at t=\(t)")
            // The queue never exceeds its bound of two.
            #expect(state.pendingReactionCount(after: t) <= 2,
                    "queue bound broken at t=\(t)")
        }
        // Exactly-once, storm-wide: every rendered run reports once — no
        // duplicate (identity, instant) pair in the whole log. (The same
        // KIND may legitimately report twice at different instants — two
        // separate rendered runs, e.g. the storm's two settle instances.)
        var counts: [String: Int] = [:]
        for entry in state.reports {
            counts["\(entry.identity)@\(entry.at)", default: 0] += 1
        }
        for (key, count) in counts {
            #expect(count == 1, "duplicate report \(key)")
        }
    }

    // MARK: Idle composure — a touch-less state stays untouched

    @Test("No events: the overlay is identity at every instant")
    func idleOverlayIdentity() {
        let state = MomoDirectorState(displayState: ReactionFixtures.content)
        for t in samples(until: 10) {
            #expect(state.overlay(at: t) == .identity)
            #expect(state.reports.isEmpty)
        }
    }
}
