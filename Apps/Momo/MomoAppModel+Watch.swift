import Foundation
import MomoKit
import MomoCore
import os

// MARK: - MomoAppModel + Watch — the WC session's executor wiring
// (TASK-040 R1/R2; 05-technical-architecture §6.1–6.4; ADR-003)

/// The sync-state file's serialized writer (O1's one-writer rule,
/// REVIEW-TASK-023): EVERY sync-state write funnels through this actor's
/// mailbox — pushes (spent snapshot seqs) and receive applies (watermark
/// records) alike — so the file has exactly one writer path even though
/// `SyncStateStore` itself is reconstructed per call over the executor's
/// directory. Stateless by design: the latest value is always carried in
/// the message, and submissions from the main actor arrive in FIFO order
/// (no suspension between the value snapshot and the submit). Even a
/// hypothetical reorder degrades safely: a stale persisted watermark only
/// PRUNES less on the Watch (conservative), and the engine's persisted
/// `processedIntents` belt still guards replays.
actor MomoWatchSyncPersister {

    private static let logger = Logger(subsystem: "com.momo.app", category: "watch-sync-persist")

    func persist(directory: URL, state: SyncState) {
        SyncStateStore(directory: directory).save(state)
        Self.logger.debug("sync state persisted")
    }
}

/// The Watch session's executor half (TASK-040). Same-target extension per
/// the `+Settings`/`+Canvas`/`+Celebrations` precedent — the main file
/// stands at its line budget, so everything with room to breathe lives
/// here, riding the executor's `internal` seams (`storeDirectory`,
/// `state`, `clock`, `calendar`, `apply(trigger:)`, `debugLoud`, the
/// `watchSyncState`/`watchSyncEpoch`/`watchTransport`/
/// `watchResetMarkerEraseCount` stored properties, and the
/// `.pushWatchSnapshot` arm). The transport itself is
/// `MomoWatchTransport.swift` (ADR-013: app-target code, duplicated by the
/// Watch twin in TASK-041/042); every DECISION is MomoKit's.
extension MomoAppModel {

    private static let logger = Logger(subsystem: "com.momo.app", category: "app-model-watch")

    private static let syncPersister = MomoWatchSyncPersister()

    // MARK: The launch read's marker half (R3 — review F-1)

    /// The launch read's reset-marker half (TASK-040 R3; review F-1): the
    /// erase count loads from the SAME §6.6 root location the erase writes —
    /// `StoreRules.watchResetMarkerDirectory()`, the Application Support
    /// root OUTSIDE the store tree — so the marker survives the erase's
    /// directory deletion and the relaunch. The load joins the init's ONE
    /// sanctioned synchronous launch read (OBS-1; D-6). Static so the init
    /// can call it before full initialization (the D-8 extension-file
    /// pattern). The directory lookup's failure path mirrors the erase
    /// site's discipline (`+Settings.eraseAllData()`): DEBUG-loud + a
    /// throwaway fallback directory, where `load()` naturally returns nil;
    /// a missing/garbled marker is likewise nil → 0 — no erase pending
    /// (degraded semantics unchanged).
    static func loadResetMarkerEraseCount() -> Int {
        let markerDirectory: URL
        do {
            markerDirectory = try StoreRules.watchResetMarkerDirectory()
        } catch {
            Self.debugLoud("MomoAppModel: marker directory lookup failed (\(error))")
            markerDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("Momo-marker-fallback", isDirectory: true)
        }
        return WatchResetMarkerStore(directory: markerDirectory)
            .load()?.eraseCount ?? 0
    }

    // MARK: Session binding (the launch leg)

    /// Binds the receive sink and activates the transport — called ONCE,
    /// at the END of init (the sink must exist before activation:
    /// WCSession.h:42-45 — "A delegate must exist before the session will
    /// allow sends"; the executor binds the sink FIRST, activates SECOND).
    /// Correctness never depends on the activation state: context is
    /// latest-wins, so an unreachable counterpart loses nothing and the
    /// next context supersedes (ADR-003).
    func bindWatchTransport() {
        guard let watchTransport else { return }
        watchTransport.onUserInfoData = { [weak self] data in
            // WCSession's delegate queue is a non-main serial queue (the
            // R4 record) — re-isolate to the executor's actor.
            Task { @MainActor [weak self] in
                await self?.receiveWatchEvent(data)
            }
        }
        watchTransport.activate()
    }

    // MARK: The push arm (R1 — the reserved seam's executor half)

