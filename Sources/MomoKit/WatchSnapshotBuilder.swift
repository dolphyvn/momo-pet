import Foundation
import MomoCore

// MARK: - WatchSnapshot builder (05-technical-architecture §6.2/§6.4; TASK-023
// Requirement 2)

/// Builds the outgoing `WatchSnapshot` — the pure derivation
/// `EngineState + DisplayState + quest inputs + watermark (+ epoch, seq
/// source) → WatchSnapshot` so EPIC-007/008's wiring is one call.
///
/// **Every input is injected; nothing ambient is read.** The
/// `state`/`display`/`questInputs` triple is derived upstream by the
/// caller (`makeDisplayState` for the display; today's `[QuestProgress]`
/// quest set — the §6.2 sketch's `QuestCascadeInputs` mapped onto MomoCore's
/// existing type — comes from the same day-record lookup the cascade reads).
/// The builder itself never derives "today" (that would need a clock or a
/// calendar) and never touches the filesystem.
///
/// **Field threading (pinned field-for-field by the builder suite).**
///
/// - `hapticsEnabled` ← `state.settings.hapticsEnabled` (UX-13; the flag
///   exists on `SettingsState`, so no extra builder parameter — and no
///   MomoCore change — was needed).
/// - `lastAppliedIntentSeq` ← `sync.watermark(for: watermarkEpoch)` — the
///   watermark OF THE EPOCH THE SNAPSHOT ADVERTISES. Another epoch's
///   watermark must not leak in: a Watch ignores a snapshot whose
///   `lastAppliedEpoch` differs from its own (§6.4 step 4), so advertising
///   the wrong epoch's PAIR is inert-by-construction — but threading both
///   from the one `watermarkEpoch` input keeps the pair coherent.
/// - `lastAppliedEpoch` ← the `watermarkEpoch` parameter verbatim (the
///   epoch the watermark belongs to; EPIC-008's wiring derives it from the
///   current Watch's identity — the epoch of the most recently applied
///   intents).
/// - `snapshotSeq` ← the sync state's `nextSnapshotSeq`, CONSUMED: the
///   returned `nextSync` has the seq spent, so successive builds through
///   the threaded state are strictly monotonic by construction (never a
///   reused seq from forgetting to advance).
/// - `resetMarkerEraseCount` ← the caller's marker count, passed through
///   verbatim (TASK-040 R3): the builder owns no marker state — the erase
///   executor mints the count, the wiring reads it, the builder carries it
///   onto the payload. Default `nil` (no erase pending); while a marker is
///   live the wiring passes it on EVERY build, because the context
///   coalesces latest-wins (only the newest value is guaranteed observed)
///   and the count is the Watch's one-shot consumption key.
/// - `character` ← the caller's character DTO, passed through verbatim
///   (ADR-014, TASK-041 R1): the builder owns no character derivation — the
///   wiring derives it from the SHARED `makeCharacterDisplayState(state)`
///   (never re-implemented; 04 §9.2) and threads it here. Default `nil`
///   (the degraded shape the additive-OPTIONAL adjudication pins).
public func makeWatchSnapshot(
    state: EngineState,
    display: DisplayState,
    questInputs: [QuestProgress],
    watermarkEpoch: UUID,
    sync: SyncState,
    resetMarkerEraseCount: Int? = nil,
    character: WatchCharacterDTO? = nil
) -> (snapshot: WatchSnapshot, nextSync: SyncState) {
    let (advancedSync, assignedSeq) = sync.consumingSnapshotSeq()
    let snapshot = WatchSnapshot(
        snapshotSeq: assignedSeq,
        display: display,
        questInputs: questInputs,
        hapticsEnabled: state.settings.hapticsEnabled,
        lastAppliedIntentSeq: sync.watermark(for: watermarkEpoch),
        lastAppliedEpoch: watermarkEpoch,
        resetMarkerEraseCount: resetMarkerEraseCount,
        character: character
    )
    return (snapshot, advancedSync)
}
