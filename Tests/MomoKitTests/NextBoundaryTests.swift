import Testing
import Foundation
@testable import MomoKit
@testable import MomoCore

/// The §4.2 next-boundary derivation's suite (TASK-031): every row of the
/// boundary table over a fixed UTC calendar, the strictly-after/no-replay
/// property, the reschedule-never-replay chain, the DST rows over the same
/// DST fixtures the engine's fold tests use (America/New_York, 2026), and
/// the cross-pin against `TimeFold.segments` — the two `enumerateDates`
/// walks must agree on where the night begins.
@Suite
struct NextBoundaryTests {

    private let calendar = AppModelFixture.calendar()

    // MARK: The phase→boundary table (05 §4.2; NextBoundary's header)

    /// Awake in the daytime: the next boundary is the 22:00 onset.
    @Test("awake daytime → night onset")
    func awakeDaytimeSchedulesNightOnset() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T15:00:00Z"),
            state: AppModelFixture.state(dayKey: "2026-03-03", lastEvaluatedAt: AppModelFixture.instant("2026-03-03T15:00:00Z")),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .nightOnset,
            instant: AppModelFixture.instant("2026-03-03T22:00:00Z")
        ))
    }

    /// Awake past the onset: the next boundary is local midnight (the
    /// day-rollover reset serving the interactive session).
    @Test("awake late evening → local midnight")
    func awakeLateEveningSchedulesMidnight() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T23:00:00Z"),
            state: AppModelFixture.state(dayKey: "2026-03-03", lastEvaluatedAt: AppModelFixture.instant("2026-03-03T23:00:00Z")),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .localMidnight,
            instant: AppModelFixture.instant("2026-03-04T00:00:00Z")
        ))
    }

    /// Awake just past midnight: the earliest of the three walls is the
    /// coming 07:00 — the current fold segment ends there, so its kind is
    /// the morning wake even though the pet never slept.
    @Test("awake post-midnight → the coming 07:00 segment end")
    func awakePostMidnightSchedulesMorningWake() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-04T00:30:00Z"),
            state: AppModelFixture.state(dayKey: "2026-03-04", lastEvaluatedAt: AppModelFixture.instant("2026-03-04T00:30:00Z")),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-03-04T07:00:00Z")
        ))
    }

    /// Awake pre-dawn: the next boundary is the coming 07:00 wake.
    @Test("awake pre-dawn → morning wake")
    func awakePredawnSchedulesMorningWake() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T02:00:00Z"),
            state: AppModelFixture.state(dayKey: "2026-03-03", lastEvaluatedAt: AppModelFixture.instant("2026-03-03T02:00:00Z")),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-03-03T07:00:00Z")
        ))
    }

    /// Asleep: the next boundary is the morning wake EVEN when midnight
    /// comes first — the wake fold subsumes the rollover (NextBoundary's
    /// header's recorded interpretation).
    @Test("asleep late evening → wake past midnight")
    func asleepSchedulesMorningWakePastMidnight() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T23:00:00Z"),
            state: AppModelFixture.state(
                dayKey: "2026-03-03",
                lastEvaluatedAt: AppModelFixture.instant("2026-03-03T23:00:00Z"),
                wakefulness: .asleep
            ),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-03-04T07:00:00Z")
        ))
    }

    /// Asleep mid-morning (the edge: 07:00 of the current day is already
    /// past): the wake scheduled is TOMORROW's — strictly after, never a
    /// replay of the crossing that already happened.
    @Test("asleep morning edge → tomorrow's wake")
    func asleepMorningEdgeSchedulesTomorrowWake() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T09:00:00Z"),
            state: AppModelFixture.state(
                dayKey: "2026-03-03",
                lastEvaluatedAt: AppModelFixture.instant("2026-03-03T09:00:00Z"),
                wakefulness: .asleep
            ),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-03-04T07:00:00Z")
        ))
    }

    /// Napping: the earliest calendar boundary, RELABELED — the nap-end
    /// instant is the next fold boundary (the domain carries no nap-start
    /// instant and no nap duration; the recorded interpretation).
    @Test("napping → earliest boundary relabeled nap-end")
    func nappingRelabelsEarliestBoundary() {
        func napping(at iso: String, dayKey: String) -> EngineState {
            AppModelFixture.state(
                dayKey: dayKey,
                lastEvaluatedAt: AppModelFixture.instant(iso),
                activity: .napping
            )
        }
        // Afternoon nap → the 22:00 onset completes it.
        #expect(NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T15:00:00Z"),
            state: napping(at: "2026-03-03T15:00:00Z", dayKey: "2026-03-03"),
            calendar: calendar
        ) == NextBoundary(kind: .napEnd, instant: AppModelFixture.instant("2026-03-03T22:00:00Z")))
        // Late-evening nap → midnight completes it.
        #expect(NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T23:00:00Z"),
            state: napping(at: "2026-03-03T23:00:00Z", dayKey: "2026-03-03"),
            calendar: calendar
        ) == NextBoundary(kind: .napEnd, instant: AppModelFixture.instant("2026-03-04T00:00:00Z")))
        // Pre-dawn nap → the 07:00 wake completes it.
        #expect(NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T02:00:00Z"),
            state: napping(at: "2026-03-03T02:00:00Z", dayKey: "2026-03-03"),
            calendar: calendar
        ) == NextBoundary(kind: .napEnd, instant: AppModelFixture.instant("2026-03-03T07:00:00Z")))
    }

    // MARK: Strictly-after (no replay)

    /// Deriving exactly AT a boundary schedules the NEXT one — never the
    /// boundary the derivation stands on.
    @Test("derivation at 22:00 sharp → midnight, not 22:00 again")
    func exactlyAtBoundaryIsStrictlyAfter() {
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-03T22:00:00Z"),
            state: AppModelFixture.state(dayKey: "2026-03-03", lastEvaluatedAt: AppModelFixture.instant("2026-03-03T22:00:00Z")),
            calendar: calendar
        )
        #expect(boundary == NextBoundary(
            kind: .localMidnight,
            instant: AppModelFixture.instant("2026-03-04T00:00:00Z")
        ))
    }

    /// The reschedule-never-replay chain, over the scheduler's ACTUAL fold
    /// target: derive at 21:00 (→ 22:00), evaluate at 22:00 SHARP (the fold
    /// completes no night segment — the onset must be CROSSED, so the pet
    /// stays awake), re-derive (→ local midnight). Each derivation is
    /// strictly after the fold that triggered it — never the same boundary
    /// twice. The asleep-landing chain (fold → `.asleep` → the 07:00 wake)
    /// is pinned by `asleepSchedulesMorningWakePastMidnight` and the nap
    /// chain in `AppModelPlanTests.boundaryRidesEveryPlan`.
    @Test("reschedule, never replay: 21:00 → 22:00 fold → midnight")
    func rescheduleNeverReplays() {
        let evening = AppModelFixture.state(dayKey: "2026-03-03", lastEvaluatedAt: AppModelFixture.instant("2026-03-03T21:00:00Z"))
        let first = NextBoundaryRules.next(from: AppModelFixture.instant("2026-03-03T21:00:00Z"), state: evening, calendar: calendar)
        #expect(first == NextBoundary(kind: .nightOnset, instant: AppModelFixture.instant("2026-03-03T22:00:00Z")))

        // The boundary evaluation at 22:00 lands exactly ON the onset: the
        // fold's last segment [21:00, 22:00] ends inside the night window,
        // so no wakefulness transition — the engine's documented crossing
        // rule (TimeFold's segment loop).
        let clock = ManualEngineClock(at: AppModelFixture.instant("2026-03-03T21:00:00Z"))
        var rng = SeededGenerator(seed: AppModelPlanCore.choreographySeed(
            petID: evening.pet.id,
            instant: AppModelFixture.instant("2026-03-03T22:00:00Z"),
            calendar: calendar
        ))
        let folded = reduce(
            evening,
            .evaluate(now: AppModelFixture.instant("2026-03-03T22:00:00Z")),
            clock: clock,
            calendar: calendar,
            rng: &rng
        )
        #expect(folded.newState.state.wakefulness == .awake)

        let second = NextBoundaryRules.next(from: AppModelFixture.instant("2026-03-03T22:00:00Z"), state: folded.newState, calendar: calendar)
        #expect(second == NextBoundary(kind: .localMidnight, instant: AppModelFixture.instant("2026-03-04T00:00:00Z")))
        // And the second boundary is strictly after the first evaluation —
        // never a replay of 22:00.
        #expect(second!.instant > first!.instant)
    }

    // MARK: DST (the engine fold tests' fixtures — America/New_York, 2026)

    /// Spring forward (2026-03-08 night, 2 AM skipped): 22:00 EST = 03:00Z,
    /// 07:00 EDT = 11:00Z — the 8-real-hour night. A pet asleep at 23:00
    /// EST wakes at 11:00Z, the WALL 07:00, not seven fixed hours later.
    @Test("spring forward: wake lands the wall 07:00 (EDT)")
    func springForwardWakeLandsWallHour() {
        let newYork = AppModelFixture.calendar(in: "America/New_York")
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-03-09T04:00:00Z"), // 23:00 EST Mar 8
            state: AppModelFixture.state(
                dayKey: "2026-03-08",
                lastEvaluatedAt: AppModelFixture.instant("2026-03-09T04:00:00Z"),
                wakefulness: .asleep
            ),
            calendar: newYork
        )
        #expect(boundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-03-09T11:00:00Z") // 07:00 EDT
        ))
    }

    /// Fall back (2026-11-01 night, 1 AM repeated): 07:00 EST = 12:00Z. A
    /// pet asleep at 23:00 EST (04:00Z next day) wakes at 12:00Z — the wall
    /// again, with the repeated hour absorbed by `.nextTime`.
    @Test("fall back: wake lands the wall 07:00 (EST)")
    func fallBackWakeLandsWallHour() {
        let newYork = AppModelFixture.calendar(in: "America/New_York")
        let boundary = NextBoundaryRules.next(
            from: AppModelFixture.instant("2026-11-02T04:00:00Z"), // 23:00 EST Nov 1
            state: AppModelFixture.state(
                dayKey: "2026-11-01",
                lastEvaluatedAt: AppModelFixture.instant("2026-11-02T04:00:00Z"),
                wakefulness: .asleep
            ),
            calendar: newYork
        )
        #expect(boundary == NextBoundary(
            kind: .morningWake,
            instant: AppModelFixture.instant("2026-11-02T12:00:00Z") // 07:00 EST
        ))
    }

    // MARK: The cross-pin (NextBoundary's header — two walks, one answer)

    /// The boundary walk and `TimeFold`'s own segment walk must agree on
    /// where the current night begins: an awake daytime pet's onset instant
    /// IS the current fold segment's end.
    @Test("cross-pin: onset instant == TimeFold's current segment end")
    func crossPinAgainstTimeFoldSegments() {
        let now = AppModelFixture.instant("2026-03-03T15:00:00Z")
        let boundary = NextBoundaryRules.next(
            from: now,
            state: AppModelFixture.state(dayKey: "2026-03-03", lastEvaluatedAt: now),
            calendar: calendar
        )
        let segments = TimeFold.segments(
            from: now,
            to: now.addingTimeInterval(3 * 86_400),
            calendar: calendar
        )
        #expect(segments.isEmpty == false)
        #expect(boundary?.instant == segments[0].end)
        #expect(boundary?.kind == .nightOnset)
    }
}
