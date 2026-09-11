import SwiftUI
import MomoKit
import MomoCore
import MomoCharacter
import os

// MARK: - MomoWatchAppModel — the Watch's W1 executor (TASK-041 R4/R5;
// 05-technical-architecture §5.6, §6.2–6.3, §6.6; OBS-1; TR9; ADR-014)

/// The Watch snapshot store's serialized writer (O1's one-writer rule, the
/// `MomoWatchSyncPersister` pattern): EVERY snapshot-store mutation funnels
/// through this actor's mailbox — receive persists (§5.6's every-receive
/// leg), background-transition persists (TR9), and §6.6 consumption wipes —
/// so the file pair has exactly one writer path even though
/// `WatchSnapshotStore` is reconstructed per call over the executor's
/// directory. Stateless by design: the latest value rides the message, and
/// submissions from the main actor arrive in FIFO order (no suspension
/// between the value snapshot and the submit). The consumption method
/// deliberately fuses wipe + record into ONE mailbox step — the F-3 order
/// (wipe BEFORE record) holds inside a single serialized step, so a
/// marker-bearing redelivery racing a consume can never interleave a save
/// between the wipe and the record.
actor MomoWatchSnapshotPersister {

    private static let logger = Logger(subsystem: "com.momo.app", category: "watch-snapshot-persist")

    /// Persists the snapshot (the §5.6 write: every receive, every
    /// background transition). The store save hops to the store actor; the
    /// store's own mailbox executes saves in submission order, so
    /// latest-wins holds even where this actor's jobs interleave at the
    /// suspension point.
    func persist(directory: URL, snapshot: WatchSnapshot) async {
        await WatchSnapshotStore(directory: directory).save(snapshot)
        Self.logger.debug("snapshot persisted")
    }

    /// The §6.6 consumption's store half: wipe the snapshot pair FIRST,
    /// record the consumed count SECOND (the F-3 order — a crash between
    /// them replays the wipe idempotently; the inverse order would let
    /// stale pet data outlive its erase forever behind a consumed count).
    /// The record runs synchronously after the wipe resumes, on this actor:
    /// a later submission can only carry POST-consumption state (the main
    /// actor's program order — every writer reads the model it just
    /// decided), so no pre-erase payload can land between the two legs.
    func consumeWipe(directory: URL, eraseCount: Int) async {
        await WatchSnapshotStore(directory: directory).wipe()
        WatchConsumedMarkerStore(directory: directory).save(WatchResetMarker(eraseCount: eraseCount))
        Self.logger.debug("consumption wipe recorded (erase \(eraseCount))")
    }
}

/// The Watch app model: W1's ONLY state source (D-R5 — views never touch
/// engine surfaces; there IS no engine here). The Watch runs NO engine
/// (EPIC-008 AC-5): it receives the iPhone's latest-wins `WatchSnapshot`
/// bytes, decides the §6.6 marker consumption through MomoKit's pure
/// function, renders what it is given, and persists on every receive and
/// every background transition — it derives nothing itself.
///
/// **Threading shape (R4).** WCSession's delegate calls arrive on a non-main
/// serial queue; the transport's sink re-isolates every frame onto the main
/// actor here (`bindWatchTransport`'s Task hop). The main actor touches NO
/// file I/O beyond the launch read — the ONE sanctioned synchronous
/// main-thread read (OBS-1, KB-scale: the snapshot + the consumed marker);
/// every save and wipe rides `MomoWatchSnapshotPersister` off the main
/// actor.
///
/// **Degraded states are quiet (UX §9).** A nil snapshot (fresh install,
/// post-wipe, unrecoverable store) renders the settling-in line; an
/// undecodable frame is skipped and logged; a nil `character` on a decoded
/// snapshot degrades to the words-only render through
/// `makeWatchCharacterDisplay`'s pinned nil path. No error surface exists.
@MainActor
@Observable
final class MomoWatchAppModel {

    private static let logger = Logger(subsystem: "com.momo.app", category: "watch-app-model")

    /// The last-synced snapshot, or nil for the settling-in shape. Replaced
    /// wholesale on every accepted receive (latest-wins, §6.3) and cleared
    /// by a marker consumption — never mutated field-by-field.
    private(set) var snapshot: WatchSnapshot?

    /// The last `resetMarkerEraseCount` this Watch has consumed (§6.6).
    /// Launched from the consumed-marker store; advanced on every
    /// consumption.
    private(set) var consumedEraseCount: Int = 0

    /// The injected store directory (`StoreRules.defaultDirectory()` in
    /// production; the UI-test seam overrides).
    private let storeDirectory: URL

    /// The receive-only transport (the ADR-013 twin).
    private let transport: any MomoWatchTransporting

    /// The snapshot files' ONE writer (O1).
    private let persister = MomoWatchSnapshotPersister()

