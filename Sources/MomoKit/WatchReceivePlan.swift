import Foundation
import MomoCore

// MARK: - WatchReceivePlan (05-technical-architecture §6.4; ADR-003; TASK-040
// R2; the accessor-driven receive half of the §6.4 dual guard)

/// The pure decision core of the Watch → iPhone intent receive path: one
/// `IntentEvent` + the current bookkeeping → APPLY or IGNORE, plus the
/// post-apply sync state when applying. Total and ambient-free — no clock,
/// no calendar, no I/O (the executor owns the fold-to-now apply, the
/// persists, and the push; the plan owns ONLY the decision).
///
/// **Composition (O5's accessor rule).** The gate is resolved through
/// `SyncState.shouldApply(_:seenIntentIDs:)` — NEVER through raw
/// `WatchSyncGate` with a call-site-resolved watermark: the UUID half is
/// the engine's own `processedIntents` belt (the caller derives the set
/// from the CURRENT engine state — no second seen-set store exists, per
/// the contract's prohibition), and the seq half is the per-epoch
/// watermark with 0-init via `SyncState.watermark(for:)`. The task's R2
/// guard pins the app layer to this accessor (no `WatchSyncGate` token in
/// app code).
///
/// **Order-independence (the O2 adjudication).** The decision consumes no
/// delivery-order assumption: under the FIFO contract stream
/// (`transferUserInfo`, evidenced at the R4 record) the gate yields
/// EXACTLY-ONCE application per distinct intent; under seeded shuffles it
/// degrades to AT-MOST-ONCE (a stale-seq event whose unseen UUID arrives
/// below the watermark is a legitimate no-op — pinning full application
/// under shuffles would pin a falsehood against §6.4).
///
/// **The caller's F-1 duty.** An `.apply` decision's `postSync` must be
/// the sync state the NEXT snapshot builds from (`makeWatchSnapshot`'s
/// `sync:` input) — a wiring leg green decision tests cannot see (the
/// TASK-034 F-1 blind-spot shape); the executor-level integration and the
/// structural guard pin it.
public enum WatchReceivePlan {

    /// The receive decision. `.apply` carries the sync state WITH the
    /// event's watermark recorded (max-semantics, per-epoch) — the caller
    /// applies the wrapped intent through the facade's interaction path,
    /// persists both states, and builds the next snapshot from `postSync`.
    public enum Decision: Equatable {

        /// The event is new (unseen UUID ∧ strictly-greater per-epoch
        /// watermark): apply the wrapped intent and adopt `postSync`.
        case apply(postSync: SyncState)

        /// Duplicate, replay, redelivery, or stale-seq: a FULL no-op —
        /// no engine apply, no sync-state write, no push (INV-10).
        case ignore
    }

    /// Decides one delivered event against the current bookkeeping.
    ///
    /// - Parameters:
    ///   - event: the decoded `IntentEvent` (undecodable bytes never
    ///     reach here — the decode half skips them, never fatal).
    ///   - sync: the current sync state (the loaded file's content).
    ///   - seenIntentIDs: the engine's `processedIntents` belt as a set —
    ///     the ONLY UUID memory (derived from the CURRENT engine state;
    ///     the belt's 64-capacity pruning is the engine's, and a pruned id
    ///     remains guarded by the watermark half).
    /// - Returns: `.apply(postSync:)` when the accessor-driven gate
    ///   admits the event (`postSync` = `sync.recordingApplied(event)`,
    ///   max-semantics), else `.ignore`.
    public static func decide(
        event: IntentEvent,
        sync: SyncState,
        seenIntentIDs: Set<UUID>
    ) -> Decision {
        guard sync.shouldApply(event, seenIntentIDs: seenIntentIDs) else {
            return .ignore
        }
        return .apply(postSync: sync.recordingApplied(event))
    }
}
