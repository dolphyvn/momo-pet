import MomoCore
import Testing

@testable import MomoCharacter

// MARK: - The event-born moment queue (TASK-036 R2/R8/R10; FR-16)

/// The `.moments` door: batches of engine-minted moments enqueue FIFO,
/// advance exactly at the three sites (an idle fold, the L4 completion,
/// `appShown`), report each moment exactly once, and never drop a moment
/// while hidden — all over the pure fold, every instant explicit. The
/// durations the timing math cites are `MomoMoments`' authored values
/// (untouched): quest sparkle 1.0 s, celebration 1.8 s, greetings ≤ 2.0 s.
struct MomoMomentQueueTests {

    // MARK: FIFO order + the completion advance site

    /// A two-moment batch plays in causal order: the quest sparkle first
    /// (1.0 s), the stage celebration starting EXACTLY at the sparkle's
    /// completion instant (the vacated slot releases the queue), each
    /// reporting once at its own end — and `drainReports` hands both over
    /// exactly once.
    @Test("A batch plays FIFO; the second starts at the first's completion instant")
    func fifoOrderAndCompletionAdvance() {
        var state = ReactionFixtures.fold([
            .moments([.questCompleted, .bondStageReached(.gettingClose)], at: 5.0),
        ])
        // The head plays now; the tail waits in the queue.
        #expect(state.moment?.moment == .questCompleted)
        #expect(abs(state.moment!.start - 5.0) < 1e-9)
        #expect(state.pendingMoments == [.bondStageReached(.gettingClose)])
        #expect(state.reports.isEmpty)

        // The completing fold vacates the slot and releases the tail at
        // the completion instant, 5.0 + 1.0.
        state.apply(.displayState(ReactionFixtures.content, at: 6.0))
        #expect(state.moment?.moment == .bondStageReached(.gettingClose))
        #expect(abs(state.moment!.start - 6.0) < 1e-9)
        let sparkle = ReactionFixtures.reports(matching: "moment:quest", in: state)
        #expect(sparkle.count == 1)
        #expect(abs(sparkle[0].at - 6.0) < 1e-9)

        // The celebration reports at 6.0 + 1.8.
        state.apply(.displayState(ReactionFixtures.content, at: 7.8))
        let celebration = ReactionFixtures.reports(
            matching: "moment:bond:gettingClose", in: state)
        #expect(celebration.count == 1)
        #expect(abs(celebration[0].at - 7.8) < 1e-9)
        #expect(state.moment == nil)
        #expect(state.pendingMoments.isEmpty)

        // The drain is exactly-once: everything, then nothing.
        var drained = state
        let entries = drained.drainReports()
        #expect(entries.count == 2)
        #expect(drained.drainReports().isEmpty)
    }

    // MARK: Hidden accumulation

    /// While hidden nothing plays and nothing drops: batches accumulate in
    /// order, no completion resolves (the hidden app is fully paused), and
    /// `appShown` releases the queue FIFO from the head.
    @Test("Hidden folds accumulate; appShown releases the queue FIFO")
    func hiddenAccumulationAndRelease() {
        var state = ReactionFixtures.fold([
            .appHidden(at: 1.0),
            .moments([.questCompleted], at: 1.1),
            .moments([.bondStageReached(.bestFriends)], at: 1.2),
        ])
        #expect(state.moment == nil)
        #expect(state.pendingMoments == [.questCompleted, .bondStageReached(.bestFriends)])
        #expect(state.reports.isEmpty)

        // The show releases the head at the show instant.
        state.apply(.appShown(at: 2.0))
        #expect(state.moment?.moment == .questCompleted)
        #expect(abs(state.moment!.start - 2.0) < 1e-9)
        #expect(state.pendingMoments == [.bondStageReached(.bestFriends)])

        // And the released batch runs the full FIFO chain to its reports.
        state.apply(.displayState(ReactionFixtures.content, at: 3.0))
        state.apply(.displayState(ReactionFixtures.content, at: 4.8))
        let sparkle = ReactionFixtures.reports(matching: "moment:quest", in: state)
        #expect(sparkle.count == 1)
        #expect(abs(sparkle[0].at - 3.0) < 1e-9)
        let celebration = ReactionFixtures.reports(
            matching: "moment:bond:bestFriends", in: state)
        #expect(celebration.count == 1)
        #expect(abs(celebration[0].at - 4.8) < 1e-9)
    }

    // MARK: The appShown advance site behind a deferred greeting

