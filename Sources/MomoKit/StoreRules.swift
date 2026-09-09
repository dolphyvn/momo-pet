import Foundation

// MARK: - StoreRules — the §5.2 store constants home (TASK-021 Requirement 5)
// (05-technical-architecture §5.2; ADR-002; house pattern per CopyRules/FoldRules)

/// The single source of every constant the `SnapshotStore` applies — the
/// `InteractionRules`/`CopyRules` discipline carried into the persistence era:
/// one auditable home, per-constant authority labels, and raw literals only in
/// the pin tests (`StoreRulesPinnedTests`) — the store and every behavior test
/// reference these constants, so a spec change surfaces as exactly one pin
/// failure plus one constants edit.
///
/// **Authorities.**
///
/// - **Spec-normative** (05-technical-architecture §5.2 + ADR-002): the three
///   file names, the retained generation count, and the envelope's
///   `schemaVersion` semantics. These are the record, not tunables.
/// - **Retention (§5.4, TASK-022's land):** `retainedDayCount` below — the
///   7-day `DayRecord` window the store's write path enforces (the engine
///   stays append-only; see `LedgerRetention`).
/// - **Migration posture (§5.5, implemented by TASK-022):** the read path
///   serves a generation at `currentSchemaVersion`, walks below-current
///   versions through the store's injected `MigrationChain` (any missing hop
///   makes the generation unreadable), and treats a version ABOVE the current
///   one as unreadable — the chain's above-head rule. With the production
///   chain (`MigrationChain.empty`) a below-current version is therefore
///   unreadable too, which is exactly TASK-021's pre-chain behavior, now as a
///   consequence of the empty walk rather than a special case.
public enum StoreRules {

    /// The current envelope schema version (05 §5.2's `schemaVersion`). `1` is
    /// the initial schema. Bumping it is a breaking-schema change owned by the
    /// §5.5 migration policy — the bump's steps are registered in the store's
    /// injected `MigrationChain` (production ships `MigrationChain.empty`).
    public static let currentSchemaVersion = 1

    /// Day-ledger retention (05 §5.4): the store's write path keeps the 7
    /// most-recent `DayRecord`s (by `dayKey` — zero-padded `"YYYY-MM-DD"`, so
    /// lexicographic order is chronological order). The window simultaneously
    /// serves §4.8's rolling 3-day quest-generation window, §6.4's late
    /// Watch-intent attribution, and §4.3's dayKey-keyed once-only resets.
    /// Applied by `LedgerRetention.pruned` before every encode; the engine
    /// stays append-only (REVIEW-TASK-015 routing — this constant is NEW
    /// normative surface, unlike the belt cap which MomoCore owns as
    /// `EngineState.processedIntentsCapacity`).
    public static let retainedDayCount = 7

    /// Retained generations: current + two predecessors (05 §5.2's three-file
    /// layout). The read path's recovery depth.
    public static let generationCount = 3

    /// Current generation (05 §5.2: "state.json ← current generation").
    public static let currentStateFileName = "state.json"

    /// Generation N−1 (05 §5.2: "state.prev.json ← generation N−1").
    public static let previousStateFileName = "state.prev.json"

    /// Generation N−2 (05 §5.2: "state.prev2.json ← generation N−2").
    public static let oldestStateFileName = "state.prev2.json"

    /// The in-flight save's temp file. It lives in the STORE DIRECTORY — the
    /// final rename must be same-volume to be a POSIX atomic rename, so the
    /// system temp directory is disqualified. Never read by anyone: a crash
    /// before the rename at worst orphans a torn temp, which the next save
    /// overwrites.
    public static let temporaryStateFileName = "state.json.tmp"

    /// The read (recovery) order, newest → oldest (05 §5.3: try `state.json`
    /// → `.prev` → `.prev2` → fresh default). Derived from the name constants
    /// above; `SnapshotStore` walks exactly this order.
    public static let generationFileNamesInReadOrder = [
        currentStateFileName,
        previousStateFileName,
        oldestStateFileName,
    ]

    // MARK: - Sync layer (05 §6.2/§6.4; ADR-003; TASK-023)

    /// The `WatchSnapshot` DTO's wire schema version (05 §6.2: the payloads
    /// are "Codable, versioned"). `1` is the initial schema. Decode-side
    /// semantics for any other version: IGNORED (nil) — the store's
    /// above-head rule with the shipped `MigrationChain.empty` is the
    /// consistent analogue (no DTO migration machinery exists; a version
    /// that is not the current one is not understood, and an ignored
    /// snapshot is §6.3's "Watch keeps rendering its last snapshot").
    public static let watchSnapshotSchemaVersion = 1

    /// The `IntentEvent` DTO's wire schema version (05 §6.2). Same
    /// ignore-semantics as `watchSnapshotSchemaVersion`: on the journal's
    /// parse path an unknown version is a SKIPPED line (the journal's
    /// documented skip semantics), so a future version can never wedge the
    /// queue.
    public static let intentEventSchemaVersion = 1

    /// The Watch → iPhone intent journal (05 §6.4's append-only queue behind
    /// `transferUserInfo`; ADR-003). NDJSON: one `IntentEvent` JSON object per
    /// line, `.sortedKeys`, newline-terminated. The doc names the MECHANISM,
    /// not a file name — the name is this layer's.
    public static let intentJournalFileName = "intent-journal.ndjson"

    /// The journal prune's in-flight temp file (the prune REWRITES the journal
    /// with its survivors; the rename is the commit point — the append path
    /// deliberately does NOT use it, because a torn append is the journal's
    /// designed crash tolerance). Same-volume rule as the store's temp: it
    /// lives in the injected journal directory. Never read by anyone.
    public static let temporaryIntentJournalFileName = "intent-journal.ndjson.tmp"

    /// The sync-state file (TASK-023 contract Requirement 3): the per-epoch
    /// watermark table + the next `snapshotSeq`, the iPhone's watermark home
    /// (05 §6.4: "the iPhone stores the watermark per epoch"). Plain JSON —
    /// no envelope — because it is iPhone-local bookkeeping (never crosses
    /// the link, TR4); a future breaking change to its shape would add a
    /// version field, mirroring the DTOs.
    public static let syncStateFileName = "sync-state.json"

    /// The sync-state save's temp file (write-temp-then-atomic-rename — the
    /// store's commit-point discipline, Requirement 3). Same-volume rule;
    /// never read by anyone.
    public static let temporarySyncStateFileName = "sync-state.json.tmp"

    /// The default store directory (05 §5.2): `Application Support/Momo/`,
    /// created if missing — so EPIC-007's wiring is one call. This is the ONE
    /// sanctioned ambient-path site in MomoKit (the discipline scan exempts
    /// exactly this file for the path family): every other MomoKit entry point
    /// takes its directory injected, per the no-ambient-paths constraint.
    public static func defaultDirectory() throws -> URL {
        let fileManager = FileManager.default
        let applicationSupport = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = applicationSupport.appendingPathComponent("Momo", isDirectory: true)
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false), isDirectory: &isDirectory) || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }
}
