import Foundation

// MARK: - WatchSnapshotStore (05-technical-architecture §6.6; ADR-013
// duplicate; TASK-041 R2)

/// The Watch-side last-synced snapshot's persistence: TWO files in the
/// injected directory — `StoreRules.watchSnapshotFileName` (current) and
/// `StoreRules.previousWatchSnapshotFileName` (its one predecessor) — written
/// with the commit-point discipline and read with generational recovery,
/// `SnapshotStore`'s shape at Watch scale. ADR-013's plain-over-DRY posture:
/// the iPhone store's envelope/checksum/migration machinery has no analogue
/// here by design — the `WatchSnapshot` DTO already carries `schemaVersion`,
/// and `WatchSnapshot.decoded(from:)` gates it, so the envelope's remaining
/// jobs (versioning, integrity) are already on the record; a Watch file that
/// fails to decode falls through to `.prev` and then to `nil`, where `nil`
/// means "render the settling-in line" — the type's one defined degraded
/// state, never an error surface (UX §9).
///
/// **Write sequence and its crash windows.** Per save, in this order — the
/// order is forced by the same reasoning `SnapshotStore` documents (the
/// previous generation is demoted BEFORE the current is replaced, and the
/// current is moved away BEFORE the new bytes land under its name):
///
///     1. prev  ← (remove) current → prev    atomic rename; destination free —
///                                            the stale prev was removed first
///     2. current ← write temp; temp → current
///                                            atomic rename; destination free —
///                                            step 1 moved current away
///
/// Every step is a same-directory rename (the temp lives in the store
/// directory, so the rename is same-volume). A file therefore only ever
/// appears complete under its final name, and at every interruption point:
///
///     interruption after…   watch-snapshot  .prev    load serves
///     ───────────────────   ──────────────  ──────   ───────────
///     (nothing done)        N               N−1      N
///     step 1 remove         N               —        N
///     step 1 rename         —               N        N
///     step 2 temp write     —               N        N (+orphan temp)
///     step 2 rename         N+1             N        N+1
///
/// — the new snapshot, the previous one, or (after a wipe) nothing; never an
/// error, never a torn mix. One generation is ENOUGH fallback for this file
/// family: it is written once per received snapshot, not per engine event,
/// and a lost `.prev` at worst costs one recovery hop into the settling-in
/// line — a defined, quiet state.
///
/// **Serialization.** `save` and `wipe` are actor-isolated: the actor
/// total-orders mutations, so a wipe racing a save cannot interleave its
/// removes between the save's renames. Production funnels EVERY call through
/// ONE serialized writer (the Watch executor's persister actor, the
/// `MomoWatchSyncPersister` pattern) because the store is cheaply
/// reconstructed per call there — the actor belt plus suspenders. `load` is
/// deliberately `nonisolated` (the `SnapshotStore` reasoning verbatim):
/// reads need no serialization because every generation file is published by
/// atomic rename only, and the launch read must hold no store cooperation.
///
/// **Totality.** Neither public API throws. `load` falls through current →
/// `.prev` → `nil` on ANY failure (missing file, empty/garbled bytes, a
/// schema version the decode gate rejects — `WatchSnapshot.decoded(from:)`'s
/// above/equal-head rule). `wipe` removes both generations plus the temp,
/// tolerating any of them already being absent — it is the §6.6 consumption
/// leg's store half and MUST be idempotent (a crash between wipe and the
/// consumed-marker record replays the whole consumption, and the replay
/// must be a no-op second time). `save` is internally total: an I/O failure
/// leaves the existing pair untouched (`assertionFailure` in DEBUG — the
/// store-family discipline; silent in release, where the stale pair remains
/// the render target).
public actor WatchSnapshotStore {

    /// The injected store directory (the Watch app passes
    /// `StoreRules.defaultDirectory()`; tests inject a throwaway).
    private let directory: URL

    /// - Parameter directory: the directory holding the two generation
    ///   files; created by `save` if missing (`load`/`wipe` over a missing
    ///   directory are valid no-data/no-op states that must not throw).
    public init(directory: URL) {
        self.directory = directory
    }

    // MARK: Write path

    /// Persists `snapshot` as the new current generation, demoting the
    /// previous one per the header's sequence. Call once per RECEIVED
    /// snapshot (§6.2's latest-wins render-and-persist leg) and on every
    /// background transition's re-persist (§6.6's process-lifecycle leg);
    /// the executor's serialized writer owns that wiring.
    public func save(_ snapshot: WatchSnapshot) {
        guard let data = snapshot.encoded() else {
            // A snapshot that cannot encode would be a domain-model
            // regression (every field is JSON-native). DEBUG-loud; the
            // existing pair stands.
            Self.debugLoudFailure("WatchSnapshotStore: snapshot encoding failed — save skipped")
            return
        }
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let current = directory.appendingPathComponent(StoreRules.watchSnapshotFileName)
            let previous = directory.appendingPathComponent(StoreRules.previousWatchSnapshotFileName)
            let temporary = directory.appendingPathComponent(StoreRules.temporaryWatchSnapshotFileName)
            // Step 1 — current → prev. The stale prev is removed FIRST so
            // the rename's destination is free (no `replaceItemAt` here: the
            // two-step is the SnapshotStore recipe and keeps every
            // intermediate state in the header's table).
            if fileManager.fileExists(atPath: current.path(percentEncoded: false)) {
                try? fileManager.removeItem(at: previous)
                try fileManager.moveItem(at: current, to: previous)
            }
            // Step 2 — write temp, atomic-rename onto the current name. The
            // temp is written plainly (nobody reads it; a torn temp is
            // inert and the next save overwrites it); the rename is the
            // commit point.
            try data.write(to: temporary)
            try fileManager.moveItem(at: temporary, to: current)
        } catch {
            // Leave the pair as it stands — every prefix of the sequence is
            // a loadable state (header table). Clean up our own temp so an
            // interrupted step 2 cannot leave junk behind the next save.
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporaryWatchSnapshotFileName)
            )
            Self.debugLoudFailure("WatchSnapshotStore: save failed (\(error)) — previous snapshot kept")
        }
    }

    // MARK: The §6.6 consumption wipe

    /// Removes both generations and the temp — the §6.6 consumption's store
    /// half, run BEFORE the consumed-marker record (wipe-then-record, so a
    /// crash between them replays the wipe: idempotent by this method's
    /// tolerance of absent files). Never throws. Deliberately touches
    /// NOTHING else in the directory — the consumed marker lives here too
    /// and must survive every wipe, or the same count would re-consume
    /// forever.
    public func wipe() {
        let fileManager = FileManager.default
        for fileName in [
            StoreRules.watchSnapshotFileName,
            StoreRules.previousWatchSnapshotFileName,
            StoreRules.temporaryWatchSnapshotFileName,
        ] {
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(fileName)
            )
        }
    }

    // MARK: Read path — nonisolated: see the header's serialization
    // statement. Loads racing saves are safe because each generation file
    // is published by atomic rename only.

    /// Returns the newest loadable generation, falling through current →
    /// `.prev` → `nil` on any failure (the header's recovery stance: `nil`
    /// is the settling-in shape, not an error).
    public nonisolated func load() -> WatchSnapshot? {
        for fileName in [StoreRules.watchSnapshotFileName, StoreRules.previousWatchSnapshotFileName] {
            let url = directory.appendingPathComponent(fileName)
            guard let data = try? Data(contentsOf: url), !data.isEmpty else { continue }
            // The decode IS the version gate: `WatchSnapshot.decoded(from:)`
            // returns nil for malformed bytes AND for a schema version this
            // build does not understand (the store family's above/equal-head
            // rule — an unknown future snapshot keeps falling through).
            if let snapshot = WatchSnapshot.decoded(from: data) {
                return snapshot
            }
        }
        return nil
    }

    private static func createDirectoryIfMissing(_ directory: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false), isDirectory: &isDirectory) || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// The `MomoCopy`/`SnapshotStore` DEBUG-loud discipline — see the type
    /// header for what is and is not loud on this store's paths.
    private static func debugLoudFailure(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
