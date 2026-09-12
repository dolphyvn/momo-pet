import Foundation
import MomoCore

// MARK: - WatchPatPlan (05-technical-architecture §6.4 step 1; §6.6;
// TASK-042 R3/R5/R6; ADR-015 D2 — the pure decision core of the Watch pat)

/// The pure core of the Watch's pat leg: the intent construction, the
/// per-epoch monotonic `watchSeq` derivation, the completion-haptic
/// estimate, and the wakefulness → reaction-kind map. Total and ambient-free
/// except for ONE disclosed mint — `makeIntent` calls `UUID()` for the
/// intent's idempotency key (INV-10's `id` is minted AT CAPTURE, the
/// iPhone's `interact` precedent; everything else about the event is pinned
/// by test). No clock, no calendar, no file I/O: the executor owns those.
///
/// **The seq formula (R3, pinned by name).**
/// `next = max(epochScopedJournalMax, epochMatchedWatermark) + 1`, where the
/// watermark term counts ONLY when the held snapshot's `lastAppliedEpoch`
/// equals the current epoch (a stale-epoch watermark is inert — the same
/// rule the journal prune applies). BOTH terms are epoch-scoped: §6.2's
/// "resets with the epoch" means a journal holding another epoch's entries
/// (a defensive case the wipe discipline should never produce) never
/// inflates the new epoch's seqs. The watermark term is the FULL-PRUNE
/// case's monotonicity: journal freshly emptied by the iPhone's apply +
/// epoch-matched watermark N ⇒ the next pat is N+1, never 1 (a reused seq
/// would be declined forever — the watermark already sits at N).
public enum WatchPatPlan {

    // MARK: Event construction (§6.4 step 1's journaled event)

    /// Builds the pat's journaled `IntentEvent`: a `.watch`-sourced
    /// `.pat(gesture: .tap, zone: nil)` (FR-17's single surface) wrapped
    /// with this Watch's epoch and the derived seq. The intent's
    /// `localDayKey` is derived from the EVENT'S OWN instant (D20/INV-9; the
    /// 23:30 pat attributes to ITS day per §6.6's offline-midnight case).
    /// The `id` is minted here — the capture-time idempotency key.
    public static func makePatEvent(
        now: Instant,
        calendar: Calendar,
        watchSessionEpoch: UUID,
        watchSeq: Int
    ) -> IntentEvent {
        IntentEvent(
            intent: InteractionIntent(
                id: UUID(),
                source: .watch,
                localDayKey: DayKey.make(from: now, calendar: calendar),
                timestamp: now,
                kind: .pat(gesture: .tap, zone: nil)
            ),
            watchSessionEpoch: watchSessionEpoch,
            watchSeq: watchSeq
        )
    }

    // MARK: The seq derivation (R3's pinned formula)

    /// The epoch-scoped journal max: the largest `watchSeq` among the given
    /// events whose `watchSessionEpoch` equals `epoch` — another epoch's
    /// entries never inflate this epoch's derivation (the type header's
    /// epoch-scoping note). Zero when none match (an empty or foreign
    /// journal is the fresh-epoch state).
    public static func journalMaxSeq(in events: [IntentEvent], epoch: UUID) -> Int {
        events.reduce(0) { current, event in
            guard event.watchSessionEpoch == epoch else { return current }
            return max(current, event.watchSeq)
        }
    }

    /// The next `watchSeq` for a pat in `currentEpoch`: the pinned formula —
    /// `max(journalMaxSeq, epochMatchedWatermark) + 1`, both terms
    /// epoch-scoped (see the type header). The watermark term counts only
    /// when `lastAppliedEpoch == currentEpoch`; a snapshot from before a
    /// re-pair (stale epoch) contributes nothing, exactly like the prune.
    public static func nextWatchSeq(
        journalMaxSeq: Int,
        lastAppliedEpoch: UUID,
        lastAppliedIntentSeq: Int,
        currentEpoch: UUID
    ) -> Int {
        let epochMatchedWatermark = lastAppliedEpoch == currentEpoch ? lastAppliedIntentSeq : 0
        return max(journalMaxSeq, epochMatchedWatermark) + 1
    }

    // MARK: The completion-haptic estimate (ADR-015 D2)

    /// The epoch's pending pat count: how many `.pat` intents this Watch has
    /// journaled but the iPhone has not yet applied (events whose
    /// `watchSessionEpoch` matches `epoch` and whose kind is a pat). The
    /// completion estimate's third term — the offline pats the held
    /// snapshot's `questInputs` cannot see. Other epochs' events and
    /// non-pat kinds (future intent vocabulary) count nothing.
    public static func pendingPatCount(in events: [IntentEvent], epoch: UUID) -> Int {
        events.reduce(0) { current, event in
            guard event.watchSessionEpoch == epoch else { return current }
            guard case .pat = event.intent.kind else { return current }
            return current + 1
        }
    }

    /// Whether THIS pat is estimated to complete the pat-quest: the held
    /// snapshot's quest line is `.wish(.q7)` (the pet ×3 quest), Q7's
    /// snapshot progress is known, and progress + this Watch's pending
    /// journal pats + this pat == the catalog target. Strict `==`: below
    /// target is an ordinary pat (tick), PAST it the completion already
    /// happened among the pending pats (also tick — the double must fire on
    /// exactly the completing pat, never twice). The estimate decides WHICH
    /// HAPTIC PLAYS and nothing else (D2 — no state moves, a disagreement
    /// with the iPhone is benign by construction). A missing Q7 progress
    /// entry (a snapshot predating the quest set) estimates `false` — the
    /// held view can only under-count, so the honest tick is the safe
    /// fallback (D2's disclosed failure asymmetry).
    public static func isCompletingPat(
        questLine: QuestGeneration.QuestLine,
        questInputs: [QuestProgress],
        pendingPatCount: Int
    ) -> Bool {
        guard case .wish(.q7) = questLine else { return false }
        guard let progress = questInputs.first(where: { $0.questID == .q7 }) else {
            return false
        }
        return progress.progress + pendingPatCount + 1 == QuestCatalog.entry(for: .q7).target
    }

    // MARK: The reaction-kind map (ADR-015 D1; 04 §6.4's state-distinct rule)

    /// The micro-reaction a pat plays for the CURRENT wakefulness: awake and
    /// waking bind the `.tap` clip's whole-body beat (the "happy
    /// micro-bounce"); settling and asleep bind the `.stir` clip (the
    /// authored 1.0 s asleep beat — the pet stirs and STAYS asleep).
    /// Waking→bounce is the map's one judgment call: a pat DURING the wake
    /// transition greets the waking pet with the awake beat (the pet is
    /// rising; the stir is the asleep body's motion). Pinned by test.
    public static func reactionKind(for wakefulness: Wakefulness) -> WatchPatReaction {
        switch wakefulness {
        case .awake, .waking: return .bounce
        case .settling, .asleep: return .stir
        }
    }
}

/// The Watch pat's two reaction bindings (ADR-015 D1): `.bounce` is the
/// `.tap` clip's motion, `.stir` the `.stir` clip's. The kind — not the
/// clip — is what MomoKit names: the clip resolution is MomoCharacter's
/// (the app layer's director maps the kind through `ReactionKeys`).
public enum WatchPatReaction: Equatable, Sendable {
    /// The awake beat: the `.tap` whole-body bounce (`ReactionKeys.tap`).
    case bounce
    /// The asleep beat: the `.stir` clip (`ReactionKeys.stir`) — stays down.
    case stir
}
