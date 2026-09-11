import Foundation
import MomoCore

// MARK: - CanvasTouch — the home canvas's pure touch vocabulary (TASK-034;
// 04-character-system §2.3 + §6.1; 03-ux-architecture §5.1)

/// The constants the canvas gesture layer applies (TASK-034 R1). One
/// auditable home, per-constant authority labels, raw literals only in the
/// pin tests — the `CopyRules`/`InteractionRules` discipline carried to the
/// touch domain. The recognizer TIMINGS below are engine-independent
/// presentation tunables (04 §6.1 fixes the clip side, not the recognizer
/// side); the zone rule is DOC-NORMATIVE (04 §2.3).
public enum CanvasTouchLaws {

    /// The §2.1 normalized grid side the rig canvas draws in — the tap
    /// space the zone rule speaks.
    public static let stageGridSide: Double = 1000

    /// 04 §2.3's zone partition: a horizontal rule at y = 550 in the
    /// y-down normalized space (≈ the neck base). Head ABOVE (y < 550),
    /// belly below (y ≥ 550).
    public static let zoneSplitY: Double = 550

    /// Movement that makes a touch a STROKE rather than a tap (grid units;
    /// ≈ 15.6 pt at the Home stage's 260-pt side). 03 §5.1's "movement-based"
    /// distinction — presentation-owned (the doc names the class, not a
    /// number).
    public static let strokeMovementGrid: Double = 60

    /// A hold at/above this duration is a LONG-PRESS (§6.1's press-length
    /// input; presentation-owned threshold — the doc names press-length as
    /// the input, not a number).
    public static let longPressMinimumSeconds: Double = 0.5

    /// Two tap-speed touches ending within this window pair into a
    /// double-tap (§6.1's double-tap row; presentation-owned, the platform
    /// convention's magnitude).
    public static let doubleTapWindowSeconds: Double = 0.35

    /// The touch pool's line-key namespace (04 §10.4). The touch-era
    /// announcement gate was keyed to EXACTLY this prefix because the
    /// feed/play/care pools were later tasks' surface (announcing their
    /// placeholder entries would have read placeholder prose aloud);
    /// TASK-035 landed those pools and widened the gate to the whole react
    /// namespace (`spokenReactPrefix` below) — this constant remains the
    /// touch family's namespace pin.
    public static let spokenTouchPrefix = "momo.line.react.touch."

    /// The react namespace all four spoken families share (04 §10.4:
    /// touch · feed · play · care) — TASK-035 R7's widened announcement-gate
    /// prefix. Slots, greetings, the vocabulary, and the moment classes stay
    /// OUTSIDE the gate (visual copy or non-reaction classes never speak).
    public static let spokenReactPrefix = "momo.line.react."

    /// The react families the announcement gate admits (04 §10.4's four
    /// families; the `.suffix + "."` form guards against prefix collisions
    /// like a hypothetical `touchX` family).
    public static let spokenFamilies = ["touch", "feed", "play", "care"]
}

// MARK: Zone hit-test (the pure partition)

/// 04 §2.3's y = 550 partition as a PURE, total function of the normalized
/// y — the unit-testable heart of R1's zone law. y grows DOWNWARD (the rig
/// canvas's screen-like space: the head anchor sits at y ≈ 380, the belly
/// at y ≈ 760 — 04 §2.3's indicative anchors), so "head above" is y < 550.
/// Out-of-range input stays total: everything above the rule line is head,
/// everything below is belly (INV-2's no-dead-zones reading).
public enum CanvasZoneHitTest {

    /// The zone of a tap at `normalizedY` (rig-grid units, y-down).
    public static func zone(normalizedY: Double) -> TouchZone {
        normalizedY < CanvasTouchLaws.zoneSplitY ? .head : .belly
    }
}

// MARK: Gesture classes (04 §6.1's rows)

/// The gesture a completed canvas touch resolves to — §6.1's tap-family
/// rows. The double-tap carries NO zone (§6.1's one row for both zones);
/// the engine's `touchReaction` maps it zone-less.
public enum CanvasGesture: Equatable, Sendable {
    case tap(TouchZone)
    case doubleTap
    case longPress(TouchZone)
    case stroke(TouchZone)
}

/// The pure classifier for ONE completed touch (TASK-034 R1): movement and
/// hold duration decide stroke and long-press; a tap-speed, low-movement
/// touch returns nil because tap-vs-double-tap needs the SEQUENCE (the
/// `CanvasTapSequence` pairing below), not the touch alone. Pure over the
/// caller-provided values — no clock, no coordinates.
public enum CanvasTouchClassifier {

    /// The gesture a completed touch was, or nil for a tap-speed touch.
    public static func completedGesture(
        holdSeconds: Double,
        maxMovementGrid: Double,
        zone: TouchZone
    ) -> CanvasGesture? {
        if maxMovementGrid >= CanvasTouchLaws.strokeMovementGrid {
            return .stroke(zone)
        }
        if holdSeconds >= CanvasTouchLaws.longPressMinimumSeconds {
            return .longPress(zone)
        }
        return nil
    }
}

