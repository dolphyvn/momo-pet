import Foundation

// MARK: - QuestTick — window-checked quest-completion detection
// (05-technical-architecture §4.8; PRD §5.4, FR-16; TASK-018 Requirement 5)

/// The completion half of §4.8: invoked at each of TASK-016's counting
/// events AFTER the counter increment and the family/variety record, it
/// advances the event day's in-set quests toward their catalog targets and
/// completes them exactly at the qualifying event.
///
/// **Semantics (contract Req 5):**
///
/// - **Scope** — in-set, not-yet-completed quests of the event's served
///   families only (a pat serves `.greet` AND `.pet`; feed serves
///   `.feed`; the unified play cease serves `.play`; care serves
///   `.care`). Out-of-set quests never tick.
/// - **Qualifying-only progress** — the window check GATES the tick: an
///   event whose local hour is outside a candidate's catalog window
///   (`QuestWindow.contains(hour:)`) leaves that quest's progress at 0
///   (Q1's window never re-opens — silent expiry, §5.1 rule 6; Q6's
///   re-opens at 20:00). The window never gates the COUNT — only the tick.
/// - **The event's own time** — the hour comes from the event's own
///   timestamp through the injected calendar, never the application
///   instant (05 §4.8's offline-pat rule: an 11:30 pat applied at 12:30
///   ticks Q1).
/// - **Attribution** — always to the event's `dayKey` (D20 day-ownership:
///   a 00:30 tuck-in belongs to the NEW day and can complete that day's
///   Q6). An expired-dayKey event (no ledger entry) ticks nothing: no
///   progress, no completion, no moment — TASK-017's ledger disposition.
/// - **Completion** — `completed` becomes true exactly when progress
///   reaches the catalog target, at this event; the completion emits the
///   bare `.questCompleted` moment (04 §9.2's frozen vocabulary) and
///   awards +4 through `BondLedger.awardQuestCompletion`'s clamp. A
///   completed quest never un-completes, never re-emits, never re-awards
///   (the progress cap makes re-entry structurally dead).
/// - **Multiples** — one event CAN complete more than one quest (e.g. a
///   morning pat serving both `.greet` and `.pet`), so the loop never
///   assumes ≤ 1: every qualifying candidate ticks, in the set's stored
///   order, each carrying its own moment and award.
enum QuestTick {

    /// Ticks the quests of `families` on `dayKey`'s ledger entry, gated by
    /// the window at `instant`'s local hour (via the injected calendar).
    /// Returns the new state and the `.questCompleted` moments in set
    /// order. Pure; no rng draws (the seed→set mapping and the choreography
    /// draw lineage are untouched).
    static func tick(
        families: Set<QuestFamily>,
        to state: EngineState,
        dayKey: String,
        instant: Instant,
        calendar: Calendar
    ) -> (state: EngineState, moments: [CharacterMoment]) {
        // Expired-dayKey: no ledger entry, no tick (no progress, no
        // completion, no moment — no retroactive record is ever created).
        guard let entry = InteractionEffects.dayEntry(in: state, dayKey: dayKey) else {
            return (state, [])
        }
        let hour = calendar.component(.hour, from: instant)
        var ticked: [QuestProgress] = []
        var completions = 0
        for quest in entry.questSet {
            let catalog = QuestCatalog.entry(for: quest.questID)
            guard !quest.completed,
                  families.contains(catalog.family),
                  catalog.window.contains(hour: hour)
            else {
                ticked.append(quest)
                continue
            }
            // The window gates the TICK: progress advances by 1 (capped at
            // the catalog target), and `completed` becomes true exactly at
            // the event that reaches the target.
            let advanced = min(catalog.target, quest.progress + 1)
            let completed = advanced == catalog.target
            if let updated = QuestProgress(questID: quest.questID, progress: advanced, completed: completed) {
                ticked.append(updated)
                if completed {
                    completions += 1
                }
            } else {
                // Unreachable: 0 < advanced ≤ target satisfies INV-6.
                assertionFailure("QuestTick: quest advance rejected — invariant regression")
                ticked.append(quest)
            }
        }
        guard ticked != entry.questSet else {
            return (state, []) // no quest moved — the event quest-ticks nothing
        }
        let recorded = InteractionEffects.updatingDay(state, dayKey) { _ in
            rebuilding(entry, questSet: ticked)
        }
        // Each completion emits the bare moment AND awards +4 through the
        // clamp, in set order (the cap arithmetic makes award order
        // non-load-bearing; the order is pinned for determinism review).
        var current = recorded
        var moments: [CharacterMoment] = []
        for _ in 0..<completions {
            current = BondLedger.awardQuestCompletion(to: current, dayKey: dayKey)
            moments.append(.questCompleted)
        }
        return (current, moments)
    }

    // MARK: Ledger-record rebuild (house pattern)

    /// A copy of `record` with the quest set replaced. The rebuild cannot
    /// fail — the ticked set has the same count, the same distinct quest
    /// ids, and only INV-6-valid members (the failable init enforced every
    /// advance above); failure would be a programmer error (house pattern:
    /// DEBUG-loud, release keeps the unchanged record rather than
    /// corrupting the ledger).
    private static func rebuilding(_ record: DayRecord, questSet: [QuestProgress]) -> DayRecord {
        guard let updated = DayRecord(
            dayKey: record.dayKey,
            feedCount: record.feedCount,
            playCount: record.playCount,
            careCount: record.careCount,
            patCount: record.patCount,
            questSet: questSet,
            helloAwarded: record.helloAwarded,
            familiesUsed: record.familiesUsed,
            bondAwarded: record.bondAwarded,
            questGenEpoch: record.questGenEpoch
        ) else {
            assertionFailure("QuestTick: quest-set update rejected — invariant regression")
            return record
        }
        return updated
    }
}
