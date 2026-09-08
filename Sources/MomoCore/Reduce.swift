import Foundation

// MARK: - reduce: the single pure entry point (05-technical-architecture §4.1;
// ADR-004: pure deterministic core, event-driven catch-up, no timers)

/// The engine's single entry point: `(state, event, clock, rng) → outcome`,
/// pure (05 §4.1). Identical inputs ⇒ identical outcome (FR-13 AC-3) — no
/// I/O, no timers, no singletons, no ambient time, no system randomness;
/// clock and RNG are injected, and this skeleton demonstrably reads neither
/// unless an event's semantics require it (probes in `EngineReduceTests`).
///
/// **This task's event semantics are deliberately minimal and HONEST —
/// bookkeeping only.** The dynamic behaviors are scoped to their owning
/// tasks and are NOT faked here:
///
/// - `.evaluate(now:)` — bookkeeping stamp: sets `lastOpenedAt` and
///   `lastEvaluatedAt` to the event's instant (§4.2: every in-session
///   evaluation is an open of the pet; the fold that decomposes elapsed time
///   into segments is TASK-015's). `changed` is true only when the stamps
///   actually moved (state inequality — see below).
/// - `.interaction(InteractionIntent)` — **pass-through**, no dynamics: the
///   §4.4 response matrix, numeric effects, counting rules, and the
///   `processedIntents` record/dedup belt (§6.4) are TASK-015–017's. The
///   outcome is the input state unchanged.
/// - `.characterReport(CharacterReport)` — **pass-through**, no dynamics:
///   handshake application, wakefulness transitions (INV-8, §4.7), and
///   moment emission are TASK-015/018's. The outcome is the input state
///   unchanged.
///
/// The `clock` parameter is part of the normative §4.1 signature; the
/// minimal semantics above consume no wall time (events carry their own
/// instants), so it goes unread until TASK-015's fold reads it. The `rng`
/// parameter likewise goes undrawn until the drawing events land (§4.10's
/// seeded picks, TASK-015–018); the tests pin that zero draws are consumed.
///
/// `changed` is honest by construction: `newState != state` — equality on
/// the whole value, so anything the engine does not actually alter reports
/// `false` (no persistence write, no sync push — §4.1).
public func reduce(
    _ state: EngineState,
    _ event: EngineEvent,
    clock: EngineClock,
    rng: inout SeededGenerator
) -> EngineOutcome {
    switch event {
    case .evaluate(let now):
        let stamped = EngineState(
            pet: state.pet,
            state: state.state,
            days: state.days,
            settings: state.settings,
            pendingHandshake: state.pendingHandshake,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: now,
            lastEvaluatedAt: now
        )
        return EngineOutcome(
            newState: stamped,
            response: nil,
            moments: [],
            changed: stamped != state
        )

    case .interaction:
        return EngineOutcome(newState: state, response: nil, moments: [], changed: false)

    case .characterReport:
        return EngineOutcome(newState: state, response: nil, moments: [], changed: false)
    }
}
