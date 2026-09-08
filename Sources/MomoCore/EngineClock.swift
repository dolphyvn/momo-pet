import Foundation

// MARK: - EngineClock (05-technical-architecture §4.10; ADR-004)

/// The engine's only time source (05 §4.10: "a minimal `EngineClock` protocol
/// (`now() -> Instant`)"; "Every engine time read goes through it"). ADR-004
/// purity: engine code never touches `Date()`, `Calendar.current`, or
/// `TimeZone.current` — the ambient world enters through this protocol, the
/// injected calendar (TASK-012's `DayKey` pattern), and the injected RNG.
///
/// **VERIFY item resolution (05 Appendix B "Swift `Clock`/concurrency
/// idioms (§4.10)"):** this protocol deliberately does NOT conform to the
/// Swift standard-library `Clock` protocol, and the production clock does
/// not wrap `ContinuousClock`. Reasons, recorded as the item's resolution:
///
/// 1. The stdlib `Clock` protocol's shipped instances (`ContinuousClock`,
///    `SuspendingClock`) are monotonic. §4.3 requires the engine to see
///    manual wall-clock changes ("manual clock changes fold like any elapsed
///    time") and to derive calendar `dayKey`s from real wall time — a
///    monotonic read cannot serve either.
/// 2. `ContinuousClock.Instant` intentionally has no conversion to `Date`;
///    any bridge needs a wall-clock anchor captured at init, which is more
///    machinery for less information than reading the wall clock directly
///    (compile-probe evidence in the TASK-014 Implementation Notes).
/// 3. What the concurrency `Clock` idiom is actually for in this
///    architecture is §4.2's in-session boundary scheduling ("a single
///    `Task`-scheduled call") — and scheduling is app-layer: the engine never
///    schedules, never runs timers (ADR-004; presentation owns whether the
///    engine runs).
///
/// So the resolution: `EngineClock` stays its own minimal protocol with
/// §4.10's normative shape (`now() -> Instant`, domain `Instant` = `Date`),
/// `SystemEngineClock` below reads Foundation's wall clock (`Date.now` — the
/// direct current-Swift wall-time read, which stdlib `Clock` conformances
/// themselves anchor to), and the async `Clock` machinery belongs to the app
/// layer that calls `reduce`. Every engine time read still flows through an
/// injected `EngineClock`, which is the invariant the tests and the purity
/// scan actually enforce.
public protocol EngineClock: Sendable {

    /// The current instant (UTC wall time, INV-9).
    func now() -> Instant
}

/// The production clock: Foundation's system wall clock (05 §4.10
/// "production uses the system clock"). This file is the ONE sanctioned
/// ambient-time site in MomoCore — the engine-purity scan exempts exactly
/// this file for exactly the `Date`-family reads, and nothing else.
public struct SystemEngineClock: EngineClock {

    public init() {}

    public func now() -> Instant {
        Date.now
    }
}

/// The manually-advanceable test clock (05 §4.10: "tests use a
/// manually-advanced test clock"). A value type: tests hold it, advance it,
/// and pass a copy into `reduce`; advancing a copy never moves another (value
/// semantics — no shared mutable clock in tests).
///
/// `advance(to:)` sets the clock outright, including backwards — tests fully
/// control time so §4.3's manual-clock-change cases are drivable. Lives in
/// MomoCore (not the test target) so every package test target reuses the
/// same clock instead of re-rolling one; it is inert outside tests.
public struct ManualEngineClock: EngineClock, Sendable {

    /// The instant the clock currently reports.
    public private(set) var current: Instant

    /// Starts the clock at `instant`.
    public init(at instant: Instant) {
        self.current = instant
    }

    /// Starts the clock at the Unix epoch — a deterministic default.
    public init() {
        self.init(at: Instant(timeIntervalSince1970: 0))
    }

    /// Moves the clock to `instant` (forward or backward — tests control
    /// time absolutely, which §4.3's clock-change cases require).
    public mutating func advance(to instant: Instant) {
        current = instant
    }

    /// Moves the clock by `interval` seconds (negative moves backward).
    public mutating func advance(by interval: TimeInterval) {
        current = current.addingTimeInterval(interval)
    }

    public func now() -> Instant {
        current
    }
}
