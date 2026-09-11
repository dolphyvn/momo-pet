import Foundation

// MARK: - WatchResetMarkerStore (05-technical-architecture §6.6; TASK-040 R3;
// `SyncStateStore`'s commit-point discipline applied to the reset marker)

/// The reset marker's persistence: one plain JSON file
/// (`StoreRules.watchResetMarkerFileName`) over an INJECTED directory,
/// written temp-then-atomic-commit (replace-when-present / move-when-absent
/// — see `save`), the exact recipe `SyncStateStore` documents. Plain over
/// DRY (ADR-013's house posture): a one-int payload does not generalize the
/// two stores into one.
///
/// **Recovery stance.** A missing file loads as `nil` — "no erase is
/// pending", the valid steady state (a fresh install has never erased). A
/// garbled file also loads as `nil`, silently: the sibling stores'
/// documented stance (load recovery is a DEFINED state, never loud — only
/// SAVE failures trip the debugger). The cost is accepted and bounded: a
/// lost marker means the Watch skips one §6.6 wipe (stale journal entries
/// could reapply across that erase — exactly what the marker prevents),
/// the bytes are unrecoverable either way, and the next erase re-signals
/// with a fresh count. Never throws.
///
/// **Serialization.** The store's canonical recipe: `.sortedKeys` (governs
/// the encoder; the record carries no Date).
public struct WatchResetMarkerStore {

    /// The injected directory (the app layer passes
    /// `StoreRules.watchResetMarkerDirectory()`; tests inject a throwaway).
    private let directory: URL

    /// - Parameter directory: the directory holding
    ///   `StoreRules.watchResetMarkerFileName`; created by `save` if
    ///   missing (`load` over a missing directory is a valid "no marker").
    public init(directory: URL) {
        self.directory = directory
    }

    /// Loads the persisted marker, or `nil` when nothing loadable is there
    /// (missing, empty, or garbled — the type header's defined recovery,
    /// deliberately silent like the sibling stores' load paths). Never
    /// throws.
    public func load() -> WatchResetMarker? {
        let url = directory.appendingPathComponent(StoreRules.watchResetMarkerFileName)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return WatchResetMarker.decoded(from: data)
    }

    /// Persists `marker` as the marker file: encode → write the temp →
    /// atomic commit (the file only ever appears complete under its final
    /// name). REPLACE-WHEN-PRESENT / MOVE-WHEN-ABSENT — the `SyncStateStore`
    /// lesson verbatim: no generations here either, so `moveItem` onto the
    /// existing file would fail (Code 516) and remove-then-move would open
    /// a loss window over the erase signal; `replaceItemAt` is the
    /// whole-or-new atomic replace (pinned by the double-save test). Total:
    /// never throws; on any internal failure the previous file is untouched
    /// (and the temp cleaned up).
    public func save(_ marker: WatchResetMarker) {
        guard let data = marker.encoded() else {
            // One JSON-native Int; failing to encode it is a domain-model
            // regression. DEBUG-loud; the old file stands.
            Self.debugLoudFailure("WatchResetMarkerStore: marker encoding failed — save skipped")
            return
        }
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let temporary = directory.appendingPathComponent(StoreRules.temporaryWatchResetMarkerFileName)
            let current = directory.appendingPathComponent(StoreRules.watchResetMarkerFileName)
            try data.write(to: temporary)
            if fileManager.fileExists(atPath: current.path(percentEncoded: false)) {
                // The replace path: every save after the marker's (re)birth.
                _ = try fileManager.replaceItemAt(current, withItemAt: temporary, backupItemName: nil, options: [])
            } else {
                // The move path: the post-erase rebirth (or first-ever save).
                try fileManager.moveItem(at: temporary, to: current)
            }
        } catch {
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporaryWatchResetMarkerFileName)
            )
            Self.debugLoudFailure("WatchResetMarkerStore: save failed (\(error)) — previous marker kept")
        }
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
