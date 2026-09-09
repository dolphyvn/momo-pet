import Foundation

// MARK: - reduce: the single pure entry point (05-technical-architecture §4.1;
// ADR-004: pure deterministic core, event-driven catch-up, no timers)

/// The engine's single entry point: `(state, event, clock, calendar, rng) →
/// outcome`, pure (05 §4.1). Identical inputs ⇒ identical outcome (FR-13
/// AC-3): no I/O, no timers, no singletons, no ambient time, no system
/// randomness — clock, calendar, and RNG are injected, and the engine reads
/// each only where an event's semantics require it (pinned by probes).
///
/// **Calendar injection — the documented §4.1 deviation (TASK-015).** The
/// §4.1 sketch's signature is `(state, event, clock, rng)`; the fold needs
/// the user's calendar to decompose elapsed time into local segments (§4.2)
/// and to derive `dayKey`s (D20). Carrying the calendar in `EngineState` was
/// rejected — persisted state must stay calendar-free (INV-9's spirit: no
/// stored value depends on the local timezone) and `Calendar` is environment,
/// not domain; per-event payloads were rejected — every event kind folds
/// (§4.2), so the payload would only re-state a parameter. The minimal honest
/// deviation is a third injected-environment parameter beside `clock`, and
/// the §4.1 type-set is otherwise intact. Deviation recorded in the TASK-015
/// Implementation Notes.
///
/// **Event semantics (real time — TASK-015; supersedes TASK-014's
/// bookkeeping-only honesty):**
///
/// - `.evaluate(now:)` — §4.2's catch-up evaluation: forward-only time fold
///   to `now` (`TimeFold` — segment dynamics, night/morning landings,
///   landing-day rollover), then the wake-stretch mint (below), then the
///   open/evaluation stamps (`lastOpenedAt` = `now` — every in-session
///   evaluation is an open of the pet, the TASK-014 convention the greeting
///   consumer will read).
/// - `.interaction(intent)` — the INV-10 belt first (FR-18 AC-1): an intent
///   id already in `processedIntents` is a total no-op — replay/duplicate
///   delivery must not even fold. A fresh id folds to the intent's own
///   timestamp (its instant is authoritative, §4.8's window-check rule),
///   mints the wake stretch if due, then applies the interaction semantics —
///   the §4.4–4.5 response matrix, effects, and counting (TASK-016;
///   `InteractionSemantics`), whose ResponsePlan is the outcome's `response`.
///   The intent is then recorded with oldest-first eviction at
///   `EngineState.processedIntentsCapacity`. Bond awards (hello, variety)
///   ride the counting events (TASK-017); quest-completion moments are
///   TASK-018's (recorded seam).
/// - `.characterReport(report)` — fold-to-now FIRST (§4.2's trigger table),
///   using the injected clock: reports carry no instant of their own, so
///   `clock.now()` is their fold target — the one event kind that reads the
///   clock. Then `HandshakeMachine` applies the report at that instant
///   (INV-8's legal transitions; idempotent matching; stale discard without
///   stranding) — the instant parameter is what dates the play round's
///   unified-cease effects and count to the cease's ledger day (TASK-016).
///
/// **The wake-stretch mint (§4.3 closing / §4.7).** A fold that lands
/// `.waking` deliberately issues no handshake (nothing was listening); the
/// NEXT event processed while the pet is still `.waking` with no pending
/// handshake mints the `.wake` handshake — the in-session emission of the
/// morning beat (FR-4). Tokens are minted from two draws of the injected
/// generator (16 bytes, big-endian): never `UUID()` (purity scan). The
/// generator's seed lineage is §4.10's — the app layer seeds it from
/// `DaySeed.make(…, salt: .choreography)`, so the token stream is
/// day-stable-seeded and fully deterministic; the engine performs no
/// `DaySeed` derivation of its own, keeping the determinism tuple exactly
/// (state, event, clock, calendar, seed).
///
/// **Forward-only folds.** `lastEvaluatedAt` is the fold's high-water mark:
/// an event whose instant precedes it folds nothing and never regresses the
/// mark (manual backward clock changes re-derive already-awarded `dayKey`s —
/// `TimeFold`'s keyed rollover makes double resets structurally impossible —
/// and re-fold no already-folded time). `.evaluate` still stamps
/// `lastOpenedAt` to the event instant: the open happened at that wall time.
///
/// `changed` remains honest by construction: `newState != state` — equality
/// on the whole value, so anything the engine does not actually alter reports
/// `false` (no persistence write, no sync push — §4.1).
public func reduce(
    _ state: EngineState,
    _ event: EngineEvent,
    clock: EngineClock,
    calendar: Calendar,
    rng: inout SeededGenerator
) -> EngineOutcome {
    switch event {
    case .evaluate(let now):
        return evaluate(state, at: now, calendar: calendar, rng: &rng)

    case .interaction(let intent):
        return interaction(state, intent, calendar: calendar, rng: &rng)

    case .characterReport(let report):
        return characterReport(state, report, clock: clock, calendar: calendar, rng: &rng)
    }
}

