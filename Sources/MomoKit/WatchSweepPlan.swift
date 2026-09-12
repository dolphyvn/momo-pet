import Foundation
import MomoCore

// MARK: - WatchSweepPlan — the launch-sweep drain decision (TASK-044 R1;
// 05-technical-architecture §6.4, §10.4 "journal drain on reconnect"; INV-10)

/// The pure core of the Watch's LAUNCH SWEEP: after a crash or termination
/// lands between the pat journal's append (§6.4 step 1) and the
/// `transferUserInfo` drain, the journaled event is stranded — durable on
/// disk, never enqueued. The sweep re-enqueues every still-pending journal
/// entry VERBATIM at the next session activation (the reconnect/cold-launch
/// moment), through the SAME send leg the pat flow uses. This type owns the
/// DECISION only — which journal entries may drain — as a pure, clock-free
/// (D20) function; the executor (`MomoWatchAppModel.flushStrandedJournal`)
/// owns the arming, the mailbox read, and the sends.
///
/// **Safety is by construction, not by coordination.** Events go out
/// verbatim — no re-sequencing, no mutation, no re-journaling (seqs were
/// assigned at append time) — and the iPhone's unseen-UUID ∧ strict-`>`
/// watermark gate makes every redelivery a no-op (INV-10, pinned in
/// `WatchReceivePlanTests`/`WatchSyncGateTests` — cited here, never
/// re-derived). The journal lines are NOT deleted on send: the watermark
/// prune (§6.4 step 4) owns removal, so a re-activation sweep re-sends the
/// same events and stays exactly-once iPhone-side.
///
/// **The reset interaction (the load-bearing hazard).** A reset marker
/// pending consumption at launch must NEVER be outrun by the sweep: the
/// §6.6 consumption wipes the journal, and entries the wipe removed must
/// not resurrect. Two defenses close it — the executor's launch-leg ORDER
/// is the first (the consumption is awaited before the sweep's journal
/// read, so the mailbox serves the read the POST-wipe journal), and this
/// type's count re-check is the second: if the consumed erase count has
/// ADVANCED between the sweep's arming (activation) and its execution, a
/// consumption landed in between and the sweep sends NOTHING.
public enum WatchSweepPlan {

    /// The drainable subset of the journal, in the journal's own order
    /// (verbatim — the FIFO the iPhone's watermark gate reasons about):
    /// the epoch-matched entries, unless a consumption landed between arm
    /// and execution (`consumedEraseCountNow` differs from
    /// `consumedEraseCountAtArm`), in which case nothing may drain.
    /// Dead-epoch entries are declined even when the counts agree: a
    /// journal that outlived its epoch cannot exist (the generation wipe
    /// removes it — TASK-042's F-3 leg), but a read racing that wipe could
    /// still observe one, and the iPhone's epoch gate would discard the
    /// events anyway. No clock reads (D20); no I/O; total over every input.
    public static func drainableEvents(
        journal: [IntentEvent],
        epoch: UUID,
        consumedEraseCountAtArm: Int,
        consumedEraseCountNow: Int
    ) -> [IntentEvent] {
        guard consumedEraseCountAtArm == consumedEraseCountNow else { return [] }
        return journal.filter { $0.watchSessionEpoch == epoch }
    }
}
