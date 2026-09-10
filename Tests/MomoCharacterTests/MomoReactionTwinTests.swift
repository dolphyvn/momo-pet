import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - Whole-trajectory determinism (TASK-028 R8; 04 §7.4 rule 8)

/// The twin-equality property: folding the SAME event list into two fresh
/// director states yields equal states, equal overlay trajectories, and
/// equal report logs — the whole-trajectory determinism law. The
/// divergence probes keep the equality honest (it can actually fail).
/// No RNG, no ambient time: every list is a literal.
struct MomoReactionTwinTests {

    /// A storm covering every event kind and every layer — one literal
    /// stream, folded identically twice.
    private static let stream: [MomoCharacterEvent] = [
        .touchBegan(zone: .head, at: 0.5),
        ReactionFixtures.plan(ReactionKeys.tapHead, at: 0.6),
        ReactionFixtures.plan(ReactionKeys.strokeBelly, at: 0.8),
        ReactionFixtures.plan(ReactionKeys.strokeBelly, at: 1.0),
        ReactionFixtures.plan(ReactionKeys.eating, at: 1.2),
        ReactionFixtures.plan(ReactionKeys.tapBelly, at: 1.4),
        .touchEnded(at: 1.5),
        .displayState(
            ReactionFixtures.displayState(momentRequest: .questCompleted),
            at: 1.6),
        .fingertip(offset: CGPoint(x: 60, y: -20), moving: true, at: 1.7),
        ReactionFixtures.plan(ReactionKeys.playReady, at: 1.8),
        .fingertip(offset: CGPoint(x: 40, y: 0), moving: true, at: 4.5),
        .fingertip(offset: CGPoint(x: 40, y: 0), moving: false, at: 6.0),
        .appHidden(at: 6.5),
        .appShown(at: 8.0),
        .displayState(
            ReactionFixtures.displayState(wakefulness: .waking), at: 8.1),
        .displayState(
            ReactionFixtures.displayState(
                wakefulness: .settling,
                momentRequest: .greeting(.nightGlance)),
            at: 12.0),
        ReactionFixtures.plan(ReactionKeys.longPressHead, at: 12.1),
        .touchBegan(zone: .head, at: 12.1),
        .touchEnded(at: 13.0),
        .displayState(ReactionFixtures.content, at: 30.0),
    ]

    @Test("Twins: the same stream folds to equal states, overlays, and reports")
    func twinEquality() {
        let first = ReactionFixtures.fold(Self.stream)
        let second = ReactionFixtures.fold(Self.stream)
        // Whole-state equality (including the report log — MomoReportEntry
        // equates on identity+instant).
        #expect(first == second)
        // The overlay TRAJECTORIES match sample-for-sample.
        for t in samples(until: 30, count: 300) {
            #expect(first.overlay(at: t) == second.overlay(at: t),
                    "overlay divergence at t=\(t)")
        }
        // The report logs match entry-for-entry, instants included.
        #expect(first.reports.count == second.reports.count)
        for (a, b) in zip(first.reports, second.reports) {
            #expect(a == b)
        }
        // The fold did real work: reports exist, layers were exercised.
        #expect(!first.reports.isEmpty)
    }

    @Test("Divergence: a single shifted event breaks the twin equality")
    func divergenceIsObservable() {
        // A minimal pair differing by ONE arrival instant: the identical
        // tap at 0.55 instead of 0.6 opens its coalescing window earlier,
        // so the folded states differ (equality is not vacuous).
        let base = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 0.5),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 0.6),
        ])
        let shifted = ReactionFixtures.fold([
            .touchBegan(zone: .head, at: 0.5),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 0.55),
        ])
        #expect(base != shifted)
        #expect(base.coalescer?.windowStart == 0.6)
        #expect(shifted.coalescer?.windowStart == 0.55)
    }

    @Test("Pause discipline: while hidden, folds change no reports and no rendering")
    func pauseDiscipline() {
        // The meal is state-backed: the display state says eating (the
        // restart-on-return reads the display state, not the plan log).
        let meal = ReactionFixtures.displayState(activity: .eating)
        let events: [MomoCharacterEvent] = [
            .displayState(meal, at: 0.5),
            ReactionFixtures.plan(ReactionKeys.eating, at: 1.0),
            .appHidden(at: 2.0),
        ]
        let hidden = ReactionFixtures.fold(events)
        #expect(hidden.hidden)
        // Extra folds arriving while hidden — even far past the meal's
        // end — resolve nothing and report nothing (§7.4 rule 8). The
        // display state keeps saying eating throughout.
        let stalled = ReactionFixtures.fold([
            .displayState(meal, at: 50.0),
            .fingertip(offset: CGPoint(x: 10, y: 10), moving: true, at: 60.0),
            ReactionFixtures.plan(ReactionKeys.tapHead, at: 61.0),
        ], into: hidden)
        #expect(stalled.reports == hidden.reports)
        // …and the return replays deterministically: two identical
        // show folds produce identical states.
        let shownA = ReactionFixtures.fold(
            [.appShown(at: 70.0)], into: hidden)
        let shownB = ReactionFixtures.fold(
            [.appShown(at: 70.0)], into: hidden)
        #expect(shownA == shownB)
        #expect(shownA.overlay(at: 70.5) == shownB.overlay(at: 70.5))
        // The meal restarted on the return (the engine still says eating).
        if case .clip(let restarted) = shownA.stateLayer {
            #expect(restarted.key == .eating)
            #expect(restarted.start == 70.0)
        } else {
            Issue.record("the meal did not restart on return")
        }
    }
}
