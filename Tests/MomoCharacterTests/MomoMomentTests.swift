import CoreGraphics
import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The L4 moments (TASK-028 R5; 04 §4.1 row 4, §4.3, ADR-010)

/// The rare moments: authored durations inside §4.3's bands, the
/// celebration's single soft overshoot ≤ 8 %, exactly-once
/// `momentFinished`, the persistent-request dedupe, and the hide-pauses /
/// return-replays-from-0 law. All instants explicit; no clock, no RNG.
struct MomoMomentTests {

    // MARK: Durations (§4.3's bands)

    @Test("Moment durations pin their authored rows inside §4.3's bands")
    func durationPins() {
        // Quest sparkle: 0.9–1.2 s, AUTHORED 1.0.
        #expect(MomoMoments.questSparkleSeconds == 1.0)
        #expect(MomoMoments.duration(for: .questCompleted) == 1.0)
        // Stage celebration: 1.6–2.0 s, AUTHORED 1.8.
        #expect(MomoMoments.celebrationSeconds == 1.8)
        #expect(MomoMoments.duration(for: .bondStageReached(.soulCompanions)) == 1.8)
        // The four greetings: each ≤ 2.0 s, AUTHORED per kind.
        #expect(MomoMoments.greetingSeconds(for: .freshMorning) == 1.6)
        #expect(MomoMoments.greetingSeconds(for: .welcomeBack) == 1.2)
        #expect(MomoMoments.greetingSeconds(for: .missedYou) == 2.0)
        #expect(MomoMoments.greetingSeconds(for: .nightGlance) == 1.4)
        for kind in [GreetingKind.freshMorning, .welcomeBack, .missedYou,
                     .nightGlance] {
            #expect(MomoMoments.greetingSeconds(for: kind) <= 2.0)
        }
    }

    // MARK: The celebration's §7.2 discipline

    @Test("The celebration is ONE soft overshoot, never past the 8 % cap")
    func celebrationOvershootDiscipline() {
        let samples = samples(until: MomoMoments.celebrationSeconds, count: 240)
            .map {
                MomoMoments.motion(for: .bondStageReached(.soulCompanions),
                                   elapsed: $0).bodyScaleYMultiplier
            }
        #expect(MomoCurves.isSingleSoftOvershoot(
            samples, target: 1, cap: MomoCurves.celebrationOvershootMax))
        // The bounce genuinely settles (it is an overshoot, not a hold).
        let late = MomoMoments.motion(
            for: .bondStageReached(.soulCompanions),
            elapsed: MomoMoments.celebrationSeconds * 0.9)
        #expect(late.bodyScaleYMultiplier == 1)
    }

    @Test("The missedYou greeting bounces softly inside the celebration cap")
    func missedYouBounceDiscipline() {
        let samples = samples(until: MomoMoments.greetingSeconds(for: .missedYou),
                              count: 240)
            .map {
                MomoMoments.motion(for: .greeting(.missedYou),
                                   elapsed: $0).bodyScaleYMultiplier
            }
        #expect(MomoCurves.isSingleSoftOvershoot(
            samples, target: 1, cap: MomoCurves.celebrationOvershootMax))
    }

    // MARK: Exactly-once completion + the request dedupe

    @Test("A moment completes exactly once at its authored duration")
    func momentCompletesOnce() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 1.0),
        ])
        // Mid-render: the sparkle is up; no report yet.
        #expect(state.overlay(at: 1.5).sparkleA != .rest)
        let finishes: (MomoDirectorState) -> [MomoReportEntry] = { state in
            state.reports.filter {
                if case .momentFinished = $0.report { return true }
                return false
            }
        }
        // Not yet at 2.0…
        let early = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 1.9)], into: state)
        #expect(finishes(early).isEmpty)
        // …the first fold past 2.0 resolves the report at the end instant.
        let done = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 2.0)], into: state)
        #expect(finishes(done).count == 1)
        #expect(abs(finishes(done).first!.at - 2.0) < 1e-9)
    }

    /// The dedupe law: the display state keeps its request until the next
    /// one — re-delivering the IDENTICAL request re-renders nothing.
    @Test("A re-delivered identical request never restarts the moment")
    func momentDedupe() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(momentRequest: .greeting(.welcomeBack)),
                at: 1.0),
            .displayState(
                ReactionFixtures.displayState(momentRequest: .greeting(.welcomeBack)),
                at: 1.3),
        ])
        // The greeting still runs on its ORIGINAL clock (1.0 + 1.2 = 2.2),
        // not restarted at 1.3.
        let done = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(momentRequest: .greeting(.welcomeBack)),
                at: 3.0)], into: state)
        #expect(done.overlay(at: 2.25) == .identity)
        let finishes = done.reports.filter {
            if case .momentFinished = $0.report { return true }
            return false
        }
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 2.2) < 1e-9)
    }

    // MARK: Hide pauses; the return replays from 0 (ADR-010)

    @Test("Hide pauses a running moment; the return replays it from 0")
    func momentReplaysFromZero() {
        let state = ReactionFixtures.fold([
            .displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 1.0),
            .appHidden(at: 1.4),
        ])
        // Fully paused: a fold arriving while hidden completes nothing —
        // the moment's report does not fire on wall-clock time.
        let hiddenFold = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 9.0)], into: state)
        #expect(hiddenFold.reports.isEmpty)
        // The return restarts the clock: the sparkle runs 3.0 → 4.0. The
        // replayed render is sampled on the shown state BEFORE any flush
        // fold (a later fold past 4.0 completes and clears the moment).
        let running = ReactionFixtures.fold(
            [.appShown(at: 3.0)], into: state)
        #expect(running.overlay(at: 3.5).sparkleA != .rest)
        // The flush fold resolves the report at the replayed end instant,
        // and the completed moment leaves the overlay.
        let shown = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(momentRequest: .questCompleted),
                at: 5.0)], into: running)
        #expect(shown.overlay(at: 4.05) == .identity)
        let finishes = shown.reports.filter {
            if case .momentFinished = $0.report { return true }
            return false
        }
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 4.0) < 1e-9)
    }

    /// A request that ARRIVES while hidden is deferred: the return starts
    /// it fresh (the newest request wins if several landed while hidden).
    @Test("A request arriving while hidden starts on the return")
    func momentDeferredWhileHidden() {
        let state = ReactionFixtures.fold([
            .appHidden(at: 1.0),
            .displayState(
                ReactionFixtures.displayState(momentRequest: .greeting(.freshMorning)),
                at: 2.0),
        ])
        #expect(state.overlay(at: 2.5) == .identity)
        // The return starts it fresh: 5.0 → 6.6. Sample the replayed
        // render on the shown state before any flush fold.
        let running = ReactionFixtures.fold(
            [.appShown(at: 5.0)], into: state)
        #expect(running.overlay(at: 5.5).earLeftDegrees != 0)
        // The flush fold resolves the exactly-once completion.
        let shown = ReactionFixtures.fold(
            [.displayState(
                ReactionFixtures.displayState(momentRequest: .greeting(.freshMorning)),
                at: 7.0)], into: running)
        let finishes = shown.reports.filter {
            if case .momentFinished = $0.report { return true }
            return false
        }
        #expect(finishes.count == 1)
        #expect(abs(finishes.first!.at - 6.6) < 1e-9)
    }
}