    /// The `.pushWatchSnapshot` step's arm: builds the latest-wins snapshot
    /// from the CURRENT (just-persisted) engine state and hands the
    /// canonical bytes to the transport. Synchronous, main-actor, no file
    /// I/O beyond the serialized sync persist — the plan core appended this
    /// step IFF-changed (unchanged since TASK-031); this is the executor
    /// half that EPIC-008 reserved.
    ///
    /// **Field threading (the R4-recorded coalescing is why every field
    /// rides every push):** the watermark pair reads
    /// `watchSyncState`/`watchSyncEpoch` — the epoch of the most recently
    /// APPLIED watch intent, or `StoreRules.zeroWatchSyncEpoch` before any
    /// (inert against every real epoch, §6.4 step 4). The marker count
    /// rides while non-zero — from an erase until Watch-side consumption —
    /// because the counterpart observes only the NEWEST context ("This
    /// method replaces the previous dictionary that was set"), never a
    /// guaranteed intermediate one.
    func pushWatchSnapshot() {
        guard let watchTransport else { return }
        let now = clock.now()
        let (snapshot, nextSync) = makeWatchSnapshot(
            state: state,
            display: makeDisplayState(state, at: now, calendar: calendar),
            questInputs: todaysQuestInputs(now: now),
            watermarkEpoch: watchSyncEpoch ?? StoreRules.zeroWatchSyncEpoch,
            sync: watchSyncState,
            resetMarkerEraseCount: watchResetMarkerEraseCount > 0 ? watchResetMarkerEraseCount : nil
        )
        watchSyncState = nextSync
        guard let data = snapshot.encoded() else {
            Self.debugLoud("pushWatchSnapshot: snapshot encoding failed — push skipped")
            return
        }
        watchTransport.send(contextData: data)
        // The spent seq's durability: without this, a relaunch would rewind
        // `nextSnapshotSeq` to the last receive-persisted state and reuse
        // seqs across restarts. Same single-writer path as the receive
        // persist (the actor serializes; O1).
        persistWatchSyncState()
    }

    /// Today's quest inputs — the SAME day-record lookup the cascade reads
    /// (`HomeReadModel`'s `state.days.first(where:)`), never a Watch-side
    /// re-derivation of quest logic (the Watch runs no engine; EPIC-008
    /// AC-5). An empty day record (pre-onboarding, pre-first-open) yields [].
    private func todaysQuestInputs(now: Instant) -> [QuestProgress] {
        let todayKey = DayKey.make(from: now, calendar: calendar)
        return state.days.first(where: { $0.dayKey == todayKey })?.questSet ?? []
    }

    // MARK: The receive path (R2 — the transferUserInfo leg)

    /// One delivered userInfo frame: decode → gate → record → apply. The
    /// decode half's failures are the documented SKIP (garbled or
    /// future-version frames — `IntentEvent.decoded(from:)` returns nil on
    /// both; a future Watch version must never wedge the iPhone, so this
    /// is silent-by-design, logged only). The gate is the accessor-driven
    /// plan core — NEVER a raw `WatchSyncGate` with call-site watermarks
    /// (O5; the structural guard pins the absence). The apply routes
    /// through the SAME facade path `interact(_:)` uses: the engine folds
    /// to the intent's own timestamp, expired-dayKey intents apply
    /// current-state effects with day attribution dropped — all engine
    /// semantics, none re-implemented here.
    func receiveWatchEvent(_ data: Data) async {
        guard let event = IntentEvent.decoded(from: data) else {
            Self.logger.notice("watch event undecodable at this schema — skipped")
            return
        }
        guard case .apply(let postSync) = WatchReceivePlan.decide(
            event: event,
            sync: watchSyncState,
            seenIntentIDs: Set(state.processedIntents)
        ) else {
            return // duplicate / replay / redelivery / stale-seq: a FULL no-op (INV-10)
        }
        // Record BEFORE the apply so the plan's own push step reads the
        // UPDATED watermark pair — the F-1 blind-spot leg (a wiring order a
        // decision test cannot see; pinned behaviorally in the
        // WatchReceivePlan suite and structurally by the executor guard).
        watchSyncState = postSync
        watchSyncEpoch = event.watchSessionEpoch
        await apply(trigger: .interaction(event.intent))
        // The receive path's OWN persist — deliberately OUTSIDE the plan's
        // IFF-changed step list: an apply whose engine outcome is unchanged
        // (the disclosed edge — e.g. a tuck-in onto an already-asleep pet,
        // if the engine calls it unchanged) must STILL land its watermark,
        // so the next changed outcome's push carries it.
        persistWatchSyncState()
    }

    /// The sync-state persist hand-off (the file's one writer, O1). The
    /// value is snapshotted on the main actor; the actor serializes the
    /// rest (see `MomoWatchSyncPersister`).
    private func persistWatchSyncState() {
        let directory = storeDirectory
        let sync = watchSyncState
        Task { await Self.syncPersister.persist(directory: directory, state: sync) }
    }
}
