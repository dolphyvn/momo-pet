import Foundation

// MARK: - EngineEvent + EngineOutcome (05-technical-architecture §4.1)

/// The three event kinds the engine consumes (05 §4.1 sketch). Sendable
/// message types — deliberately not `Equatable` (`InteractionIntent` is a
/// message, not a compared value; 05 §3.1).
public enum EngineEvent: Sendable {

    /// A user interaction arriving from either device (§4.4 semantics —
    /// TASK-016/017 own the response matrix and numeric effects).
    case interaction(InteractionIntent)

    /// The character's completion/cancellation report (04 §9.2 vocabulary,
    /// incl. `handshakeCancelled`) — handshake application is TASK-015's.
    case characterReport(CharacterReport)

    /// Catch-up/scheduled evaluation (§4.2): the caller states the evaluation
    /// instant — foreground opens, in-session boundaries (22:00 / 07:00 /
    /// local midnight / nap-end), and fold-before-event triggers all arrive
    /// as this event. Time passes ONLY here (ADR-004: no timers).
    case evaluate(now: Instant)
}

/// The engine's answer to one event (05 §4.1 sketch).
///
/// Side effects live in the app layer, in the §4.1 fixed order: apply
/// `newState` → persist if `changed` (write-through) → deliver
/// `response`/`moments` → push snapshot if `changed`. The engine itself
/// performs none of them (purity, ADR-004).
public struct EngineOutcome: Equatable, Sendable {

    /// The state after the event.
    public let newState: EngineState

    /// The interaction's response plan (04 §9.2) — "one per interaction
    /// event"; nil for every other event kind (and for interactions until the
    /// response matrix lands, TASK-016/017).
    public let response: ResponsePlan?

    /// Moment requests (greeting / questCompleted / bondStageReached —
    /// 04 §9.2); TASK-015/018 populate these.
    public let moments: [CharacterMoment]

    /// False ⇒ the app layer persists nothing and pushes no snapshot
    /// (05 §4.1: "false ⇒ no persistence write, no sync push"). Honest by
    /// construction: the engine reports whether the new state differs from
    /// the input state — nothing else counts as a change.
    public let changed: Bool

    public init(
        newState: EngineState,
        response: ResponsePlan?,
        moments: [CharacterMoment],
        changed: Bool
    ) {
        self.newState = newState
        self.response = response
        self.moments = moments
        self.changed = changed
    }
}
