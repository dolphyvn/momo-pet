import Testing
import Foundation
@testable import MomoCore

/// Care semantics (PRD §4 care rows; FR-8 AC-1; TASK-016 Requirement 8;
/// AC-6): the tuck-in's exact 20:00-local clock gate (DST-safe through the
/// injected calendar), the in-window settle that mints `.settle` (making
/// TASK-015's preemption edge live), blanket-adjust while asleep, the
/// mid-settle reaffirm, and the band-gated nap the fold completes.
@Suite("Care — tuck-in window, settle, blanket-adjust, nap (TASK-016)")
struct CareInteractionTests {

    private let fixture = InteractionFixture()

    private let day = "2026-09-08"

    // MARK: The 20:00-local clock gate (FR-8 AC-1, exact)

    @Test("the gate is exact: 19:59 declines, 20:00 settles")
    func gateExactAtTwentyHundred() {
        let before = fixture.instant("2026-09-08T19:59:00Z")
        let atOpen = fixture.instant("2026-09-08T20:00:00Z")
        // Each send gets its own zero-elapsed state so the pins are the
        // care semantics alone (a 19:59→20:00 shared state would drag the
        // fold's one-minute waking decline into the exact arithmetic).
        let declinedStart = fixture.state(dayKey: day, lastEvaluatedAt: before)
        let acceptedStart = fixture.state(dayKey: day, lastEvaluatedAt: atOpen)

        let declined = fixture.send(declinedStart, .tuckIn, at: before, dayKey: day)
        #expect(declined.response == ResponsePlan(reaction: ReactionKeys.decline, lineKey: nil, haptic: nil))
        #expect(declined.newState.state.wakefulness == .awake) // no settle
        #expect(declined.newState.pendingHandshake == nil) // no token
        #expect(declined.newState.days.first?.careCount == 0) // no count
        #expect(declined.newState.state.mood == declinedStart.state.mood) // no effect

        let accepted = fixture.send(acceptedStart, .tuckIn, at: atOpen, dayKey: day)
        #expect(accepted.response == ResponsePlan(reaction: ReactionKeys.settling, lineKey: nil, haptic: nil))
        #expect(accepted.newState.state.wakefulness == .settling)
        #expect(accepted.newState.pendingHandshake?.kind == .settle)
        #expect(accepted.newState.state.mood == acceptedStart.state.mood + InteractionRules.tuckInMoodDelta)
        #expect(accepted.newState.state.energy == acceptedStart.state.energy + InteractionRules.tuckInEnergyDelta)
        #expect(accepted.newState.days.first?.careCount == 1)
    }

    @Test("the window runs through the night: 06:59 is in, 07:00 (the wake bound) is out")
    func windowThroughTheNight() {
        let lateNight = fixture.instant("2026-09-09T06:59:00Z")
        let morning = fixture.instant("2026-09-09T07:00:00Z")
        let start = fixture.state(dayKey: "2026-09-09", lastEvaluatedAt: lateNight)

        let accepted = fixture.send(start, .tuckIn, at: lateNight, dayKey: "2026-09-09")
        #expect(accepted.response == ResponsePlan(reaction: ReactionKeys.settling, lineKey: nil, haptic: nil))
        #expect(accepted.newState.state.wakefulness == .settling)

        let declined = fixture.send(start, .tuckIn, at: morning, dayKey: "2026-09-09")
        #expect(declined.response == ResponsePlan(reaction: ReactionKeys.decline, lineKey: nil, haptic: nil))
        #expect(declined.newState.pendingHandshake == nil)
    }

    @Test("the gate reads LOCAL hours through the injected calendar and is DST-safe")
    func gateIsDSTSafe() {
        let newYork = InteractionFixture(timeZoneIdentifier: "America/New_York")

        // Fall-back night (2026-11-01): local 01:00 happens TWICE (EDT then
        // EST) — both belong to the through-the-night window.
        let fallBackEDT = newYork.instant("2026-11-01T05:00:00Z") // 01:00 EDT (UTC−4)
        let fallBackEST = newYork.instant("2026-11-01T06:00:00Z") // 01:00 EST (UTC−5)
        #expect(newYork.calendar.component(.hour, from: fallBackEDT) == 1)
        #expect(newYork.calendar.component(.hour, from: fallBackEST) == 1)
        #expect(InteractionRules.isTuckInWindow(fallBackEDT, calendar: newYork.calendar))
        #expect(InteractionRules.isTuckInWindow(fallBackEST, calendar: newYork.calendar))

        // Spring-forward night (2026-03-08, 23 h): local 20:00 exists once
        // (EDT) — the gate reads the wall hour, not the day length.
        let springForwardEvening = newYork.instant("2026-03-09T00:00:00Z") // 20:00 EDT on Mar 8
        #expect(newYork.calendar.component(.hour, from: springForwardEvening) == 20)
        #expect(InteractionRules.isTuckInWindow(springForwardEvening, calendar: newYork.calendar))
        let springForwardBefore = newYork.instant("2026-03-08T23:00:00Z") // 19:00 EDT — the hour before the window opens
        #expect(newYork.calendar.component(.hour, from: springForwardBefore) == 19)
        #expect(!InteractionRules.isTuckInWindow(springForwardBefore, calendar: newYork.calendar))

        // One reduce-level gate check on the DST calendar: 01:00 EST settles.
        let start = newYork.state(dayKey: "2026-11-01", lastEvaluatedAt: fallBackEST)
        let settled = newYork.send(start, .tuckIn, at: fallBackEST, dayKey: "2026-11-01")
        #expect(settled.newState.state.wakefulness == .settling)
    }

