import Foundation
import MomoCore

// MARK: - NextBoundary — the §4.2 in-session boundary derivation (TASK-031;
// 05-technical-architecture §4.2's scheduled-boundary row)

/// The ONE next in-session boundary evaluation instant, derived from the
/// folded state (05 §4.2: "the app layer computes the *next* boundary instant
/// from the folded state and schedules exactly one evaluation at that
/// instant"). The executor schedules exactly one call at `instant`; after
/// every evaluation it re-derives — schedulers re-schedule, never replay
/// (04 §5.3 pause discipline). The derivation is PURE: injected instant,
/// injected calendar, folded state — no clocks, no ambient anything, so the
/// boundary table is headlessly testable (the 05 §10.1 no-app-unit-test-target
/// constraint shapes this split; the executor is thin by construction).
///
/// **The four boundary kinds (05 §4.2's scheduled-boundary row, verbatim
/// "22:00 onset, 07:00 wake, local midnight, nap-end instant") and the
/// recorded phase→boundary interpretation.** The table's boundaries are
/// phase events of the pet, not an unconditional earliest-of-all race — a
/// sleeping pet's next event is its morning wake, not a midnight reset (the
/// wake fold subsumes the rollover: `TimeFold`'s segment decomposition folds
/// [22:00 → 07:00] in one segment and the landing-day rollover keys on the
/// landing day). The derivation:
///
/// - `.napEnd` — the pet is mid-nap (`activity == .napping`). The domain
///   model carries no nap-start instant and no nap duration (TimeFold's
///   recorded interpretation 3: the nap SPANS the fold and completes at fold
///   end), so the nap-end instant IS the next fold boundary — the earliest of
///   the three calendar boundaries, relabeled: the evaluation there is the
///   one that completes the nap. Inventing a nap-duration constant to make
///   the instant differ would be un-sourced arithmetic; no spec text and no
///   domain field carries one.
/// - `.morningWake` — the pet is asleep (`wakefulness == .asleep`): the next
///   `FoldRules.morningWakeHour` crossing, EVEN when local midnight comes
///   first. This is the one deliberate ordering choice: an in-session
///   midnight reset has no sleeping pet to show it to, and the 07:00 fold
///   performs the same rollover decomposition. (The 05 §4.2 table's "midnight
///   reset" serves the interactive session — an awake pet — which the next
///   case covers.)
/// - otherwise (awake / settling / waking) — the earliest of the three
///   calendar boundaries, labeled by which it is: the next
///   `FoldRules.nightOnsetHour` (`.nightOnset`), the next local midnight
///   (`.localMidnight`), or — for a pre-dawn session — the next
///   `FoldRules.morningWakeHour` (`.morningWake`).
///
/// Every boundary is strictly AFTER `now` (the enumeration below is
/// `startingAfter`), so a derivation can never hand back an already-due
/// instant — the structural "no replay" property: re-deriving after a fold
/// that landed exactly ON a boundary yields the NEXT boundary, never the same
/// one again (pinned by `NextBoundaryTests.rescheduleNeverReplays`).
///
/// Boundary hours come ONLY from `FoldRules` (the engine's constants home);
/// this file restates no clock arithmetic literals. The mechanism mirrors
/// `TimeFold`'s own segment-boundary walk (`calendar.enumerateDates` with
/// `.nextTime`, which resolves DST-skipped/repeated walls); `TimeFold`'s
/// helper is private inside the frozen engine module, so the walk is
/// reimplemented here over the same calendar API — the cross-pin against
/// `TimeFold.segments` in the tests keeps the two walks honest.
public struct NextBoundary: Equatable, Sendable {

    /// Which boundary this is (the executor logs it; the tests pin it).
    public enum Kind: Equatable, Sendable {
        /// The night-onset crossing (22:00 local — `FoldRules.nightOnsetHour`).
        case nightOnset
        /// The morning-wake crossing (07:00 local — `FoldRules.morningWakeHour`).
        case morningWake
        /// The local-midnight crossing (00:00 local — the day-rollover reset).
        case localMidnight
        /// The fold that completes a live nap (the earliest calendar boundary,
        /// relabeled — see the type header's nap interpretation).
        case napEnd
    }

    /// Which boundary this is.
    public let kind: Kind

