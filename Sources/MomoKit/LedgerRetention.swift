import MomoCore

// MARK: - LedgerRetention (05-technical-architecture §5.4; TASK-022)

/// The store's retention function (05 §5.4): a pure, deterministic, total
/// `EngineState -> EngineState` prune that caps the two structures §5.4
/// bounds — the day ledger (the 7 most-recent `DayRecord`s) and the
/// processed-intent belt (at most `EngineState.processedIntentsCapacity`
/// recent ids) — while leaving every other field untouched.
///
/// **Why the store owns this (§5.4; REVIEW-TASK-015 routing).** The engine is
/// append-only: `EngineState.days` may exceed the window in memory, and the
/// fold appends per dayKey rollover without ever looking back. Retention is a
/// persistence obligation — the on-disk payload must always satisfy the caps —
/// so the store applies this prune on its WRITE path (`SnapshotStore.save`
/// prunes before encode). The read path does NOT prune: a load returns the
/// generation's payload exactly as verified (loads never write or mutate —
/// the TASK-021 stance).
///
/// **The 7-day window serves three consumers (05 §5.4).** The rolling 3-day
/// quest-generation window (§4.8), late Watch-intent attribution to their own
/// day (§6.4), and dayKey-keyed once-only clock-change resets (§4.3) all read
/// at most the recent tail; a ledger pruned to the 7 newest days serves every
/// one of them.
///
/// **The two caps.**
///
/// - Days: keep the `StoreRules.retainedDayCount` lexicographically-greatest
///   `dayKey`s. `DayKey.make` emits zero-padded `"YYYY-MM-DD"` strings
///   (`%04d-%02d-%02d`), so lexicographic order IS chronological order — the
///   format assumption this function is built on (pinned by name in
///   `LedgerRetentionTests`). A key's multiplicity never earns it extra slots:
///   duplicate dayKeys (a defect the engine cannot produce — one record per
///   dayKey is the store's own §5.4-era guarantee) collapse to their FIRST
///   occurrence, deterministically.
/// - Intents: keep the LAST `EngineState.processedIntentsCapacity` elements of
///   `processedIntents` (append order = recency order — EngineState's own
///   bookkeeping contract). The capacity is REUSED from MomoCore, never
///   restated here.
///
/// Both selections preserve the survivors' relative order, so the pruned
/// state is the same ledger the engine would have produced under a
/// rollover-time pruning discipline — see the SnapshotStore header for the
/// save-time-application equivalence note.
///
/// Totality: defined on every input (empty ledger, under-cap, at-cap,
/// oversized, duplicates) — there is no input without a well-defined output.
public enum LedgerRetention {

    /// The §5.4-pruned form of `state`: at most `StoreRules.retainedDayCount`
    /// day records (the newest dayKeys, first occurrence per key) and at most
    /// `EngineState.processedIntentsCapacity` processed intents (the last
    /// ones), everything else passed through unchanged.
    public static func pruned(_ state: EngineState) -> EngineState {
        // The retained dayKeys: the lexicographically-greatest DISTINCT keys
        // present. Set FIRST — duplicates collapse before the window opens,
        // so a duplicated key can never crowd a distinct one out of it —
        // then sort, then the window. The record filter below keeps each
        // survivor's FIRST occurrence, preserving input order.
        let retainedDayKeys = Set(state.days.map(\.dayKey))
            .sorted()
            .suffix(StoreRules.retainedDayCount)
        // Order-preserving filter with first-occurrence dedup: survivors keep
        // the input ledger's relative order, and a duplicated dayKey keeps
        // exactly its first record.
        var seenDayKeys = Set<String>()
        let retainedDays = state.days.filter { record in
            guard retainedDayKeys.contains(record.dayKey) else { return false }
            return seenDayKeys.insert(record.dayKey).inserted
        }
        // The belt: the last N ids in append order (`suffix` preserves order;
        // an empty or under-cap belt passes through whole).
        let retainedIntents = Array(
            state.processedIntents.suffix(EngineState.processedIntentsCapacity)
        )
        // Full-value rebuild: `EngineState` is `let`-immutable, so the pruned
        // state is a new value, never a mutation of the input.
        return EngineState(
            pet: state.pet,
            state: state.state,
            days: retainedDays,
            settings: state.settings,
            pendingHandshake: state.pendingHandshake,
            processedIntents: retainedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: state.lastOpenedAt,
            lastEvaluatedAt: state.lastEvaluatedAt,
            lastGreeting: state.lastGreeting
        )
    }
}
