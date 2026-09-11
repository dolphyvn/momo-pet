import Foundation

// MARK: - Watch session epoch (05-technical-architecture §6.2; TASK-042 R1;
// the WatchResetMarker pattern applied to the Watch's own sync identity)

/// The Watch's per-install sync identity: the `watchSessionEpoch` every
/// journaled `IntentEvent` carries (05 §6.2 — generated at Watch app first
/// launch, persisted in the Watch store §5.6, regenerated on
/// reinstall/re-pair/new Watch). The iPhone's watermark table and the
/// journal's prune rule are keyed on it, so a STALE epoch's journal entries
/// can never apply and a fresh epoch's seqs start over (§6.2: "resets with
/// the epoch").
///
/// **Shape — deliberately bare, no envelope (the `WatchResetMarker`
/// precedent).** Watch-local bookkeeping (the epoch never crosses the link
/// as its own payload; it rides each event's `watchSessionEpoch` field), so
/// like the markers it is plain JSON-native fields with synthesized
/// `Codable` — a future breaking change would add a version field mirroring
/// the DTOs.
///
/// **Generation is CALLER-side by design.** The store is dumb load-or-nil /
/// save; the app model decides (read; on a miss mint a fresh `UUID()`, save,
/// and wipe any journal present — the TASK-040 F-3 self-defense, whose wipe
/// leg must run through the Watch's one-writer persister and therefore
/// cannot live in a store type). The store never mints.
public struct WatchSessionEpoch: Equatable, Sendable, Codable {

    /// The per-install epoch. A fresh UUID per generation; stable across
    /// relaunches (pinned by test). Reinstall/re-pair resets it naturally —
    /// the app container (and this file with it) is wiped, so the next
    /// launch's read misses and the caller regenerates (documented, not
    /// coded — no code can observe its own container's deletion).
    public let epoch: UUID

    public init(epoch: UUID) {
        self.epoch = epoch
    }

    // MARK: Codec (the store's canonical recipe, single-sourced on the
    // record — one UUID, no Date, so the default Date strategy clause is
    // vacuous but stated for the family)

    /// The canonical bytes (`.sortedKeys`; see the type header's posture).
    /// Nil on an encoding failure — a one-field record that cannot encode
    /// is a domain-model regression, not a runtime state.
    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    /// The total decode: nil for malformed bytes. No version gate exists —
    /// the record is deliberately envelope-free (the type header); the
    /// store's load path owns the defined nil recovery.
    public static func decoded(from data: Data) -> WatchSessionEpoch? {
        try? JSONDecoder().decode(WatchSessionEpoch.self, from: data)
    }
}

// MARK: - WatchSessionEpochStore

/// The session epoch's persistence: one plain JSON file
/// (`StoreRules.watchSessionEpochFileName`) over an INJECTED directory,
/// written temp-then-atomic-commit (replace-when-present / move-when-absent
/// — the `WatchResetMarkerStore` recipe verbatim, plain over DRY per
/// ADR-013's house posture: a one-UUID payload does not generalize the
/// stores into one).
///
/// **Recovery stance** (the marker store's, verbatim in shape): a missing OR
/// garbled file loads as `nil` — "no epoch minted yet", the fresh-install
/// steady state whose caller-side consequence is generation + journal wipe.
/// A lost epoch file (garble) costs one regeneration: the journal's stale
/// entries are wiped by that same leg (the F-3 self-defense) and the
/// iPhone's old-epoch watermark becomes permanently inert — exactly the
/// reinstall posture. Never throws.
///
/// **Serialization.** The store's canonical recipe: `.sortedKeys` (governs
/// the encoder; the record carries no Date). The caller serializes
/// generation decisions (the Watch app model reads once, at init, before
/// any pat leg can run).
public struct WatchSessionEpochStore {

    /// The injected directory (the Watch app passes
    /// `StoreRules.defaultDirectory()`; tests inject a throwaway).
    private let directory: URL

    /// - Parameter directory: the directory holding
    ///   `StoreRules.watchSessionEpochFileName`; created by `save` if
    ///   missing (`load` over a missing directory is a valid "no epoch").
    public init(directory: URL) {
        self.directory = directory
    }

    /// Loads the persisted epoch record, or `nil` when nothing loadable is
    /// there (missing, empty, or garbled — the type header's defined
    /// recovery, deliberately silent like the sibling stores' load paths).
    /// Never throws.
    public func load() -> WatchSessionEpoch? {
        let url = directory.appendingPathComponent(StoreRules.watchSessionEpochFileName)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        return WatchSessionEpoch.decoded(from: data)
    }

    /// Persists `epoch` as the epoch file: encode → write the temp → atomic
    /// commit (the file only ever appears complete under its final name).
    /// REPLACE-WHEN-PRESENT / MOVE-WHEN-ABSENT — the `WatchResetMarkerStore`
    /// recipe verbatim (`replaceItemAt` is the whole-or-new atomic replace;
    /// pinned by the double-save test). Total: never throws; on any internal
    /// failure the previous file is untouched (and the temp cleaned up).
    public func save(_ epoch: WatchSessionEpoch) {
        guard let data = epoch.encoded() else {
            // One JSON-native UUID; failing to encode it is a domain-model
            // regression. DEBUG-loud; the old file stands.
            Self.debugLoudFailure("WatchSessionEpochStore: epoch encoding failed — save skipped")
            return
        }
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let temporary = directory.appendingPathComponent(StoreRules.temporaryWatchSessionEpochFileName)
            let current = directory.appendingPathComponent(StoreRules.watchSessionEpochFileName)
            try data.write(to: temporary)
            if fileManager.fileExists(atPath: current.path(percentEncoded: false)) {
                // The replace path: every save after the epoch's (re)birth.
                _ = try fileManager.replaceItemAt(current, withItemAt: temporary, backupItemName: nil, options: [])
            } else {
                // The move path: the first-ever save (fresh install, or the
                // post-garble rebirth).
                try fileManager.moveItem(at: temporary, to: current)
            }
        } catch {
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporaryWatchSessionEpochFileName)
            )
            Self.debugLoudFailure("WatchSessionEpochStore: save failed (\(error)) — previous epoch kept")
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
