import Foundation

// MARK: - Watch reset-marker consumption (05-technical-architecture §6.6;
// TASK-041 R5; ADR-013 duplicate for the store)

/// The Watch's one-side-of-the-link half of §6.6: deciding whether an
/// incoming application context's `resetMarkerEraseCount` announces an erase
/// this Watch has NOT yet consumed. The DECISION is pure (this file's
/// `decide`); the WIPE orchestration is the executor's (receive path: wipe
/// the snapshot store → record the count → render the settling-in line);
/// the persistence of the consumed count is `WatchConsumedMarkerStore`.
public enum WatchResetConsumption {

    /// The consumption decision for one incoming context.
    public enum Decision: Equatable, Sendable {

        /// A NEW erase is pending: wipe the snapshot store (the journal leg
        /// is TASK-042's), record the count, render the settling-in line,
        /// and DO NOT render the incoming snapshot (its pet data describes
        /// the world the erase just deleted).
        case consume

        /// Nothing to consume: render the context normally (or, for a nil
        /// count, the plain no-marker steady state).
        case render
    }

    /// The one-shot consumption key (the marker record's count semantics,
    /// Watch-side): consume IFF the incoming count EXCEEDS the last count
    /// this Watch has consumed. Total and pure — value-in/value-out, nothing
    /// ambient.
    ///
    /// - `incoming == nil` → `.render`: no erase is pending. This is the
    ///   overwhelmingly common shape — the builder only threads a non-zero
    ///   count while a marker is live (TASK-040 R3).
    /// - `incoming <= consumed` → `.render`: an already-consumed count (==
    ///   — the steady redelivery: the count rides EVERY context until the
    ///   iPhone's next erase re-mints it, so equality is the NORMAL
    ///   post-consumption state, not an error) or a REGRESSION (< — a stale
    ///   frame from an older erase; consuming it again would be harmless
    ///   only by luck, so it is refused by the monotonic rule).
    /// - `incoming > consumed` → `.consume`: an erase the Watch has never
    ///   seen. **F-3 self-defense (REVIEW-TASK-040's crash-window finding):**
    ///   the executor wipes BEFORE recording the consumed count, so a crash
    ///   in between leaves the count unconsumed — the redelivered context
    ///   re-decides `.consume` and the replayed wipe is a no-op second time
    ///   (`WatchSnapshotStore.wipe` tolerates absent files). The inverse
    ///   order (record-then-wipe) would be the dangerous one: a crash there
    ///   leaves stale pet data persisted forever behind a consumed count.
    public static func decide(
        incomingEraseCount: Int?,
        consumedEraseCount: Int
    ) -> Decision {
        guard let incomingEraseCount, incomingEraseCount > consumedEraseCount else {
            return .render
        }
        return .consume
    }
}

/// The consumed count's persistence: ONE plain JSON file
/// (`StoreRules.watchConsumedMarkerFileName`) over an INJECTED directory —
/// the store directory, NOT outside it — written with the exact
/// commit-point discipline `WatchResetMarkerStore` documents (temp-then-
/// atomic-commit; replace-when-present / move-when-absent). ADR-013's
/// plain-over-DRY posture: a one-int store does not generalize the store
/// family into one.
///
/// **Why the record is reused.** The file holds a `WatchResetMarker` — the
/// same one-int record the iPhone's sentinel uses — because the count IS the
/// same number on the other side of the link; only the FILE differs
/// (Watch-local bookkeeping inside the store directory). The deliberate
/// consequence pinned in the suite: a §6.6 snapshot wipe removes the
/// generation files ONLY (`WatchSnapshotStore.wipe`), never this file —
/// wiping it would reset consumption to 0 and the same count would
/// re-consume forever.
///
/// **Recovery stance.** Identical to `WatchResetMarkerStore`'s, read from
/// the consumer's side: a missing or garbled file loads `nil` — "nothing
/// consumed yet" — which composes with `decide` as consumed-count 0: the
/// first erase ever is then `1 > 0` → consume, and a lost consumed record
/// re-consumes ONE wipe idempotently (the F-3 replay stance). Never throws.
public struct WatchConsumedMarkerStore {

    /// The injected directory (the Watch app passes
    /// `StoreRules.defaultDirectory()`; tests inject a throwaway).
    private let directory: URL

    /// - Parameter directory: the directory holding
    ///   `StoreRules.watchConsumedMarkerFileName`; created by `save` if
    ///   missing (`load` over a missing directory is a valid "nothing
    ///   consumed").
    public init(directory: URL) {
        self.directory = directory
    }

    /// Loads the persisted consumed count, or `nil` when nothing loadable is
    /// there (missing, empty, or garbled — the sibling stores' silent
    /// load-recovery stance; only SAVE failures trip the debugger). Never
    /// throws.
    public func load() -> WatchResetMarker? {
        let url = directory.appendingPathComponent(StoreRules.watchConsumedMarkerFileName)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return WatchResetMarker.decoded(from: data)
    }

    /// Persists `marker` (the newly consumed count) as the marker file: the
    /// `WatchResetMarkerStore.save` recipe verbatim — encode → write temp →
    /// atomic commit. Total: never throws; on any internal failure the
    /// previous file is untouched (and the temp cleaned up).
    public func save(_ marker: WatchResetMarker) {
        guard let data = marker.encoded() else {
            // One JSON-native Int; failing to encode it is a domain-model
            // regression. DEBUG-loud; the old file stands.
            Self.debugLoudFailure("WatchConsumedMarkerStore: marker encoding failed — save skipped")
            return
        }
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let temporary = directory.appendingPathComponent(StoreRules.temporaryWatchConsumedMarkerFileName)
            let current = directory.appendingPathComponent(StoreRules.watchConsumedMarkerFileName)
            try data.write(to: temporary)
            if fileManager.fileExists(atPath: current.path(percentEncoded: false)) {
                // The replace path: every save after the first.
                _ = try fileManager.replaceItemAt(current, withItemAt: temporary, backupItemName: nil, options: [])
            } else {
                // The move path: the first-ever consumption (or the
                // recovery rebirth after a lost record).
                try fileManager.moveItem(at: temporary, to: current)
            }
        } catch {
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporaryWatchConsumedMarkerFileName)
            )
            Self.debugLoudFailure("WatchConsumedMarkerStore: save failed (\(error)) — previous marker kept")
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