    /// The evaluation instant (strictly after the derivation's `now`).
    public let instant: Instant

    public init(kind: Kind, instant: Instant) {
        self.kind = kind
        self.instant = instant
    }
}

// MARK: - Derivation

/// The §4.2 next-boundary rules — one auditable home, the
/// `FoldRules`/`StoreRules` constants-home pattern carried into the
/// orchestration layer. Pure: `(now, folded state, calendar) → boundary`.
public enum NextBoundaryRules {

    /// Derives the ONE next in-session boundary (see `NextBoundary`'s header
    /// for the phase→boundary interpretation and the strictly-after
    /// guarantee). Nil only if the injected calendar cannot enumerate any
    /// next occurrence of the requested walls — never observed for a real
    /// `Calendar`; the executor treats nil as "schedule nothing" rather than
    /// fabricating an instant.
    public static func next(
        from now: Instant,
        state: EngineState,
        calendar: Calendar
    ) -> NextBoundary? {
        let pet = state.state
        if pet.activity == .napping {
            // Nap-end IS the next fold boundary (interpretation in the
            // type header): the earliest of the three, relabeled.
            return earliest(of: allCalendarBoundaries(after: now, calendar: calendar))
                .map { NextBoundary(kind: .napEnd, instant: $0.instant) }
        }
        if pet.wakefulness == .asleep {
            // A sleeping pet's next event is its morning wake; the midnight
            // rollover is subsumed by the wake fold (type header).
            return nextLocalHourBound(FoldRules.morningWakeHour, after: now, calendar: calendar)
                .map { NextBoundary(kind: .morningWake, instant: $0) }
        }
        return earliest(of: allCalendarBoundaries(after: now, calendar: calendar))
    }

    // MARK: Internals

    /// The three calendar boundaries strictly after `now`, each labeled by
    /// kind. The earliest of these, unmodified, is the awake-phase answer.
    private static func allCalendarBoundaries(
        after now: Instant,
        calendar: Calendar
    ) -> [NextBoundary] {
        [
            nextLocalHourBound(FoldRules.nightOnsetHour, after: now, calendar: calendar)
                .map { NextBoundary(kind: .nightOnset, instant: $0) },
            nextLocalHourBound(FoldRules.morningWakeHour, after: now, calendar: calendar)
                .map { NextBoundary(kind: .morningWake, instant: $0) },
            nextLocalMidnight(after: now, calendar: calendar)
                .map { NextBoundary(kind: .localMidnight, instant: $0) },
        ]
        .compactMap { $0 }
    }

    /// The boundary with the earliest instant (ties impossible — the walls
    /// are distinct hours; a degenerate calendar could tie only by failing
    /// first, which the optionals above already absorb).
    private static func earliest(of boundaries: [NextBoundary]) -> NextBoundary? {
        boundaries.min { $0.instant < $1.instant }
    }

    /// The next occurrence of local `hour`:00 strictly after `instant`,
    /// DST-safe (`matchingPolicy: .nextTime` resolves skipped/repeated
    /// walls). The same walk `TimeFold` uses for its own segment ends —
    /// reimplemented here because the engine's helper is private inside the
    /// frozen module; the tests cross-pin the two walks against each other.
    private static func nextLocalHourBound(
        _ hour: Int,
        after instant: Instant,
        calendar: Calendar
    ) -> Instant? {
        var components = DateComponents()
        components.hour = hour
        return firstMatch(components, after: instant, calendar: calendar)
    }

    /// The next local midnight strictly after `instant` (hour 0 — the
    /// definition of local midnight, not a restated spec constant).
    private static func nextLocalMidnight(
        after instant: Instant,
        calendar: Calendar
    ) -> Instant? {
        nextLocalHourBound(0, after: instant, calendar: calendar)
    }

    /// The `enumerateDates` walk shared by both bound lookups.
    private static func firstMatch(
        _ components: DateComponents,
        after instant: Instant,
        calendar: Calendar
    ) -> Instant? {
        var found: Instant?
        calendar.enumerateDates(
            startingAfter: instant,
            matching: components,
            matchingPolicy: .nextTime
        ) { date, _, stop in
            if let date {
                found = date
                stop = true
            }
        }
        return found
    }
}
