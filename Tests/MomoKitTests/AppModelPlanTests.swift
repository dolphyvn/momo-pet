import Testing
import Foundation
@testable import MomoKit
@testable import MomoCore

/// The app-model plan core's suite (TASK-031; 05 §4.1–§4.2): the fixed-order
/// effect plan, the persist-iff-changed rule, exactly-once delivery shape,
/// the reserved Watch seam, the five triggers' routing (fold-to-now through
/// the engine's own interface, pinned by composition equality), and
/// determinism. All time is literal over injected clocks/calendars — the
/// `InteractionFixture`/`MetaDeterminismTests` discipline carried into the
/// orchestration layer.
@Suite
struct AppModelPlanTests {

    private let calendar = AppModelFixture.calendar()

    // MARK: The fixed-order plan (05 §4.1)

    /// A foreground fold produces the full fixed order: persist → deliver
    /// moments (the absence greeting) → the reserved Watch push. Response is
    /// nil on evaluate paths, so no response step appears.
    @Test("fixed order: foreground fold = persist → moments → watch seam")
    func fixedOrderForegroundPlan() {
        let state = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T09:00:00Z")
        )
        let plan = AppModelPlanCore.plan(
            state: state,
            trigger: .foreground(now: AppModelFixture.instant("2026-03-03T15:00:00Z")),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T15:00:00Z")),
            calendar: calendar
        )
        #expect(plan.steps == [
            .persist,
            .deliverMoments([.greeting(.welcomeBack)]),
            .pushWatchSnapshot,
        ])
        // Step 0 is the apply; the open stamp followed the trigger's instant.
        #expect(plan.appliedState.lastOpenedAt == AppModelFixture.instant("2026-03-03T15:00:00Z"))
        #expect(plan.appliedState.lastEvaluatedAt == AppModelFixture.instant("2026-03-03T15:00:00Z"))
    }

    /// The play authorization, then the mid-round replay with a FRESH id:
    /// the round's cheer response rides alongside the IFF steps — the fold's
    /// decay and the intent-id recording keep `changed` true, so persist and
    /// the reserved seam frame the delivery. (The truly-EMPTY plan is the
    /// duplicate-id case, pinned by the next test.)
    @Test("mid-round play: the cheer rides the changed plan")
    func midRoundPlayRidesTheChangedPlan() {
        let start = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T10:00:00Z")
        )
        let authorizing = AppModelPlanCore.plan(
            state: start,
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID1,
                dayKey: "2026-03-03",
                timestamp: AppModelFixture.instant("2026-03-03T10:00:00Z"),
                kind: .play
            )),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:00:00Z")),
            calendar: calendar
        )
        #expect(authorizing.steps.contains(.persist))
        // Mid-round play: the cheer, no further state effect from the play
        // itself — but the fold's half-hour decay and the recorded intent id
        // still move the state.
        let midRound = AppModelPlanCore.plan(
            state: authorizing.appliedState,
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID2,
                dayKey: "2026-03-03",
                timestamp: AppModelFixture.instant("2026-03-03T10:30:00Z"),
                kind: .play
            )),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:30:00Z")),
            calendar: calendar
        )
        #expect(midRound.steps.count == 3)
        #expect(midRound.steps.first == .persist)
        #expect(midRound.steps.last == .pushWatchSnapshot)
        guard case let .deliverResponse(response) = midRound.steps[1] else {
            Issue.record("expected the cheer response at step 1, got \(midRound.steps[1])")
            return
        }
        #expect(response.reaction == ReactionKeys.cheer)
        #expect(response.haptic == nil)
        // The state deltas: both ids recorded (INV-10's belt), the fold's
        // half-hour decay (80 − 1.5 × 0.5), the fold mark at the intent.
        #expect(midRound.appliedState.processedIntents == [AppModelFixture.intentID1, AppModelFixture.intentID2])
        #expect(midRound.appliedState.state.energy == 79.25)
        #expect(midRound.appliedState.lastEvaluatedAt == AppModelFixture.instant("2026-03-03T10:30:00Z"))
    }

    /// A duplicate intent id is a TOTAL no-op (INV-10's belt, before any
    /// fold): empty plan, state unchanged — nothing delivered, nothing
    /// persisted, nothing scheduled-change.
    @Test("duplicate intent: empty plan, state untouched")
    func duplicateIntentIsTotalNoOp() {
        let start = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T10:00:00Z")
        )
        let intent = AppModelFixture.intent(
            id: AppModelFixture.intentID1,
            dayKey: "2026-03-03",
            timestamp: AppModelFixture.instant("2026-03-03T10:00:00Z"),
            kind: .play
        )
        let first = AppModelPlanCore.plan(
            state: start,
            trigger: .interaction(intent),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:00:00Z")),
            calendar: calendar
        )
        let replay = AppModelPlanCore.plan(
            state: first.appliedState,
            trigger: .interaction(intent),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:00:00Z")),
            calendar: calendar
        )
        #expect(replay.steps == [])
        #expect(replay.appliedState == first.appliedState)
    }

    /// The Watch-push slot exists ONLY on changed plans and is always the
    /// LAST step — the reserved seam's shape, pinned so it cannot silently
    /// vanish before EPIC-008 lands the transport.
    @Test("reserved Watch seam: last step, only when changed")
    func watchSeamReservedOnlyWhenChanged() {
        let start = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T09:00:00Z")
        )
        let changed = AppModelPlanCore.plan(
            state: start,
            trigger: .foreground(now: AppModelFixture.instant("2026-03-03T15:00:00Z")),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T15:00:00Z")),
            calendar: calendar
        )
        #expect(changed.steps.last == .pushWatchSnapshot)

        let unchanged = AppModelPlanCore.plan(
            state: changed.appliedState,
            trigger: .foreground(now: AppModelFixture.instant("2026-03-03T15:01:00Z")),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T15:01:00Z")),
            calendar: calendar
        )
        // 5-minute regreet floor: no new greeting, no moments — the fold's
        // stamp movement alone keeps it `changed`, so the plan is exactly
        // the persist and the reserved seam.
        #expect(unchanged.steps == [.persist, .pushWatchSnapshot])
    }

    // MARK: Trigger routing (05 §4.2 — fold-to-now through the engine's own
    // interface; the facade's obligation is CORRECT SUBMISSION)

    /// The interaction trigger submits as-is: the plan equals a manual
    /// `reduce(.interaction)` seeded by the same documented convention —
    /// no synthetic fold, no extra stamps, seed-for-seed. The engine's
    /// internal fold to the intent's own timestamp is visible in the result.
    @Test("interaction = correct submission (plan == manual reduce, seed-for-seed)")
    func interactionSubmitsWithoutSyntheticFold() {
        let evaluatedAt = AppModelFixture.instant("2026-03-03T09:00:00Z")
        let intent = AppModelFixture.intent(
            id: AppModelFixture.intentID1,
            dayKey: "2026-03-03",
            timestamp: AppModelFixture.instant("2026-03-03T12:00:00Z"),
            kind: .pat(gesture: .tap, zone: .head)
        )
        let state = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: evaluatedAt
        )
        let plan = AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(intent),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T12:00:00Z")),
            calendar: calendar
        )
        // The manual composition: one reduce, the engine's own interface,
        // the app layer's documented seed lineage.
        var rng = SeededGenerator(seed: AppModelPlanCore.choreographySeed(
            petID: state.pet.id,
            instant: intent.timestamp,
            calendar: calendar
        ))
        let manual = reduce(
            state,
            .interaction(intent),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T12:00:00Z")),
            calendar: calendar,
            rng: &rng
        )
        // The IFF rules, applied to the manual outcome by the test itself.
        var steps: [AppModelPlan.Step] = []
        if manual.changed { steps.append(.persist) }
        if let response = manual.response { steps.append(.deliverResponse(response)) }
        if !manual.moments.isEmpty { steps.append(.deliverMoments(manual.moments)) }
        if manual.changed { steps.append(.pushWatchSnapshot) }
        #expect(plan == AppModelPlan(
            appliedState: manual.newState,
            steps: steps,
            nextBoundary: NextBoundaryRules.next(
                from: intent.timestamp,
                state: manual.newState,
                calendar: calendar
            )
        ))
        // The engine's internal fold-to-now happened (three waking hours),
        // with the fold mark at the intent's own timestamp.
        #expect(plan.appliedState.lastEvaluatedAt == intent.timestamp)
        #expect(plan.appliedState.state.energy == 75.5) // 80 − 1.5 × 3
    }

    /// The report trigger submits as-is: the plan equals a manual
    /// `reduce(.characterReport)` — whose fold target is the clock's now —
    /// with the settle handshake completing to `.asleep`.
    @Test("report = correct submission; folds to the clock's now")
    func reportSubmitsAndFoldsToNow() {
        let state = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T21:00:00Z"),
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: AppModelFixture.handshakeToken)
        )
        let clock = ManualEngineClock(at: AppModelFixture.instant("2026-03-03T21:30:00Z"))
        let plan = AppModelPlanCore.plan(
            state: state,
            trigger: .characterReport(.settleFinished),
            clock: clock,
            calendar: calendar
        )
        var rng = SeededGenerator(seed: AppModelPlanCore.choreographySeed(
            petID: state.pet.id,
            instant: clock.now(),
            calendar: calendar
        ))
        let manual = reduce(
            state,
            .characterReport(.settleFinished),
            clock: clock,
            calendar: calendar,
            rng: &rng
        )
        #expect(plan.appliedState == manual.newState)
        #expect(plan.appliedState.state.wakefulness == .asleep)
        #expect(plan.appliedState.lastEvaluatedAt == clock.now())
        #expect(plan.steps == [.persist, .pushWatchSnapshot])
    }

    // MARK: The play round's ledger path (TASK-035 R1; 04 §9.6 item 4's
    // unified cease — the count lands at the REPORT, never the auth)

    /// The `.play` interaction authorizes the round (activity + pending
    /// handshake) but touches NO counter; the round's cease report is what
    /// lands `playCount` — exactly once.
    @Test("play counts at the report, not the authorization")
    func playCountsAtTheReportNotTheAuth() {
        let state = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T10:00:00Z")
        )
        let authorizing = AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID1,
                dayKey: "2026-03-03",
                timestamp: AppModelFixture.instant("2026-03-03T10:00:00Z"),
                kind: .play
            )),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:00:00Z")),
            calendar: calendar
        )
        // The authorization: round in flight, handshake pending, counter
        // untouched.
        #expect(authorizing.appliedState.state.activity == .playing)
        #expect(authorizing.appliedState.pendingHandshake?.kind == .play)
        #expect(authorizing.appliedState.days.first { $0.dayKey == "2026-03-03" }?.playCount == 0)

        // The cease report lands the count and clears the round.
        let cease = AppModelPlanCore.plan(
            state: authorizing.appliedState,
            trigger: .characterReport(.playRoundFinished),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:05:00Z")),
            calendar: calendar
        )
        #expect(cease.appliedState.days.first { $0.dayKey == "2026-03-03" }?.playCount == 1)
        #expect(cease.appliedState.state.activity == nil)
        #expect(cease.appliedState.pendingHandshake == nil)

        // A duplicate cease (the drained-report belt's whole point) is the
        // engine's tolerated no-op — no re-count.
        let duplicate = AppModelPlanCore.plan(
            state: cease.appliedState,
            trigger: .characterReport(.playRoundFinished),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:06:00Z")),
            calendar: calendar
        )
        #expect(duplicate.appliedState.days.first { $0.dayKey == "2026-03-03" }?.playCount == 1)
    }

    /// The Done-tap path: a cancelled round counts ONCE, exactly like a
    /// finished one (the unified cease — `handshakeCancelled(.play)` rides
    /// the same `completePlayRound`).
    @Test("the cancelled round counts once, exactly like a finished one")
    func cancelledRoundCountsOnce() {
        let state = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T10:00:00Z")
        )
        let authorizing = AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID1,
                dayKey: "2026-03-03",
                timestamp: AppModelFixture.instant("2026-03-03T10:00:00Z"),
                kind: .play
            )),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:00:00Z")),
            calendar: calendar
        )
        let cancel = AppModelPlanCore.plan(
            state: authorizing.appliedState,
            trigger: .characterReport(.handshakeCancelled(.play)),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T10:02:00Z")),
            calendar: calendar
        )
        #expect(cancel.appliedState.days.first { $0.dayKey == "2026-03-03" }?.playCount == 1)
        #expect(cancel.appliedState.state.activity == nil)
        #expect(cancel.appliedState.pendingHandshake == nil)
    }

    /// The §4.2 composition pin: the facade's foreground-then-interaction
    /// session equals the manual evaluate-then-interact composition — every
    /// application's outcome, step for step and seed for seed.
    @Test("composed session equals the manual evaluate-then-interact composition")
    func compositionEqualsManualEvaluateThenInteract() {
        let state = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: AppModelFixture.instant("2026-03-03T09:00:00Z")
        )
        let open = AppModelFixture.instant("2026-03-03T09:30:00Z")
        let patAt = AppModelFixture.instant("2026-03-03T11:30:00Z")
        let intent = AppModelFixture.intent(
            id: AppModelFixture.intentID1,
            dayKey: "2026-03-03",
            timestamp: patAt,
            kind: .pat(gesture: .tap, zone: .head)
        )
        // Facade.
        let facadeOpen = AppModelPlanCore.plan(
            state: state,
            trigger: .foreground(now: open),
            clock: ManualEngineClock(at: open),
            calendar: calendar
        )
        let facadePat = AppModelPlanCore.plan(
            state: facadeOpen.appliedState,
            trigger: .interaction(intent),
            clock: ManualEngineClock(at: patAt),
            calendar: calendar
        )
        // Manual composition, the app layer's documented per-application
        // seed lineage at each step.
        var rng1 = SeededGenerator(seed: AppModelPlanCore.choreographySeed(
            petID: state.pet.id, instant: open, calendar: calendar
        ))
        let manualOpen = reduce(
            state, .evaluate(now: open),
            clock: ManualEngineClock(at: open),
            calendar: calendar,
            rng: &rng1
        )
        var rng2 = SeededGenerator(seed: AppModelPlanCore.choreographySeed(
            petID: state.pet.id, instant: patAt, calendar: calendar
        ))
        let manualPat = reduce(
            manualOpen.newState, .interaction(intent),
            clock: ManualEngineClock(at: patAt),
            calendar: calendar,
            rng: &rng2
        )
        #expect(facadeOpen.appliedState == manualOpen.newState)
        #expect(facadePat.appliedState == manualPat.newState)
    }

    // MARK: The next boundary rides every plan (05 §4.2)

    /// The boundary is derived from the FOLDED state: an evening open at
    /// 21:30 schedules the 22:00 onset; a live nap schedules the fold that
    /// completes it; the boundary evaluation there lands the nap (asleep —
    /// the landing is in the night window) and re-derives the 07:00 wake.
    @Test("next boundary from the folded state: onset, live nap, then wake")
    func boundaryRidesEveryPlan() {
        // Evening open → onset.
        let evening = AppModelPlanCore.plan(
            state: AppModelFixture.state(
                dayKey: "2026-03-03",
                lastEvaluatedAt: AppModelFixture.instant("2026-03-03T21:00:00Z")
            ),
            trigger: .foreground(now: AppModelFixture.instant("2026-03-03T21:30:00Z")),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T21:30:00Z")),
            calendar: calendar
        )
        #expect(evening.nextBoundary == NextBoundary(
            kind: .nightOnset,
            instant: AppModelFixture.instant("2026-03-03T22:00:00Z")
        ))
        // A drowsy pet naps at 15:00 → the nap-end fold is 22:00.
        let napping = AppModelPlanCore.plan(
            state: AppModelFixture.state(
                dayKey: "2026-03-03",
                lastEvaluatedAt: AppModelFixture.instant("2026-03-03T15:00:00Z"),
                energy: 30
            ),
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID1,
                dayKey: "2026-03-03",
                timestamp: AppModelFixture.instant("2026-03-03T15:00:00Z"),
                kind: .nap
            )),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T15:00:00Z")),
            calendar: calendar
        )
        #expect(napping.appliedState.state.activity == .napping)
        #expect(napping.nextBoundary == NextBoundary(
            kind: .napEnd,
            instant: AppModelFixture.instant("2026-03-03T22:00:00Z")
        ))
        // The boundary evaluation at 22:00 completes the nap — the landing
        // is inside the night window, so the pet is asleep — and the next
        // boundary re-derives to the morning wake.
        let napEnd = AppModelPlanCore.plan(
            state: napping.appliedState,
            trigger: .scheduledBoundary(instant: AppModelFixture.instant("2026-03-03T22:00:00Z")),
            clock: ManualEngineClock(at: AppModelFixture.instant("2026-03-03T22:00:00Z")),
            calendar: calendar
        )
        #expect(napEnd.appliedState.state.activity == nil)
        #expect(napEnd.appliedState.state.wakefulness == .asleep)
        #expect(napEnd.nextBoundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-03-04T07:00:00Z")
        ))
    }

    // MARK: Determinism (FR-13 AC-3's shape, over the app model)

    /// A scripted multi-trigger session run twice from the same start —
    /// equal plans, equal final state; and a tooth: a different pet identity
    /// (different choreography seed) diverges.
    @Test("same inputs ⇒ equal plans; a different pet diverges")
    func determinism() {
        let (firstRun, firstState) = scriptedSession(petID: AppModelFixture.petID)
        let (secondRun, secondState) = scriptedSession(petID: AppModelFixture.petID)
        #expect(firstRun == secondRun)
        #expect(firstState == secondState)

        let (otherRun, otherState) = scriptedSession(petID: UUID(
            uuidString: "AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE"
        )!)
        #expect(otherRun != firstRun)
        #expect(otherState != firstState)
    }

    /// Foreground → pat → play → the 22:00 boundary: a bounded seeded
    /// sequence, the MetaDeterminismTests shape over the app model.
    private func scriptedSession(petID: UUID) -> ([AppModelPlan], EngineState) {
        let clock = ManualEngineClock(at: AppModelFixture.instant("2026-03-03T09:00:00Z"))
        var state = AppModelFixture.state(
            petID: petID,
            dayKey: "2026-03-03",
            lastEvaluatedAt: clock.now()
        )
        var plans: [AppModelPlan] = []
        let open = AppModelFixture.instant("2026-03-03T09:30:00Z")
        var current = AppModelPlanCore.plan(
            state: state, trigger: .foreground(now: open), clock: clock, calendar: calendar
        )
        plans.append(current)
        state = current.appliedState
        let patAt = AppModelFixture.instant("2026-03-03T10:00:00Z")
        current = AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID1, dayKey: "2026-03-03",
                timestamp: patAt, kind: .pat(gesture: .tap, zone: .head)
            )),
            clock: clock, calendar: calendar
        )
        plans.append(current)
        state = current.appliedState
        let playAt = AppModelFixture.instant("2026-03-03T11:00:00Z")
        current = AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(AppModelFixture.intent(
                id: AppModelFixture.intentID2, dayKey: "2026-03-03",
                timestamp: playAt, kind: .play
            )),
            clock: clock, calendar: calendar
        )
        plans.append(current)
        state = current.appliedState
        let boundaryAt = AppModelFixture.instant("2026-03-03T22:00:00Z")
        current = AppModelPlanCore.plan(
            state: state,
            trigger: .scheduledBoundary(instant: boundaryAt),
            clock: clock, calendar: calendar
        )
        plans.append(current)
        return (plans, current.appliedState)
    }

    // MARK: The choreography-seed pin (REVIEW-TASK-031 MINOR-1)

    /// Pins the seed SHAPE against the engine's own API — never against the
    /// facade's own wrapper (a wrapper-referencing pin is tautological: a
    /// wrong salt, epoch, or day-key source would ship green). The expected
    /// value is derived directly from `DaySeed.make` with the LITERAL spec
    /// salt (`.choreography`) and the LITERAL epoch value `1` (04 §5.1's
    /// initial-catalog reading) over `DayKey.make` of the given instant
    /// under the injected calendar; the epoch CONSTANT is pinned to that
    /// same value so an intentional retune trips this pin and forces the
    /// deliberate companion update.
    @Test("choreography seed: shape pinned to DaySeed.make; epoch value pinned to 1")
    func choreographySeedShapePinnedToTheEngine() {
        let instant = AppModelFixture.instant("2026-03-03T15:00:00Z")
        let seed = AppModelPlanCore.choreographySeed(
            petID: AppModelFixture.petID,
            instant: instant,
            calendar: calendar
        )
        #expect(seed == DaySeed.make(
            petID: AppModelFixture.petID,
            localDayKey: DayKey.make(from: instant, calendar: calendar),
            epoch: 1,
            salt: .choreography
        ))
        #expect(AppModelPlanCore.choreographyEpoch == 1)
    }
}
