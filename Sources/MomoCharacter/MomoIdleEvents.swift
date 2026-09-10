import CoreGraphics
import MomoCore

// MARK: - Event kinds (§5.2's four schedulers)

/// The idle schedulers of 04 §5.2, as event identities. The case order is
/// the arbiter priority (§7.4 rule 4): when more than three property groups
/// would animate at once, LOWER cases keep their groups and higher cases
/// yield — the blink (the aliveness floor) can never be displaced.
public enum MomoIdleEventKind: Int, Sendable, CaseIterable, Comparable {

    case blink = 0
    case gaze = 1
    case variant = 2
    case yawn = 3

    /// Scheduler priority: lower wins the property-group budget.
    public var arbiterPriority: Int { rawValue }

    public static func < (lhs: MomoIdleEventKind, rhs: MomoIdleEventKind) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

// MARK: - Property groups (§7.4 rule 4's concurrency budget)

/// The coarse property groups the concurrency budget counts. An event
/// declares the groups its rendering touches; the arbiter admits events
/// while their groups' union stays within the ≤ 3 budget (breath excluded —
/// §5.3 splits the standing breath from event motion). Groups are additive:
/// a later task's new event kind declares groups, not new budget rules.
public struct MomoPropertyGroup: OptionSet, Hashable, Sendable {

    public let rawValue: UInt

    public init(rawValue: UInt) {
        self.rawValue = rawValue
    }

    public static let body = MomoPropertyGroup(rawValue: 1 << 0)
    public static let head = MomoPropertyGroup(rawValue: 1 << 1)
    public static let ears = MomoPropertyGroup(rawValue: 1 << 2)
    public static let tail = MomoPropertyGroup(rawValue: 1 << 3)
    public static let aperture = MomoPropertyGroup(rawValue: 1 << 4)
    public static let gaze = MomoPropertyGroup(rawValue: 1 << 5)
}

// MARK: - Gaze targets (§5.2's five-point set)

/// The five-point gaze set §5.2 gives the look-around scheduler.
public enum MomoGazeTarget: String, Sendable, CaseIterable {

    case left
    case right
    case upTowardUser
    case atUser
    case eyesCloseMoment

    /// The target's pupil offset in grid units. Magnitudes stay inside the
    /// §2.4 clamp (30 % of the 50-unit eye radius = 15 units); the model
    /// re-clamps anyway. `eyesCloseMoment` keeps the gaze centered — its
    /// "look" IS the slow close and reopen of the aperture.
    public var pupilOffset: CGPoint {
        switch self {
        case .left: CGPoint(x: -15, y: 0)
        case .right: CGPoint(x: 15, y: 0)
        case .upTowardUser: CGPoint(x: 0, y: -11)
        case .atUser, .eyesCloseMoment: .zero
        }
    }

    /// The §5.2 base draw weights (authored; the look-around must read
    /// scattered, with meeting the user's eyes the single most likely
    /// target). Tuple labels match `MomoIdleRandom.nextWeighted`'s entry
    /// contract; this array order is the canonical draw-scan order. Joyful
    /// multiplies `atUser` ×1.4 before renormalizing (§5.2).
    public static let baseWeights: [(value: MomoGazeTarget, weight: Double)] = [
        (.left, 0.22), (.right, 0.22), (.upTowardUser, 0.16),
        (.atUser, 0.25), (.eyesCloseMoment, 0.15),
    ]
}

// MARK: - Event payloads

/// A blink's drawn envelope (§7.1 close/open bands; the double-blink
/// repeats the pair after a small authored gap).
public struct MomoBlinkEnvelope: Equatable, Sendable {

    /// 12 % of blinks are doubles (§5.2).
    public let isDouble: Bool
    public let closeSeconds: Double
    public let openSeconds: Double
    /// The authored pause between the two closings of a double blink.
    public let interBlinkGapSeconds: Double

    public init(
        isDouble: Bool, closeSeconds: Double, openSeconds: Double,
        interBlinkGapSeconds: Double
    ) {
        self.isDouble = isDouble
        self.closeSeconds = closeSeconds
        self.openSeconds = openSeconds
        self.interBlinkGapSeconds = interBlinkGapSeconds
    }
}

/// A look-around event: shift to the target, hold it, return (§7.1 gaze
/// row). The hold is stillness — it costs no motion-occupancy budget.
public struct MomoGazeEnvelope: Equatable, Sendable {

    public let target: MomoGazeTarget
    public let shiftSeconds: Double
    public let holdSeconds: Double
    public let returnSeconds: Double