    /// The presentation-owned character clock — ONE clock for the session,
    /// handed to the rig view; the view pauses/resumes it with the scene
    /// (the TASK-032 R12 pattern). The glyph tier never binds it.
    let canvasClock = CharacterClock(timeSource: SystemEngineClock())

    /// The DEBUG AOD-preview enabler's resolution (R7): true forces the
    /// luminance-reduced glyph branch for the whole launch (the O4 evidence
    /// vehicle). Release builds are always false. Resolved once, at init.
    let aodPreview: Bool

    /// - Parameters:
    ///   - storeDirectory: nil resolves `StoreRules.defaultDirectory()` (the
    ///     ONE sanctioned ambient path — watchOS resolves it inside this
    ///     app's own container); a failure falls back to a throwaway temp
    ///     directory DEBUG-loud, where the store's `load` reads nil (the
    ///     settling-in shape — degraded, never wedged). The UI-test seam
    ///     injects a throwaway directory.
    ///   - transport: the live WC twin in production; tests inject a fake.
    init(storeDirectory: URL?, transport: any MomoWatchTransporting) {
        let resolved: URL
        if let storeDirectory {
            resolved = storeDirectory
        } else {
            do {
                resolved = try StoreRules.defaultDirectory()
            } catch {
                Self.debugLoud("MomoWatchAppModel: store directory lookup failed (\(error))")
                resolved = FileManager.default.temporaryDirectory
                    .appendingPathComponent("MomoWatch-store-fallback", isDirectory: true)
            }
        }
        self.storeDirectory = resolved
        self.transport = transport
        self.aodPreview = Self.aodPreviewEnabled()

        // The DEBUG fixture seam seeds through the REAL store BEFORE the
        // launch read, so the restore test exercises the genuine read path
        // (disclosed in the task notes; release builds never seed).
        Self.seedFixtureIfRequested(directory: resolved)

        // The launch read (OBS-1's one sanctioned synchronous main-thread
        // read): the snapshot pair plus the consumed marker, both KB-scale.
        snapshot = WatchSnapshotStore(directory: resolved).load()
        consumedEraseCount = WatchConsumedMarkerStore(directory: resolved)
            .load()?.eraseCount ?? 0

        // The sink binds FIRST, activation SECOND (the WCSession.h:42-45
        // discipline). The WC queue's frames hop to the main actor; the
        // actor total-orders them, and each receive's persist submission
        // preserves that order through the persister's mailbox (FIFO).
        transport.onContextData = { [weak self] data in
            Task { @MainActor [weak self] in
                await self?.receiveContext(data)
            }
        }
        transport.activate()
    }

    // MARK: The assembled render inputs (ADR-014; 04 §9.2)

    /// The assembled character read-model for the rig — the snapshot's
    /// `display` + `character` through MomoKit's ONE assembly. Nil snapshot
    /// OR nil character (cross-version skew) yields nil: the view renders
    /// words-only / the settling-in line — never a crash (UX §9). The Watch
    /// derives NOTHING: no band, stage, or moment derivation happens here.
    var characterDisplay: CharacterDisplayState? {
        guard let snapshot else { return nil }
        return makeWatchCharacterDisplay(display: snapshot.display, character: snapshot.character)
    }

    // MARK: The receive path (R4/R5)

    /// One delivered context frame: decode-or-skip → §6.6 consumption
    /// decision → latest-wins render + persist (05 §5.6). The decode half's
    /// failures are the documented SKIP (garbled or future-version frames —
    /// `WatchSnapshot.decoded(from:)` returns nil on both; a future iPhone
    /// version must never wedge the Watch, so this is silent-by-design,
    /// logged only).
    func receiveContext(_ data: Data) async {
        guard let snapshot = WatchSnapshot.decoded(from: data) else {
            Self.logger.notice("watch snapshot undecodable at this schema — skipped")
            return
        }
        let decision = WatchResetConsumption.decide(
            incomingEraseCount: snapshot.resetMarkerEraseCount,
            consumedEraseCount: consumedEraseCount
        )
        if case .consume = decision {
            // A NEW erase is pending: the just-received payload is PRE-erase
            // state — discarded, never rendered. Wipe → record → settle;
            // the journal-wipe leg is TASK-042's (the journal does not
            // exist yet — nothing to wipe there, and F-3's disagreement
            // reasoning is documented at the decision site). The count is
            // non-nil by `decide`'s contract (.consume requires an incoming
            // count that exceeds the consumed one); the guard is the
            // compiler-visible restatement, never a silent fallback.
            guard let eraseCount = snapshot.resetMarkerEraseCount else {
                Self.debugLoud("receiveContext: .consume decided with a nil marker count — skipped")
                return
            }
            await persister.consumeWipe(directory: storeDirectory, eraseCount: eraseCount)
            consumedEraseCount = eraseCount
            self.snapshot = nil
            return
        }
        // The steady shape: latest-wins render first (§6.3's instant local
        // render), persist second — the submission order through the
        // persister's mailbox matches the receive order (O1).
        self.snapshot = snapshot
        await persister.persist(directory: storeDirectory, snapshot: snapshot)
    }

