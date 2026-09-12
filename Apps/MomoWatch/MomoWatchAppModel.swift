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

    /// The §6.6 consumption's store half: wipe the snapshot pair FIRST, the
    /// journal SECOND (TASK-042's R2c leg — all wipes BEFORE the record),
    /// record the consumed count THIRD (the F-3 order — a crash between
    /// them replays the wipe idempotently; the inverse order would let
    /// stale pet data outlive its erase forever behind a consumed count).
    /// The record runs synchronously after the wipes resume, on this actor:
    /// a later submission can only carry POST-consumption state (the main
    /// actor's program order — every writer reads the model it just
    /// decided), so no pre-erase payload can land between the legs.
    func consumeWipe(directory: URL, eraseCount: Int) async {
        await WatchSnapshotStore(directory: directory).wipe()
        wipeJournal(directory: directory)
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
/// main-thread read (OBS-1, KB-scale: three store reads — the snapshot pair,
/// the consumed marker, and the session epoch); every save and wipe rides
/// `MomoWatchSnapshotPersister` off the main actor.
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

    /// The LIVE quest line (TASK-043 R1; 05 §4.8/§4.11): the shared cascade
    /// re-run over the carried `questInputs` under THIS Watch's local hour.
    /// STORED observable state — an `@Observable` computed property reading
    /// `wallClock.now()` would not be change-tracked, so the recompute legs
    /// (below) write here and receives re-render the body through it.
    ///
    /// Nil exactly when `snapshot` is nil; the view reads the frozen
    /// `display.questLine` only as the belt-and-braces fallback for the
    /// never-expected window between the two. Recompute legs (exactly four
    /// `recomputeQuestLine()` calls — the scan census): init (first render),
    /// receive (steady shape), receive (consume clears it with the
    /// snapshot), and scene activation (background→foreground). NO timers
    /// (§4.2): between legs a line can go stale at an hour boundary until
    /// the next render trigger — the accepted latency UX-9's
    /// no-freshness-indicator calm governs. Day semantics: the cascade runs
    /// over the CARRIED set only — the Watch never synthesizes a day's quest
    /// set; the set refreshes on the next snapshot (`WatchCascade`'s note).
    private(set) var liveQuestLine: QuestGeneration.QuestLine?

    /// The last `resetMarkerEraseCount` this Watch has consumed (§6.6).
    /// Launched from the consumed-marker store; advanced on every
    /// consumption.
    private(set) var consumedEraseCount: Int = 0

    /// The injected store directory (`StoreRules.defaultDirectory()` in
    /// production; the UI-test seam overrides). Internal — not `private` —
    /// because the pat seam's cross-file extension reads it (Swift's
    /// `private` is file-scoped; the `MomoAppModel+Canvas` pattern).
    let storeDirectory: URL

    /// The receive-only transport (the ADR-013 twin). Internal for the pat
    /// seam's cross-file extension (see `storeDirectory`).
    let transport: any MomoWatchTransporting

    /// The snapshot files' ONE writer (O1) — and, since TASK-042, the
    /// intent journal's (the journal legs live in the same-target
    /// `MomoWatchPersister+Journal.swift` extension). Internal for the pat
    /// seam's cross-file extension (see `storeDirectory`).
    let persister = MomoWatchSnapshotPersister()

    /// This Watch's session identity (R1; 05 §6.2): resolved from the
    /// persisted store at init; a miss MINTS one in memory (the leg's
    /// persistence + journal self-defense ride the init task below — a
    /// crash before the save lands simply regenerates on the next launch,
    /// whose generation leg wipes again). Every journaled intent is wrapped
    /// in this epoch; the iPhone's own epoch gate declines anything else.
    private(set) var watchSessionEpoch: UUID

    /// The intent journal's haptic seam (R6; ADR-015 D3): the live
    /// `WKInterfaceDevice` conformance in production; injectable for
    /// doubles/fakes. The `hapticsEnabled` gate lives at the call site (at
    /// pat time), never in the seam.
    let haptics: any MomoWatchHaptics

    /// The intent's timestamp clock (R3): INJECTED — the journaled pat's
    /// `timestamp` and `localDayKey` are derived from THIS clock and
    /// calendar, never ambient `Date()`/`.current` (the 23:30 offline
    /// midnight case is pinned against the injected pair in MomoKit).
    /// Internal for the pat seam's cross-file extension (see
    /// `storeDirectory`).
    let wallClock: any EngineClock

    /// The intent's day-attribution calendar (R3; D20/INV-9). Internal for
    /// the pat seam's cross-file extension (see `storeDirectory`).
    let calendar: Calendar

    /// The pat reaction's clip renderer (R5; ADR-015 D1) — a transient
    /// holder for the reaction slots the pat folds in (the ONLY public path
    /// to the frozen vocabulary's authored clip motion; the rationale is
    /// recorded on `reactionMotion()` in `MomoWatchPat.swift`). Re-seeded
    /// from the launch snapshot and from every accepted steady receive;
    /// nil until a renderable character exists (the words-only degraded
    /// state has no rig to animate). Whole property internal — setter
    /// included — because the pat seam's cross-file extension folds the
    /// reaction into it (see `storeDirectory`); only this file and the pat
    /// seam ever assign it.
    var reactionDirector: MomoDirectorState?

    /// F-1's once-per-snapshot memo (the nil-character DEBUG-loud fires on
    /// the FIRST body evaluation of a degraded snapshot — an unconditional
    /// log would trap on every render and crash-loop DEBUG builds).
    @ObservationIgnored private var f1LoggedSnapshotSeq: Int?

    /// The launch sweep's ARM (TASK-044 R1): true from the session's
    /// activation completion until the sweep's one execution. The drain
    /// itself runs AFTER a receive decision — never at activation, which
    /// can precede the pending context's delivery (the very frame that may
    /// carry a reset marker). An activation with no subsequent receive
    /// simply leaves the journal to the next launch's sweep: the events are
    /// durable, so this is liveness deferred, never correctness.
    @ObservationIgnored private var sweepArmed = false

    /// The consumed erase count AS OF the arming — the sweep's baseline for
    /// `WatchSweepPlan`'s count re-check (a consumption that advanced the
    /// count between arm and execution suppresses the drain: pre-wipe
    /// entries must never resurrect behind a decided erase).
    @ObservationIgnored private var consumedEraseCountAtArm = 0

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
    ///   - haptics: the live `WKInterfaceDevice` seam in production.
    ///   - wallClock/calendar: the intent's timestamp + day attribution
    ///     (injected per R3; production defaults are the system pair).
    init(
        storeDirectory: URL?,
        transport: any MomoWatchTransporting,
        haptics: any MomoWatchHaptics = LiveWatchHaptics(),
        wallClock: any EngineClock = SystemEngineClock(),
        calendar: Calendar = .current
    ) {
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
        self.haptics = haptics
        self.wallClock = wallClock
        self.calendar = calendar
        self.aodPreview = Self.aodPreviewEnabled()

        // The DEBUG fixture seam seeds through the REAL store BEFORE the
        // launch read, so the restore test exercises the genuine read path
        // (disclosed in the task notes; release builds never seed — and the
        // reset kind's returned marker frame is therefore nil in release,
        // making the delivery leg below dead code there).
        let pendingResetFrame = Self.seedFixtureIfRequested(directory: resolved)

        // The launch read (OBS-1's one sanctioned synchronous main-thread
        // read): three KB-scale store reads — the snapshot pair, the
        // consumed marker, and (below) the session epoch.
        snapshot = WatchSnapshotStore(directory: resolved).load()
        consumedEraseCount = WatchConsumedMarkerStore(directory: resolved)
            .load()?.eraseCount ?? 0

        // The session epoch (R1; 05 §6.2): the persisted identity is
        // preferred. A miss mints one IN MEMORY now, while the save and the
        // F-3 journal self-defense ride the init task OFF the main actor
        // (OBS-1's no-main-thread-I/O rule — the identity is usable this
        // launch regardless; if the save never lands, the next launch's
        // generation repeats and wipes again). The wipe is submitted through
        // the persister's mailbox BEFORE any pat can exist, so a stale-
        // epoch journal cannot outlive its epoch even against an
        // immediately-following pat.
        if let persisted = WatchSessionEpochStore(directory: resolved).load()?.epoch {
            watchSessionEpoch = persisted
        } else {
            let minted = UUID()
            watchSessionEpoch = minted
            let epochStore = WatchSessionEpochStore(directory: resolved)
            let directory = resolved
            let persister = self.persister
            Task.detached(priority: .utility) {
                epochStore.save(WatchSessionEpoch(epoch: minted))
                await persister.wipeJournal(directory: directory)
            }
        }

        // The pat reaction's clip renderer seeds from the launch snapshot's
        // assembled character (R5); a degraded or nil launch read leaves it
        // nil until the first renderable receive.
        if let snapshot,
            let display = makeWatchCharacterDisplay(
                display: snapshot.display,
                character: snapshot.character
            ) {
            reactionDirector = MomoDirectorState(displayState: display)
        }

        // The live quest line's FIRST recompute leg (TASK-043 R1): the
        // launch render derives it from the restored snapshot under the
        // launch hour. (Legs census: init + receive steady + receive
        // consume + scene activation = 4.)
        recomputeQuestLine()

        // The sinks bind FIRST, activation LAST (the WCSession.h:42-45
        // discipline). The WC queue's frames hop to the main actor; the
        // actor total-orders them, and each receive's persist submission
        // preserves that order through the persister's mailbox (FIFO).
        // TASK-044 R1: the activation completion arms the launch sweep the
        // same way — the WC queue emits it BEFORE the pending context, and
        // each sink's task is created in that emission order, so the arm's
        // main-actor job precedes the first receive's. (Even if a frame
        // outran it, the outcome is a missed — never a wrong — drain: the
        // next receive decision or the next launch re-arms.)
        transport.onContextData = { [weak self] data in
            Task { @MainActor [weak self] in
                await self?.receiveContext(data)
            }
        }
        transport.onActivation = { [weak self] in
            Task { @MainActor [weak self] in
                self?.armLaunchSweep()
            }
        }
        transport.activate()

        // The reset E2E's delivery leg (TASK-044 R2; DEBUG-only by
        // construction — `seedFixtureIfRequested` returns nil in release).
        // The pending marker frame enters through the REAL receive path —
        // the same `receiveContext` a WC delivery lands in — so the §6.6
        // decision (`WatchResetConsumption.decide`, never mocked), the
        // fused consumeWipe, and the settling-in render all run production
        // code. Scheduled AFTER `activate()` (the launch sinks are bound
        // first — the arm has been raised by the time this frame lands,
        // mirroring the real delivery order; the consume branch's sweep
        // then reads the post-wipe journal).
        if let pendingResetFrame {
            Task { @MainActor [weak self] in
                await self?.receiveContext(pendingResetFrame)
            }
        }
    }

    // MARK: The assembled render inputs (ADR-014; 04 §9.2)

    /// The assembled character read-model for the rig — the snapshot's
    /// `display` + `character` through MomoKit's ONE assembly. Nil snapshot
    /// OR nil character (cross-version skew) yields nil: the view renders
    /// words-only / the settling-in line — never a crash (UX §9). The Watch
    /// derives NOTHING: no band, stage, or moment derivation happens here.
    ///
    /// The nil-character case is DEBUG-loud (ADR-014's promised log, landed
    /// as TASK-042's F-1 fold): cross-version skew cannot ship in Phase 1
    /// (both targets update together), so an invariant regression trips the
    /// debugger. The memo makes it ONCE PER SNAPSHOT — this property is
    /// evaluated on every body render, and an unconditional trap would
    /// crash-loop a DEBUG build instead of surfacing one actionable log.
    var characterDisplay: CharacterDisplayState? {
        guard let snapshot else { return nil }
        guard let character = snapshot.character else {
            if f1LoggedSnapshotSeq != snapshot.snapshotSeq {
                f1LoggedSnapshotSeq = snapshot.snapshotSeq
                Self.debugLoud(
                    "watch snapshot seq \(snapshot.snapshotSeq) carries a nil character — cross-version skew; rendering words-only"
                )
            }
            return nil
        }
        return makeWatchCharacterDisplay(display: snapshot.display, character: character)
    }

    // MARK: The live quest line (TASK-043 R1)

    /// The ONE re-cascade, written by each recompute leg: the SHARED
    /// derivation through MomoKit's seam (`WatchCascade` — the Watch target
    /// names no engine surface in code) over the carried inputs under the
    /// hour of the INJECTED `wallClock` + `calendar` (D20 — no ambient
    /// reads; the `makeDisplayState` shape). A nil snapshot clears the line
    /// with it — the settling-in shape never carries a quest line.
    private func recomputeQuestLine() {
        guard let snapshot else {
            liveQuestLine = nil
            return
        }
        let localHour = calendar.component(.hour, from: wallClock.now())
        liveQuestLine = WatchCascade.liveQuestLine(
            questSet: snapshot.questInputs,
            localHour: localHour
        )
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
            // state — discarded, never rendered. Wipe snapshot pair → wipe
            // journal → record → settle (the F-3 order, all inside the
            // persister's one serialized step — TASK-042's R2c landed the
            // journal leg in `consumeWipe`). The count is non-nil by
            // `decide`'s contract (.consume requires an incoming count that
            // exceeds the consumed one); the guard is the compiler-visible
            // restatement, never a silent fallback.
            guard let eraseCount = snapshot.resetMarkerEraseCount else {
                Self.debugLoud("receiveContext: .consume decided with a nil marker count — skipped")
                return
            }
            await persister.consumeWipe(directory: storeDirectory, eraseCount: eraseCount)
            consumedEraseCount = eraseCount
            self.snapshot = nil
            // The consume recompute leg (TASK-043 R1): the line clears WITH
            // the snapshot — post-wipe renders the settling-in shape, never
            // a quest line beside a nil snapshot.
            recomputeQuestLine()
            // The launch sweep's post-consume leg (TASK-044 R1 — the reset
            // interaction's first defense): the sweep fires only AFTER the
            // awaited `consumeWipe` has completed, so its mailbox-ordered
            // journal read serves the POST-wipe (empty) journal — a pending
            // marker suppresses the sweep to zero sends.
            await flushStrandedJournal()
            return
        }
        // The steady shape: latest-wins render first (§6.3's instant local
        // render), persist second, journal prune third (R2b — the §6.4
        // step-4 leg: the snapshot's watermark pair prunes the applied
        // entries, epoch-matched; the mailbox keeps it strictly after the
        // persist that carried the pair). The submission order through the
        // persister's mailbox matches the receive order (O1).
        self.snapshot = snapshot
        // The receive recompute leg (TASK-043 R1): the line re-cascades from
        // the NEW snapshot's carried inputs before the disk legs, so the
        // render input is coherent the moment the render state lands.
        recomputeQuestLine()
        await persister.persist(directory: storeDirectory, snapshot: snapshot)
        await persister.pruneJournal(
            directory: storeDirectory,
            watermarkEpoch: snapshot.lastAppliedEpoch,
            watermarkSeq: snapshot.lastAppliedIntentSeq
        )
        // The launch sweep's steady leg (TASK-044 R1): fired after the
        // watermark prune so the drain enqueues only still-pending entries —
        // already-applied ones ride the prune's drop, sparing the wire
        // (INV-10 would make sending them harmless; the prune makes it
        // unnecessary).
        await flushStrandedJournal()
        // The pat reaction's clip renderer re-seeds from the NEWEST
        // snapshot (R5): the next pat's clip context rides the latest
        // state. A mid-flight reaction is cut by this re-seed — accepted:
        // the snapshot IS the newest truth (the drain's returning echo must
        // not outrank it), and reaction continuity is not a contract.
        if let display = makeWatchCharacterDisplay(
            display: snapshot.display,
            character: snapshot.character
        ) {
            reactionDirector = MomoDirectorState(displayState: display)
        }
    }

    // MARK: The launch sweep (TASK-044 R1; §6.4, §10.4 "journal drain on
    // reconnect")

    /// The activation-completion leg (the ARM): raises the sweep flag and
    /// records the consumed erase count as its baseline. No I/O, no sends —
    /// the drain waits for the next receive decision (the arm-then-flush
    /// discipline on `onActivation`; the arm property's doc carries the
    /// ordering argument).
    private func armLaunchSweep() {
        sweepArmed = true
        consumedEraseCountAtArm = consumedEraseCount
    }

    /// The launch sweep's ONE execution: every journaled-but-unenqueued
    /// event re-enqueued VERBATIM through the pat flow's OWN send leg. A
    /// crash between the pat journal's append and its `finishPat()` drain
    /// strands a durable-but-never-sent event (REVIEW-TASK-042 F-R1); this
    /// is the reconnect leg that delivers it. One-shot per arming — the
    /// first receive decision after activation runs it and disarms. The
    /// journal lines are NOT deleted on send (the watermark prune owns
    /// removal), so a re-activation sweep re-sends the same events and the
    /// iPhone's unseen-UUID gate keeps exactly-once (INV-10 — cited; pinned
    /// in MomoKit, never re-derived here).
    ///
    /// **The reset interaction (both defenses).** The consume branch calls
    /// this AFTER its awaited `consumeWipe` — the persister's mailbox
    /// serves this read the POST-wipe journal, which holds nothing to
    /// drain — and `WatchSweepPlan`'s count re-check refuses every event
    /// when the consumed count advanced between arm and here. A marker
    /// pending at launch therefore sends nothing: either its frame has not
    /// arrived (the sweep is still unarmed — the drain fires only on a
    /// receive decision) or its consumption wiped the journal before this
    /// read.
    ///
    /// **Disclosed residual** (shared with the pat flow's existing
    /// mid-pat exposure): a consumption suspended INSIDE `consumeWipe` at
    /// the instant of this read could hand the sweep pre-wipe bytes already
    /// enqueued to WC's reliable queue when the wipe lands. iPhone-side
    /// those replay as no-ops against the standing watermark, and apply
    /// warm only against a fresh store — the same accepted shape the gate
    /// pins for iPhone reinstalls (`WatchSyncGateTests` "iPhone reinstall:
    /// empty table…stale queued pats apply warm"). No new class of
    /// exposure.
    private func flushStrandedJournal() async {
        guard sweepArmed else { return }
        sweepArmed = false
        let journal = await persister.pendingEvents(directory: storeDirectory)
        let drainable = WatchSweepPlan.drainableEvents(
            journal: journal,
            epoch: watchSessionEpoch,
            consumedEraseCountAtArm: consumedEraseCountAtArm,
            consumedEraseCountNow: consumedEraseCount
        )
        for event in drainable {
            guard let payload = event.encoded() else {
                Self.debugLoud("launch sweep: journal event failed to encode — skipped (a valid IntentEvent always encodes)")
                continue
            }
            transport.sendUserInfo(payload: payload)
        }
        if !drainable.isEmpty {
            Self.logger.debug("launch sweep drained \(drainable.count) stranded event(s)")
        }
    }

    // MARK: The lifecycle leg (TR9)

    /// Persist on every background transition so raise-to-wake never starts
    /// cold or stale (TR9/NFR-9; §6.5). The current snapshot rides the
    /// serialized writer off the main actor; a nil snapshot has nothing to
    /// persist (the store already matches: fresh, wiped, or unrecoverable —
    /// and re-wiping on nil would be a state-changing write the transition
    /// leg does not own). Foreground transitions are renders-from-memory,
    /// not writes — except for the ONE foreground recompute (TASK-043 R1's
    /// activation leg): returning to the active scene re-cascades the quest
    /// line under the CURRENT local hour, so raise-to-wake tracks the hours
    /// that elapsed in the background without any timer (§4.2).
    func scenePhaseChanged(to phase: ScenePhase) {
        // The activation recompute leg (the fourth and last; TASK-043 R1):
        // background→foreground re-derives the line before the render.
        if phase == .active {
            recomputeQuestLine()
            return
        }
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
    /// production launches never seed. Kinds: `w1` (the standard rendered
    /// glance, TASK-041), `alldone` and `stale` (TASK-043's cascade flows),
    /// and TASK-044 R2's erase pair — `reset` (the clean w1 bytes PLUS a
    /// pending marker frame, returned for delivery to the REAL receive
    /// path) and `resethold` (the same clean bytes, NO frame — the red
    /// direction's control).
    ///
    /// The seed MUST land before the synchronous launch read below it in
    /// `init` (the whole point — the read then restores what the real
    /// `save` wrote), but `WatchSnapshotStore.save` is actor-isolated and
    /// `init` is sync. The DEBUG-only bridge is a detached task plus a
    /// semaphore: it blocks this launch thread for the one KB write, the
    /// store actor is independent of the main actor (no deadlock), and the
    /// write path is the store's own `save` — not a seam-side re-encoding.
    /// Release builds never enter the DEBUG body: the function's release
    /// shape is a bare `return nil`, so the init's pending-frame delivery
    /// is dead code there (the recorded release-inertness evidence).
    private static func seedFixtureIfRequested(directory: URL) -> Data? {
        #if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-momo-watch-fixture"),
            index + 1 < arguments.count
        else { return nil }
        switch arguments[index + 1] {
        case "w1":
            seedFixture(w1FixtureSnapshot(), to: directory)
        case "alldone":
            seedFixture(allDoneFixtureSnapshot(), to: directory)
        case "stale":
            seedFixture(staleFixtureSnapshot(), to: directory)
        case "reset":
            // The CLEAN bytes seed the store — the marker is deliberately
            // NOT on the seeded snapshot, so the launch read restores a
            // rendered glance first and the returned frame's consumption
            // then wipes a store that demonstrably held something.
            seedFixture(w1FixtureSnapshot(), to: directory)
            return resetMarkerFrame()
        case "resethold":
            seedFixture(w1FixtureSnapshot(), to: directory)
            return nil
        default:
            assertionFailure("MomoWatchAppModel: unknown -momo-watch-fixture kind '\(arguments[index + 1])'")
            return nil
        }
        return nil
        #else
        return nil
        #endif
    }

    /// The reset kind's marker frame (DEBUG-only): the w1 fixture's
    /// PRE-erase content with `resetMarkerEraseCount` raised to 1 — the
    /// frame the iPhone's §6.6 push carries after an erase-all. The
    /// consumption discards this payload (it is pre-erase state); only the
    /// count and the decision matter.
    private static func resetMarkerFrame() -> Data? {
        let base = w1FixtureSnapshot()
        let marked = WatchSnapshot(
            snapshotSeq: base.snapshotSeq,
            display: base.display,
            questInputs: base.questInputs,
            hapticsEnabled: base.hapticsEnabled,
            lastAppliedIntentSeq: base.lastAppliedIntentSeq,
            lastAppliedEpoch: base.lastAppliedEpoch,
            resetMarkerEraseCount: 1,
            character: base.character
        )
        return marked.encoded()
    }

    /// The one semaphore bridge shared by every fixture kind (the save is
    /// actor-isolated; the launch is sync — see `seedFixtureIfRequested`).
    private static func seedFixture(_ snapshot: WatchSnapshot, to directory: URL) {
        #if DEBUG
        let store = WatchSnapshotStore(directory: directory)
        let seeded = DispatchSemaphore(value: 0)
        Task.detached(priority: .userInitiated) {
            await store.save(snapshot)
            seeded.signal()
        }
        seeded.wait()
        #endif
    }

    /// The `w1` fixture (DEBUG-only): a fully-populated snapshot — mood
    /// content, energy energetic, playing while recently fed, stage
    /// Getting Close, quest Q7 (the pat-completable wish) — whose character
    /// DTO carries all four fields so the rig renders a real pose.
    ///
    /// The carried `questInputs` are the display line's PROVENANCE (the
    /// TASK-043 R3 property at fixture scale): [Q1 ✓, Q2 ✓, Q7 in progress]
    /// cascades to `.wish(.q7)` at EVERY local hour, so the frozen line and
    /// the live re-cascade agree all day — the fixture stays self-consistent
    /// under the live line (the empty set the pre-TASK-043 seed carried
    /// would cascade to `.allDone` and contradict its own display).
    private static func w1FixtureSnapshot() -> WatchSnapshot {
        fixtureSnapshot(
            questLine: .wish(.q7),
            questInputs: [
                QuestProgress(questID: .q1, progress: 1, completed: true),
                QuestProgress(questID: .q2, progress: 1, completed: true),
                QuestProgress(questID: .q7, progress: 0, completed: false),
            ].compactMap { $0 }
        )
    }

    /// The `alldone` fixture (DEBUG-only, TASK-043 R2/R6): the day's set
    /// fully completed — the live cascade yields `.allDone` at every local
    /// hour, so W1 renders the all-done line (`HomeCopyKeys.allDoneLineKey`
    /// → "Momo had a lovely day.") in the UI flow.
    private static func allDoneFixtureSnapshot() -> WatchSnapshot {
        fixtureSnapshot(
            questLine: .allDone,
            questInputs: [
                QuestProgress(questID: .q1, progress: 1, completed: true),
                QuestProgress(questID: .q2, progress: 1, completed: true),
                QuestProgress(questID: .q7, progress: 3, completed: true),
            ].compactMap { $0 }
        )
    }

    /// The `stale` fixture (DEBUG-only, TASK-043 R6's §10.4 stale-data
    /// share): a snapshot whose FROZEN line says all-done (the push instant's
    /// day had finished) over a CARRIED set of a fresh, untouched day — the
    /// shape after a midnight day-roll the next push has not refreshed. The
    /// live re-cascade under the Watch's own local hour renders the new
    /// day's actual wish (Q6 from 20:00 ∨ before 07:00, Q1 before noon, Q2
    /// otherwise — never all-done while an in-window rule holds), proving
    /// stale bytes render sanely, with no error surface (§10.4's stale-data
    /// row).
    private static func staleFixtureSnapshot() -> WatchSnapshot {
        fixtureSnapshot(
            questLine: .allDone,
            questInputs: [
                QuestProgress(questID: .q1, progress: 0, completed: false),
                QuestProgress(questID: .q2, progress: 0, completed: false),
                QuestProgress(questID: .q6, progress: 0, completed: false),
            ].compactMap { $0 }
        )
    }

    /// The fixtures' shared body: the same populated display + character
    /// DTO across kinds; only the quest line and its provenance inputs vary
    /// (the fields under TASK-043's test). `hapticsEnabled: true` — the pat
    /// flows' toggle-honoring seam stays exercised.
    private static func fixtureSnapshot(
        questLine: QuestGeneration.QuestLine,
        questInputs: [QuestProgress]
    ) -> WatchSnapshot {
        let stage = BondStage.gettingClose
        let display = DisplayState(
            petName: "Momo",
            moodWordKey: VocabularyKeys.moodWordKey(for: .content),
            energyPhraseKey: VocabularyKeys.energyPhraseKey(for: .energetic),
            bondStage: stage,
            bondDescriptorKey: VocabularyKeys.bondDescriptorKey(for: stage),
            questLine: questLine,
            wakefulness: .awake,
            greeting: nil
        )
        return WatchSnapshot(
            snapshotSeq: 1,
            display: display,
            questInputs: questInputs,
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
    static func debugLoud(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
