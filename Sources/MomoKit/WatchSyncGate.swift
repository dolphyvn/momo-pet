import Foundation
import MomoCore

// MARK: - WatchSyncGate (05-technical-architecture §6.4 step 2; ADR-003;
// INV-10; TASK-023)

/// The delivery gate — the pure arithmetic deciding whether a received
/// `IntentEvent` applies to the engine. THE formula (05 §6.4 step 2):
///
///     apply  iff  the intent UUID is unseen (INV-10)
///             AND event.watchSeq > watermark FOR THAT INTENT'S EPOCH
///
/// **The two guards and their interplay (ADR-003's "two independent
/// guards").** The UUID set (`EngineState.processedIntents`) is the primary
/// idempotency guard; the per-epoch watermark (`SyncState`) is the
/// independent one that outlives the UUID belt's retention cap: when the
/// 64-entry belt has evicted an intent's UUID, the watermark still refuses
/// its replayed seq. Neither guard alone is exactly-once; the cell matrix
/// below is their composition, pinned cell-by-cell in
/// `WatchSyncGateTests`.
///
/// **The §6.4 cell matrix (each row = one named test).**
///
///     seen UUID?  seq vs watermark?          →    because
///     ─────────   ─────────────────          ──   ──────────────────────────
///     unseen      seq > watermark             APPLY (the only apply cell)
///     seen        any (even higher seq)      no-op UUID outranks seq — a
///                                               duplicate with a bigger seq
///                                               is still the same pat
///     unseen      seq ≤ watermark            no-op the retention interplay —
///                                               replayed old seq after the
///                                               belt forgot the UUID
///     unseen      seq == watermark           no-op the boundary is STRICTLY
///                                               greater (§6.4: ">")
///     any         epoch unseen → wm 0        0-init: seq 1, 2, … apply
///                                               immediately (§6.6 reset row)
///
/// **Expired-dayKey pass-through (§6.4 step 3).** The gate NEVER reads
/// `intent.localDayKey` — day-attribution (including the expired-dayKey
/// rule: current-state effects apply, all day-ledger attribution drops) is
/// `InteractionSemantics`' engine-side contract (TASK-016). The gate's only
/// obligation is passing a valid intent through UNCHANGED so the engine's
/// rule can act; the signature has no dayKey input, and the pass-through
/// shape is pinned by name.
///
/// Total and pure: defined on every input, reads nothing ambient, mutates
/// nothing.
public enum WatchSyncGate {

    /// Whether `event` applies, given the caller's seen-UUID set and the
    /// watermark for the event's OWN epoch. The watermark is passed
    /// PRE-RESOLVED (the formula's shape); `SyncState.shouldApply` is the
    /// accessor-driven wrapper that resolves it through the 0-initializing
    /// lookup. Duplicate delivery, replay, and redelivery of an applied
    /// event are all no-ops by construction here — FR-18 AC-1.
    public static func shouldApply(
        _ event: IntentEvent,
        seenIntentIDs: Set<UUID>,
        watermarkForEpoch: Int
    ) -> Bool {
        // Guard 1 (INV-10) — the UUID outranks everything: a duplicate
        // delivery is a no-op even if it claims a higher seq than the
        // watermark (a corrupted or hostile resend cannot double-apply by
        // inflating the seq).
        guard !seenIntentIDs.contains(event.intent.id) else { return false }
        // Guard 2 — strictly greater (§6.4's ">"): seq == watermark is a
        // replay of the last applied intent.
        return event.watchSeq > watermarkForEpoch
    }
}
