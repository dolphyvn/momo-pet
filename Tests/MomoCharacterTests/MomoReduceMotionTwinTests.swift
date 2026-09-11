import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The RM render-only twin law (TASK-029 R15; 04 §7.3's closing law)

/// R15: for ANY event stream the `CharacterReport` sequence is IDENTICAL
/// under both Reduce Motion values — "Reduce Motion never removes
/// information" reads on the engine side as "the engine observes the same
/// story either way". Honesty note (what this suite can and cannot prove):
/// the director fold takes NO flag — `apply(_:)` has no Reduce Motion
/// input, and the scoping test in `RigDisciplineTests` pins that the flag
/// enters the module ONLY through the view's environment mapping — so the
/// fold cannot fork on the flag BY CONSTRUCTION. Behaviorally pinned here,
/// over the TASK-028 adversarial corpus replayed plus RM-specific streams:
///   1. fold twins — the same stream folds to equal states (whole-state
///      `==`, report logs included): the observed report sequence is a
///      function of the stream alone, never of the flag;
///   2. RM observability — each corpus stream renders DIFFERENTLY under
///      the flag at some sampled instant (the flag's effect is real), with
///      the one disclosed exception: a press-only stream pins the L1
///      glance's flag-INVARIANCE (the §7.3 look-around row's static touch
///      glance);
///   3. tracker twins — the R5 crossfade inputs fold deterministically
///      from the same `.displayState` events the director consumes, and
///      never touch the director in return.
/// The clock's determinism (04 §7.4 rule 8) is TASK-028's; the fold pacing
/// these reports is untouched — only the rendered motion transforms.
struct MomoReduceMotionTwinTests {

    /// What the suite asserts about a stream's flag visibility.
    private enum Visibility {
        /// Some sampled instant must render differently under RM.
        case mustDiffer
        /// The render must be flag-INVARIANT at every sampled instant
        /// (the L1 press glance — R4's disclosed identity).
        case pressGlanceInvariant
    }

    // MARK: The corpus (literal streams; TASK-028's shapes + RM ones)

    /// The director-test adversarial storm, verbatim: every event kind,
    /// every layer, coalescing, supersede, hide epochs, handshakes,
    /// moments, queue churn.
    private static let storm: [MomoCharacterEvent] = [
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
        .displayState(ReactionFixtures.displayState(wakefulness: .settling), at: 1.7),
        ReactionFixtures.plan(ReactionKeys.stir, at: 1.8),
        .touchEnded(at: 1.9),
        .appHidden(at: 2.0),
        .appShown(at: 2.1),
        .displayState(
            ReactionFixtures.displayState(momentRequest: .questCompleted), at: 2.2),
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
        .fingertip(offset: .zero, moving: false, at: 3.1),
        .displayState(ReactionFixtures.content, at: 60),
    ]

    /// Coalescer shapes: five identical taps inside one window (run / run
    /// / abbreviated / coalesced / coalesced) plus a superseding stroke.
    private static let coalescerStorm: [MomoCharacterEvent] = [
        .touchBegan(zone: .head, at: 0.5),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.0),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.05),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.1),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.15),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 1.2),
        ReactionFixtures.plan(ReactionKeys.strokeHead, at: 1.4),
        .touchEnded(at: 4.0),
        .displayState(ReactionFixtures.content, at: 10),
    ]

    /// Queue formation and clearing: four one-shots chain in turn, the
    /// fourth drops the oldest; an L2 arrival then clears pending.
    private static let queueChurn: [MomoCharacterEvent] = [
        .touchBegan(zone: .belly, at: 0.5),
        ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.0),
        ReactionFixtures.plan(ReactionKeys.doubleTap, at: 1.1),
        ReactionFixtures.plan(ReactionKeys.cheer, at: 1.2),
        ReactionFixtures.plan(ReactionKeys.decline, at: 1.3),
        ReactionFixtures.plan(ReactionKeys.eating, at: 2.0),
        .touchEnded(at: 2.5),
        .displayState(ReactionFixtures.content, at: 12),
    ]

    /// Hide epochs across phases: hidden mid-reaction, mid-handshake,
    /// mid-moment; every return replays deterministically.
    private static let hideShowMatrix: [MomoCharacterEvent] = [
        .touchBegan(zone: .head, at: 0.5),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 0.6),
        .appHidden(at: 0.8),
        .appShown(at: 1.5),
        ReactionFixtures.plan(ReactionKeys.settling, at: 2.0),
        .displayState(ReactionFixtures.displayState(wakefulness: .settling), at: 2.1),
        .appHidden(at: 2.5),
        .appShown(at: 4.0),
        .displayState(
            ReactionFixtures.displayState(momentRequest: .questCompleted), at: 4.5),
        .appHidden(at: 4.7),
        .appShown(at: 5.2),
        .displayState(ReactionFixtures.content, at: 12),
    ]

    /// Pacer streams: a follow that never rests (deadline cease), a
    /// resting one (solo finish), and a Drowsy round (fixed 8.0).
    private static let pacerNoRest: [MomoCharacterEvent] = [
        ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        .fingertip(offset: CGPoint(x: 30, y: -10), moving: true, at: 2.0),
        .fingertip(offset: CGPoint(x: -20, y: 10), moving: true, at: 8.0),
        .fingertip(offset: CGPoint(x: 10, y: 0), moving: true, at: 14.0),
        .displayState(ReactionFixtures.content, at: 30),
    ]
    private static let pacerRest: [MomoCharacterEvent] = [
        ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        .fingertip(offset: CGPoint(x: 30, y: -10), moving: true, at: 2.0),
        .fingertip(offset: CGPoint(x: 30, y: -10), moving: false, at: 6.0),
        .displayState(ReactionFixtures.content, at: 30),
    ]
    private static let pacerDrowsy: [MomoCharacterEvent] = [
        .displayState(ReactionFixtures.displayState(energy: .drowsy), at: 0.5),
        ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        .fingertip(offset: .zero, moving: false, at: 4.0),
        .displayState(ReactionFixtures.content, at: 30),
    ]

    /// The R4 exception: a press with NO reaction — the L1 glance is
    /// already the §7.3 static touch glance, so the render is
    /// flag-invariant BY DESIGN.
    private static let pressOnly: [MomoCharacterEvent] = [
        .touchBegan(zone: .head, at: 1.0),
        .touchEnded(at: 2.5),
        .displayState(ReactionFixtures.content, at: 10),
    ]

    /// TASK-035 R6: a Done-stop mid-round (invite → input → stop), plus
    /// the stop's no-op twin — a running SETTLE the play-only stop must
    /// leave untouched.
    private static let playStop: [MomoCharacterEvent] = [
        ReactionFixtures.plan(ReactionKeys.playReady, at: 1.0),
        .fingertip(offset: CGPoint(x: 30, y: -10), moving: true, at: 2.0),
        .playStopped(at: 4.0),
        .displayState(ReactionFixtures.content, at: 30),
    ]
    private static let playStopNoRound: [MomoCharacterEvent] = [
        ReactionFixtures.plan(ReactionKeys.settling, at: 1.0),
        .playStopped(at: 2.0),
        .displayState(ReactionFixtures.content, at: 10),
    ]

    /// Long-press holds swept across the input-length band: the end pose
    /// (and thus the RM render) tracks the resolved hold.
    private static func holdSweep(_ hold: Double) -> [MomoCharacterEvent] {
        [
            .touchBegan(zone: .head, at: 0.5),
            ReactionFixtures.plan(ReactionKeys.longPressHead, at: 0.6),
            .touchEnded(at: 0.6 + hold),
            .displayState(ReactionFixtures.content, at: 0.6 + hold + 2.0),
        ]
    }

    // MARK: The twin checks

    /// The event's instant (every corpus event carries one explicitly).
    private func eventTime(_ event: MomoCharacterEvent) -> Double {
        switch event {
        case .touchBegan(_, let at): at
        case .touchEnded(let at): at
        case .fingertip(_, _, let at): at
        case .appHidden(let at): at
        case .appShown(let at): at
        case .displayState(_, let at): at
        case .plan(_, let at): at
        case .playStopped(let at): at
        }
    }

    private func twinCheck(
        _ stream: [MomoCharacterEvent], visibility: Visibility
    ) {
        // (1) Fold twins: whole-state equality — reports included.
        let first = ReactionFixtures.fold(stream)
        let second = ReactionFixtures.fold(stream)
        #expect(first == second)
        #expect(first.reports == second.reports)
        if case .mustDiffer = visibility {
            #expect(!first.reports.isEmpty, "the corpus stream reported nothing")
        }

        // (2) Flag visibility, probed on MID-FLIGHT snapshots: the final
        // state forgets completed layers (they were pruned with their
        // reports), so the probe walks the stream's prefixes and samples
        // each event's wake — exactly what a live session renders.
        var working = MomoDirectorState(displayState: ReactionFixtures.content)
        var differs = false
        for event in stream {
            working.apply(event)
            let t0 = eventTime(event)
            for step in 0...6 {
                let t = t0 + Double(step) * 0.25
                let rm = working.reduceMotionOverlay(at: t)
                let full = working.overlay(at: t)
                switch visibility {
                case .mustDiffer:
                    differs = differs || (rm != full)
                case .pressGlanceInvariant:
                    #expect(rm == full, "the L1 glance moved under RM at t=\(t)")
                }
            }
        }
        if case .mustDiffer = visibility {
            #expect(differs, "RM never diverged — the corpus stream is blind to the flag")
        }

        // (3) Tracker twins: the R5 inputs fold identically from the same
        // stream, prefix by prefix (they never touch the director).
        var trackerA = MomoReduceMotionStateTracker(initial: ReactionFixtures.content)
        var trackerB = trackerA
        for event in stream {
            trackerA.fold(event)
            trackerB.fold(event)
            let t0 = eventTime(event)
            for step in 0...6 {
                let t = t0 + Double(step) * 0.25
                #expect(
                    trackerA.transition(at: t) == trackerB.transition(at: t),
                    "tracker divergence at t=\(t)")
            }
        }
        #expect(trackerA.state == trackerB.state)
    }

    @Test("Twin law: the adversarial storm folds identically and renders RM-visibly")
    func stormTwins() {
        twinCheck(Self.storm, visibility: .mustDiffer)
    }

    @Test("Twin law: the coalescer storm folds identically and renders RM-visibly")
    func coalescerTwins() {
        twinCheck(Self.coalescerStorm, visibility: .mustDiffer)
    }

    @Test("Twin law: queue churn folds identically and renders RM-visibly")
    func queueTwins() {
        twinCheck(Self.queueChurn, visibility: .mustDiffer)
    }

    @Test("Twin law: the hide/show matrix folds identically and renders RM-visibly")
    func hideShowTwins() {
        twinCheck(Self.hideShowMatrix, visibility: .mustDiffer)
    }

    @Test("Twin law: the pacer streams fold identically and render RM-visibly")
    func pacerTwins() {
        twinCheck(Self.pacerNoRest, visibility: .mustDiffer)
        twinCheck(Self.pacerRest, visibility: .mustDiffer)
        twinCheck(Self.pacerDrowsy, visibility: .mustDiffer)
    }

    @Test("Twin law: the Done-stop stream folds identically and renders RM-visibly")
    func playStopTwins() {
        twinCheck(Self.playStop, visibility: .mustDiffer)
        twinCheck(Self.playStopNoRound, visibility: .mustDiffer)
    }

    @Test("Twin law: a press-only stream is flag-INVARIANT (R4's static glance)")
    func pressGlanceInvariantTwins() {
        twinCheck(Self.pressOnly, visibility: .pressGlanceInvariant)
    }

    @Test("Twin law: the hold sweep folds identically at every hold length")
    func holdSweepTwins() {
        for hold in [0.1, 0.5, 0.8, 2.0, 5.5] {
            twinCheck(Self.holdSweep(hold), visibility: .mustDiffer)
        }
    }
}
