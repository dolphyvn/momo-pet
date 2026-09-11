import Foundation
import WatchConnectivity
import os

// MARK: - MomoWatchTransport — the WCSession-echoing seam + the live wrapper
// (TASK-040 R1/R5; ADR-003; ADR-013; 05-technical-architecture §6.1–6.4)

/// The transport seam the executor depends on (R1): activation, the
/// latest-wins context send, and the `transferUserInfo` receive sink —
/// nothing else. WCSession-echoing ON PURPOSE (ADR-013: duplicated per app
/// target, plain over DRY — the Watch twin lands in TASK-041/042), so push
/// and receive logic is headlessly testable with a recording fake and the
/// executor never names `WCSession` (D-R5: the transport is not engine
/// code; it hangs off the `.pushWatchSnapshot` seam and the receive entry).
///
/// **Queue contract.** `onUserInfoData` may be invoked on a BACKGROUND
/// queue — WCSession calls its delegate on a non-main serial queue
/// (WCSession.h:135-139, the R4 record: "It is the client's responsibility
/// to dispatch to another queue"). The receiver hops (the executor's sink
/// re-isolates to the main actor); the transport does NOT hop for you.
protocol MomoWatchTransporting: AnyObject {

    /// Launch-time activation. The delegate must exist before activation
    /// (WCSession.h:42-45 — "A delegate must exist before the session will
    /// allow sends"; "Calling activate without a delegate set is
    /// undefined"), so conformers own their delegate wiring before this
    /// runs; the executor binds its sink FIRST and activates SECOND.
    func activate()

    /// Delivers the latest-wins application context (§6.2's down-transport):
    /// the snapshot's canonical JSON bytes wrapped as a property-list
    /// `Data` value. Best-effort by design — an unreachable counterpart
    /// loses nothing (the NEXT context supersedes); failures degrade to a
    /// log line, never a crash.
    func send(contextData: Data)

    /// The receive sink for `transferUserInfo` frames (§6.4's up-transport):
    /// the raw JSON bytes of one `IntentEvent` (undecodable bytes are the
    /// RECEIVER's skip — the sink still gets them).
    var onUserInfoData: (@Sendable (Data) -> Void)? { get set }
}

/// The live WCSession conformance — deliberately THIN (R1): activation,
/// delegate plumbing, and the plist wrap/unwrap around the canonical JSON
/// bytes. No sync semantics live here; every decision is MomoKit's
/// (`WatchReceivePlan`) or the executor's.
///
/// **Session lifecycle (the R4-recorded evidence).** The delegate is set
/// and `activateSession()` runs at app-launch construction; correctness
/// NEVER depends on the activation state (context is latest-wins — an
/// unreachable counterpart is not an error). Sends are gated on
/// `.activated` because the docs call an inactive-session send "a
/// programmer error" — the guard turns that into a logged drop, and the
/// next successful push supersedes. Background delivery of both
/// transports needs NO capability, entitlement, or Info.plist key (the R4
/// record — zero references across the framework headers).
///
/// **Delegate surface.** All three REQUIRED (pre-`@optional`) delegate
/// methods are implemented (WCSession.h:143-152): the activation callback
/// is logged; `sessionDidBecomeInactive`/`sessionDidDeactivate` are
/// single-watch no-op / re-activate (the header's recipe for making the
/// session usable again for the selected watch). The `@optional`
/// `didReceiveApplicationContext` is deliberately NOT implemented: the
/// Watch → iPhone direction is `transferUserInfo` ONLY (ADR-003), and an
/// unimplemented optional callback is an ignored delivery.
final class LiveWatchTransport: NSObject, WCSessionDelegate, MomoWatchTransporting {

    private static let logger = Logger(subsystem: "com.momo.app", category: "watch-transport")

    /// The receive sink. Set ONCE by the executor at bind time — strictly
    /// before `activate()`, and WCSession's queue only reads it for
    /// deliveries that can arise after activation, so the set-from-main /
    /// read-from-WC-queue pair has no reachable race (and the closure is
    /// `@Sendable`).
    var onUserInfoData: (@Sendable (Data) -> Void)?

    /// The session, resolved once. Nil when the device does not support
    /// WatchConnectivity (the `isSupported` guard is iOS-only — WCSession.h:34:
    /// "Session is always available on WatchOS", so the Watch twin never guards).
    private let session: WCSession?

    override init() {
        session = WCSession.isSupported() ? WCSession.default : nil
        super.init()
        // The delegate MUST exist before activation (protocol doc); setting
        // it here makes every later `activate()` well-defined.
        session?.delegate = self
    }

    func activate() {
        // The Swift overlay renames the header's `activateSession` to
        // `activate` (WCSession.h:180's C spelling, obsoleted in Swift 3).
        session?.activate()
    }

    func send(contextData: Data) {
        guard let session else {
            Self.logger.notice("context drop: WatchConnectivity unsupported on this device")
            return
        }
        guard session.activationState == .activated else {
            // An inactive-session send is "a programmer error" per the docs;
            // logged drop, next push supersedes (latest-wins).
            Self.logger.notice("context drop: session not yet activated (\(session.activationState.rawValue))")
            return
        }
        do {
            // `Data` is a property-list type (WCSession.h:107/:115 — the
            // dicts "can only accept the property list types"); the JSON
            // bytes ride as one value under a stable key.
            try session.updateApplicationContext(["payload": contextData])
        } catch {
            Self.logger.error("context send failed (\(error)) — the next push supersedes")
        }
    }

    // MARK: WCSessionDelegate (all three REQUIRED methods; WC's non-main
    // serial queue — receivers hop, this class does not)

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
    }

    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS-required; single-watch UX — the watch switch flow's other
        // half re-activates below.
    }

    func sessionDidDeactivate(_ session: WCSession) {
        // iOS-required; the header's recipe: re-activate for the (same)
        // selected watch so the session stays usable.
        session.activate()
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        guard let payload = userInfo["payload"] as? Data else {
            Self.logger.notice("userInfo frame without a payload — skipped")
            return
        }
        onUserInfoData?(payload)
    }
}