    // MARK: In-window settle (the state TASK-015's preemption edge needs)

    @Test("the in-window settle mints a seeded .settle token; the preemption edge un-strands it")
    func settleTokenAndPreemption() {
        let at = fixture.instant("2026-09-08T21:00:00Z")
        let start = fixture.state(dayKey: day, lastEvaluatedAt: at)
        let settled = fixture.send(start, .tuckIn, at: at, dayKey: day, seed: 11)
        #expect(settled.newState.state.wakefulness == .settling)
        #expect(settled.newState.pendingHandshake?.kind == .settle)

        // The token is a seeded draw: the same seed replays it exactly
        // (the path's draw COUNT is pinned in
        // InteractionResponseTests.rngDrawDiscipline).
        let rerun = fixture.send(start, .tuckIn, at: at, dayKey: day, seed: 11)
        #expect(rerun.newState.pendingHandshake?.token == settled.newState.pendingHandshake?.token)

        // TASK-015's preemption edge is now REACHABLE: a cancelled settle
        // from .settling restores .awake and clears the token.
        var cancelRng = SeededGenerator(seed: 7)
        let cancelled = reduce(
            settled.newState,
            .characterReport(.handshakeCancelled(.settle)),
            clock: ManualEngineClock(at: at),
            calendar: fixture.calendar,
            rng: &cancelRng
        )
        #expect(cancelled.newState.state.wakefulness == .awake)
        #expect(cancelled.newState.pendingHandshake == nil)
    }

    @Test("a tuck-in while a play round is in flight declines until the round ceases")
    func tuckInDuringRoundDeclines() {
        let at = fixture.instant("2026-09-08T21:00:00Z")
        let start = fixture.state(
            dayKey: day,
            activity: .playing,
            pendingHandshake: Handshake(kind: .play, token: UUID()),
            lastEvaluatedAt: at
        )
        let declined = fixture.send(start, .tuckIn, at: at, dayKey: day)
        #expect(declined.response == ResponsePlan(reaction: ReactionKeys.decline, lineKey: nil, haptic: nil))
        #expect(declined.newState.state.activity == .playing) // the round is intact
        #expect(declined.newState.pendingHandshake?.kind == .play) // the slot still holds the round
        #expect(declined.newState.days.first?.careCount == 0)
    }

    // MARK: Blanket-adjust while asleep (still counts)

