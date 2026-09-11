import CoreGraphics
import MomoCore

// MARK: - Events into the director (04 §9.2's character-facing seam)

/// Everything the character side can observe, as timeline-stamped values.
/// The director folds these in order; the fold is PURE — the same event
/// list always yields the same state, overlay trajectory and report log
/// (the twin-equality pin). Event times are character-timeline seconds
/// (`CharacterClock.elapsed`), monotone within one awake epoch.
public enum MomoCharacterEvent: Equatable, Sendable {

    /// The engine's plan (§9.2) — the character executes it, never
    /// deciding warm/declined itself (D18).
    case plan(ResponsePlan, at: Double)

    /// The engine's read-model update (§9.3) — the only door for
    /// wakefulness transitions and L4 moment requests.
    case displayState(CharacterDisplayState, at: Double)

    /// Presentation-forwarded touch tracking (§6.1's press-length and
    /// stroke boundaries are input).
    case touchBegan(zone: TouchZone?, at: Double)
    case touchEnded(at: Double)

    /// The play pacer's fingertip samples (§6.3): offset in grid units
    /// from the stage center, and whether the finger is moving.
    case fingertip(offset: CGPoint, moving: Bool, at: Double)

    /// §7.4 rule 8 / §4.1 rule 7: hide pauses; what each layer does is
    /// the coherence matrix's job.
    case appHidden(at: Double)
    case appShown(at: Double)

    /// The user's early exit from a play round (TASK-035 R6; UX-3's "Done"
    /// pill): the ONE presentation→director stop event. The fold cancels an
    /// in-flight round through the SAME displacement-cancel machinery
    /// `appHidden` uses — exactly-once `handshakeCancelled(.play)` when (and
    /// only when) a round was in flight — and is a tolerated no-op otherwise
    /// (never `.appHidden`-as-lie, never a UI-only dismissal).
    case playStopped(at: Double)

    /// A batch of engine-minted moments (TASK-036 R1; FR-16): quest
    /// completions and bond-stage crossings born as EVENTS (`EngineOutcome`
    /// §4.3 L4), delivered through the app model's `.deliverMoments` arm.
    /// The state-born greeting door stays `.displayState`'s `momentRequest`
    /// — the two doors share one L4 slot, event moments queueing behind a
    /// fold that arrives mid-moment. The batch plays FIFO in causal order
    /// (the engine's emission order); an empty batch is a no-op.
    case moments([CharacterMoment], at: Double)
}

extension MomoDirectorState {

    /// The event's fold instant (every variant carries exactly one).
    func eventTime(of event: MomoCharacterEvent) -> Double {
        switch event {
        case .plan(_, let at), .displayState(_, let at), .touchEnded(let at),
            .fingertip(_, _, let at), .appHidden(let at), .appShown(let at),
            .playStopped(let at), .moments(_, let at):
            return at
        case .touchBegan(_, let at):
            return at
        }
    }
}

// MARK: - Director value types (TASK-028 R3/R4)

/// One emitted `CharacterReport` with the instant it resolves at. The log
/// is append-only; entries are emitted exactly once by construction (each
/// append site is guarded by the owning instance's `reported` flag).
public struct MomoReportEntry: Equatable, Sendable {

    public let report: CharacterReport
    public let at: Double

    /// The report's identity — `CharacterReport` lives in frozen MomoCore,
    /// so equality is realized here (the exactly-once checks compare
    /// entries by identity + instant).
    var identity: String {
        switch report {
        case .reactionFinished(let id): return "reaction:\(id.rawValue)"
        case .playRoundFinished: return "playRound"
        case .handshakeCancelled(let kind): return "cancelled:\(kind)"
        case .settleFinished: return "settle"
        case .wakeFinished: return "wake"
        case .momentFinished(let moment): return "moment:\(momentIdentity(moment))"
        }
    }

    private func momentIdentity(_ moment: CharacterMoment) -> String {
        switch moment {
        case .greeting(let kind): return "greeting:\(kind)"
        case .questCompleted: return "quest"
        case .bondStageReached(let stage): return "bond:\(stage)"
        }
    }

    public static func == (lhs: MomoReportEntry, rhs: MomoReportEntry) -> Bool {
        lhs.identity == rhs.identity && lhs.at == rhs.at
    }
}

// MARK: Layer instances

/// One scheduled L3 reaction: its clip identity, its resolved instants,
/// and the shape modifiers the coherence rules applied. `start`/`end` are
/// absolute character-timeline seconds; `supersededAt` marks a cut (newest
/// wins / L2 preemption / app-hide), faded over `fadeOutSeconds`.
struct MomoReactionSlot: Equatable, Sendable {

    let key: MomoReactionKey
    /// Mutable only for the queue's drop-oldest re-chain (the survivors
    /// shift to the vacated start — MINOR-3); a visible run never moves.
    var start: Double
    /// The resolved end (nil = press-shaped and still holding; touchEnded
    /// resolves it).
    var end: Double?
    let tempo: Double
    let context: MomoReactionContext
    /// Press-shaped clips: the resolved hold length (nil = still holding).
    var holdSeconds: Double?
    /// The stroke deepening (2nd stroke in the same touch).
    var deepened: Bool
    /// Rule 3's abbreviated class (3–4 in the window): half duration.
    let abbreviated: Bool
    /// Rule 5: rendered as the eating glance-up beat (the meal continues).
    let glanceUp: Bool
    var supersededAt: Double?
    var fadeOutSeconds: Double
    /// The report was emitted (exactly-once guard for the deferred paths).
    var reported: Bool
    /// A cyclical stroke's end was resolved by touchEnded (the authored
    /// cycle cap no longer applies).
    var touchResolved: Bool
}

/// The L2 occupant: a state beat clip or one of the three handshakes.
enum MomoStateInstance: Equatable, Sendable {

    case clip(MomoReactionSlot)
    case settle(start: Double, reported: Bool)
    case wake(start: Double)
    case play(MomoPlayInstance)
}

/// The play round's pacer state (§6.3). Instants are absolute.
struct MomoPlayInstance: Equatable, Sendable {

    let start: Double
    let drowsy: Bool
    let followStart: Double
    /// The resolved follow cease (nil = still following).
    var followCease: Double?
    var payoffEnd: Double?
    /// When the fingertip's current stillness began (nil = moving).
    var restStart: Double?
    var lastOffset: CGPoint
    var reported: Bool
}

/// The L4 moment instance (replays from 0 across app-hide).
struct MomoMomentInstance: Equatable, Sendable {

    let moment: CharacterMoment
    /// The (possibly replayed) start — `applyShown` re-stamps it into the
    /// new epoch.
    var start: Double
    var reported: Bool
}

/// The L1 press micro-feedback tracker (and the long-press clock).
struct MomoPressState: Equatable, Sendable {

    let zone: TouchZone?
    let start: Double
    /// Rule 1: when a reaction arrived, the feedback began fading.
    var fadingSince: Double?
}

/// Rule 3's identical-reaction coalescing window.
struct MomoCoalescer: Equatable, Sendable {

    let id: String
    let windowStart: Double
    var count: Int
    var coalescedIssued: Bool
}
