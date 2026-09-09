import Foundation
import MomoCore

// MARK: - SnapshotStore (05-technical-architecture §5.1–§5.3; ADR-002; TASK-021)

/// The iPhone-side snapshot store: a plain Codable file store with atomic
/// writes and generational recovery (ADR-002's decision; implements FR-13
/// AC-1/AC-2 by construction — write-through bounds force-quit loss to the
/// in-flight event, and a bad write recovers to the last valid snapshot with
/// no user-visible surface, UX §9).
///
/// **On-disk format (05 §5.2).** The store directory holds exactly
/// `state.json` / `state.prev.json` / `state.prev2.json` (names single-sourced
/// in `StoreRules`); each file is one `SnapshotEnvelope`:
/// `{schemaVersion, savedAt (UTC), checksum, payload}`.
///
/// **Checksum recipe (Requirement 1 — the authoritative statement).**
/// `checksum` = the lowercase-hex SHA-256 digest (MomoCore's repo-owned
/// FIPS 180-4 implementation — D-R4 bans CryptoKit) over EXACTLY the bytes
/// `JSONEncoder` (`.sortedKeys` REQUIRED — JSON key order is otherwise
/// unspecified, which would make the recipe unverifiable run-to-run) produces
/// for the payload's `EngineState`. Both the standalone payload encoding and
/// the envelope encoding use `.sortedKeys`, so the hashed bytes appear
/// verbatim inside the file. Date encoding strategy: Foundation's DEFAULT
/// (seconds since the reference date, a JSON number) on both the encoder and
/// the decoder — recorded here as the recipe's one description; nothing
/// customizes it. The load path verifies by re-deriving exactly this recipe
/// from the decoded payload and comparing to the recorded checksum.
///
/// **Documented limit — the recipe is toolchain-coupled (TASK-022, the
/// TASK-021 review's OBS-3).** The canonical bytes above are the Swift
/// toolchain's Codable output shape (for example, this toolchain encodes a
/// simple enum case as a keyed object: `{"settle":{}}`). The checksum recipe
/// is therefore coupled to that toolchain-canonical byte shape: a future
/// toolchain whose Codable emits different canonical bytes fails EVERY
/// generation's checksum at once, and every store falls through to the
/// injected fresh default. That outcome is self-consistent (write and read
/// share the encoder, so a store never rejects its own writes) and
/// contract-compliant (§5.3's invisible-recovery stance), but it is a real
/// limit — such a toolchain transition forfeits persisted state rather than
/// serving it. The `SnapshotStoreGoldenBytesTests` pin (recorded
/// out-of-process bytes) makes this coupling explicit and testable: any
/// canonical-byte drift fails the pin, forcing a deliberate fixture re-record.
///
/// **Write sequence and its crash windows (Requirement 2).** Per save, in
/// this order — the order is forced: demoting `prev` down BEFORE renaming
/// `current` away is what keeps generation N−1 from being clobbered, and
/// moving `current` to `prev` BEFORE writing the new current is what keeps
/// generation N recoverable:
///
///     1. prev2 ← (remove) prev → prev2     atomic rename; N−2 is retired
///     2. prev  ← current → prev            atomic rename; destination free —
///                                          step 1 moved prev away
///     3. current ← write temp; temp → current
///                                          atomic rename; destination free —
///                                          step 2 moved current away
///
/// Every step is a same-directory rename (POSIX atomic; the temp lives in the
/// store directory so the rename is same-volume). A file therefore only ever
/// appears complete under its final name — nothing can tear — and at every
/// interruption point the chain is one of:
///
///     interruption after …   state.json  state.prev  state.prev2  load serves
///     ───────────────────    ──────────  ───────────  ───────────  ───────────
///     (nothing done)         N           N−1          N−2          N
///     step 1 remove          N           N−1          —            N
///     step 1 rename          N           —            N−1          N
///     step 2 rename          —           N            N−1          N
///     step 3 temp write      —           N            N−1          N (+orphan temp)
///     step 3 rename          N+1         N            N−1          N+1
///
/// — the new state, the previous state, or an older-but-valid state; never an
/// error, never a mix (each slot moves at most one slot down per save, so
/// cross-generation mixing cannot arise). Honest limits: the table covers
/// process death at any point; under POWER loss a completed rename either
/// replays (file system journaling) or does not — every outcome is still one
/// of the table's rows, because content is never written in place under a
/// live name. Total loss of all three generations regenerates the INJECTED
/// fresh default, silently — §5.3's documented limit.
///
/// **Serialization (Requirement 4).** `save` is actor-isolated: the actor
/// total-orders saves, so concurrent saves converge to a consistent chain
/// whose newest completed save is current. `load` is deliberately
/// `nonisolated`: reads need no serialization — every rename above is atomic,
/// so a read racing a save observes one complete generation — and keeping the
/// read path outside the actor is what lets the stress test exercise the
/// atomicity guarantee for real instead of masking it behind the actor's
/// queue (a launch read must hold it with no store cooperation anyway).
///
/// **Totality (Requirement 3).** Neither public API throws. `load` falls
/// through current → `.prev` → `.prev2` → the injected fresh default on ANY
/// failure (missing file, garbage/truncated/empty bytes, decode failure,
/// checksum mismatch, a `schemaVersion` above the current one, a below-current
/// version whose migration walk is missing a hop) and returns a state, never
/// an error. `save` is internally total: an encoding or I/O failure leaves
/// the existing chain untouched (it trips `assertionFailure` in DEBUG — the
/// `MomoCopy` discipline — and stays silent in release, where the stale-but-
/// valid chain remains the recovery target).
///
/// **Retention on the write path (05 §5.4, TASK-022).** Every save prunes the
/// state through `LedgerRetention.pruned` BEFORE encoding, so every on-disk
/// payload satisfies §5.4's caps (the 7-newest-day ledger, the
/// ≤ `processedIntentsCapacity` intent belt) — the engine stays append-only
/// (REVIEW-TASK-015 routing) and demoted generations are untouched bytes that
/// were pruned when they were written. Applying the prune on EVERY save (the
/// doc says "pruned at each rollover") is a deterministic SUPERSET of §5.4's
/// intent, not a deviation: under ADR-002 write-through, a rollover that
/// changed state is immediately followed by a save, and pruning at every save
/// yields exactly the payloads a rollover-time discipline would have written
/// at those points — plus the same guarantee at every other save, where the
/// rollover rule said nothing. Same deterministic outputs wherever the caps
/// can actually bind; strictly stronger enforcement everywhere else.
///
/// **Migration on the read path (05 §5.5, TASK-022).** The store carries an
/// INJECTED `MigrationChain` (production ships `MigrationChain.empty` —
/// additive evolution is the norm and schema 1 is correct as shipped; no
/// version bump). The read path's amended gate order:
///
///     1. bytes exist → envelope (incl. payload) decodes
///     2. version RANGE check — above `currentSchemaVersion` is unreadable
///        (the chain's above-head rule) regardless of its bytes
///     3. checksum re-derived over the on-disk payload (the recipe above)
///     4. migration walk v → v+1 → … → current (pure, in-memory); any
///        missing hop ⇒ generation unreadable
///     5. serve
///
/// The checksum gate precedes the walk BY DESIGN: it verifies what is on
/// disk, and a below-current generation that fails it falls through — it
/// never migrates (pinned by name). Migration is pure in-memory afterward:
/// loading a migrated generation writes nothing and prunes nothing. A state
/// that entered memory through migration is simply the state there is; the
/// next save persists it at `currentSchemaVersion` with a fresh checksum.
///
/// The persisted payload graph's `Codable` support lives in MomoCore as
/// additive conformances (enumerated in the TASK-021 Implementation Notes).
public actor SnapshotStore {

    /// The envelope written to and read from every generation file
    /// (05 §5.2: `{schemaVersion, savedAt (UTC), checksum, payload}`).
    /// Internal on purpose: the public surface is `save`/`load`; the envelope
    /// is the on-disk format, reached in tests via `@testable`.
    struct SnapshotEnvelope: Codable {

        /// The schema version this envelope was written under
        /// (`StoreRules.currentSchemaVersion` at write time).
        let schemaVersion: Int

        /// When the snapshot was taken (UTC, INV-9) — read from the INJECTED
        /// `EngineClock`, never from ambient time (Requirement 6).
        let savedAt: Instant

        /// The checksum-recipe digest of the payload's `.sortedKeys` JSON
        /// bytes (see the type header's recipe statement).
        let checksum: String

        /// The full persisted domain state (05 §4.1) — the intent ledger
        /// (`processedIntents`) travels inside it (§5.3).
        let payload: EngineState
    }

    /// The injected store directory (05 §5.2's `Application Support/Momo/`
    /// comes from `StoreRules.defaultDirectory()` when the app layer wires
    /// it — never hardcoded elsewhere).
    private let directory: URL

    /// The only time source for `savedAt` (Requirement 6; 05 §4.10).
    private let clock: any EngineClock

    /// The injected schema-migration chain the read path walks for
    /// below-current generations (05 §5.5; see the header's gate order).
    /// Production ships `MigrationChain.empty`.
    private let chain: MigrationChain

    /// - Parameters:
    ///   - directory: the store directory; created if missing (the save path
    ///     needs it, and `load` over a missing directory is a valid fresh
    ///     start that must not throw).
    ///   - clock: the injected time source for `savedAt`. Defaults to
    ///     MomoCore's `SystemEngineClock` so EPIC-007's wiring is one call;
    ///     tests inject `ManualEngineClock`. The ambient read stays inside
    ///     MomoCore's one sanctioned site — no `Date` literal exists here.
    ///   - chain: the injected migration chain (05 §5.5). Defaults to
    ///     `MigrationChain.empty` — the production shape (additive evolution
    ///     is the norm; schema 1 ships correct). A non-empty chain is
    ///     registered only by a §5.5 schema-version bump.
    public init(
        directory: URL,
        clock: any EngineClock = SystemEngineClock(),
        chain: MigrationChain = .empty
    ) {
        self.directory = directory
        self.clock = clock
        self.chain = chain
    }

    // MARK: Write path (05 §5.2)

    /// Persists `state` as the new current generation, demoting the previous
    /// generations down the chain per the header's sequence. The §5.4 prune
    /// runs first (header: retention on the write path), so the encoded
    /// payload always satisfies the retention caps. Total: never throws; on
    /// any internal failure the existing chain is left untouched.
    ///
    /// Caller note (ADR-002 write-through): call once per engine event that
    /// changed state — loss is then bounded by the in-flight event (FR-13
    /// AC-1). EPIC-007 owns that wiring.
    public func save(_ state: EngineState) {
        let retained = LedgerRetention.pruned(state)
        guard let envelopeData = Self.envelopeData(
            schemaVersion: StoreRules.currentSchemaVersion,
            savedAt: clock.now(),
            payload: retained
        ) else {
            // An `EngineState` that cannot encode would be a domain-model
            // regression (every persisted field is JSON-native). DEBUG-loud,
            // and the chain keeps its last valid generations.
            Self.debugLoudFailure("SnapshotStore: payload/envelope encoding failed — save skipped, chain untouched")
            return
        }
        let fileManager = FileManager.default
        do {
            try Self.createDirectoryIfMissing(directory, fileManager: fileManager)
            let previous = directory.appendingPathComponent(StoreRules.previousStateFileName)
            let oldest = directory.appendingPathComponent(StoreRules.oldestStateFileName)
            let current = directory.appendingPathComponent(StoreRules.currentStateFileName)
            let temporary = directory.appendingPathComponent(StoreRules.temporaryStateFileName)
            // Step 1 — prev → prev2 (retires N−2; removal of the old prev2 is
            // the one bounded window in the header's table).
            if fileManager.fileExists(atPath: previous.path(percentEncoded: false)) {
                try? fileManager.removeItem(at: oldest)
                try fileManager.moveItem(at: previous, to: oldest)
            }
            // Step 2 — current → prev (destination is free after step 1).
            if fileManager.fileExists(atPath: current.path(percentEncoded: false)) {
                try fileManager.moveItem(at: current, to: previous)
            }
            // Step 3 — write temp, atomic-rename onto state.json. The temp is
            // written plainly (nobody reads it; a torn temp is inert) and the
            // rename is the atomicity boundary.
            try envelopeData.write(to: temporary)
            try fileManager.moveItem(at: temporary, to: current)
        } catch {
            // Leave the chain as it stands — every prefix of the sequence is
            // a loadable state (header table). Clean up our own temp so an
            // interrupted step 3 cannot leave junk behind the next save.
            try? fileManager.removeItem(
                at: directory.appendingPathComponent(StoreRules.temporaryStateFileName)
            )
            Self.debugLoudFailure("SnapshotStore: save failed (\(error)) — chain kept at its last consistent state")
        }
    }

    // MARK: Read path (05 §5.3) — nonisolated: see the header's serialization
    // statement. Loads racing saves are safe because every generation file is
    // published by atomic rename only.

    /// Returns the newest loadable generation, falling through current →
    /// `.prev` → `.prev2` → `fallback` (the INJECTED fresh default) on any
    /// failure. Never throws, never surfaces an error (UX §9: corruption
    /// recovery is indistinguishable from a normal open).
    ///
    /// - Parameter fallback: the caller-injected fresh default, returned only
    ///   when no generation is loadable (MomoCore has no initial-state
    ///   factory — the default is nobody's to invent here).
    public nonisolated func load(fallback: EngineState) -> EngineState {
        for fileName in StoreRules.generationFileNamesInReadOrder {
            if let state = Self.loadGeneration(directory: directory, fileName: fileName, chain: chain) {
                return state
            }
        }
        return fallback
    }

    /// Reads one generation file through the full gate (the header's amended
    /// order): bytes exist → envelope decodes → version RANGE check →
    /// checksum over the on-disk payload → migration walk → serve. Any
    /// failure returns nil (the caller falls through) — this is the ONLY
    /// internal error surface, and it is total by construction.
    private static func loadGeneration(
        directory: URL,
        fileName: String,
        chain: MigrationChain
    ) -> EngineState? {
        let url = directory.appendingPathComponent(fileName)
        guard let data = try? Data(contentsOf: url), !data.isEmpty else { return nil }
        guard let envelope = try? JSONDecoder().decode(SnapshotEnvelope.self, from: data) else {
            return nil
        }
        // Gate 2 — the version RANGE check precedes the checksum: a version
        // above `currentSchemaVersion` is unreadable by definition (§5.5's
        // above-head rule) regardless of its bytes. Below-current generations
        // pass this gate and are decided by the walk AFTER the checksum.
        guard envelope.schemaVersion <= StoreRules.currentSchemaVersion else { return nil }
        // Gate 3 — the checksum verifies what is ON DISK. It precedes the
        // migration walk deliberately: a generation that fails its integrity
        // gate falls through and is NEVER migrated (pinned by name). The
        // payload decoded above is only now trusted.
        guard let payloadJSON = payloadJSONData(for: envelope.payload),
              checksumHex(of: payloadJSON) == envelope.checksum else {
            return nil
        }
        // Gates 4–5 — at the current version the payload IS the state; below
        // it, the pure in-memory walk v → v+1 → … → current applies the
        // injected chain, and any missing hop makes the generation unreadable
        // (§5.5: a half-migrated state is never served).
        guard envelope.schemaVersion == StoreRules.currentSchemaVersion else {
            return chain.migrated(
                envelope.payload,
                from: envelope.schemaVersion,
                to: StoreRules.currentSchemaVersion
            )
        }
        return envelope.payload
    }

    // MARK: The checksum recipe (single home — write and read paths both
    // derive their bytes/digest from these two functions only)

    /// The payload's canonical JSON: `JSONEncoder` with `.sortedKeys` output
    /// formatting REQUIRED (Requirement 1 — key order is otherwise
    /// unspecified, which would make checksums unverifiable run-to-run).
    /// Date strategy: Foundation's default (see the type header).
    static func payloadJSONData(for state: EngineState) -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(state)
    }

    /// The recipe's digest: lowercase hex of MomoCore's repo-owned FIPS 180-4
    /// SHA-256 over exactly the payload JSON bytes (D-R4: no CryptoKit).
    static func checksumHex(of payloadJSON: Data) -> String {
        SHA256.digest([UInt8](payloadJSON)).map { String(format: "%02x", $0) }.joined()
    }

    /// Builds the complete envelope bytes for a save: payload → recipe
    /// checksum → envelope (itself `.sortedKeys`, so the hashed payload bytes
    /// appear verbatim inside the file).
    static func envelopeData(schemaVersion: Int, savedAt: Instant, payload: EngineState) -> Data? {
        guard let payloadJSON = payloadJSONData(for: payload) else { return nil }
        let envelope = SnapshotEnvelope(
            schemaVersion: schemaVersion,
            savedAt: savedAt,
            checksum: checksumHex(of: payloadJSON),
            payload: payload
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(envelope)
    }

    private static func createDirectoryIfMissing(_ directory: URL, fileManager: FileManager) throws {
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: directory.path(percentEncoded: false), isDirectory: &isDirectory) || !isDirectory.boolValue {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }

    /// The `MomoCopy` DEBUG-loud discipline: invariant regressions trip the
    /// debugger in debug builds and stay silent in release, where the
    /// documented fallback (chain untouched / load falls through) governs.
    private static func debugLoudFailure(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
