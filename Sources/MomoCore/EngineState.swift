import Foundation

// MARK: - Handshake token (05-technical-architecture §4.7)

/// The settle/wake/play handshake token (05 §4.7: "the engine sets the
/// intermediate `wakefulness` + a `Handshake` token (kind + UUID)"). This is
/// the minimal honest carrier §4.7 specifies — exactly those two fields.
///
/// Deliberately NOT owned here: the machine semantics — who issues tokens,
/// when `pendingHandshake` is set/cleared, idempotent report matching by
/// token, and the `handshakeCancelled(HandshakeKind)` preemption paths — are
/// the wakefulness/handshake task's contract (TASK-015; 05 §4.7, INV-8). The
/// character runs its choreography and reports; the token is what the report
/// is matched against.
public struct Handshake: Equatable, Hashable, Sendable, Codable {

    /// Which choreography class this handshake authorizes (04 §9.2).
    public let kind: HandshakeKind

    /// The matching token (§4.7: "kind + UUID") — reports are matched by it.
    public let token: UUID

    public init(kind: HandshakeKind, token: UUID) {
        self.kind = kind
        self.token = token
    }
}

// MARK: - Greeting stamp (TASK-019; 05 §4.2's "Foreground / scenePhase →
// active … absence greeting")

/// The greeting in effect for the current open: the kind plus the instant it
/// was emitted. The minimal honest carrier (TASK-019 Requirement 5's named
/// supersession): the greeting is the one L4 moment that OUTLIVES its event —
/// `DisplayState.greeting` and `CharacterDisplayState.momentRequest` must
/// project it across the events that follow the open, which a derivation
/// alone cannot (the selector's inputs — the pre-stamp open — are consumed at
/// emission time), so the kind persists in state once emitted.
///
/// Presentation owns transience/fading: the stamp persists until the NEXT
/// greeting replaces it — it is "the greeting in effect for the current
/// open", not a timer.
public struct GreetingStamp: Equatable, Sendable, Codable {

    /// The selected kind (`Greeting.select`, TASK-019).
    public let kind: GreetingKind

    /// The open instant the greeting was stamped at (UTC, INV-9).
    public let at: Instant

    public init(kind: GreetingKind, at: Instant) {
        self.kind = kind
        self.at = at
    }
}

// MARK: - EngineState (05-technical-architecture §4.1)

/// The full persisted domain state the engine reduces over (05 §4.1 sketch).
///
/// All properties are `let` — the TASK-012 module convention (zero mutable
/// state in MomoCore); the §4.1 sketch's `var` fields yield to immutability
/// exactly as the domain types did, and `reduce` constructs new values rather
/// than mutating. `Equatable` is added beyond the sketch so FR-13 AC-3's
/// determinism property ("identical (state, event, clock, seed) ⇒ identical
/// outcome") is directly assertable on values.
public struct EngineState: Equatable, Sendable, Codable {

    /// Capacity of the `processedIntents` ledger (05 §4.1: "recent intent ids
    /// (≤ 64) — belt for §6.4"). Single-sourced here because it is the state
    /// shape's own bookkeeping bound; the append/evict semantics that consume
    /// it are the fold/interaction task's (TASK-015 — this skeleton never
    /// grows the ledger).
    public static let processedIntentsCapacity = 64

    /// Pet identity and name (05 §3.1).
    public let pet: Pet

    /// The live pet dimensions + machine fields (05 §3.1).
    public let state: PetState

    /// The 7-day ledger, newest last (05 §4.1). Retention/pruning is the
    /// store's concern (§5.4); the engine appends per dayKey rollover (§4.3,
    /// TASK-015).
    public let days: [DayRecord]

    /// Settings (05 §3.1).
    public let settings: SettingsState

    /// The issued settle/wake/play handshake token, if one is in flight
    /// (§4.7). Nil whenever no choreography is pending a report.
    public let pendingHandshake: Handshake?

    /// Recent intent ids for exactly-once interaction application — the
    /// engine-side belt for §6.4's dual idempotency guards (FR-18 AC-1,
    /// INV-10). Recorded in intent-arrival order; evicted oldest-first at
    /// `processedIntentsCapacity`.
    public let processedIntents: [UUID]

    /// The highest bond stage whose one-time celebration has fired
    /// (§4.6's `highestCelebratedStage` guard; UX-10; FR-10 AC-4).
    public let highestCelebratedStage: BondStage

    /// Last foreground-open instant (UTC, INV-9). Stamped by `.evaluate`
    /// (§4.2's foreground trigger); greeting selection consumes it (TASK-015).
    public let lastOpenedAt: Instant

    /// Last evaluation instant (UTC, INV-9) — the fold's high-water mark
    /// (§4.2/§4.3; segment folding decomposes `now − lastEvaluatedAt`).
    public let lastEvaluatedAt: Instant

    /// The greeting in effect for the current open (TASK-019; the
    /// `GreetingStamp` header). Stamped by `.evaluate` when the greeting
    /// selector fires; nil in the initial state (onboarding's own flow is
    /// the greeting — 04 §10.2's S1–S3). Persists until the next greeting;
    /// presentation owns transience.
    public let lastGreeting: GreetingStamp?

    public init(
        pet: Pet,
        state: PetState,
        days: [DayRecord],
        settings: SettingsState,
        pendingHandshake: Handshake?,
        processedIntents: [UUID],
        highestCelebratedStage: BondStage,
        lastOpenedAt: Instant,
        lastEvaluatedAt: Instant,
        lastGreeting: GreetingStamp?
    ) {
        self.pet = pet
        self.state = state
        self.days = days
        self.settings = settings
        self.pendingHandshake = pendingHandshake
        self.processedIntents = processedIntents
        self.highestCelebratedStage = highestCelebratedStage
        self.lastOpenedAt = lastOpenedAt
        self.lastEvaluatedAt = lastEvaluatedAt
        self.lastGreeting = lastGreeting
    }
}
