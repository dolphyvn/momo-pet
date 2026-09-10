import Foundation
import MomoCore

/// The character's ONE pausable animation timeline (TASK-026 Requirement 1;
/// 04 §9.5 pause authority, §7.4 rule 1). Every channel the rig renders is a
/// function of this clock's elapsed time — so pausing it is pausing
/// everything, in one call, and a stopped clock (elapsed 0) freezes the
/// character at its unaged pose — every motion channel at rest, the band
/// expression base otherwise (TASK-027).
///
/// Contract (all pinned headlessly in `CharacterClockTests`):
/// - **Injected time source.** The clock NEVER reads ambient time — every
///   instant comes from the injected `EngineClock` (the engine-era
///   discipline; `SystemEngineClock` stays MomoCore's one ambient site).
///   `elapsed(at:)` additionally answers arbitrary instants so a
///   TimelineView context date renders deterministically.
/// - **Pause zeroes the timeline.** After `pause()`, elapsed is 0 and stays
///   0 no matter how long the world moves on.
/// - **Resume restarts from zero.** No backlog replay (§5.3): returning
///   after a long background dwell resumes at elapsed 0, not at the missed
///   time. Double `resume()` never resets a running accumulation.
/// - **Idempotent.** Double pause and double resume are both no-ops.
/// - **SwiftUI-independent.** A pure type over `EngineClock`; the view
///   observes it and maps scenePhase onto `pause()`/`resume()` — that one
///   call is §7.4 rule 1's global gate.
public final class CharacterClock: @unchecked Sendable {

    private let timeSource: any EngineClock
    private var state = State()
    private let lock = NSLock()

    private struct State {
        var running = false
        var resumeAnchor = Instant(timeIntervalSince1970: 0)
    }

    /// Creates a stopped clock (elapsed 0 → the unaged pose) over an
    /// injected time source.
    public init(timeSource: any EngineClock) {
        self.timeSource = timeSource
    }

    /// Whether the timeline is currently accumulating.
    public var isRunning: Bool {
        lock.withLock { state.running }
    }

    /// Starts (or restarts) accumulation from zero. Idempotent: calling it
    /// while already running never re-anchors, so elapsed keeps growing.
    public func resume() {
        lock.withLock {
            guard !state.running else { return }
            state.resumeAnchor = timeSource.now()
            state.running = true
        }
    }

    /// Stops the timeline and zeroes it. Idempotent. This is §7.4 rule 1's
    /// one call: scenePhase ≠ active / AOD ⇒ pause everything.
    public func pause() {
        lock.withLock { state.running = false }
    }

    /// Elapsed seconds on the character timeline right now (0 while stopped).
    public func elapsed() -> Double {
        elapsed(at: timeSource.now())
    }

    /// Elapsed seconds at an arbitrary instant — 0 while stopped, otherwise
    /// clamped at 0 so a manual wall-clock change never yields negative
    /// time. Side-effect-free: rendering a past context date never mutates
    /// the clock.
    public func elapsed(at instant: Instant) -> Double {
        let snapshot = lock.withLock { state }
        guard snapshot.running else { return 0 }
        return max(0, instant.timeIntervalSince(snapshot.resumeAnchor))
    }
}
