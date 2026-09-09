import Foundation
import MomoCore

// MARK: - SyncState (05-technical-architecture §6.4; ADR-003; TASK-023)

/// The iPhone's sync bookkeeping — the watermark home (TASK-023 contract
/// Requirement 3): the per-`watchSessionEpoch` watermark table (05 §6.4:
/// "the iPhone stores the watermark per epoch") plus the next
/// `snapshotSeq` for the outgoing `WatchSnapshot`s (05 §6.2: "monotonic,
/// iPhone-assigned").
///
/// A pure VALUE type — every operation returns a new value; persistence is a
/// separate concern (`SyncStateStore`, the store's write-temp-then-atomic-
/// rename discipline over `StoreRules.syncStateFileName`).
///
/// **The two guards' division of labor (ADR-003).** The seen-UUID set is
/// `EngineState.processedIntents` — engine state, persisted by the
/// SnapshotStore, retention-capped by `LedgerRetention`. THIS table is the
/// other, independent guard: it survives the UUID belt's eviction, which is
/// exactly why replayed OLD seqs stay no-ops after retention has forgotten
/// their UUIDs (the interplay `WatchSyncGateTests` pins).
///
/// **`snapshotSeq` monotonicity scope — documented.** Strictly increasing
/// per sync-state-file lifetime: `consumingSnapshotSeq` hands out
/// `nextSnapshotSeq` and advances it, so successive snapshots through the
/// returned state can never repeat a seq. Loss of the sync-state file
/// (fresh state, seq restarts at 1) REUSES seqs — a deliberate, defined
/// non-event: the seq is ordering metadata for the Watch's latest-wins
/// render, never a correctness input on either side (the prune gate reads
/// `lastAppliedIntentSeq`, and the Watch renders whatever snapshot arrived
/// last), so a reset seq is a display no-op. `watchSeq`, the OTHER
/// monotonic counter in the protocol, is Watch-assigned (05 §6.2) and out
/// of scope here (§5.6 = EPIC-008).
public struct SyncState: Equatable, Sendable, Codable {

    /// The per-epoch watermark table: for each `watchSessionEpoch` the
    /// iPhone has applied intents from, the highest applied `watchSeq`.
    /// Consulted ONLY through `watermark(for:)` — the 0-initialization is
    /// the accessor's job (§6.4/§6.6: an unseen epoch initializes its
    /// watermark at 0), never a sprinkled `?? 0` at call sites.
    public let watermarks: [UUID: Int]

    /// The seq the NEXT built snapshot carries (`makeWatchSnapshot`
    /// consumes it through `consumingSnapshotSeq`). Starts at 1 — the first
    /// snapshot ever built is seq 1.
    public let nextSnapshotSeq: Int

    /// - Parameters:
    ///   - watermarks: the per-epoch table; empty is the fresh shape.
    ///   - nextSnapshotSeq: defaults to 1 (the fresh shape).
    public init(watermarks: [UUID: Int] = [:], nextSnapshotSeq: Int = 1) {
        self.watermarks = watermarks
        self.nextSnapshotSeq = nextSnapshotSeq
    }

    /// The watermark for `epoch` — **0 for an unseen epoch** (§6.4/§6.6:
    /// pats after a counter reset — re-pair, watch app reinstall, new
    /// Watch — apply immediately at seq 1, 2, …; no starvation). The ONE
    /// place the 0-initialization exists.
    public func watermark(for epoch: UUID) -> Int {
        watermarks[epoch] ?? 0
    }

    /// The state after `event`'s intent was applied: the event's epoch's
    /// watermark advances to `max(current, event.watchSeq)`. The max keeps
    /// an out-of-order or duplicate redelivery (a LOWER seq than the
    /// watermark already recorded) from REGRESSING the watermark — a
    /// regression would let a replayed seq re-apply through the gate.
    public func recordingApplied(_ event: IntentEvent) -> SyncState {
        let advanced = max(watermark(for: event.watchSessionEpoch), event.watchSeq)
        var updated = watermarks
        updated[event.watchSessionEpoch] = advanced
        return SyncState(watermarks: updated, nextSnapshotSeq: nextSnapshotSeq)
    }

    /// Hands out the next snapshot seq and returns the advanced state to
    /// thread into subsequent builds — the structural form of "monotonic,
    /// iPhone-assigned" (see the type header's monotonicity-scope note).
    public func consumingSnapshotSeq() -> (sync: SyncState, assignedSeq: Int) {
        (
            SyncState(watermarks: watermarks, nextSnapshotSeq: nextSnapshotSeq + 1),
            nextSnapshotSeq
        )
    }

    /// The §6.4 apply gate with the watermark RESOLVED for the event's own
    /// epoch — the accessor-driven form of `WatchSyncGate.shouldApply`. The
    /// formula's single home stays in `WatchSyncGate`; this wrapper adds
    /// exactly the epoch-scoped lookup (and is what EPIC-008's wiring calls,
    /// so no call site can resolve the watermark for the wrong epoch).
    public func shouldApply(_ event: IntentEvent, seenIntentIDs: Set<UUID>) -> Bool {
        WatchSyncGate.shouldApply(
            event,
            seenIntentIDs: seenIntentIDs,
            watermarkForEpoch: watermark(for: event.watchSessionEpoch)
        )
    }
}
