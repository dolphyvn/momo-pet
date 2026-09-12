import Foundation
import MomoCore
import MomoKit
import os

// MARK: - MomoWatchSnapshotPersister + Journal — the O1 journal legs (R2;
// 05-technical-architecture §6.4; TASK-042)

/// The intent journal's file mutations, same-target extension of the Watch's
/// one-writer actor (O1): the append-drain (`appendPat`), the watermark prune
/// (`pruneJournal`), the epoch generation's self-defense wipe (`wipeJournal`),
/// and the estimate's pending-count read (`pendingPatCount`). The
/// `IntentJournal` instance is reconstructed per call over the executor's
/// directory (the established store pattern); routing even the READ through
/// the mailbox keeps every journal touch — read or write — in exactly one
/// file (the structural census guard's premise).
///
/// **Why the seq derivation runs IN the mailbox (R3).** `watchSeq` is derived,
/// never stored: `max(epochScopedJournalMax, epochMatchedWatermark) + 1`. The
/// journal-max term must be read at the moment of the append — a counter kept
/// in the app model would miss a relaunch (a queued offline pat from the
/// previous launch must raise the floor) and would dual-write state the
/// journal already holds. `nextWatchSeq`'s watermark term covers the
/// full-prune case (the named monotonicity test in `WatchPatPlanTests`).
extension MomoWatchSnapshotPersister {

    /// The journal legs' own logger — the main file's `logger` is `private`
    /// (file-scoped, the established pattern), so this extension declares its
    /// own under a distinct category.
    private static let logger = Logger(subsystem: "com.momo.app", category: "watch-intent-journal")

    /// The §6.4 step-1 append: derives the event's `watchSeq` and journals
    /// it, returning the journaled event (the send's payload source) or nil
    /// when the append did not land (the durability gate — the caller sends
    /// ONLY journaled events, so a lost line is a lost pat, never a
    /// later-reused seq).
    ///
    /// **Ordering argument (the correctness this method leans on).** The
    /// journal read is the FIRST statement — actor jobs interleave only at
    /// suspensions, so the read + append pair is atomic within this mailbox
    /// job. The watermark pair is captured by the caller on the main actor
    /// IMMEDIATELY before submission (no suspension between read and
    /// submit), which makes one of two interleavings provable: (a) a receive
    /// whose main-actor half ran before that stretch enqueues its
    /// persist+prune BEFORE this job, so this job reads either the pre-prune
    /// journal (holding every event that prune could remove — its events
    /// were journaled when sent) or a watermark ≥ that prune's; and (b) a
    /// receive processed after the submission enqueues AFTER this job, so
    /// this job's journal read predates the prune and holds its events. In
    /// both, `max(journalMax, watermark) + 1` exceeds any watermark the
    /// concurrent prune applies — the fresh event can never be pruned as
    /// already-applied, and the derivation can never reuse a declined seq.
    func appendPat(
        directory: URL,
        now: Instant,
        calendar: Calendar,
        watchSessionEpoch: UUID,
        lastAppliedEpoch: UUID,
        lastAppliedIntentSeq: Int
    ) -> IntentEvent? {
        let journal = IntentJournal(directory: directory)
        let journalMaxSeq = WatchPatPlan.journalMaxSeq(in: journal.events(), epoch: watchSessionEpoch)
        let watchSeq = WatchPatPlan.nextWatchSeq(
            journalMaxSeq: journalMaxSeq,
            lastAppliedEpoch: lastAppliedEpoch,
            lastAppliedIntentSeq: lastAppliedIntentSeq,
            currentEpoch: watchSessionEpoch
        )
        let event = WatchPatPlan.makePatEvent(
            now: now,
            calendar: calendar,
            watchSessionEpoch: watchSessionEpoch,
            watchSeq: watchSeq
        )
        guard journal.append(event) else {
            Self.logger.notice("pat append did not land — the pat is lost (the journal's keep-as-is discipline)")
            return nil
        }
        Self.logger.debug("pat journaled (seq \(watchSeq))")
        return event
    }

    /// The §6.4 step-4 prune (R2b): drop the journal entries the iPhone's
    /// watermark has applied — epoch-matched ONLY (`IntentJournal.pruned`'s
    /// core: a stale-epoch watermark prunes nothing, pinned in MomoKit).
    /// Called on every steady-shape receive AFTER the snapshot persist; the
    /// mailbox orders it behind that persist, so the pruned watermark can
    /// never run ahead of the snapshot that carried it.
    func pruneJournal(directory: URL, watermarkEpoch: UUID, watermarkSeq: Int) {
        IntentJournal(directory: directory).prune(
            watermarkEpoch: watermarkEpoch,
            watermarkSeq: watermarkSeq
        )
        Self.logger.debug("journal pruned through the applied watermark")
    }

    /// The journal wipe, shared by BOTH wipe legs: the epoch
    /// (re)generation's F-3 self-defense (TASK-040 F-3; R1 — a journal
    /// present at the moment a NEW epoch is minted holds entries of a dead
    /// epoch: they can never apply and must never linger) and the §6.6
    /// consumption's journal half (R2c). Idempotent by `IntentJournal.wipe`'s
    /// contract (an absent journal is the wiped state), so a replayed leg is
    /// a no-op.
    func wipeJournal(directory: URL) {
        IntentJournal(directory: directory).wipe()
        Self.logger.debug("intent journal wiped")
    }

    /// The estimate's pending-count read (the completion haptic's third
    /// term): this epoch's journaled-but-unapplied pats. A read — but routed
    /// through the mailbox like every journal touch (the census guard's
    /// premise), and serialized against appends so the count can never tear
    /// across a mid-append state.
    func pendingPatCount(directory: URL, epoch: UUID) -> Int {
        WatchPatPlan.pendingPatCount(in: IntentJournal(directory: directory).events(), epoch: epoch)
    }

    /// The launch sweep's full-journal read (TASK-044 R1): every journaled
    /// event, in file order, ALL epochs — `WatchSweepPlan.drainableEvents`
    /// does the epoch filtering, so the mailbox hands over the bytes
    /// verbatim and decides nothing. Routed through the mailbox like every
    /// journal touch (the census guard's premise), and serialized against
    /// appends/prunes/wipes so the sweep can never read a torn or
    /// half-pruned queue.
    func pendingEvents(directory: URL) -> [IntentEvent] {
        IntentJournal(directory: directory).events()
    }
}
