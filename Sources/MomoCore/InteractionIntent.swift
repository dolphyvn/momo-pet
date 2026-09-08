import Foundation

// MARK: - Touch vocabulary (04 §2.3, §6.1)

/// Touch gestures (04 §6.1: tap / double-tap / long-press / stroke).
public enum PatGesture: Equatable, Hashable, Sendable {
    case tap
    case doubleTap
    case longPress
    case stroke
}

/// Touch zones (04 §2.3: exactly two, split at the y = 550 rule — head / belly).
public enum TouchZone: Equatable, Hashable, Sendable {
    case head
    case belly
}

// MARK: - InteractionIntent

/// An interaction intent arriving from the iPhone UI or Watch sync
/// (05-technical-architecture §3.1).
///
/// INV-10's representation half lives here: every intent carries a
/// non-optional UUID `id` — the idempotency key (FR-18 AC-1). The exactly-once
/// application (replay/duplicate delivery as no-op, intent-UUID set +
/// per-epoch watermark, §6.4) is the sync/engine contract (EPIC-004/005),
/// consuming this key.
///
/// `Sendable` only, per 05 §3.1 — intents are messages, not compared values.
public struct InteractionIntent: Sendable {

    /// Where the intent came from (05 §3.1: `.iPhone` / `.watch`).
    public enum Source: Sendable {
        case iPhone
        case watch
    }

    /// The interaction itself (05 §3.1 Kind; the Watch sends
    /// `.pat(.tap, nil)` — FR-17's single surface).
    public enum Kind: Sendable {
        case pat(gesture: PatGesture, zone: TouchZone?)
        case feed
        case play
        case tuckIn
        case nap
    }

    /// Idempotency key (FR-18 AC-1; INV-10).
    public let id: UUID

    /// Origin device.
    public let source: Source

    /// Attributed day = the calendar day of `timestamp` (D20; Q6's
    /// day-ownership rule, PRD §5.1 rule 6) — derived by the caller via
    /// `DayKey.make`, never stored as a timezone-dependent date type (INV-9).
    public let localDayKey: String

    /// When the interaction happened (UTC instant, D20 / INV-9) — window
    /// checks evaluate this, never the application instant (§4.8).
    public let timestamp: Instant

    /// What happened.
    public let kind: Kind

    public init(
        id: UUID,
        source: Source,
        localDayKey: String,
        timestamp: Instant,
        kind: Kind
    ) {
        self.id = id
        self.source = source
        self.localDayKey = localDayKey
        self.timestamp = timestamp
        self.kind = kind
    }
}
