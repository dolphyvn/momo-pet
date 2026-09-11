import Foundation

// MARK: - Watch reset marker (05-technical-architecture §6.6; TASK-040 R3;
// the TASK-038 routed AC-2 leg)

/// The §6.6 erase signal's persistent half: the record whose `eraseCount`
/// rides EVERY application context from an erase until the Watch consumes
/// it (wipe snapshot + journal → the settling-in line). Persisted OUTSIDE
/// the store tree (`StoreRules.watchResetMarkerDirectory()` — Application
/// Support/ itself), so the erase's directory deletion can never touch the
/// signal: the marker outlives the very erase it announces and every
/// relaunch after (the contract's survival requirement; pinned by the
/// marker suite).
///
/// **Shape — deliberately bare, no envelope (the sync-state precedent).**
/// The marker is iPhone-local bookkeeping (never a file the Watch reads;
/// only the COUNT crosses the link, as `WatchSnapshot`'s additive optional
/// `resetMarkerEraseCount`), so like `SyncState` it is plain JSON-native
/// fields with synthesized `Codable` — a future breaking change to its
/// shape would add a version field mirroring the DTOs, per
/// `StoreRules.syncStateFileName`'s documented posture.
///
/// **Count semantics.** The count is the ONE-SHOT consumption key: the
/// Watch consumes when a context's count exceeds the last count it
/// consumed, so a re-delivered context (latest-wins redelivery, §6.2) is
/// inert and a SECOND erase produces a NEW consumption event. The erase
/// path reads the persisted count, saves +1, and only then deletes the
/// store tree — signal-first ordering, so by the time pet data is gone the
/// Watch's wipe instruction is already durable. The iPhone never clears
/// the marker — consumption is Watch-side (TASK-041/044); a context
/// carrying an already-consumed count is the steady state, not an error.
public struct WatchResetMarker: Equatable, Sendable, Codable {

    /// Monotonic across the install's lifetime: 1 after the first erase,
    /// 2 after the second, … (the persisted count is read and re-issued
    /// +1). A missing marker means "no erase has ever happened" — count 0
    /// is the implicit fresh shape.
    public let eraseCount: Int

    public init(eraseCount: Int) {
        self.eraseCount = eraseCount
    }

    // MARK: Codec (the store's canonical recipe, single-sourced on the
    // record — the `WatchSnapshot` pattern; one Int, no Date, so the
    // default Date strategy clause is vacuous but stated for the family)

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
    public static func decoded(from data: Data) -> WatchResetMarker? {
        try? JSONDecoder().decode(WatchResetMarker.self, from: data)
    }
}
