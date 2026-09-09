import Foundation
import MomoCore

// MARK: - SyncStateStore (TASK-023 contract Requirement 3; the store's
// commit-point discipline applied to the sync state)

/// The sync state's persistence: one plain JSON file
/// (`StoreRules.syncStateFileName`) over an INJECTED directory, written
/// temp-then-atomic-commit (replace-when-present / move-when-absent — see
/// `save`). Deliberately NOT a generalization of `SnapshotStore`
/// (contract: refactoring the store into a generic one is out of scope):
/// the sync state has no generations, no checksum, and no migration chain —
/// it is regenerable bookkeeping, where the store's payload is the only
/// copy of the pet.
///
/// **Recovery stance.** A missing, empty, or garbled file loads as the FRESH
/// state (empty watermark table, `nextSnapshotSeq == 1`) — silently, the
/// same defined-recovery shape as the store's fall-through. The consequences
/// are documented on `SyncState`: watermarks reset to 0 (the §6.6
/// iPhone-reinstall shape — queued intents apply warm, the dual guard's UUID
/// belt in engine state is the remaining guard) and the snapshot seq
/// restarts (a display no-op — see `SyncState`'s monotonicity note). Never
/// throws, never surfaces an error (UX §9).
///
/// **Serialization.** The store's canonical recipe: `.sortedKeys` (key order
/// is otherwise unspecified), Foundation's default Date strategy (the sync
/// state carries no Date today; the recipe governs the encoder). The
/// `[UUID: Int]` table encodes with UUID-string keys — JSON-native.
public struct SyncStateStore {

    /// The injected directory (the app layer passes
    /// `StoreRules.defaultDirectory()`; tests inject a throwaway).
    private let directory: URL

    /// - Parameter directory: the directory holding
    ///   `StoreRules.syncStateFileName`; created by `save` if missing
    ///   (`load` over a missing directory is a valid fresh start).
    public init(directory: URL) {
        self.directory = directory
    }

    /// Loads the persisted sync state, or the fresh state when nothing
    /// loadable is there. Never throws.
    public func load() -> SyncState {
        let url = directory.appendingPathComponent(StoreRules.syncStateFileName)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return SyncState() }
        guard let state = try? JSONDecoder().decode(SyncState.self, from: data) else {
            return SyncState()
        }
        return state
    }

    /// Persists `state` as the sync-state file: encode → write the temp →
    /// atomic commit (the file only ever appears complete under its final
    /// name). The commit point is REPLACE-WHEN-PRESENT / MOVE-WHEN-ABSENT:
    /// unlike `SnapshotStore` — whose generation rotation vacates
    /// `state.json` before its final move, making a plain `moveItem` safe
    /// there — this store has no generations, so `moveItem` onto the
    /// existing file would fail (Code 516) and `removeItem`-then-move would
    /// open a loss window over the watermark table. `replaceItemAt` is the
    /// whole-or-new atomic replace (the same commit `IntentJournal.prune`
    /// uses over a surviving journal). Total: never throws; on any internal
    /// failure the previous file is untouched (and the temp cleaned up).
    public func save(_ state: SyncState) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(state) else {
            // `SyncState` is two JSON-native fields; failing to encode it is
            // a domain-model regression. DEBUG-loud; the old file stands.
            Self.debugLoudFailure("SyncStateStore: sync-state encoding failed — save skipped")
            return
        }
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let temporary = directory.appendingPathComponent(StoreRules.temporarySyncStateFileName)
            let current = directory.appendingPathComponent(StoreRules.syncStateFileName)
            try data.write(to: temporary)
            if fileManager.fileExists(atPath: current.path(percentEncoded: false)) {
                // The replace path: the file already exists (every save
                // after the first). `moveItem` would fail onto it; this is
                // the atomic whole-or-new commit.
                _ = try fileManager.replaceItemAt(current, withItemAt: temporary, backupItemName: nil, options: [])
            } else {
                // The move path: first-ever save, nothing to replace.
                try fileManager.moveItem(at: temporary, to: current)
            }
        } catch {
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporarySyncStateFileName)
            )
            Self.debugLoudFailure("SyncStateStore: save failed (\(error)) — previous sync state kept")
        }
    }

    private static func createDirectoryIfMissing(_ directory: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false), isDirectory: &isDirectory) || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// The `MomoCopy`/`SnapshotStore` DEBUG-loud discipline for INVARIANT
    /// REGRESSIONS and I/O failures: trip the debugger in debug builds, stay
    /// silent in release where the documented recovery (previous file kept /
    /// fresh state) governs. The load path's DEFINED fresh-state recovery is
    /// deliberately NOT loud — a missing file is a fresh install, not a
    /// defect (mirrors the store's silent load fall-through).
    private static func debugLoudFailure(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