    @Test("in-window tuck-in on an asleep pet: blanket-adjust, counts, asleep preserved, no token")
    func blanketAdjustWhileAsleep() {
        let at = fixture.instant("2026-09-08T23:00:00Z")
        let start = fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: at)
        let outcome = fixture.send(start, .tuckIn, at: at, dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.blanketAdjust, lineKey: nil, haptic: nil))
        #expect(outcome.newState.state.wakefulness == .asleep) // no wakefulness change
        #expect(outcome.newState.pendingHandshake == nil) // no new token
        #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.tuckInMoodDelta)
        #expect(outcome.newState.state.energy == start.state.energy + InteractionRules.tuckInEnergyDelta)
        #expect(outcome.newState.days.first?.careCount == 1) // still counts (PRD §4)
    }

    @Test("in-window tuck-in on a napping pet: the same blanket-adjust, nap preserved")
    func blanketAdjustWhileNapping() {
        // The isSleeping rule covers the day-nap too (activity == .napping
        // reads as asleep), so the in-window instant must sit in the
        // night shoulder: 02:00 local.
        let inWindow = fixture.instant("2026-09-09T02:00:00Z")
        let napping = fixture.state(dayKey: "2026-09-09", wakefulness: .awake, activity: .napping, lastEvaluatedAt: inWindow)
        let outcome = fixture.send(napping, .tuckIn, at: inWindow, dayKey: "2026-09-09")
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.blanketAdjust, lineKey: nil, haptic: nil))
        #expect(outcome.newState.state.activity == .napping) // the nap is untouched
        #expect(outcome.newState.state.wakefulness == .awake)
        #expect(outcome.newState.days.first?.careCount == 1)
    }

    // MARK: The mid-settle reaffirm

    @Test("in-window tuck-in mid-settle: the warm reaffirm — no state change, no second token, no count")
    func reaffirmMidSettle() {
        let token = UUID()
        let at = fixture.instant("2026-09-08T21:30:00Z")
        let start = fixture.state(
            dayKey: day,
            mood: 66,
            energy: 74,
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: token),
            lastEvaluatedAt: at
        )
        let outcome = fixture.send(start, .tuckIn, at: at, dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.blanketAdjust, lineKey: nil, haptic: nil))
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .settle, token: token)) // the single token, not a second
        #expect(outcome.newState.state == start.state) // pet EXACTLY unchanged (no effects, no transition)
        #expect(outcome.newState.days.first?.careCount == 0) // the settle's care was counted at authorization
        // And the reaffirmed settle still completes.
        let finished = fixture.report(outcome.newState, .settleFinished, at: at)
        #expect(finished.newState.state.wakefulness == .asleep)
        #expect(finished.newState.pendingHandshake == nil)
    }

    // MARK: Nap (band-gated; the fold completes it)

    @Test("nap offered in Drowsy and Exhausted: activity .napping, counts, stays awake-in-nap")
    func napOfferedInSleepyBands() {
        for energy in [30.0, 15.0] {
            let at = fixture.instant("2026-09-08T14:00:00Z")
            let start = fixture.state(dayKey: day, energy: energy, lastEvaluatedAt: at)
            let outcome = fixture.send(start, .nap, at: at, dayKey: day)
            #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.settling, lineKey: nil, haptic: nil))
            #expect(outcome.newState.state.activity == .napping)
            #expect(outcome.newState.state.wakefulness == .awake) // the nap is an activity, not a wakefulness
            #expect(outcome.newState.pendingHandshake == nil) // no token: the fold owns the completion
            #expect(outcome.newState.state.energy == start.state.energy) // the +20 lands at fold completion
            #expect(outcome.newState.days.first?.careCount == 1)
        }
    }

    @Test("nap-then-fold completes the nap: +20 energy, activity cleared, landed .waking (TASK-015 integration)")
    func napThenFoldCompletes() {
        let napAt = fixture.instant("2026-09-08T14:00:00Z")
        let start = fixture.state(dayKey: day, energy: 30, lastEvaluatedAt: napAt)
        let napping = fixture.send(start, .nap, at: napAt, dayKey: day)

        var rng = SeededGenerator(seed: 7)
        let folded = reduce(
            napping.newState,
            .evaluate(now: fixture.instant("2026-09-08T15:00:00Z")),
            clock: ManualEngineClock(),
            calendar: fixture.calendar,
            rng: &rng
        )
        #expect(folded.newState.state.energy == start.state.energy + FoldRules.napRestoreEnergy) // +20, waking decline suppressed
        #expect(folded.newState.state.activity == nil)
        #expect(folded.newState.state.wakefulness == .waking) // §4.7's napping → waking edge (15:00 is day)
    }

    @Test("a nap that runs into the night lands .asleep (the pet slept through)")
    func napIntoNightLandsAsleep() {
        let napAt = fixture.instant("2026-09-08T21:30:00Z")
        let start = fixture.state(dayKey: day, energy: 30, lastEvaluatedAt: napAt)
        let napping = fixture.send(start, .nap, at: napAt, dayKey: day)

        var rng = SeededGenerator(seed: 7)
        let folded = reduce(
            napping.newState,
            .evaluate(now: fixture.instant("2026-09-08T23:00:00Z")),
            clock: ManualEngineClock(),
            calendar: fixture.calendar,
            rng: &rng
        )
        #expect(folded.newState.state.wakefulness == .asleep) // 23:00 is inside the night window
        #expect(folded.newState.state.activity == nil)
    }

    @Test("care never carries a repetition multiplier and never moves the belt-less fields")
    func careArithmeticHonesty() {
        let at = fixture.instant("2026-09-08T20:30:00Z")
        let start = fixture.state(dayKey: day, mood: 90, energy: 20, lastEvaluatedAt: at)
        let settled = fixture.send(start, .tuckIn, at: at, dayKey: day)
        // The ceiling clamps the care gain too (mood 90 + 3 → 92).
        #expect(settled.newState.state.mood == InteractionRules.interactionMoodCeiling)
        #expect(settled.newState.state.energy == start.state.energy + InteractionRules.tuckInEnergyDelta)
        #expect(settled.newState.state.bond == start.state.bond) // care banks no bond in Phase 1 (TASK-017 owns the ledger)
    }
}
