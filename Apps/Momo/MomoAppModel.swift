import SwiftUI
import UIKit
import MomoCharacter
import MomoKit
import MomoCore
import os

// MARK: - MomoAppModel — the thin executor behind the app model (TASK-031;
// 05-technical-architecture §4.1–§4.2, §5.2–§5.3)

/// The app model's executor: the ONE place in the app target that owns the
/// real world — the `SystemEngineClock`, the `SnapshotStore`, the local
/// calendar, `scenePhase` and the significant-time-change notifications, the
/// boundary schedule — and performs each `AppModelPlan`'s steps in §4.1's
/// fixed order. Every DECISION it makes is delegated to the pure plan core
/// (`AppModelPlanCore` / `NextBoundaryRules` / `AppModelLaunch` in MomoKit);
/// what remains here is deliberately mechanical.
///
/// **D-R5 by construction.** This file is the engine-facing executor: besides
/// this file, the only app-target file that imports `MomoCore` is the entry
/// point's disclosed R7 UI-test clock enabler (`MomoApp.fixedTimeSources`,
/// TASK-033 — it constructs a clock to INJECT into this model and reaches no
/// other engine API); views consume the app model through SwiftUI's
/// environment and never invoke the engine. The engine's `reduce` itself is
/// called only inside the plan core — the facade (this executor + that core)
/// is the engine's sole entry point.
///
/// **The launch read is the ONE sanctioned synchronous main-thread I/O**
/// (05 §5.2: "the main thread never blocks on I/O beyond launch's initial
/// read — a KB-scale JSON decode, milliseconds, inside the 2 s launch
/// budget"; the OBS-1 property routed from REVIEW-TASK-024). Both the
/// fresh-vs-loaded probe and `SnapshotStore.load`'s nonisolated read happen
/// once, here, in `init` — `SnapshotStore` was designed for exactly this
/// (its `load` is `nonisolated` precisely so a launch read holds with no
/// store cooperation). Every other I/O goes through the store actor
/// (`await store.save`) off the main actor.
///
/// **Boundary scheduling — the 05 §4.2 VERIFY-AT-BUILD resolution.** The
/// doc's "a single `Task`-scheduled call or equivalent" is realized as ONE
/// cancellable Swift Concurrency `Task` per boundary, sleeping for the
/// interval to the boundary instant (`Task.sleep(for:)` over the derived
/// delay). Why this mechanism: it is the doc's named shape; cancellation on
/// every re-derivation makes "schedulers re-schedule, never replay"
/// structural (exactly one live schedule, cancelled — not replayed — when a
/// newer one is derived); the event carries the BOUNDARY instant, so
/// scheduler slack never shifts the fold target; and a backgrounded
/// boundary is inert by construction — `backgrounded()` cancels the task,
/// the task's foreground guard refuses to fire anyway, and iOS suspends the
/// process regardless. The next foreground fold catches up (§4.2).
///
/// **Seed/clock discipline (05 §4.10).** Production time is
/// `SystemEngineClock`, injected like everything else; the plan core seeds
/// the choreography stream per the `reduce` header's convention
/// (`DaySeed.make(…, salt: .choreography)`, fresh `SeededGenerator` per
/// application) — this executor performs no seed arithmetic. The calendar is
/// the app layer's injection point: `.current` here (the app target has no
/// ambient ban — the discipline scans govern the package targets), re-derived
/// on the significant-time-change trigger and handed to every plan-core call.
///
/// **Lifetime.** The model lives for the app's lifetime; the time-change
/// observation is registered in `init` and removed in `deinit`.
@MainActor
@Observable
final class MomoAppModel {

    /// Lifecycle telemetry (the launch evidence that the executor is live
    /// behind the placeholder shell; literal, non-interpolated text).
    private static let logger = Logger(subsystem: "com.momo.app", category: "app-model")

    /// Whether the store held generations at launch (05 §5.2's fresh-vs-loaded
    /// input; `AppModelLaunch`'s header records the §5.3 reading — this is
    /// diagnostics/onboarding surface, never a recovery signal).
    enum LaunchOrigin: Equatable {
        case freshStore
        case loadedStore
    }

    /// The write-through store (its actor serializes every save; §5.2).
    private let store: SnapshotStore

