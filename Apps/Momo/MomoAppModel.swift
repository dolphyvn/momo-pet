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

    /// The production time source (05 §4.10) — every engine time read
    /// in the executor flows through it.
    private let clock: any EngineClock

    /// The presentation-owned character clock (TASK-032 R12; EPIC-006's
    /// view API): ONE clock for the whole session, fed by the same injected
    /// time source as the engine, handed to every `MomoRigView` host. The
    /// view manages its own pause/resume on scene phase; TASK-033's
    /// director/report wiring reuses this same clock.
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
    /// greeting animation"; director/moments wiring is TASK-033's.
    var characterDisplayState: CharacterDisplayState {
        makeCharacterDisplayState(state)
    }

    /// The Home composition's read-model (TASK-033 R2; UX §5.1): mirrors
    /// `displayState` — the same (state, now, calendar) inputs through
    /// MomoKit's `makeHomeReadModel`, so the Home view binds through the app
    /// model and never the engine (D-R5).
    var homeReadModel: HomeReadModel {
        makeHomeReadModel(state, at: clock.now(), calendar: calendar)
    }

    /// The UI-facing delivery seam (§4.1's fixed order, steps 2–3): the
    /// shell hosts these closures; the character layer's full wiring is
    /// TASK-032/033. Exactly-once invocation is the plan-loop's guarantee.
    var deliverResponse: ((ResponsePlan) -> Void)?
    var deliverMoments: (([CharacterMoment]) -> Void)?

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
        self.state = store.load(fallback: freshDefault ?? Self.freshDefaultState(clock: clock))
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
    /// triggers nothing in §4.2's table.
    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .active: foregrounded()
        case .background: backgrounded()
        case .inactive: break
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

    /// The onboarding completion tap (TASK-032 R5; FR-1 AC-2, FR-13 AC-1):
    /// mints the final pet identity AT THE TAP (the injected UUID keeps the
    /// plan core pure and determinism testable) and applies the completion
    /// trigger — the transformation whose `.persist` step is the atomic
    /// completion write. The S2 button's disabled state is INV-1's product
    /// face (whitespace-only names never reach here enabled); a violation
    /// now is an invariant regression — DEBUG-loud, inert in release (no
    /// plan applied, nothing persisted, the gate keeps the flow on S2).
    func completeOnboarding(name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            Self.debugLoud("MomoAppModel: onboarding completion rejected a whitespace-only name")
            return
        }
        Task { await self.apply(trigger: .onboardingCompleted(petID: UUID(), name: trimmed)) }
    }

    // MARK: The apply loop (§4.1's fixed order — the one engine entry)

    /// Applies one trigger through the pure plan core, then performs the
    /// plan mechanically: step 0 apply → the steps in their fixed order →
    /// re-schedule the boundary from the folded state. The decision is ALL
    /// in `AppModelPlanCore.plan`; nothing here interprets the domain.
    private func apply(trigger: AppModelTrigger) async {
        let plan = AppModelPlanCore.plan(
            state: state,
            trigger: trigger,
            clock: clock,
            calendar: calendar
        )
        // Step 0 — apply the new state.
        state = plan.appliedState
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
                deliverResponse?(response)
            case .deliverMoments(let moments):
                deliverMoments?(moments)
            case .pushWatchSnapshot:
                // RESERVED SEAM (EPIC-008): the Watch push is a documented
                // no-op this task — no WatchConnectivity code exists; the
                // transport hangs here when EPIC-008 lands.
                break
            }
        }
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
    /// debugger in debug builds and stay silent in release.
    private static func debugLoud(_ message: String) {
        #if DEBUG
        assertionFailure(message)
        #endif
    }
}