    /// A moment request folded while hidden defers; `appShown` re-takes
    /// the slot with the STATE-born greeting FIRST and the queued
    /// event-born moments release only after the greeting's own completion
    /// (the two doors share one slot; greeting door dedupe untouched).
    @Test("A deferred state-born greeting replays first; the queue follows it")
    func applyShownOrderingBehindDeferredGreeting() {
        var state = ReactionFixtures.fold([
            .appHidden(at: 1.0),
            .displayState(
                ReactionFixtures.displayState(momentRequest: .greeting(.welcomeBack)),
                at: 1.1),
            .moments([.questCompleted, .bondStageReached(.gettingClose)], at: 1.2),
        ])
        #expect(state.moment == nil)
        #expect(state.pendingMoments == [.questCompleted, .bondStageReached(.gettingClose)])

        // The show starts the DEFERRED greeting (1.2 s); the queue waits.
        state.apply(.appShown(at: 3.0))
        #expect(state.moment?.moment == .greeting(.welcomeBack))
        #expect(abs(state.moment!.start - 3.0) < 1e-9)
        #expect(state.pendingMoments.count == 2)

        // The greeting completes at 3.0 + 1.2; the queue's head starts at
        // exactly that instant.
        state.apply(.displayState(
            ReactionFixtures.displayState(momentRequest: .greeting(.welcomeBack)),
            at: 4.6))
        let greeting = ReactionFixtures.reports(
            matching: "moment:greeting:welcomeBack", in: state)
        #expect(greeting.count == 1)
        #expect(abs(greeting[0].at - 4.2) < 1e-9)
        #expect(state.moment?.moment == .questCompleted)
        #expect(abs(state.moment!.start - 4.2) < 1e-9)

        // Then the rest of the chain, unchanged.
        state.apply(.displayState(ReactionFixtures.content, at: 5.2))
        state.apply(.displayState(ReactionFixtures.content, at: 7.0))
        let celebration = ReactionFixtures.reports(
            matching: "moment:bond:gettingClose", in: state)
        #expect(celebration.count == 1)
        #expect(abs(celebration[0].at - 7.0) < 1e-9)
    }

    // MARK: Empty batch + cross-fold queueing

    /// An empty batch is a full no-op: no enqueue, no advance, no state.
    @Test("An empty batch is a no-op")
    func emptyBatchNoOp() {
        let state = ReactionFixtures.fold([
            .moments([], at: 1.0),
            .moments([], at: 1.5),
            .displayState(ReactionFixtures.content, at: 2.0),
        ])
        #expect(state.moment == nil)
        #expect(state.pendingMoments.isEmpty)
        #expect(state.reports.isEmpty)
    }

    /// A batch folded while the slot is BUSY waits whole: the queue grows
    /// across folds and drains FIFO at the completions.
    @Test("A batch folded mid-moment queues whole and drains FIFO")
    func crossFoldQueueing() {
        var state = ReactionFixtures.fold([
            .moments([.questCompleted], at: 1.0),
            .moments([.bondStageReached(.newFriends)], at: 1.5),
        ])
        #expect(state.moment?.moment == .questCompleted)
        #expect(state.pendingMoments == [.bondStageReached(.newFriends)])
        state.apply(.displayState(ReactionFixtures.content, at: 2.0))
        state.apply(.displayState(ReactionFixtures.content, at: 3.8))
        let sparkle = ReactionFixtures.reports(matching: "moment:quest", in: state)
        #expect(sparkle.count == 1)
        #expect(abs(sparkle[0].at - 2.0) < 1e-9)
        let celebration = ReactionFixtures.reports(
            matching: "moment:bond:newFriends", in: state)
        #expect(celebration.count == 1)
        #expect(abs(celebration[0].at - 3.8) < 1e-9)
    }

    // MARK: The per-outcome cap, end to end

    /// The engine mints at most three moments per outcome (≤ 2 quest +
    /// ≤ 1 bond, TASK-018's cap): a maximal batch plays all three FIFO
    /// through and reports each exactly once — nothing beyond the cap
    /// exists to queue, and the queue empties.
    @Test("A maximal three-moment batch drains fully, each reported once")
    func maximalBatchDrains() {
        var state = ReactionFixtures.fold([
            .moments(
                [.questCompleted, .questCompleted, .bondStageReached(.soulCompanions)],
                at: 1.0),
        ])
        #expect(state.pendingMoments == [.questCompleted, .bondStageReached(.soulCompanions)])
        for t in [2.0, 3.0, 4.8] {
            state.apply(.displayState(ReactionFixtures.content, at: t))
        }
        let sparkles = ReactionFixtures.reports(matching: "moment:quest", in: state)
        #expect(sparkles.count == 2)
        #expect(abs(sparkles[0].at - 2.0) < 1e-9)
        #expect(abs(sparkles[1].at - 3.0) < 1e-9)
        let celebration = ReactionFixtures.reports(
            matching: "moment:bond:soulCompanions", in: state)
        #expect(celebration.count == 1)
        #expect(abs(celebration[0].at - 4.8) < 1e-9)
        #expect(state.moment == nil)
        #expect(state.pendingMoments.isEmpty)
    }

    // MARK: R8 — the RM tracker fold (harmlessness by construction)

    /// The Reduce Motion tracker folds the SAME event stream; a `.moments`
    /// event must leave it untouched — no state change, no pending
    /// crossfade window (the moment is motion-only, never a state change).
    @Test("The RM tracker folds .moments harmlessly (R8)")
    func reduceMotionTrackerFold() {
        var tracker = MomoReduceMotionStateTracker(initial: ReactionFixtures.content)
        tracker.fold(.moments(
            [.questCompleted, .bondStageReached(.gettingClose)], at: 1.0))
        tracker.fold(.moments([], at: 1.5))
        #expect(tracker.state == ReactionFixtures.content)
        #expect(tracker.transition(at: 2.0) == nil)
    }
}