    public init(
        target: MomoGazeTarget, shiftSeconds: Double,
        holdSeconds: Double, returnSeconds: Double
    ) {
        self.target = target
        self.shiftSeconds = shiftSeconds
        self.holdSeconds = holdSeconds
        self.returnSeconds = returnSeconds
    }
}

/// An idle-variant event (catalog §5.2): entry envelope, held pose, exit
/// envelope. Spring-family variants fix their entry/exit to the spring
/// response; crossfade-family variants draw from §7.1's state-crossfade
/// band.
public struct MomoVariantEnvelope: Equatable, Sendable {

    public let id: MomoVariantID
    /// Left/right (or sign) mirrored draw, where the variant has a side.
    public let mirrored: Bool
    public let inSeconds: Double
    public let holdSeconds: Double
    public let outSeconds: Double

    public init(
        id: MomoVariantID, mirrored: Bool,
        inSeconds: Double, holdSeconds: Double, outSeconds: Double
    ) {
        self.id = id
        self.mirrored = mirrored
        self.inSeconds = inSeconds
        self.holdSeconds = holdSeconds
        self.outSeconds = outSeconds
    }
}

/// A yawn (Drowsy-only, §5.2): eyes close, a small head nod, reopen — the
/// authored 0.45 / 0.5 / 0.45 split of §7.1's 1.4 s. The mouth stays at the
/// authored neutral: an open-mouth yawn pose does not exist in the three
/// pre-built mouth shapes (R1) — the geometry gap is routed, not
/// synthesized.
public struct MomoYawnEnvelope: Equatable, Sendable {

    public let closeSeconds: Double
    public let holdSeconds: Double
    public let openSeconds: Double

    public init(closeSeconds: Double, holdSeconds: Double, openSeconds: Double) {
        self.closeSeconds = closeSeconds
        self.holdSeconds = holdSeconds
        self.openSeconds = openSeconds
    }
}

// MARK: - The event

/// One scheduled idle event: kind, window, and the payload the motion model
/// renders. Events are VALUE data — the schedule is recomputable and
/// comparable (determinism pins compare event arrays byte-for-byte).
public struct MomoIdleEvent: Equatable, Sendable {

    public let kind: MomoIdleEventKind
    /// Start on the character timeline (seconds since the clock's resume).
    public let start: Double
    public let duration: Double
    public let payload: Payload

    public enum Payload: Equatable, Sendable {
        case blink(MomoBlinkEnvelope)
        case gaze(MomoGazeEnvelope)
        case variant(MomoVariantEnvelope)
        case yawn(MomoYawnEnvelope)
    }

    public init(kind: MomoIdleEventKind, start: Double, duration: Double, payload: Payload) {
        self.kind = kind
        self.start = start
        self.duration = duration
        self.payload = payload
    }

    /// Whether the event's window covers `time` (half-open: start ≤ t <
    /// start + duration).
    public func isActive(at time: Double) -> Bool {
        start <= time && time < start + duration
    }

    /// The property groups this event's rendering animates (§7.4 rule 4).
    public var propertyGroups: MomoPropertyGroup {
        switch payload {
        case .blink:
            return [.aperture]
        case .gaze(let envelope):
            return envelope.target == .eyesCloseMoment
                ? [.aperture] : [.gaze]
        case .variant(let envelope):
            return MomoIdleVariantCatalog.spec(for: envelope.id)?.propertyGroups ?? []
        case .yawn:
            return [.aperture, .head]
        }
    }
}

// MARK: - The arbiter (§7.4 rule 4, executable)

/// Admits active events onto the rig under the §7.4 rule 4 concurrency
/// budget: at most `concurrentPropertyBudget` property groups animate at
/// once (breath excluded — §5.3 splits the standing breath from event
/// motion). Events are admitted in scheduler priority order (blink first);
/// an event that would push the group union past the budget YIELDS for that
/// instant — it renders as nothing and the band expression shows instead.
/// The SCHEDULE itself stays doc-exact (§5.2 distributions are pinned on
/// the schedule); the arbiter is the render-level enforcement.
public enum MomoIdleArbiter {

    /// §7.4 rule 4: "Ambient idle animates ≤ 3 properties concurrently."
    public static let concurrentPropertyBudget = 3

    /// The active events at `time`, priority-admitted under the budget.
    public static func admitted(
        schedule: [MomoIdleEvent], at time: Double,
        budget: Int = concurrentPropertyBudget
    ) -> [MomoIdleEvent] {
        let active = schedule
            .filter { $0.isActive(at: time) }
            .sorted { $0.kind < $1.kind }
        var usedGroups: MomoPropertyGroup = []
        var admitted: [MomoIdleEvent] = []
        for event in active {
            let union = usedGroups.union(event.propertyGroups)
            if union.rawValue.nonzeroBitCount <= budget {
                usedGroups = union
                admitted.append(event)
            }
        }
        return admitted
    }
}