    // MARK: The lifecycle leg (TR9)

    /// Persist on every background transition so raise-to-wake never starts
    /// cold or stale (TR9/NFR-9; §6.5). The current snapshot rides the
    /// serialized writer off the main actor; a nil snapshot has nothing to
    /// persist (the store already matches: fresh, wiped, or unrecoverable —
    /// and re-wiping on nil would be a state-changing write the transition
    /// leg does not own). Foreground transitions are renders-from-memory,
    /// not writes.
    func scenePhaseChanged(to phase: ScenePhase) {
        guard phase == .background, let snapshot else { return }
        Task { await persister.persist(directory: storeDirectory, snapshot: snapshot) }
    }

    // MARK: The DEBUG enablers (each disclosed in the task notes)

    /// The UI-test store seam (`-momo-store-directory <path>`, the MomoApp
    /// R13 pattern's Watch twin): an ABSOLUTE path is honored as-is; a
    /// RELATIVE value resolves against the APP's own temporary directory
    /// (the runner and the app-under-test live in different sandboxes).
    /// Mirrors the iPhone seam — including its ungated precedent (the
    /// argument only exists when a test passes it; production launches
    /// never do).
    static func testStoreDirectory() -> URL? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-momo-store-directory"),
              index + 1 < arguments.count
        else { return nil }
        let raw = arguments[index + 1]
        if raw.hasPrefix("/") {
            return URL(fileURLWithPath: raw, isDirectory: true)
        }
        return FileManager.default.temporaryDirectory
            .appendingPathComponent(raw, isDirectory: true)
    }

    /// The DEBUG AOD-preview enabler (`-momo-aod-preview`, R7's sanctioned
    /// evidence vehicle): forces the luminance-reduced glyph branch for the
    /// launch. DEBUG-only — release builds always return false.
    private static func aodPreviewEnabled() -> Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-momo-aod-preview")
        #else
        return false
        #endif
    }

    /// The UI-test fixture seam (`-momo-watch-fixture <kind>`, the MomoApp
    /// R10 pattern's Watch twin): seeds a FIXTURE snapshot through the REAL
    /// store before the launch read, so the restore test drives the
    /// genuine persistence + read path with deterministic bytes. DEBUG-only;
    /// production launches never seed.
    ///
    /// The seed MUST land before the synchronous launch read below it in
    /// `init` (the whole point — the read then restores what the real
    /// `save` wrote), but `WatchSnapshotStore.save` is actor-isolated and
    /// `init` is sync. The DEBUG-only bridge is a detached task plus a
    /// semaphore: it blocks this launch thread for the one KB write, the
    /// store actor is independent of the main actor (no deadlock), and the
    /// write path is the store's own `save` — not a seam-side re-encoding.
    /// Release builds never enter this function.
    private static func seedFixtureIfRequested(directory: URL) {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-momo-watch-fixture"),
            index + 1 < arguments.count
        else { return }
        switch arguments[index + 1] {
        case "w1":
            let snapshot = w1FixtureSnapshot()
            let store = WatchSnapshotStore(directory: directory)
            let seeded = DispatchSemaphore(value: 0)
            Task.detached(priority: .userInitiated) {
                await store.save(snapshot)
                seeded.signal()
            }
            seeded.wait()
        default:
            assertionFailure("MomoWatchAppModel: unknown -momo-watch-fixture kind '\(arguments[index + 1])'")
        }
        #endif
    }

    /// The `w1` fixture (DEBUG-only): a fully-populated snapshot — mood
    /// content, energy energetic, playing while recently fed, stage
    /// Getting Close, quest Q7 (the pat-completable wish) — whose character
    /// DTO carries all four fields so the rig renders a real pose.
    private static func w1FixtureSnapshot() -> WatchSnapshot {
        let stage = BondStage.gettingClose
        let display = DisplayState(
            petName: "Momo",
            moodWordKey: VocabularyKeys.moodWordKey(for: .content),
            energyPhraseKey: VocabularyKeys.energyPhraseKey(for: .energetic),
            bondStage: stage,
            bondDescriptorKey: VocabularyKeys.bondDescriptorKey(for: stage),
            questLine: .wish(.q7),
            wakefulness: .awake,
            greeting: nil
        )
        return WatchSnapshot(
            snapshotSeq: 1,
            display: display,
            questInputs: [],
            hapticsEnabled: true,
            lastAppliedIntentSeq: 0,
            lastAppliedEpoch: StoreRules.zeroWatchSyncEpoch,
            character: WatchCharacterDTO(
                moodBand: .content,
                energyBand: .energetic,
                activity: .playing,
                satietyHint: .recentlyFed
            )
        )
    }

    /// The `MomoCopy` DEBUG-loud discipline: invariant regressions trip the
    /// debugger in debug builds and stay silent in release, where the
    /// documented fallback governs.
    private static func debugLoud(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