// MARK: - Event paths

/// `.evaluate`: fold to `now`, mint check, stamps.
private func evaluate(_ state: EngineState, at now: Instant, calendar: Calendar, rng: inout SeededGenerator) -> EngineOutcome {
    let fold = TimeFold.apply(
        petState: state.state,
        days: state.days,
        pendingHandshake: state.pendingHandshake,
        from: state.lastEvaluatedAt,
        to: now,
        calendar: calendar
    )
    var next = state
        .with(state: fold.petState)
        .with(days: fold.days)
        .with(pendingHandshake: fold.pendingHandshake)
    next = mintWakeStretchIfNeeded(next, incomingWakefulness: state.state.wakefulness, rng: &rng)
    // Stamps: the fold mark never regresses; the open stamp follows the wall.
    next = next.with(
        stamps: now,
        lastEvaluatedAt: max(state.lastEvaluatedAt, now)
    )
    // §4.6 stage reconciliation: state-based, after every path's mutation —
    // a threshold crossed while the app was closed surfaces here (UX-10).
    let reconciled = BondLedger.reconcileStage(next)
    return EngineOutcome(newState: reconciled.state, response: nil, moments: reconciled.moments, changed: reconciled.state != state)
}

/// `.interaction`: INV-10 belt, then fold to the intent's instant, then the
/// wake-stretch mint, then the interaction semantics (05 §4.4–4.5; TASK-016):
/// effects, counts, machine writes, and the ResponsePlan all derive from the
/// FOLDED state at the intent's instant. The §4.6 bond ledger rides the
/// counting events (TASK-017), and stage reconciliation closes the path —
/// quest-completion moments remain TASK-018's (recorded seam).
/// Token mints happen in wake-stretch-then-interaction order, so the draw
/// lineage is: stretch (if it fires) first, then the interaction's own
/// authorization token, if any.
private func interaction(_ state: EngineState, _ intent: InteractionIntent, calendar: Calendar, rng: inout SeededGenerator) -> EngineOutcome {
    guard !state.processedIntents.contains(intent.id) else {
        // Duplicate delivery: a total no-op (INV-10 — "replay/duplicate
        // delivery is a no-op"), before any folding.
        return EngineOutcome(newState: state, response: nil, moments: [], changed: false)
    }
    let fold = TimeFold.apply(
        petState: state.state,
        days: state.days,
        pendingHandshake: state.pendingHandshake,
        from: state.lastEvaluatedAt,
        to: intent.timestamp,
        calendar: calendar
    )
    var next = state
        .with(state: fold.petState)
        .with(days: fold.days)
        .with(pendingHandshake: fold.pendingHandshake)
    next = mintWakeStretchIfNeeded(next, incomingWakefulness: state.state.wakefulness, rng: &rng)
    let applied = InteractionSemantics.apply(intent, to: next, calendar: calendar, rng: &rng)
    next = applied.state
    next = next.with(processedIntents: record(intent.id, in: next.processedIntents))
    next = next.with(
        stamps: nil,
        lastEvaluatedAt: max(state.lastEvaluatedAt, intent.timestamp)
    )
    // §4.6 stage reconciliation after the interaction's mutation: a
    // hello-carrying first pat can cross a stage threshold (contract Req 7).
    let reconciled = BondLedger.reconcileStage(next)
    return EngineOutcome(newState: reconciled.state, response: applied.response, moments: reconciled.moments, changed: reconciled.state != state)
}

