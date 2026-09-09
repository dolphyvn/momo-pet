import Foundation
import Testing
@testable import MomoCore

/// The time fold: segment decomposition + §4.3 dynamics + day rollover +
/// clock edge cases (05 §4.2–4.3, FR-11/FR-12, D20; TASK-015 Requirements
/// 1–4, 8). The named tests required by the task contract live here:
/// night onset 22:00, morning wake 07:00, midnight rollover ×1, DST
/// fall-back/spring-forward, timezone change mid-day, backward clock,
/// 7-day absence, wake clamp ≥ 75, attractor τ = 3 h, coupling 35/floor 25.
///
/// Exact-value expectations restate the §4.3 formulas independently
/// (`exp(…)`, hand-derived arithmetic) — never by calling the production
/// helpers — so a regression in `TimeFold` cannot hide behind a circular
/// expectation.
@Suite("TimeFold — segments, dynamics, rollover, clock edges")
struct TimeFoldTests {

    // MARK: - Fixtures

    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    /// Gregorian UTC — the common calendar; DST/timezone tests build their own.
    private var utcCalendar: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        return gregorian
    }

    private func calendar(in timeZoneName: String) -> Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: timeZoneName)!
        return gregorian
    }

    private func instant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    private func quest(_ id: QuestID) -> QuestProgress {
        QuestProgress(questID: id, progress: 0, completed: false)!
    }

    private func state(
        mood: Double = 60,
        energy: Double = 80,
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        dayKey: String = "2026-09-08",
        helloAwarded: Bool = false,
        lastEvaluatedAt: Instant
    ) -> EngineState {
        let pet = Pet(id: petID, name: "Momo", createdAt: instant("2026-01-01T00:00:00Z"))!
        let petState = PetState(
            mood: mood,
            energy: energy,
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
            helloAwarded: helloAwarded,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: 0
        )!
        return EngineState(
            pet: pet,
            state: petState,
            days: [day],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: lastEvaluatedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// An evaluate through the public entry point (so fold + stamps + belt
    /// all run exactly as in production).
    private func evaluate(_ state: EngineState, at now: Instant, calendar: Calendar, seed: UInt64 = 7) -> EngineOutcome {
        var rng = SeededGenerator(seed: seed)
        return reduce(state, .evaluate(now: now), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
    }

    // MARK: - Coupling band timing (REVIEW-TASK-015 MINOR-1)

    @Test("coupling band reads segment-START energy: a crossing takes effect next segment")
    func couplingBandReadsSegmentStart() {
        // Energy 46 starts Relaxed (20/45/75 bands) and declines to 43
        // (Drowsy) across the segment. The documented reading (TimeFold
        // interpretation 1) couples the NEXT segment, so this whole segment
        // attracts toward plain 60 and mood 60 stays exactly 60 — the
        // segment-end reading would couple this segment (target 35 →
        // 47.8354…), which this pin rejects.
        let start = evaluate(
            state(mood: 60, energy: 46, lastEvaluatedAt: instant("2026-09-08T10:00:00Z")),
            at: instant("2026-09-08T12:00:00Z"),
            calendar: utcCalendar
        )
        #expect(start.newState.state.energy == 43) // waking decline −1.5/h × 2 h, exact
        #expect(start.newState.state.mood == 60) // segment-start band governs: no coupling yet
        // The crossing is now in effect: this short segment STARTS Drowsy →
        // coupled target 35 (attractor step, re-derived independently).
        let next = evaluate(
            start.newState,
            at: instant("2026-09-08T12:30:00Z"),
            calendar: utcCalendar
        )
        let expected = 60 - 25 * (1 - exp(-0.5 / 3))
        #expect(abs(next.newState.state.mood - expected) < 1e-9)
    }

    // MARK: - Segment decomposition (pure unit level)

    @Test("segments: a waking hour is one waking segment")
    func segmentsSingleWaking() {
        let segments = TimeFold.segments(
            from: instant("2026-09-08T09:00:00Z"),
            to: instant("2026-09-08T10:00:00Z"),
            calendar: utcCalendar
        )
        #expect(segments.count == 1)
        #expect(segments[0].isNight == false)
        #expect(segments[0].start == instant("2026-09-08T09:00:00Z"))
        #expect(segments[0].end == instant("2026-09-08T10:00:00Z"))
    }

    @Test("segments split at 22:00 onset and 07:00 wake only (midnight needs no split)")
    func segmentsSplitAtBounds() {
        // 21:00 → 23:00: waking [21,22), night [22,23).
        let evening = TimeFold.segments(
            from: instant("2026-09-08T21:00:00Z"),
            to: instant("2026-09-08T23:00:00Z"),
            calendar: utcCalendar
        )
        #expect(evening.map(\.isNight) == [false, true])

        // 06:00 → 08:00: night [06,07), waking [07,08).
        let morning = TimeFold.segments(
            from: instant("2026-09-08T06:00:00Z"),
            to: instant("2026-09-08T08:00:00Z"),
            calendar: utcCalendar
        )
        #expect(morning.map(\.isNight) == [true, false])

        // 23:00 → 01:00 next day: midnight is interior to the night window —
        // ONE night segment, no midnight split (rollover is keyed, not
        // segment-arithmetic).
        let acrossMidnight = TimeFold.segments(
            from: instant("2026-09-08T23:00:00Z"),
            to: instant("2026-09-09T01:00:00Z"),
            calendar: utcCalendar
        )
        #expect(acrossMidnight.count == 1)
        #expect(acrossMidnight[0].isNight)
    }

    @Test("segments: zero and backward spans decompose to nothing (forward-only folds)")
    func segmentsEmptyForNonForwardSpans() {
        let t = instant("2026-09-08T09:00:00Z")
        #expect(TimeFold.segments(from: t, to: t, calendar: utcCalendar).isEmpty)
        #expect(TimeFold.segments(from: t, to: t.addingTimeInterval(-3600), calendar: utcCalendar).isEmpty)
    }

    @Test("named: DST fall-back — the 2026-11-01 night is TEN real hours (America/New_York)")
    func dstFallBackNightIsTenHours() {
        let ny = calendar(in: "America/New_York")
        // Oct 31 21:00 EDT → Nov 1 08:00 EST crosses the repeated hour.
        let segments = TimeFold.segments(
            from: instant("2026-10-31T21:00:00-04:00"),
            to: instant("2026-11-01T08:00:00-05:00"),
            calendar: ny
        )
        #expect(segments.map(\.isNight) == [false, true, false])
        let night = segments[1]
        #expect(night.start == instant("2026-10-31T22:00:00-04:00"))
        #expect(night.end == instant("2026-11-01T07:00:00-05:00"))
        #expect(night.end.timeIntervalSince(night.start) == 36000) // 10 h, not 9

        // The extra hour is dynamics-visible: entering mid-night at 05:00 EST
        // with energy 78, the ramp (anchored to the full 10 h night) adds
        // (85−78)/10 × 2 = 1.4 by 07:00 → 79.4 — above the wake clamp, so
        // observable — then the waking hour declines 1.5 → 77.9. A 9 h anchor
        // would leave 78.055… — the pin discriminates.
        let folded = TimeFold.apply(
            petState: PetState(mood: 60, energy: 78, bond: 0, wakefulness: .awake, activity: nil, lastFedAt: nil, satietyPhase: .hungry)!,
            days: [],
            pendingHandshake: nil,
            from: instant("2026-11-01T05:00:00-05:00"),
            to: instant("2026-11-01T08:00:00-05:00"),
            calendar: ny
        )
        #expect(abs(folded.petState.energy - 77.9) < 1e-9)
        #expect(folded.petState.wakefulness == .waking)
    }

    @Test("named: DST spring-forward — the 2026-03-08 night is EIGHT real hours (America/New_York)")
    func dstSpringForwardNightIsEightHours() {
        let ny = calendar(in: "America/New_York")
        let segments = TimeFold.segments(
            from: instant("2026-03-07T21:00:00-05:00"),
            to: instant("2026-03-08T08:00:00-04:00"),
            calendar: ny
        )
        #expect(segments.map(\.isNight) == [false, true, false])
        let night = segments[1]
        #expect(night.start == instant("2026-03-07T22:00:00-05:00"))
        #expect(night.end == instant("2026-03-08T07:00:00-04:00"))
        #expect(night.end.timeIntervalSince(night.start) == 28800) // 8 h, not 9

        // Same discriminator as fall-back: (85−78)/8 × 2 = 1.75 → 79.75, then
        // −1.5 → 78.25 (a 9 h anchor would leave 78.055…).
        let folded = TimeFold.apply(
            petState: PetState(mood: 60, energy: 78, bond: 0, wakefulness: .awake, activity: nil, lastFedAt: nil, satietyPhase: .hungry)!,
            days: [],
            pendingHandshake: nil,
            from: instant("2026-03-08T05:00:00-04:00"),
            to: instant("2026-03-08T08:00:00-04:00"),
            calendar: ny
        )
        #expect(abs(folded.petState.energy - 78.25) < 1e-9)
        #expect(folded.petState.wakefulness == .waking)
    }

    // MARK: - Named dynamics tests

    @Test("named: waking hours decline energy −1.5 pts/h (§4.3)")
    func wakingHoursDeclineEnergy() {
        let state = state(lastEvaluatedAt: instant("2026-09-08T09:00:00Z"))
        let outcome = evaluate(state, at: instant("2026-09-08T10:00:00Z"), calendar: utcCalendar)
        #expect(abs(outcome.newState.state.energy - 78.5) < 1e-9)
        #expect(outcome.newState.state.wakefulness == .awake) // no boundary crossed
    }

    @Test("named: night onset at 22:00 lands the pet .asleep with NO handshake (zero rng draws)")
    func nightOnsetLandsAsleepHandshakeFree() {
        let start = state(
            wakefulness: .awake,
            lastEvaluatedAt: instant("2026-09-08T21:30:00Z")
        ).with(pendingHandshake: Handshake(kind: .settle, token: UUID()))
        var rng = SeededGenerator(seed: 7)
        let twin = SeededGenerator(seed: 7)
        let outcome = reduce(start, .evaluate(now: instant("2026-09-08T23:00:00Z")), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(outcome.newState.state.wakefulness == .asleep)
        #expect(outcome.newState.pendingHandshake == nil) // the transition orphans it — never stranded
        #expect(rng.state == twin.state) // the fold mints nothing: zero draws consumed
    }

    @Test("named: morning wake at 07:00 lands .waking; energy clamped ≥ 75 for the short sleeper")
    func morningWakeClampsEnergy() {
        // A pet that only slept 06:30–07:00 cannot have restored to 85 — the
        // wake clamp is what keeps PRD §3.2's "≥ 75 by 07:00" honest. Ramp
        // from 20 over half of the 9 h night: 20 + 65/9 × 0.5 ≈ 23.61 → the
        // 07:00 boundary clamps to exactly 75, then the waking quarter-hour
        // declines 0.375 → 74.625.
        let outcome = evaluate(
            state(energy: 20, lastEvaluatedAt: instant("2026-09-08T06:30:00Z")),
            at: instant("2026-09-08T07:15:00Z"),
            calendar: utcCalendar
        )
        #expect(outcome.newState.state.wakefulness == .waking)
        #expect(abs(outcome.newState.state.energy - 74.625) < 1e-9)
    }

    @Test("named: the mood attractor converges by τ = 3 h exactly (mood += (t−m)(1−e^(−Δt/τ)))")
    func attractorConvergenceMatchesTau() {
        // mood 30 → target 60 over exactly τ: the remaining distance must
        // shrink by e^(−1) — the identity of the §4.3 formula, restated.
        let outcome = evaluate(
            state(mood: 30, lastEvaluatedAt: instant("2026-09-08T09:00:00Z")),
            at: instant("2026-09-08T12:00:00Z"),
            calendar: utcCalendar
        )
        let expected = 60.0 - 30.0 / exp(1) // 48.9636…
        #expect(abs(outcome.newState.state.mood - expected) < 1e-9)
        // Energy over the same 3 h declines to 75.5 — still Relaxed, so the
        // coupling target cannot have contaminated the attractor's target.
        #expect(abs(outcome.newState.state.energy - 75.5) < 1e-9)
    }

    @Test("named: exhausted waking couples mood to 35; the 25 floor is structural")
    func couplingAndFloor() {
        // Coupling: energy 10 (Exhausted) at segment start → target 35, so
        // mood 60 converges DOWN toward 35 over the hour.
        let coupled = evaluate(
            state(mood: 60, energy: 10, lastEvaluatedAt: instant("2026-09-08T09:00:00Z")),
            at: instant("2026-09-08T10:00:00Z"),
            calendar: utcCalendar
        )
        let expectedCoupled = 60.0 - 25.0 * (1.0 - exp(-1.0 / 3.0)) // 52.9133…
        #expect(abs(coupled.newState.state.mood - expectedCoupled) < 1e-9)
        #expect(abs(coupled.newState.state.energy - 8.5) < 1e-9)

        // Floor: from mood 0 the attractor after six minutes only reaches
        // ≈ 1.15 — the INV-2/PRD clamp lifts the final value to exactly 25.
        let floored = evaluate(
            state(mood: 0, energy: 10, lastEvaluatedAt: instant("2026-09-08T09:00:00Z")),
            at: instant("2026-09-08T09:06:00Z"),
            calendar: utcCalendar
        )
        #expect(floored.newState.state.mood == 25.0)
    }

    @Test("INV-2: energy never leaves 0…100 even after long waking stretches")
    func energyClampsHold() {
        let outcome = evaluate(
            state(energy: 0.5, lastEvaluatedAt: instant("2026-09-08T09:00:00Z")),
            at: instant("2026-09-08T10:00:00Z"),
            calendar: utcCalendar
        )
        #expect(outcome.newState.state.energy == 0) // −1.5 clamped at the floor
    }

    @Test("nap spanning the fold completes: +20 clamped ≤ 100, activity cleared, wakefulness landed")
    func napCompletesAcrossFold() {
        // Nap at 21:30 → 23:00: the night ramps, then the nap itself adds 20.
        let folded = TimeFold.apply(
            petState: PetState(mood: 60, energy: 30, bond: 0, wakefulness: .awake, activity: .napping, lastFedAt: nil, satietyPhase: .hungry)!,
            days: [],
            pendingHandshake: nil,
            from: instant("2026-09-08T21:30:00Z"),
            to: instant("2026-09-08T23:00:00Z"),
            calendar: utcCalendar
        )
        #expect(folded.petState.activity == nil)
        // Waking decline is suppressed while napping; the night segment is a
        // full hour [22:00, 23:00): slope (85−30)/9 h × 1 h = 6.111… → 36.111…,
        // then the nap's +20 → 56.111….
        #expect(abs(folded.petState.energy - (30 + 55.0 / 9.0 + 20)) < 1e-9)
        #expect(folded.petState.wakefulness == .asleep) // landed inside the night window
    }

    // MARK: - Day rollover + absence + clock edges

    @Test("named: a fold across local midnight appends the new day EXACTLY once")
    func midnightRolloverExactlyOnce() {
        let start = state(lastEvaluatedAt: instant("2026-09-08T23:00:00Z"))
        let outcome = evaluate(start, at: instant("2026-09-09T01:00:00Z"), calendar: utcCalendar)

        // One new record, newest-last, keyed on the landing day.
        #expect(start.days.count == 1)
        #expect(outcome.newState.days.count == 2)
        #expect(outcome.newState.days.last?.dayKey == "2026-09-09")
        #expect(outcome.newState.days.first == start.days.first) // yesterday untouched
        #expect(outcome.newState.state.wakefulness == .asleep) // landed in the night window

        // Re-evaluating the SAME instant (retry/duplicate evaluation) must not
        // double-award: the ledger is keyed, so exactly-once is structural.
        let again = evaluate(outcome.newState, at: instant("2026-09-09T01:00:00Z"), calendar: utcCalendar)
        #expect(again.newState.days == outcome.newState.days)
        #expect(!again.changed)
    }

    @Test("named: seven absent days produce only the landing day's record (FR-12)")
    func sevenDayAbsenceAddsOnlyLandingDay() {
        let start = state(lastEvaluatedAt: instant("2026-09-08T10:00:00Z"))
        let outcome = evaluate(start, at: instant("2026-09-15T10:00:00Z"), calendar: utcCalendar)

        // Absent days 09-09 … 09-14 are silently empty; only the landing day
        // gets a record (a fresh daily reset — zero counters, no hello).
        #expect(outcome.newState.days.count == 2)
        #expect(outcome.newState.days.last?.dayKey == "2026-09-15")
        #expect(outcome.newState.days.last?.feedCount == 0)
        #expect(outcome.newState.days.last?.helloAwarded == false)
        #expect(outcome.newState.days.first == start.days.first)

        // The pet lived the week: woke at 07:00 on the landing day…
        #expect(outcome.newState.state.wakefulness == .waking)
        // …at a plausible post-restore level (equilibrium keeps 62.5–85 over
        // the days; three waking hours later it is 85 − 4.5).
        #expect(abs(outcome.newState.state.energy - 80.5) < 1e-9)
        #expect(outcome.newState.state.mood > FoldRules.moodFloor)
        #expect(outcome.newState.state.mood <= FoldRules.moodAttractorTarget)

        // And the fold is idempotent against its own target.
        let again = evaluate(outcome.newState, at: instant("2026-09-15T10:00:00Z"), calendar: utcCalendar)
        #expect(again.newState.days == outcome.newState.days)
    }

    @Test("named: a backward clock folds NOTHING and can never double-reset or double-hello")
    func backwardClockFoldsNothing() {
        let awarded = state(dayKey: "2026-09-08", helloAwarded: true, lastEvaluatedAt: instant("2026-09-08T09:00:00Z"))
        // The user's clock jumps back a day…
        let backward = evaluate(awarded, at: instant("2026-09-07T09:00:00Z"), calendar: utcCalendar)
        // …nothing refolds, the mark never regresses, and the awarded day —
        // hello included — survives untouched.
        #expect(backward.newState.days == awarded.days)
        #expect(backward.newState.lastEvaluatedAt == instant("2026-09-08T09:00:00Z"))
        #expect(backward.newState.state == awarded.state)
        // (The open stamp follows the wall: the open DID happen at that instant.)
        #expect(backward.newState.lastOpenedAt == instant("2026-09-07T09:00:00Z"))

        // …and forward again, even past midnight: re-deriving "2026-09-08"
        // finds its record present — no second record, no reset, no second
        // hello chance.
        let forwardAgain = evaluate(backward.newState, at: instant("2026-09-08T23:00:00Z"), calendar: utcCalendar)
        #expect(forwardAgain.newState.days.count == 1)
        #expect(forwardAgain.newState.days[0].helloAwarded == true)
        #expect(forwardAgain.newState.days[0].feedCount == 0)
    }

    @Test("named: a timezone change mid-day causes AT MOST one rollover")
    func timezoneChangeCausesAtMostOneRollover() {
        // 12:00 UTC is 21:00 in Tokyo (same evening, waking hour) and 08:00
        // in New York. A user who flies mid-day must not mint two days.
        let start = state(dayKey: "2026-09-08", lastEvaluatedAt: instant("2026-09-08T12:00:00Z"))

        // Day 1 evaluated under Tokyo time; the fold lands on 2026-09-09 local.
        let tokyoFold = evaluate(
            start,
            at: instant("2026-09-09T12:00:00Z"),
            calendar: calendar(in: "Asia/Tokyo")
        )
        #expect(tokyoFold.newState.days.count == 2)
        #expect(tokyoFold.newState.days.last?.dayKey == "2026-09-09")

        // The SAME instant re-evaluated under New York's calendar finds
        // "2026-09-09" already present — still exactly one rollover total.
        let nyRecheck = evaluate(
            tokyoFold.newState,
            at: instant("2026-09-09T12:00:00Z"),
            calendar: calendar(in: "America/New_York")
        )
        #expect(nyRecheck.newState.days == tokyoFold.newState.days)
    }

    // MARK: - Belt: processedIntents eviction (INV-10)

    @Test("the ledger evicts oldest-first at the 64-intent capacity")
    func processedIntentsEvictOldestAtCapacity() {
        var current = state(lastEvaluatedAt: instant("2026-09-08T09:00:00Z"))
        let now = instant("2026-09-08T09:00:00Z")
        var ids: [UUID] = []
        for index in 0..<70 {
            let id = UUID(uuidString: String(format: "00000000-0000-0000-0000-%012d", index))!
            ids.append(id)
            let intent = InteractionIntent(id: id, source: .iPhone, localDayKey: "2026-09-08", timestamp: now, kind: .pat(gesture: .tap, zone: .head))
            var rng = SeededGenerator(seed: UInt64(index))
            let outcome = reduce(current, .interaction(intent), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
            current = outcome.newState
        }
        #expect(current.processedIntents.count == EngineState.processedIntentsCapacity)
        #expect(current.processedIntents == Array(ids.dropFirst(70 - EngineState.processedIntentsCapacity)))
        #expect(!current.processedIntents.contains(ids[0])) // evicted…
        #expect(!current.processedIntents.contains(ids[5]))
        #expect(current.processedIntents.contains(ids[6])) // …the 64 newest remain
        // …and an evicted id replayed is treated as FRESH again (the belt's
        // documented window semantics — beyond 64 the id is forgotten).
        let replay = InteractionIntent(id: ids[0], source: .iPhone, localDayKey: "2026-09-08", timestamp: now, kind: .pat(gesture: .tap, zone: .head))
        var rng = SeededGenerator(seed: 99)
        let outcome = reduce(current, .interaction(replay), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(outcome.changed)
    }

    // MARK: - Interaction path folds to the intent's own instant

    @Test("interactions fold to the intent's timestamp — a 22:30 pat crosses night onset")
    func interactionFoldsToItsOwnInstant() {
        let start = state(lastEvaluatedAt: instant("2026-09-08T20:00:00Z"))
        let intent = InteractionIntent(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            source: .iPhone,
            localDayKey: "2026-09-08",
            timestamp: instant("2026-09-08T22:30:00Z"),
            kind: .pat(gesture: .tap, zone: .head)
        )
        var rng = SeededGenerator(seed: 3)
        let outcome = reduce(start, .interaction(intent), clock: ManualEngineClock(), calendar: utcCalendar, rng: &rng)
        #expect(outcome.newState.state.wakefulness == .asleep) // the fold carried it past 22:00
        #expect(outcome.newState.lastEvaluatedAt == intent.timestamp)
        #expect(outcome.newState.processedIntents == [intent.id])
        // TASK-016 supersession (in place): the nil-response pin WAS the
        // documented TASK-016 seam. The plan now exists — and the fact that
        // it is the asleep-stir (not the tap-head touch beat) is extra
        // evidence the semantics evaluated the FOLDED state at the intent's
        // instant.
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: nil, haptic: nil))
    }
}
