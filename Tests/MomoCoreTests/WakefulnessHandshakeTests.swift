import Foundation
import Testing
@testable import MomoCore

/// The wakefulness machine's handshake half: report application under INV-8,
/// idempotent completion, cancellation, stale/late tolerance, the wake-stretch
/// mint, and the fold's never-stranded rule (05 §4.7, 04 §9.2; TASK-015
/// Requirements 5–7).
///
/// Interaction-during-settling is pinned structurally: `EngineState` has a
/// single `pendingHandshake` slot, so "declines warm, never queues" holds by
/// construction — the interaction leaves the settle handshake untouched.
/// (TASK-016 filled the response half: the warm-decline plan is asserted in
/// `interactionDuringSettleDoesNotQueue`; the play round's unified cease is
/// asserted in `playRoundFinishedClearsTokenOnly`.)
@Suite("Wakefulness + handshakes — INV-8, idempotency, mint")
struct WakefulnessHandshakeTests {

    // MARK: - Fixtures

    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    private var utcCalendar: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        return gregorian
    }

    private func instant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func quest(_ id: QuestID) -> QuestProgress {
        QuestProgress(questID: id, progress: 0, completed: false)!
    }

    private func state(
        wakefulness: Wakefulness,
        activity: Activity? = nil,
        pending: Handshake? = nil,
        dayKey: String = "2026-09-08",
        lastEvaluatedAt: Instant
    ) -> EngineState {
        let pet = Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!
        let petState = PetState(
            mood: 60,
            energy: 80,
            bond: 0,
            wakefulness: wakefulness,
            activity: activity,
            lastFedAt: nil,
            satietyPhase: .hungry
        )!
        let day = DayRecord(
            dayKey: dayKey,
            feedCount: 0,
            playCount: 0,
            careCount: 0,
            patCount: 0,
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: 0
        )!
        return EngineState(
            pet: pet,
            state: petState,
            days: [day],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: pending,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: lastEvaluatedAt,
            lastEvaluatedAt: lastEvaluatedAt,
            lastGreeting: nil
        )
    }

    /// A report through the public entry point, folding from `lastEvaluatedAt`
    /// to the injected clock's instant — zero elapsed unless the test says so.
    private func report(_ state: EngineState, _ report: CharacterReport, seed: UInt64 = 7) -> EngineOutcome {
        var rng = SeededGenerator(seed: seed)
        return reduce(
            state,
            .characterReport(report),
            clock: ManualEngineClock(at: state.lastEvaluatedAt),
            calendar: utcCalendar,
            rng: &rng
        )
    }

    private func interaction(_ state: EngineState, timestamp: Instant, id: UUID = UUID()) -> EngineOutcome {
        var rng = SeededGenerator(seed: 7)
        let intent = InteractionIntent(id: id, source: .iPhone, localDayKey: "2026-09-08", timestamp: timestamp, kind: .pat(gesture: .tap, zone: .head))
        return reduce(state, .interaction(intent), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
    }

    // MARK: - Legal transitions apply (the §4.7 diagram)

    @Test("settleFinished: settling → asleep, token cleared, idempotent on repeat")
    func settleFinishedAppliesAndIsIdempotent() {
        let settleToken = UUID()
        let settling = state(wakefulness: .settling, pending: Handshake(kind: .settle, token: settleToken), lastEvaluatedAt: instant("2026-09-08T21:00:00Z"))
        let outcome = report(settling, .settleFinished)
        #expect(outcome.newState.state.wakefulness == .asleep)
        #expect(outcome.newState.pendingHandshake == nil)
        #expect(outcome.changed)

        // Duplicate delivery: nothing pending, nothing happens (tolerated).
        let duplicate = report(outcome.newState, .settleFinished)
        #expect(duplicate.newState == outcome.newState)
        #expect(!duplicate.changed)
    }

    @Test("wakeFinished: waking → awake (never cancelled, completes on return)")
    func wakeFinishedApplies() {
        let waking = state(wakefulness: .waking, pending: Handshake(kind: .wake, token: UUID()), lastEvaluatedAt: instant("2026-09-08T07:10:00Z"))
        let outcome = report(waking, .wakeFinished)
        #expect(outcome.newState.state.wakefulness == .awake)
        #expect(outcome.newState.pendingHandshake == nil)
        #expect(outcome.changed)
    }

    @Test("REVIEW-TASK-016 MINOR-1: a zero-elapsed wakeFinished after a mid-waking nap preserves the counted nap")
    func wakeFinishedAfterMidWakingNapPreservesNap() {
        // The waking stretch accepts a band-gated nap (no token — the fold
        // owns its completion, TASK-016 Req 9). A zero-elapsed wakeFinished
        // skips reduce's fold (from >= to), so the handshake completion must
        // not erase the nap: pre-fix, `complete` cleared `activity`, voiding
        // a nap whose careCount already stood and dropping
        // FoldRules.napRestoreEnergy with it.
        let fixture = InteractionFixture()
        let wakeToken = UUID()
        let waking = fixture.state(
            dayKey: "2026-09-08",
            energy: 30, // Drowsy — the nap is offered
            wakefulness: .waking,
            pendingHandshake: Handshake(kind: .wake, token: wakeToken),
            lastEvaluatedAt: instant("2026-09-08T07:10:00Z")
        )
        let nap = fixture.send(waking, .nap, at: instant("2026-09-08T07:10:00Z"), dayKey: "2026-09-08")
        #expect(nap.newState.state.activity == .napping)
        #expect(nap.newState.state.wakefulness == .waking)
        #expect(nap.newState.state.energy == 30) // the +20 is the fold's, at nap end
        #expect(nap.newState.days.first?.careCount == 1)
        #expect(nap.newState.pendingHandshake == Handshake(kind: .wake, token: wakeToken))

        let finished = fixture.report(nap.newState, .wakeFinished, at: instant("2026-09-08T07:10:00Z"))
        #expect(finished.newState.state.wakefulness == .awake)
        #expect(finished.newState.state.activity == .napping) // THE PIN — preserved, not erased
        #expect(finished.newState.state.energy == 30) // restored by the fold later, never voided
        #expect(finished.newState.pendingHandshake == nil)

        // The next positive-elapsed fold then completes the nap exactly as
        // TASK-015 pinned it: +FoldRules.napRestoreEnergy, the activity
        // clears, landing .waking (the fold end is outside the night window).
        var rng = SeededGenerator(seed: 7)
        let completed = reduce(
            finished.newState,
            .evaluate(now: instant("2026-09-08T08:10:00Z")),
            clock: ManualEngineClock(),
            calendar: fixture.calendar,
            rng: &rng
        )
        #expect(completed.newState.state.activity == nil)
        #expect(completed.newState.state.energy == 30 + FoldRules.napRestoreEnergy)
        #expect(completed.newState.state.wakefulness == .waking)
    }

    @Test("playRoundFinished: the unified cease — effects + count once, token and activity cleared")
    func playRoundFinishedClearsTokenOnly() {
        // TASK-016 supersession (in place, per the contract): the "no effect
        // arithmetic yet" pin WAS TASK-016's seam — the round's effects now
        // land at this cease instant: energy −10, mood +6 (the day's first
        // round → curve ×1.0), playCount +1 on the cease's ledger day, the
        // activity clears with the round, the token with the handshake.
        let playing = state(wakefulness: .awake, activity: .playing, pending: Handshake(kind: .play, token: UUID()), lastEvaluatedAt: instant("2026-09-08T10:00:00Z"))
        let outcome = report(playing, .playRoundFinished)
        #expect(outcome.newState.state.wakefulness == .awake) // play never moves wakefulness
        #expect(outcome.newState.state.activity == nil)
        #expect(outcome.newState.pendingHandshake == nil)
        #expect(outcome.newState.state.energy == playing.state.energy + InteractionRules.playRoundEnergyDelta)
        #expect(outcome.newState.state.mood == playing.state.mood + InteractionRules.playRoundMoodDelta)
        #expect(outcome.newState.days.first?.playCount == 1)
        // And a second report finds nothing pending — never double-applies
        // (the duplicate is the exact no-op: no arithmetic, no count).
        let duplicate = report(outcome.newState, .playRoundFinished)
        #expect(duplicate.newState == outcome.newState)
    }

    // MARK: - Cancellation + stale/late tolerance (INV-8 rejections un-strand)

    @Test("handshakeCancelled(.settle) preempts settling to awake (§4.7); other cancellations clear kind-only")
    func cancellationMatchesKindOnly() {
        // §4.7's preemption edge (REVIEW-TASK-015 MINOR-2): a cancelled
        // settle from .settling restores .awake — cancellation exists so the
        // engine is never stranded in an intermediate wakefulness (04 §9.2).
        let settleToken = UUID()
        let settling = state(wakefulness: .settling, pending: Handshake(kind: .settle, token: settleToken), lastEvaluatedAt: instant("2026-09-08T21:00:00Z"))
        let cancelled = report(settling, .handshakeCancelled(.settle))
        #expect(cancelled.newState.pendingHandshake == nil)
        #expect(cancelled.newState.state.wakefulness == .awake)
        // Idempotent: a second cancellation finds nothing pending — no-op.
        #expect(report(cancelled.newState, .handshakeCancelled(.settle)).newState == cancelled.newState)

        // A different kind pending: no-op. Nothing pending: no-op.
        let playing = state(wakefulness: .awake, pending: Handshake(kind: .play, token: UUID()), lastEvaluatedAt: instant("2026-09-08T10:00:00Z"))
        #expect(report(playing, .handshakeCancelled(.settle)).newState == playing)
        let idle = state(wakefulness: .awake, lastEvaluatedAt: instant("2026-09-08T10:00:00Z"))
        #expect(report(idle, .handshakeCancelled(.play)).newState == idle)
    }

    @Test("stale report: the illegal transition is REJECTED and the dead token is cleared")
    func staleReportDiscardedAndUnstrands() {
        // The fold already landed .asleep, but a .settle token lingers in
        // state: settling→? — the pet has moved PAST the report's source.
        let stranded = state(wakefulness: .asleep, pending: Handshake(kind: .settle, token: UUID()), lastEvaluatedAt: instant("2026-09-08T23:00:00Z"))
        let outcome = report(stranded, .settleFinished)
        #expect(outcome.newState.state.wakefulness == .asleep) // INV-8: no transition
        #expect(outcome.newState.pendingHandshake == nil) // …but nothing strands

        // Same rejection while .awake with a stale settle token.
        let awakeWithToken = state(wakefulness: .awake, pending: Handshake(kind: .settle, token: UUID()), lastEvaluatedAt: instant("2026-09-08T10:00:00Z"))
        let rejected = report(awakeWithToken, .settleFinished)
        #expect(rejected.newState.state.wakefulness == .awake)
        #expect(rejected.newState.pendingHandshake == nil)
    }

    @Test("a late report after the fold cleared the token is a tolerated no-op")
    func lateReportAfterFoldClearance() {
        // Fold 21:30 → 23:00 crossed night onset: the settle token was
        // cleared fold-side; the choreography's report arrives anyway.
        let settling = state(wakefulness: .settling, pending: Handshake(kind: .settle, token: UUID()), lastEvaluatedAt: instant("2026-09-08T21:30:00Z"))
        var rng = SeededGenerator(seed: 7)
        let folded = reduce(settling, .evaluate(now: instant("2026-09-08T23:00:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(folded.newState.state.wakefulness == .asleep)
        #expect(folded.newState.pendingHandshake == nil)

        var lateRng = SeededGenerator(seed: 7)
        let late = reduce(folded.newState, .characterReport(.settleFinished), clock: ManualEngineClock(at: instant("2026-09-08T23:05:00Z")), calendar: utcCalendar, rng: &lateRng)
        #expect(late.newState.state.wakefulness == .asleep) // no illegal flipping
        #expect(late.newState.pendingHandshake == nil)
        #expect(late.response == nil)
        #expect(late.moments.isEmpty)
    }

    // MARK: - Interactions during settling: warm decline, never queued

    @Test("interaction during settling leaves the settle handshake untouched (nothing queues)")
    func interactionDuringSettleDoesNotQueue() {
        let settleToken = UUID()
        let settling = state(wakefulness: .settling, pending: Handshake(kind: .settle, token: settleToken), lastEvaluatedAt: instant("2026-09-08T21:00:00Z"))
        let outcome = interaction(settling, timestamp: instant("2026-09-08T21:01:00Z"))
        // The single-slot design makes queuing unrepresentable: the pending
        // handshake is EXACTLY the settle handshake, not replaced, not stacked.
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .settle, token: settleToken))
        // TASK-016 supersession (in place, per the contract — "extends
        // TASK-015's pin"): the warm-decline plan now EXISTS — the settling
        // soft-stir (touch is never refused; it just never queues).
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.touch.00", haptic: nil))
        #expect(outcome.moments.isEmpty)
        #expect(outcome.newState.state.wakefulness == .settling)
        // And the settle choreography still completes normally afterwards.
        let finished = report(outcome.newState, .settleFinished)
        #expect(finished.newState.state.wakefulness == .asleep)
        #expect(finished.newState.pendingHandshake == nil)
    }

    // MARK: - The wake-stretch mint (§4.3 closing / §4.7)

    @Test("morning fold lands .waking silently; the NEXT event mints the wake handshake")
    func wakeStretchMintDefersPastTheFold() {
        var rng = SeededGenerator(seed: 0xE220A8397B1DCDAF)
        var twin = SeededGenerator(seed: 0xE220A8397B1DCDAF)

        let asleep = state(wakefulness: .asleep, lastEvaluatedAt: instant("2026-09-08T06:30:00Z"))
        let landingFold = reduce(asleep, .evaluate(now: instant("2026-09-08T07:15:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(landingFold.newState.state.wakefulness == .waking)
        #expect(landingFold.newState.pendingHandshake == nil) // nothing was listening at 07:00
        #expect(rng.state == twin.state) // the landing fold consumed ZERO draws

        // The next in-session event finds .waking with nothing pending → mint.
        let nextEvent = reduce(landingFold.newState, .evaluate(now: instant("2026-09-08T07:20:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        let minted = nextEvent.newState.pendingHandshake
        #expect(minted != nil)
        #expect(minted?.kind == .wake)

        // Exactly two draws were consumed (16 bytes = 2 × 8).
        _ = twin.next(); _ = twin.next()
        #expect(rng.state == twin.state)

        // And the mint does not repeat while the handshake is pending.
        let again = reduce(nextEvent.newState, .evaluate(now: instant("2026-09-08T07:25:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(again.newState.pendingHandshake == minted)
    }

    @Test("minted tokens are seed-deterministic and seed-sensitive (injected rng, never UUID())")
    func tokensAreDeterministicPerSeed() {
        func mintedToken(_ seed: UInt64) -> UUID {
            let asleep = state(wakefulness: .asleep, lastEvaluatedAt: instant("2026-09-08T06:30:00Z"))
            var rng = SeededGenerator(seed: seed)
            let first = reduce(asleep, .evaluate(now: instant("2026-09-08T07:15:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
            let second = reduce(first.newState, .evaluate(now: instant("2026-09-08T07:20:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
            return second.newState.pendingHandshake!.token
        }
        #expect(mintedToken(42) == mintedToken(42)) // same seed → same token (FR-13 AC-3)
        #expect(mintedToken(42) != mintedToken(43)) // different seed → different token
    }

    @Test("a cancelled wake handshake is replaced by a FRESH generation on the same event")
    func cancelledWakeRecovers() {
        let original = UUID()
        let waking = state(wakefulness: .waking, pending: Handshake(kind: .wake, token: original), lastEvaluatedAt: instant("2026-09-08T07:10:00Z"))
        let cancelled = report(waking, .handshakeCancelled(.wake))
        #expect(cancelled.newState.state.wakefulness == .waking) // no illegal transition
        // The cancellation cleared the stale token — and the same event's
        // mint check immediately re-issued a fresh generation: the pet is
        // .waking with nothing pending, so the engine is never left waiting
        // on a cancelled choreography (never stranded, never stuck).
        #expect(cancelled.newState.pendingHandshake?.kind == .wake)
        #expect(cancelled.newState.pendingHandshake?.token != original)

        // The re-issued handshake is stable — it does not re-mint per event.
        var rng = SeededGenerator(seed: 11)
        let later = reduce(cancelled.newState, .evaluate(now: instant("2026-09-08T07:12:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(later.newState.pendingHandshake == cancelled.newState.pendingHandshake)
    }

    @Test("the fold landing .waking lets a .wake token SURVIVE (it is the stretch's own token)")
    func wakeTokenSurvivesMorningLanding() {
        let wakeToken = UUID()
        let asleepWithToken = state(wakefulness: .asleep, pending: Handshake(kind: .wake, token: wakeToken), lastEvaluatedAt: instant("2026-09-08T06:00:00Z"))
        var rng = SeededGenerator(seed: 7)
        let folded = reduce(asleepWithToken, .evaluate(now: instant("2026-09-08T07:30:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(folded.newState.state.wakefulness == .waking)
        #expect(folded.newState.pendingHandshake == Handshake(kind: .wake, token: wakeToken))
        // And it still completes.
        var finishRng = SeededGenerator(seed: 7)
        let finished = reduce(folded.newState, .characterReport(.wakeFinished), clock: ManualEngineClock(at: instant("2026-09-08T07:35:00Z")), calendar: utcCalendar, rng: &finishRng)
        #expect(finished.newState.state.wakefulness == .awake)
        #expect(finished.newState.pendingHandshake == nil)
    }

    @Test("a fold with no wakefulness transition leaves the pending handshake untouched")
    func foldWithoutTransitionKeepsHandshake() {
        let settleToken = UUID()
        let awake = state(wakefulness: .awake, pending: Handshake(kind: .settle, token: settleToken), lastEvaluatedAt: instant("2026-09-08T09:00:00Z"))
        var rng = SeededGenerator(seed: 7)
        let outcome = reduce(awake, .evaluate(now: instant("2026-09-08T10:00:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(outcome.newState.state.wakefulness == .awake)
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .settle, token: settleToken))
    }
}
