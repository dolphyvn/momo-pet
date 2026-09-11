import Foundation
import WatchConnectivity
import os

// MARK: - MomoWatchTransport — the WCSession-echoing seam + the live wrapper
// (TASK-041 R3; ADR-003; ADR-013; 05-technical-architecture §6.1–6.3)

/// The Watch-side transport seam (ADR-013's deliberate DUPLICATE of the
/// iPhone `Apps/Momo/MomoWatchTransport.swift` pattern — per-target code,
/// plain over DRY; the roles differ so nothing is shared). RECEIVE-only this
/// task: activation and the latest-wins application-context receive sink —
/// nothing else. NO send surface exists (the Watch → iPhone `transferUserInfo`
/// intent path is TASK-042's; an unimplemented capability is not stubbed
/// here), so push and receive logic stays headlessly simple and the executor
/// never names `WCSession` (D-R5).
///
/// **Queue contract.** `onContextData` may be invoked on a BACKGROUND queue —
/// WCSession calls its delegate on a non-main serial queue (the TASK-040 R4
/// record, WCSession.h:135-139: "It is the client's responsibility to
/// dispatch to another queue"). The receiver hops (the executor's sink
/// re-isolates to the main actor); the transport does NOT hop for you.
protocol MomoWatchTransporting: AnyObject {

    /// Launch-time activation. The delegate must exist before activation
    /// (WCSession.h:42-45 — "A delegate must exist before the session will
    /// allow sends"), so the conformer wires its delegate at init; the
    /// executor binds the sink FIRST and activates SECOND (the TASK-040
    /// sink-before-activate discipline).
    func activate()

    /// The receive sink for `updateApplicationContext` deliveries (§6.1's
    /// iPhone → Watch down-transport): the snapshot's canonical JSON bytes
    /// unwrapped from the property-list `Data` value (undecodable bytes are
    /// the RECEIVER's skip — the sink still gets them).
    var onContextData: (@Sendable (Data) -> Void)? { get set }
}

/// The live WCSession conformance — deliberately THIN (the iPhone twin's
/// discipline): delegate plumbing and the plist unwrap around the canonical
/// JSON bytes. No sync semantics live here; every decision is MomoKit's
/// (`WatchResetConsumption`) or the executor's.
///
/// **Session lifecycle.** On watchOS the session is ALWAYS available
/// (WCSession.h:34 — "Session is always available on WatchOS"; the
/// `isSupported` guard is iOS-only, so unlike the iPhone twin there is no
/// optional session here). The delegate is set at construction and
/// `activate()` runs at app-launch binding; correctness NEVER depends on the
/// activation state — the context is latest-wins, and the pending context is
/// delivered around activation completion (VERIFY-AT-BUILD, §6.1: launch-time
/// context delivery on watchOS), landing in `didReceiveApplicationContext`
/// like every later delivery.
///
/// **Delegate surface.** watchOS requires EXACTLY ONE delegate method
/// (pre-`@optional` on iOS but the sole requirement here):
/// `session(_:activationDidCompleteWith:error:)` — logged only. The context
/// delivery rides the `@optional` `didReceiveApplicationContext`. The iOS
/// multi-watch methods (`sessionDidBecomeInactive`/`sessionDidDeactivate`)
/// are deliberately NOT implemented — a single-watch platform never calls
/// them, and TASK-041 ships no dead code.
final class LiveWatchTransport: NSObject, WCSessionDelegate, MomoWatchTransporting {

    private static let logger = Logger(subsystem: "com.momo.app", category: "watch-transport")

    /// The receive sink. Set ONCE by the executor at bind time — strictly
    /// before `activate()`, and WCSession's queue only reads it for
    /// deliveries that can arise after activation, so the set-from-main /
    /// read-from-WC-queue pair has no reachable race (and the closure is
    /// `@Sendable`).
    var onContextData: (@Sendable (Data) -> Void)?

    private let session: WCSession

    override init() {
        session = WCSession.default
        super.init()
        // The delegate MUST exist before activation (protocol doc); setting
        // it here makes every later `activate()` well-defined.
        session.delegate = self
    }

    func activate() {
        // The Swift overlay renames the header's `activateSession` to
        // `activate` (WCSession.h:180's C spelling, obsoleted in Swift 3).
        session.activate()
    }

    // MARK: WCSessionDelegate (the watchOS surface; WC's non-main serial
    // queue — receivers hop, this class does not)

    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        if let error {
            Self.logger.error("session activation error (\(error)) — correctness never depends on activation")
        } else {
            Self.logger.notice("session activated (state \(activationState.rawValue))")
        }
        // The launch-time context delivery (§6.1 VERIFY-AT-BUILD): watchOS
        // hands the pending context to `didReceiveApplicationContext`
        // around this completion — no separate surface exists or is needed.
    }

    func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        guard let payload = applicationContext["payload"] as? Data else {
            Self.logger.notice("application context without a payload — skipped")
            return
        }
        onContextData?(payload)
    }
}