    /// The store directory the RUNNING session uses (TASK-038 R5.1):
    /// retained at init so the erase path deletes EXACTLY this directory —
    /// the `-momo-store-directory` override honored, never a re-resolved
    /// path (`SnapshotStore` keeps its own copy; this is the executor's).
    /// Internal, not private: the same-target settings extension
    /// (`MomoAppModel+Settings.swift`, TASK-038's disclosed extraction for
    /// the 800-line budget) reads it — target-scoped only.
    let storeDirectory: URL

    /// The production time source (05 §4.10) — every engine time read
    /// in the executor flows through it.
    private let clock: any EngineClock

    /// The presentation-owned character clock (TASK-032 R12; EPIC-006's
    /// view API): ONE clock for the whole session, fed by the same injected
    /// time source as the engine, handed to every `MomoRigView` host. The
    /// view manages its own pause/resume on scene phase; TASK-034's
    /// director/report wiring reuses this same clock — every director
    /// event's `at:` stamp is `canvasClock.elapsed()`, so the folded
    /// choreography lives on the SAME timeline the rig samples.
    let canvasClock: CharacterClock

    /// The significant-time-change observation token (§4.2's fifth trigger).
    /// The block-API's `NSObjectProtocol` token is not `Sendable`; the box
    /// below is the honest minimal crossing — its only use is
    /// `removeObserver`, and `NotificationCenter` is thread-safe — so the
    /// nonisolated `deinit` may read it under Swift 6 strict concurrency.
    /// Optional because registration happens at the END of `init`: the
    /// closure captures `self`, legal only once every stored property is
    /// initialized.
    private struct ObserverToken: @unchecked Sendable {
        let token: NSObjectProtocol
    }

    private var timeChangeObserver: ObserverToken?

    /// The local calendar handed to every plan-core call; re-derived when
    /// the OS reports a significant time change (§4.2's "re-derive dayKey").
    private(set) var calendar: Calendar

    /// The live domain state — applied as each plan's step 0, before any
    /// other effect (§4.1's fixed order).
    private(set) var state: EngineState

    /// How the launch read found the store.
    let launchOrigin: LaunchOrigin

    /// Whether the session is currently foreground (the boundary task's
    /// inertness guard).
    private var isForeground = false

    /// The "not onboarded" flow input (§5.3): the loaded state's own
    /// onboarding flag. A fresh store serves the injected fresh default
    /// (`false`); total corruption recovers to it invisibly — which lands
    /// here too, exactly §5.3's indistinguishable-recovery stance.
    /// Onboarding itself is TASK-032; this flag is its input.
    var requiresOnboarding: Bool { !state.settings.onboardingComplete }

    /// The surfaces' read-model (05 §4.11) — derived from the app model's
    /// state through MomoCore's one derivation, so the placeholder shell's
    /// consumers (TASK-032/033) bind through the app model, never the engine.
    var displayState: DisplayState {
        makeDisplayState(state, at: clock.now(), calendar: calendar)
    }

    /// The character canvas's read-model (TASK-032 R12): the onboarding
    /// canvas binds through this, never the engine (D-R5). The rig state
    /// alone — the alive-at-rest blink/breath IS the whole S1/S3 "small
    /// greeting animation"; director/moments wiring is TASK-034's.
    var characterDisplayState: CharacterDisplayState {
        makeCharacterDisplayState(state)
    }

    /// The Home composition's read-model (TASK-033 R2; UX §5.1): mirrors
    /// `displayState` — the same (state, now, calendar) inputs through
    /// MomoKit's `makeHomeReadModel`, plus TASK-035 R5's in-memory latest
    /// care moment (the contextual line's top priority), so the Home view
    /// binds through the app model and never the engine (D-R5).
    var homeReadModel: HomeReadModel {
        makeHomeReadModel(
            state, at: clock.now(), calendar: calendar,
            latestCareMoment: latestCareMoment)
    }

    // MARK: The reaction director (TASK-034; EPIC-006's frozen fold)

    /// The folded reaction director state (04 §4.1's choreography layer):
    /// every `MomoCharacterEvent` the presentation observes — the engine's
    /// plans, the read-model updates, the canvas touch boundaries, the app
    /// hide/show gates, the play round's early-exit stop (TASK-035 R6), the
    /// engine's event-born quest/bond moments (TASK-036 R1) — folds HERE,
    /// and the Home rig samples the projection through
    /// `reactionMotion(at:reduceMotion:)`. The app model is the ONE
    /// app-target owner of the fold (D-R5: the view never touches the
    /// director; MomoKit never imports MomoCharacter). Value-typed and
    /// observable: a fold re-renders the rig on the next frame. Every report
    /// a fold emits drains into `submit` (TASK-035 R1's exactly-once chain).
    private(set) var director: MomoDirectorState