/// The pure tap/double-tap pairing state (TASK-034 R1). The gesture layer
/// feeds every tap-speed touch; the sequence answers with a double-tap the
/// moment the second tap pairs, and hands the single tap back when its
/// window matures unclaimed. Immutable-update style: every operation
/// returns the successor sequence, never mutating.
public struct CanvasTapSequence: Equatable, Sendable {

    private struct PendingTap: Equatable, Sendable {
        let zone: TouchZone
        let upAt: Double
    }

    private var pending: PendingTap?

    public init() {
        pending = nil
    }

    /// Whether a single tap is parked awaiting its possible double.
    public var hasPendingTap: Bool { pending != nil }

    /// Feeds a completed tap-speed touch. Pairing requires the second tap
    /// to end AFTER the first (a clock that reset underneath — the
    /// `CharacterClock` pause-zeroing — never pairs across the reset) and
    /// within the window. Unpaired: the tap becomes the new pending one and
    /// no gesture is dispatched yet.
    public func recording(zone: TouchZone, upAt: Double) -> (sequence: CanvasTapSequence, gesture: CanvasGesture?) {
        if let parked = pending, upAt >= parked.upAt,
            upAt - parked.upAt <= CanvasTouchLaws.doubleTapWindowSeconds {
            return (CanvasTapSequence(), .doubleTap)
        }
        var successor = self
        successor.pending = PendingTap(zone: zone, upAt: upAt)
        return (successor, nil)
    }

    /// Hands back the pending single tap once its window has matured
    /// unclaimed (`now` at/after the parked tap's window — the view's
    /// dispatch schedules strictly after it, so the exact-edge double
    /// arithmetic never matters in production). Before that (or with
    /// nothing parked, or with the clock reset underneath) it answers
    /// nothing and keeps the state.
    public func maturing(now: Double) -> (sequence: CanvasTapSequence, gesture: CanvasGesture?) {
        guard let parked = pending, now - parked.upAt >= CanvasTouchLaws.doubleTapWindowSeconds else {
            return (self, nil)
        }
        return (CanvasTapSequence(), .tap(parked.zone))
    }

    /// Drops any parked tap — the cancellation seam (a cancelled or
    /// interrupted touch stream must not speak for a tap that never
    /// completed its disambiguation window).
    public func resetting() -> CanvasTapSequence {
        CanvasTapSequence()
    }
}

// MARK: VoiceOver custom actions (03 §5.1; 04 §2.3 + §10 — R6)

/// The canvas's VoiceOver custom actions (TASK-034 R6): the gesture ANALOGS
/// only — feed/play/care stay the action row's labeled buttons (04 §10's
/// no-rotor-duplication resolution). Each routes the ZONE-LESS Watch
/// convention (FR-17's `.pat(.tap, nil)` path — the clip system's zone-less
/// rows), because VoiceOver offers no zone geometry. The names are the doc's
/// normative labels ("Pat" / "Cuddle", 03 §5.1), carried here so the view
/// assembles `UIAccessibilityCustomAction`s from ONE pinned vocabulary.
public enum CanvasCustomAction: String, CaseIterable, Sendable {

    /// The quick-pat analog — the tap row.
    case pat = "Pat"

    /// The long-press analog (the cuddle/hold) — the long-press row.
    case cuddle = "Cuddle"

    /// The zone-less intent the action routes through the app model.
    public var intent: InteractionIntent.Kind {
        switch self {
        case .pat: return .pat(gesture: .tap, zone: nil)
        case .cuddle: return .pat(gesture: .longPress, zone: nil)
        }
    }
}

// MARK: Spoken-line gate (UX-8 — TASK-034 R7; TASK-035 R7's widening)

/// The spoken-reaction announcement gate (UX-8): a reaction's line key is
/// announced while VoiceOver runs — never rendered. TASK-034 admitted only
/// the touch pool (the other families' placeholder entries must never be
/// spoken); TASK-035 landed the feed/play/care pools and widened the gate
/// to ALL FOUR react families (04 §10.4) — slots, greetings, the
/// vocabulary, and the moment classes stay outside. Pure over the key
/// string (INV-11 holds — keys in, keys out).
public enum SpokenReaction {

    /// The reaction line key to announce, or nil when `lineKey` is outside
    /// the four spoken families (or the plan carries no line at all).
    public static func announcementKey(for lineKey: String?) -> String? {
        guard let lineKey, lineKey.hasPrefix(CanvasTouchLaws.spokenReactPrefix) else {
            return nil
        }
        let remainder = lineKey.dropFirst(CanvasTouchLaws.spokenReactPrefix.count)
        guard CanvasTouchLaws.spokenFamilies.contains(where: {
            remainder.hasPrefix($0 + ".")
        }) else {
            return nil
        }
        return lineKey
    }
}
