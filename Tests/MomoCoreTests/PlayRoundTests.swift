import Testing
import Foundation
@testable import MomoCore

/// The play-round lifecycle (04 §6.3, §9.2, §9.6 item 4; TASK-016
/// Requirement 7; AC-5): authorization mints a seeded `.play` token into the
/// single slot and sets the activity — with NO effects and NO count — and
/// the effects + `playCount` land EXACTLY ONCE at the unified cease instant
/// (`playRoundFinished` and `handshakeCancelled(.play)` alike). Stir-only
/// states never start rounds; the clamps respect INV-2 and the D18 gain
/// ceiling.
@Suite("Play rounds — authorization, unified cease, idempotency (TASK-016)")
struct PlayRoundTests {

    private let fixture = InteractionFixture()

    private let day = "2026-09-08"
    private let t = "2026-09-08T09:00:00Z"

    @Test("authorization: activity .playing, a minted .play token, the round-start beat, NO effects or count")
    func authorizationMintsAndSets() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.playReady, lineKey: "momo.line.react.play.00", haptic: nil))
        #expect(outcome.newState.state.activity == .playing)
        #expect(outcome.newState.state.wakefulness == .awake) // play never moves wakefulness
        let pending = outcome.newState.pendingHandshake
        #expect(pending?.kind == .play)
        #expect(pending != nil) // the token itself is a seeded draw (mint purity is TASK-015's pin)
        #expect(outcome.newState.state.mood == start.state.mood && outcome.newState.state.energy == start.state.energy)
        #expect(outcome.newState.days.first?.playCount == 0) // a round that has not ceased has not happened
    }

    @Test("Drowsy authorizes the SAME round (the short low-key pacing is character-side)")
    func drowsyRoundAuthorized() {
        let start = fixture.state(dayKey: day, energy: 30, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.playReady, lineKey: "momo.line.react.play.00", haptic: nil))
        #expect(outcome.newState.state.activity == .playing)
        #expect(outcome.newState.pendingHandshake?.kind == .play)
    }

    @Test("full lifecycle through reduce: authorize → cease applies −10/+6 once, clears token + activity, counts 1")
    func fullLifecycle() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let authorized = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        let token = authorized.newState.pendingHandshake

        var ceaseRng = SeededGenerator(seed: 7)
        let ceased = reduce(
            authorized.newState,
            .characterReport(.playRoundFinished),
            clock: ManualEngineClock(at: fixture.instant(t)), // zero-elapsed fold: the exact pins are the round's, not the fold's
            calendar: fixture.calendar,
            rng: &ceaseRng
        )
        #expect(ceased.newState.state.energy == authorized.newState.state.energy
            + InteractionRules.playRoundEnergyDelta * InteractionRules.repetitionMultipliers[0])
        #expect(ceased.newState.state.mood == authorized.newState.state.mood
            + InteractionRules.playRoundMoodDelta * InteractionRules.repetitionMultipliers[0])
        #expect(ceased.newState.state.activity == nil)
        #expect(ceased.newState.pendingHandshake == nil)
        #expect(ceased.newState.days.first?.playCount == 1)

        // The cease's belt-guard twin: a report consumes no rng (no mint —
        // the pet is .awake, not .waking).
        let idleTwin = SeededGenerator(seed: 7)
        #expect(ceaseRng.state == idleTwin.state)

        _ = token // (the token value is the seeded draw; presence asserted above)
    }

    @Test("cancellation is the SAME unified cease: identical effects + count")
    func cancellationIsTheUnifiedCease() {
        // The pinned intent id keeps the belt's recorded id identical across
        // the twin runs (the ONLY permitted difference would be the cease).
        let intentID = UUID()
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let authorized = fixture.send(start, .play, at: fixture.instant(t), dayKey: day, intentID: intentID)
        let finished = fixture.report(authorized.newState, .playRoundFinished, at: fixture.instant("2026-09-08T09:00:30Z"))

        // A twin run whose round is CANCELLED instead of finished must land
        // on the same effects and count — one cease, two spellings.
        let startTwin = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let authorizedTwin = fixture.send(startTwin, .play, at: fixture.instant(t), dayKey: day, intentID: intentID)
        let cancelled = fixture.report(authorizedTwin.newState, .handshakeCancelled(.play), at: fixture.instant("2026-09-08T09:00:30Z"))
        #expect(cancelled.newState == finished.newState)
        #expect(cancelled.newState.days.first?.playCount == 1)
    }

    @Test("stale reports apply nothing: a cease or cancellation with nothing pending is a tolerated no-op")
    func staleReportsApplyNothing() {
        let idle = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let finished = fixture.report(idle, .playRoundFinished, at: fixture.instant(t))
        #expect(finished.newState == idle)

        let cancelled = fixture.report(idle, .handshakeCancelled(.play), at: fixture.instant(t))
        #expect(cancelled.newState == idle)

        // A DIFFERENT kind pending: the play report is a no-op too.
        let settling = fixture.state(
            dayKey: day,
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: UUID()),
            lastEvaluatedAt: fixture.instant(t)
        )
        let mismatched = fixture.report(settling, .playRoundFinished, at: fixture.instant(t))
        #expect(mismatched.newState == settling)
    }

    @Test("the mood ceiling clamps the GAIN, never the level (D18: play never lowers mood)")
    func ceilingClampsGainNotLevel() {
        // mood 90: 90 + 6 → clamped to the ceiling exactly.
        let below = fixture.state(dayKey: day, mood: 90, activity: .playing, pendingHandshake: Handshake(kind: .play, token: UUID()), lastEvaluatedAt: fixture.instant(t))
        let clamped = fixture.report(below, .playRoundFinished, at: fixture.instant(t))
        #expect(clamped.newState.state.mood == InteractionRules.interactionMoodCeiling)
        #expect(clamped.newState.state.mood > below.state.mood) // still a gain

        // mood 95 (already above the ceiling — e.g. a stage moment): HOLDS,
        // never pulled down.
        let above = fixture.state(dayKey: day, mood: 95, activity: .playing, pendingHandshake: Handshake(kind: .play, token: UUID()), lastEvaluatedAt: fixture.instant(t))
        let held = fixture.report(above, .playRoundFinished, at: fixture.instant(t))
        #expect(held.newState.state.mood == above.state.mood)
    }

    @Test("the energy floor and INV-2 domains hold at the extremes")
    func energyClampsHold() {
        // 5 − 10 lands clamped at 0, never negative.
        let low = fixture.state(dayKey: day, energy: 5, activity: .playing, pendingHandshake: Handshake(kind: .play, token: UUID()), lastEvaluatedAt: fixture.instant(t))
        let floored = fixture.report(low, .playRoundFinished, at: fixture.instant(t))
        #expect(floored.newState.state.energy == Thresholds.Scalar.lower)
        #expect(floored.newState.state.energy >= Thresholds.Scalar.lower)

        // A near-full pet stays within the domain.
        let high = fixture.state(dayKey: day, energy: 99, activity: .playing, pendingHandshake: Handshake(kind: .play, token: UUID()), lastEvaluatedAt: fixture.instant(t))
        let dropped = fixture.report(high, .playRoundFinished, at: fixture.instant(t))
        #expect(dropped.newState.state.energy == high.state.energy + InteractionRules.playRoundEnergyDelta)
        #expect(dropped.newState.state.energy <= Thresholds.Scalar.upper)
    }

    @Test("the cease touches mood/energy/activity only: lastFedAt, satiety, wakefulness, bond preserved")
    func ceasePreservesTheRest() {
        let fedAt = fixture.instant("2026-09-08T08:00:00Z")
        let start = fixture.state(
            dayKey: day,
            energy: 80,
            wakefulness: .awake,
            activity: .playing,
            lastFedAt: fedAt,
            satietyPhase: .recentlyFed,
            pendingHandshake: Handshake(kind: .play, token: UUID()),
            lastEvaluatedAt: fixture.instant(t)
        )
        let ceased = fixture.report(start, .playRoundFinished, at: fixture.instant(t))
        #expect(ceased.newState.state.lastFedAt == fedAt)
        #expect(ceased.newState.state.satietyPhase == .recentlyFed)
        #expect(ceased.newState.state.wakefulness == .awake)
        #expect(ceased.newState.state.bond == start.state.bond) // play banks no bond in Phase 1
    }

    @Test("night overtaking a round folds it away WITHOUT effects or count (token + activity cleared, never stranded)")
    func nightOvertookRoundFoldsAwaySilently() {
        // Authorized 23:58 inside the night window; the next event folds to
        // 00:01 — the fold's night onset transitioned the wakefulness, which
        // orphans the .play token (TASK-015's disposition, extended by
        // TASK-016 to clear the playing activity). The unified cease belongs
        // to the character reports alone, so this path applies NO arithmetic:
        // the round silently did not happen (FR-7 AC-2's letter — a round
        // that never completes counts nothing).
        let start = fixture.state(
            dayKey: day,
            activity: .playing,
            pendingHandshake: Handshake(kind: .play, token: UUID()),
            lastEvaluatedAt: fixture.instant("2026-09-08T23:58:00Z")
        )
        var rng = SeededGenerator(seed: 7)
        let outcome = reduce(
            start,
            .evaluate(now: fixture.instant("2026-09-09T00:01:00Z")),
            clock: ManualEngineClock(),
            calendar: fixture.calendar,
            rng: &rng
        )
        #expect(outcome.newState.state.wakefulness == .asleep) // the fold's night transition
        #expect(outcome.newState.state.activity == nil) // not stranded .playing forever
        #expect(outcome.newState.pendingHandshake == nil) // the token did not strand
        // NO −10: the energy is the fold's night-ramped 80 (the ramp's exact
        // arithmetic is TimeFoldTests'; ±0.1 pins "untouched by the round"
        // against a would-be 70).
        #expect(abs(outcome.newState.state.energy - start.state.energy) < 0.1)
        #expect(outcome.newState.state.mood == start.state.mood) // NO +6 (night attractor holds 60 → 60 exactly)
        #expect(outcome.newState.days.first?.playCount == 0) // NO count on the authorization day
        #expect(outcome.newState.days.last?.dayKey == "2026-09-09") // the fold's landing-day rollover
        #expect(outcome.newState.days.last?.playCount == 0) // …and no count there either

        // A late playRoundFinished for the folded-away round: tolerated no-op
        // (zero-elapsed fold — nothing left to cease, nothing changes).
        var lateRng = SeededGenerator(seed: 7)
        let late = reduce(
            outcome.newState,
            .characterReport(.playRoundFinished),
            clock: ManualEngineClock(at: fixture.instant("2026-09-09T00:01:00Z")),
            calendar: fixture.calendar,
            rng: &lateRng
        )
        #expect(late.newState == outcome.newState)
    }

    @Test("authorization determinism: the same seed mints the same token (the round is replayable)")
    func authorizationDeterminism() {
        let intentID = UUID() // pinned so the belt ledger is identical too
        let a = fixture.send(fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t)), .play, at: fixture.instant(t), dayKey: day, seed: 42, intentID: intentID)
        let b = fixture.send(fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t)), .play, at: fixture.instant(t), dayKey: day, seed: 42, intentID: intentID)
        #expect(a.newState == b.newState)
        #expect(a.response == b.response)
        #expect(a.newState.pendingHandshake?.token == b.newState.pendingHandshake?.token)
    }
}