    // MARK: The play round (TASK-035 R2; UX-3)

    /// Authored cadence of the play round's stillness ticker (TASK-035 R2,
    /// disclosed): while a round is in flight the app model folds a
    /// `moving: false` fingertip sample every second, so the director's
    /// pacer resolves exactly as designed even with no finger on screen
    /// (UX-3: "passive is fine — Momo performs solo"). The folds are the
    /// pacer's OWN input vocabulary — §6.3's stillness drives the solo
    /// wind-down, the payoff, and the `playRoundFinished` report that
    /// drains into the engine's unified cease.
    static let playTickerSeconds: Double = 1.0

    /// Authored delay of the quiet "Done" pill after the round's start
    /// instant (TASK-035 R2, disclosed; 03 §5.3's "~5 s"): inside the
    /// acceptance band [4.5, 6.0] s.
    static let donePillDelaySeconds: Double = 5.0

    /// The live stillness-ticker task (nil while no round is in flight).
    private var playTickerTask: Task<Void, Never>?

    /// The live Done-pill window task (nil while no round is in flight).
    private var donePillTask: Task<Void, Never>?

    /// Whether the Done-pill window is open (the ~5 s task flipped it; the
    /// pill itself is `isPlayDonePillVisible`, computed, so it disappears
    /// when the round ends by ANY path).
    private(set) var isDonePillWindowOpen = false

    /// The last fingertip offset the play surface streamed (grid units from
    /// the stage center) — the stillness ticker's solo samples resume from
    /// it; nil before the first real sample of a round. Internal, not
    /// private: the same-target canvas extension
    /// (`MomoAppModel+Canvas.swift`, TASK-039 R8's disclosed extraction)
    /// records the streamed sample.
    internal var lastPlayFingertipOffset: CGPoint?

    /// Whether a play round is in flight — ENGINE-visible, not a
    /// presentation guess: the engine sets `activity = .playing` at
    /// authorization and the unified cease (report-path completion OR
    /// cancellation) clears it.
    var isPlayRoundInFlight: Bool { state.state.activity == .playing }

    /// Whether the quiet "Done" pill shows: the round is in flight AND its
    /// ~5 s window has opened. Computed, so the pill disappears when the
    /// round ends by any path (Done tap, solo completion, app hide).
    var isPlayDonePillVisible: Bool { isPlayRoundInFlight && isDonePillWindowOpen }

    // MARK: The care moments (TASK-035 R5)

    /// The latest visual care moment (tuck-in settle / refusal /
    /// blanket-adjust), tracked in MEMORY ONLY — never persisted, never
    /// archived: it holds until superseded by a newer care moment or the
    /// app relaunches (the retention disclosed in the task contract; it
    /// rides REVIEW-TASK-033 OBSERVATION-A's ambient-visibility owner item).
    /// The Home contextual line renders its fixed line above greeting and
    /// ambient (UX-12's priority verbatim).
    private(set) var latestCareMoment: CareMomentKind?

    // MARK: The quest moments + celebrations state (TASK-036; UX §5.5–§5.6)
    // (The authored constants and the machinery live in the same-target
    // `MomoAppModel+Celebrations.swift` extension — TASK-039 R8's split;
    // stored properties cannot leave the type's main declaration.)

    /// The M2 banner's visible stage — nil while hidden (UX §5.6's calm
    /// in-scene banner over Home; never a modal, never chrome). The
    /// celebration's ONE-TIME-NESS is the ENGINE's (UX-10's
    /// `highestCelebratedStage` guard advances with the emission and is
    /// persisted) — this presentation state is deliberately stateless
    /// about once-per-stage. Disclosed: the banner does not defer across
    /// backgrounding — a celebration arriving in a backgrounded apply
    /// auto-fades on the wall clock; the engine's once-guard means the
    /// moment itself is never re-minted. The property (and its setter)
    /// is internal (the same-target celebrations extension shows and
    /// fades it — TASK-039 R8's disclosed extraction); nothing leaves
    /// the target either way.
    var activeCelebrationStage: BondStage?