/// `.characterReport`: fold-to-now via the injected clock (the one clock
/// read), then the handshake machine, then the mint check.
private func characterReport(_ state: EngineState, _ report: CharacterReport, clock: EngineClock, calendar: Calendar, rng: inout SeededGenerator) -> EngineOutcome {
    let now = clock.now()
    let fold = TimeFold.apply(
        petState: state.state,
        days: state.days,
        pendingHandshake: state.pendingHandshake,
        from: state.lastEvaluatedAt,
        to: now,
        calendar: calendar
    )
    let folded = state
        .with(state: fold.petState)
        .with(days: fold.days)
        .with(pendingHandshake: fold.pendingHandshake)
    let applied = HandshakeMachine.apply(report, to: folded, at: now, calendar: calendar)
    let next = mintWakeStretchIfNeeded(applied, incomingWakefulness: folded.state.wakefulness, rng: &rng)
        .with(
            stamps: nil,
            lastEvaluatedAt: max(state.lastEvaluatedAt, now)
        )
    // §4.6 stage reconciliation after the report's mutation (a care-side
    // award can cross; the fold in this path can too).
    let reconciled = BondLedger.reconcileStage(next)
    return EngineOutcome(newState: reconciled.state, response: nil, moments: reconciled.moments, changed: reconciled.state != state)
}

// MARK: - Wake-stretch mint + intent ledger

/// Mints the `.wake` handshake when an event finds the pet still in the
/// fold-landed waking state with nothing pending (see `reduce`'s header).
/// The incoming-wakefulness check is what defers the mint past the fold that
/// LANDED `.waking` — the emission is the next event's job, not that fold's.
private func mintWakeStretchIfNeeded(_ state: EngineState, incomingWakefulness: Wakefulness, rng: inout SeededGenerator) -> EngineState {
    guard state.state.wakefulness == .waking,
          state.pendingHandshake == nil,
          incomingWakefulness == .waking
    else { return state }
    return state.with(pendingHandshake: Handshake(kind: .wake, token: mintToken(rng: &rng)))
}

/// A handshake token: 16 bytes from two generator draws, big-endian — no
/// system randomness (§4.10; the purity scan bans the ambient `UUID()`
/// initializer in MomoCore, so the deterministic 16-byte initializer is
/// reached via `.init`). Internal: shared with `InteractionSemantics`, whose
/// play/tuck-in authorizations mint with the same two-draw discipline
/// (TASK-016 Requirements 7–8).
func mintToken(rng: inout SeededGenerator) -> UUID {
    let high = rng.next()
    let low = rng.next()
    var bytes: [UInt8] = []
    for word in [high, low] {
        for shift in stride(from: 56, through: 0, by: -8) {
            bytes.append(UInt8(truncatingIfNeeded: word >> UInt64(shift)))
        }
    }
    let token: UUID = .init(uuid: (bytes[0], bytes[1], bytes[2], bytes[3],
                                   bytes[4], bytes[5], bytes[6], bytes[7],
                                   bytes[8], bytes[9], bytes[10], bytes[11],
                                   bytes[12], bytes[13], bytes[14], bytes[15]))
    return token
}

/// Appends an intent id, evicting oldest-first beyond
/// `EngineState.processedIntentsCapacity` (§4.1: "recent intent ids (≤ 64) —
/// belt for §6.4").
private func record(_ id: UUID, in ledger: [UUID]) -> [UUID] {
    var updated = ledger
    updated.append(id)
    if updated.count > EngineState.processedIntentsCapacity {
        updated.removeFirst(updated.count - EngineState.processedIntentsCapacity)
    }
    return updated
}