    /// The banner's live auto-fade task (nil while no banner shows).
    /// Internal, not private: the same-target celebrations extension
    /// (`MomoAppModel+Celebrations.swift`, TASK-039 R8's disclosed
    /// extraction) cancels and reassigns it.
    internal var celebrationTask: Task<Void, Never>?

    /// The quests whose completion the card is still flourishes (M1's
    /// mark swell) — memory only, latest-wins exactly like
    /// `latestCareMoment`: never persisted, cleared by the authored
    /// flourish task or superseded by the next application. The property
    /// (and its setter) is internal for the same extension-extraction
    /// reason (nothing leaves the target either way).
    var celebratingQuests: [QuestID] = []

    /// The flip flourish's live auto-clear task. Internal: the
    /// celebrations extension cancels and reassigns it.
    internal var questFlipTask: Task<Void, Never>?

    /// The moment-haptic sink (TASK-036 R7): the kinds
    /// `MomentHapticKind.deliveryKinds` decides fire here — gated on
    /// `state.settings.hapticsEnabled` AT DELIVERY (the arm's argument),
    /// independent of Reduce Motion (D16 fades motion, never touch). The
    /// default is the UIKit implementation — M1 a light impact (UX §5.5's
    /// "optional light haptic"), M2 a single warm success notification
    /// (§5.6's crossing beat); an injectable closure keeps the seam
    /// observable. The engine's `ResponsePlan.haptic` stays nil everywhere
    /// — this is presentation-owned, decided at delivery.
    var momentHapticSink: (MomentHapticKind) -> Void = { kind in
        switch kind {
        case .questCompleted:
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        case .stageCelebration:
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// Whether a canvas touch is currently open (the `touchEnded`
    /// idempotence guard — the FIX1-NOTE-1 cancel seam closes the press
    /// EXACTLY once per opened touch, whichever path ends it). Internal,
    /// not private: the same-target canvas extension
    /// (`MomoAppModel+Canvas.swift`, TASK-039 R8's disclosed extraction)
    /// flips it from the touch entries.
    internal var isTouchOpen = false

    /// The UI-facing response seam (§4.1's fixed order, step 2): the shell
    /// may host this closure to observe the delivery; exactly-once
    /// invocation is the plan-loop's guarantee. (TASK-036 R1: the moments
    /// half of this seam was REMOVED — it was declared and called but
    /// never hosted, the delivery gap this task fixes; the `.deliverMoments`
    /// arm folds the event into the director itself, which IS the
    /// delivery.)
    var deliverResponse: ((ResponsePlan) -> Void)?

    /// The ONE live boundary schedule — cancelled and re-derived after every
    /// application (re-schedule, never replay).
    private var boundaryTask: Task<Void, Never>?

    /// - Parameters:
    ///   - storeDirectory: the store directory. Nil (production) resolves
    ///     through `StoreRules.defaultDirectory()` — the ONE sanctioned
    ///     ambient-path site. Injected values serve previews/tests.
    ///   - clock: the injected time source; production defaults to
    ///     `SystemEngineClock` (05 §4.10).
    ///   - calendar: the injected local calendar; production defaults to
    ///     the current one (re-derived on significant time change).
    ///   - freshDefault: the store's injected fresh default (05 §5.3 — the
    ///     caller's to inject; MomoCore owns no initial-state factory by
    ///     design). Defaults to `MomoAppModel.freshDefaultState`.
    init(
        storeDirectory: URL? = nil,
        clock: any EngineClock = SystemEngineClock(),
        calendar: Calendar = .current,
        freshDefault: EngineState? = nil
    ) {
        let directory: URL
        if let storeDirectory {
            directory = storeDirectory
        } else {
            do {
                directory = try StoreRules.defaultDirectory()
            } catch {
                // The sandbox Application Support lookup failing is not an
                // expected path (StoreRules creates the container on the
                // way). DEBUG-loud per the MomoCopy discipline; the
                // last-resort directory keeps the session functional over a
                // throwaway store (the §5.3 worst case, self-inflicted and
                // bounded to this launch).
                Self.debugLoud("MomoAppModel: defaultDirectory() failed (\(error))")
                directory = FileManager.default.temporaryDirectory
                    .appendingPathComponent("Momo-store-fallback", isDirectory: true)
            }
        }
        self.store = SnapshotStore(directory: directory, clock: clock)
        self.storeDirectory = directory
        self.clock = clock
        self.canvasClock = CharacterClock(timeSource: clock)
        self.calendar = calendar

        // THE launch read (see the type header; OBS-1 review-attention
        // item): one synchronous main-thread operation — the fresh-vs-loaded
        // probe plus the store's nonisolated load with its invisible
        // corruption fall-through.
        self.launchOrigin = AppModelLaunch.hasGenerations(directory: directory)
            ? .loadedStore
            : .freshStore
        let loadedState = store.load(fallback: freshDefault ?? Self.freshDefaultState(clock: clock))
        self.state = loadedState
        // The director starts from the LOADED state's read-model (the rig's
        // waking/settling choreography follows the state the session opens
        // onto, not a fresh default's) — derived from the load result's
        // LOCAL, since `self` is not yet fully initialized here.
        self.director = MomoDirectorState(
            displayState: makeCharacterDisplayState(loadedState)
        )
        switch launchOrigin {
        case .freshStore:
            Self.logger.notice("app model live — fresh store, onboarding input surfaced")
        case .loadedStore:
            Self.logger.notice("app model live — loaded store, launch is the first open")
        }

        // §4.2's significant-time-change trigger (new day, timezone, DST —
        // the OS's one notification covers the row's cases). Queue .main so
        // the assume-isolated hop below is honest. Registered LAST: the
        // closure captures `self`, legal only after every stored property
        // above is initialized.
        self.timeChangeObserver = ObserverToken(token: NotificationCenter.default.addObserver(
            forName: UIApplication.significantTimeChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.significantTimeChangeOccurred()
            }
        })
    }

    isolated deinit {
        if let observer = timeChangeObserver {
            NotificationCenter.default.removeObserver(observer.token)
        }
    }

    // MARK: §4.2's trigger entries (the facade's whole public surface)

    /// scenePhase → the trigger table's foreground/background behavior:
    /// `.active` is the catch-up fold; `.background` makes the boundary
    /// schedule inert; `.inactive` is transitional (app switcher) and
    /// triggers NOTHING in §4.2's table — its fold below is the DIRECTOR's
    /// clock-pause gate ONLY (TASK-034): the rig's clock rule pauses on
    /// anything but `.active` (the frozen `RigMotionViewMapping`), and the
    /// director must mirror that pause or its windows would reference a
    /// timeline the zeroed clock abandoned. `.appHidden`/`.appShown` are
    /// its pause/resume face (§7.4 rule 8; ADR-010). Only `.background`
    /// ALSO runs the §4.2 backgrounding side — the foreground flag and the
    /// boundary-task cancel (`backgrounded()`); `.inactive` leaves the
    /// engine semantics untouched.
    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .active:
            foldDirector(.appShown(at: canvasClock.elapsed()))
            foregrounded()
        case .background:
            foldDirector(.appHidden(at: canvasClock.elapsed()))
            backgrounded()
        case .inactive:
            // The paused-clock tear argument holds on the app-switcher
            // transition too — but §4.2's backgrounding machinery is
            // `.background`-only (the trigger table gives `.inactive` no
            // row).
            foldDirector(.appHidden(at: canvasClock.elapsed()))
        @unknown default: break
        }
    }

    /// The interaction trigger (§4.2): the intent envelope (idempotency id,
    /// timestamp, attributed day key — D20/INV-10) is the facade's to
    /// assemble; the engine folds to the intent's own timestamp internally.
    /// Gesture/flow surfaces (TASK-032/033) route through here.
    func interact(_ kind: InteractionIntent.Kind) {
        let now = clock.now()
        let intent = InteractionIntent(
            id: UUID(),
            source: .iPhone,
            localDayKey: DayKey.make(from: now, calendar: calendar),
            timestamp: now,
            kind: kind
        )
        Task { await apply(trigger: .interaction(intent)) }
    }

    /// The character-report trigger (§4.2): submitted as-is; the engine
    /// folds to the clock's now internally. The character layer's report
    /// wiring routes through here.
    func submit(_ report: CharacterReport) {
        Task { await self.apply(trigger: .characterReport(report)) }
    }

    // (The canvas touch entries, the play-round entries, and the rig's
    // reaction-motion seam live in the same-target
    // `MomoAppModel+Canvas.swift` extension — TASK-039 R8's split.)

    /// Folds ONE presentation event into the director. The frozen `apply`
    /// is a mutating fold over a value type; the successor is built in a
    /// local copy and stored wholesale — the observable property changes
    /// once per event, never mid-fold. TASK-035 R1: every report the fold
    /// emitted drains out of the director and submits to the engine
    /// EXACTLY ONCE, in emission (causal) order — the drain clears the
    /// log, so a report can never be delivered twice, and reports emitted
    /// after this drain accumulate for the next one. Internal, not
    /// private: the same-target canvas extension
    /// (`MomoAppModel+Canvas.swift`, TASK-039 R8's disclosed extraction)
    /// folds the touch/play events through it.
    func foldDirector(_ event: MomoCharacterEvent) {
        var successor = director
        successor.apply(event)
        let emitted = successor.drainReports()
        director = successor
        for entry in emitted {
            submit(entry.report)
        }
    }

    // (The VoiceOver announcements and the quest-moments/celebrations
    // machinery live in the same-target `MomoAppModel+Canvas.swift` and
    // `MomoAppModel+Celebrations.swift` extensions — TASK-039 R8's split.)

    // MARK: The settings-extension seams (TASK-038; the disclosed extraction)

    /// TASK-038 R5.3's transient reset: every transient app-model
    /// presentation state returns to its post-init value — the boundary
    /// schedule, the play round's ticker/Done-pill machinery and its
    /// fingertip memory, the celebration banner and its auto-fade task, the
    /// quest-flip flourish and its task, the latest-care-moment memory, the
    /// open-touch guard. The erase path calls this BEFORE the fresh-state
    /// swap. The `canvasClock` needs no reset — it is monotonic and
    /// ambient-free, so post-erase events simply stamp at the current
    /// elapsed time. Internal: the same-target settings extension
    /// (`MomoAppModel+Settings.swift`) drives it; target-scoped only.
    func resetTransientPresentationState() {
        boundaryTask?.cancel()
        boundaryTask = nil
        playTickerTask?.cancel()
        playTickerTask = nil
        donePillTask?.cancel()
        donePillTask = nil
        isDonePillWindowOpen = false
        lastPlayFingertipOffset = nil
        celebrationTask?.cancel()
        celebrationTask = nil
        questFlipTask?.cancel()
        questFlipTask = nil
        activeCelebrationStage = nil
        celebratingQuests = []
        latestCareMoment = nil
        isTouchOpen = false
    }

    /// TASK-038 R5.3's in-memory fresh swap: the state and the reaction
    /// director return to the SAME fresh construction the init path uses —
    /// `freshDefaultState(clock:)`, single-sourced, so erase and
    /// fresh-install are indistinguishable (NFR-7). Deliberately NO
    /// persist here: the first write remains the onboarding completion
    /// write (`SnapshotStore.save` recreates the deleted directory).
    /// Internal: the settings extension calls it after the directory
    /// deletion and the transient reset.
    func installFreshDefaultState() {
        let fresh = Self.freshDefaultState(clock: clock)
        state = fresh
        director = MomoDirectorState(displayState: makeCharacterDisplayState(fresh))
    }

    // MARK: The apply loop (§4.1's fixed order — the one engine entry)

    /// Applies one trigger through the pure plan core, then performs the
    /// plan mechanically: step 0 apply → the steps in their fixed order →
    /// re-schedule the boundary from the folded state. The decision is ALL
    /// in `AppModelPlanCore.plan`; nothing here interprets the domain.
    /// Internal since TASK-038: the same-target settings extension's
    /// rename/haptics entries apply their triggers through this ONE loop
    /// (no side door), like every other trigger entry.
    func apply(trigger: AppModelTrigger) async {
        let plan = AppModelPlanCore.plan(
            state: state,
            trigger: trigger,
            clock: clock,
            calendar: calendar
        )
        // Step 0 — apply the new state.
        let previousState = state
        state = plan.appliedState
        // TASK-036 R3: the M1 flips — the day-record diff of THIS
        // application (completion never reverses — FR-16/TR5 — so the
        // one-way diff is total). `CharacterMoment.questCompleted` carries
        // no payload, so the card's per-row flourish and the done-state
        // announcements derive WHICH quest flipped from the state itself.
        // Memory only, latest-wins; a no-op on every flip-less trigger.
        recordQuestFlips(QuestMomentSupport.flippedQuests(
            before: previousState.days, after: state.days))
        // TASK-034 R4: the read-model feed. A display-state CHANGE (the
        // wakefulness transitions and L4 moment-request transitions §9.3
        // routes through this door) folds into the director on the canvas
        // timeline the rig samples. Equality-gated so the fold log carries
        // transitions only — the director's wake/settle choreography keys
        // off `displayState` edges, not steady states.
        let characterState = makeCharacterDisplayState(state)
        if characterState != director.displayState {
            foldDirector(.displayState(characterState, at: canvasClock.elapsed()))
        }
        // Exactly ONE next boundary from the folded state — scheduled BEFORE
        // the effect awaits below, so under two racing applies the surviving
        // schedule is always the one derived by the LATEST apply to start
        // (each plan reads the freshest applied state at its own start),
        // never a one-event-stale resume (REVIEW-TASK-031 MINOR-2).
        scheduleBoundary(from: plan)
        // The plan's steps, exactly once each, in the §4.1 fixed order.
        for step in plan.steps {
            switch step {
            case .persist:
                // Write-through persistence — off the main actor via the
                // store actor (§5.2; FR-13 AC-1 bounds loss to the in-flight
                // event).
                await store.save(plan.appliedState)
            case .deliverResponse(let response):
                // TASK-034: the engine's plan folds into the director —
                // the §6.1 clip the rig then plays through
                // `reactionMotion(at:reduceMotion:)` — and the reaction's
                // spoken line is announced under VoiceOver (R7/UX-8,
                // accessibility-only; TASK-035 widened the gate to all
                // four react families). TASK-035 R5: a visual care moment
                // (tuck-in settle / refusal / blanket-adjust) records as
                // the contextual line's top-priority line — memory only,
                // held until a newer care moment supersedes it.
                foldDirector(.plan(response, at: canvasClock.elapsed()))
                announceSpokenLine(for: response)
                if let moment = CareMoment.classify(response: response, state: state) {
                    latestCareMoment = moment
                }
                deliverResponse?(response)
            case .deliverMoments(let moments):
                // TASK-036 R1: the event-born door — the greeting stays on
                // the state-born `.displayState` `momentRequest` door (the
                // TASK-019 state-alone pin; this fold runs AFTER step 0's
                // displayState fold, so a fold-carried greeting starts
                // first and the event moments queue behind it). Everything
                // else folds FIFO into the director's L4 slot on the
                // canvas timeline; an empty remainder is a no-op.
                let eventBorn = QuestMomentSupport.eventBornMoments(moments)
                if !eventBorn.isEmpty {
                    foldDirector(.moments(eventBorn, at: canvasClock.elapsed()))
                }
                // R4: the M2 stage celebration — the banner state and its
                // VoiceOver full-line announcement (§5.6: the stage moment
                // is never visual-only).
                if let stage = QuestMomentSupport.celebrationStage(in: moments) {
                    showStageCelebration(stage)
                }
                // R7: the authored haptics — decided from the RAW batch
                // (the greeting on it fires nothing) and gated on the
                // user's setting read at delivery.
                for kind in MomentHapticKind.deliveryKinds(
                    for: moments,
                    hapticsEnabled: state.settings.hapticsEnabled
                ) {
                    momentHapticSink(kind)
                }
            case .pushWatchSnapshot:
                // RESERVED SEAM (EPIC-008): the Watch push is a documented
                // no-op this task — no WatchConnectivity code exists; the
                // transport hangs here when EPIC-008 lands.
                break
            }
        }
        // TASK-035 R2: reconcile the play round's presentation machinery
        // with the (possibly changed) engine state — the ticker and the
        // Done-pill window live exactly while a round is in flight.
        reconcilePlayPresentation()
    }

    // MARK: The play round machinery (TASK-035 R2)

    /// Aligns the stillness ticker and the Done-pill window with the
    /// engine's round-in-flight truth: both start together at the round's
    /// start (the authorization's state application lands here) and both
    /// stop when the round ends by ANY path — the Done tap, a solo
    /// completion, an app-hide cancellation, a tuck-in preemption.
    private func reconcilePlayPresentation() {
        if isPlayRoundInFlight {
            guard playTickerTask == nil else { return }
            lastPlayFingertipOffset = nil
            isDonePillWindowOpen = false
            playTickerTask = Task { await runPlayTicker() }
            donePillTask = Task { await openDonePillWindow() }
        } else {
            playTickerTask?.cancel()
            playTickerTask = nil
            donePillTask?.cancel()
            donePillTask = nil
            isDonePillWindowOpen = false
            lastPlayFingertipOffset = nil
        }
    }

    /// The stillness ticker: while the round is in flight, folds a
    /// `moving: false` fingertip sample every second (the authored
    /// `playTickerSeconds`), resuming from the last real fingertip offset.
    /// This is what lets a passive round complete — the pacer reads the
    /// stillness, resolves the solo wind-down, plays the payoff, and
    /// reports `playRoundFinished`, which drains into the engine's unified
    /// cease and ends the round (this loop's own exit, via the reconcile).
    private func runPlayTicker() async {
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(Self.playTickerSeconds))
            guard !Task.isCancelled else { return }
            guard isPlayRoundInFlight else { return }
            foldDirector(.fingertip(
                offset: lastPlayFingertipOffset ?? .zero,
                moving: false,
                at: canvasClock.elapsed()))
        }
    }

    /// The Done-pill window: ~5 s (the authored `donePillDelaySeconds`,
    /// 03 §5.3's "~5 s") after the round's start the window opens and the
    /// pill becomes visible. Real-time sleep — works under any clock. The
    /// window never opens for an already-ended round.
    private func openDonePillWindow() async {
        try? await Task.sleep(for: .seconds(Self.donePillDelaySeconds))
        guard !Task.isCancelled, isPlayRoundInFlight else { return }
        isDonePillWindowOpen = true
    }

    // MARK: Scheduling (§4.2 — see the type header's mechanism resolution)

    /// Cancels any live schedule and derives the next one from the plan
    /// (re-schedule, never replay). Nil boundary (the degenerate-calendar
    /// caveat) schedules nothing rather than fabricating an instant.
    private func scheduleBoundary(from plan: AppModelPlan) {
        boundaryTask?.cancel()
        guard let boundary = plan.nextBoundary else {
            boundaryTask = nil
            return
        }
        let delay = max(0, boundary.instant.timeIntervalSince(clock.now()))
        boundaryTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self, self.isForeground else { return }
            await self.apply(trigger: .scheduledBoundary(instant: boundary.instant))
        }
    }

    // MARK: Trigger internals

    private func foregrounded() {
        isForeground = true
        Task { await self.apply(trigger: .foreground(now: self.clock.now())) }
    }

    private func backgrounded() {
        // A boundary scheduled before backgrounding simply does not matter
        // (§4.2): cancelled here, refused by the foreground guard, and the
        // process suspends regardless. No replay — the next foreground fold
        // catches up.
        isForeground = false
        boundaryTask?.cancel()
        boundaryTask = nil
    }

    private func significantTimeChangeOccurred() {
        // The app layer is the calendar's injection point: re-derive it
        // (§4.2's "re-derive dayKey" row), then the catch-up fold.
        calendar = .current
        Task { await self.apply(trigger: .significantTimeChange(now: self.clock.now())) }
    }

    // MARK: The injected fresh default (05 §5.3)

    /// The pre-onboarding carrier injected as the store's fresh default —
    /// served on total absence AND (invisibly, §5.3) on total corruption.
    /// MomoCore owns no initial-state factory by design (the default is the
    /// CALLER's to inject); the REAL initial state — the pet identity minted
    /// at the Enter tap, the first day record, the greeting flow — is
    /// onboarding's (TASK-032). Every field here is valid by construction
    /// (INV-1/2/3 failable inits over in-range values); the name is the
    /// product name, carried but never displayed by this task's shell.
    private static func freshDefaultState(clock: any EngineClock) -> EngineState {
        let now = clock.now()
        return EngineState(
            pet: Pet(id: UUID(), name: "Momo", createdAt: now)!,
            state: PetState(
                mood: 70,
                energy: 80,
                bond: Thresholds.Bond.minimum,
                wakefulness: .awake,
                activity: nil,
                lastFedAt: nil,
                satietyPhase: .hungry
            )!,
            days: [],
            settings: SettingsState(onboardingComplete: false, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: now,
            lastEvaluatedAt: now,
            lastGreeting: nil
        )
    }

    /// The `MomoCopy` DEBUG-loud discipline: invariant regressions trip the
    /// debugger in debug builds and stay silent in release. Internal since
    /// TASK-038: the same-target settings extension rejects its invalid
    /// inputs through the same discipline.
    static func debugLoud(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
