import Foundation
import MomoCore

// MARK: - AppModelPlan — the §4.1 fixed-order effect plan (TASK-031;
// 05-technical-architecture §4.1–§4.2)

/// The value-typed result of ONE application of the app model: the engine
/// outcome wrapped as the ordered, side-effect-free plan the executor
/// mechanically performs (05 §4.1: "The app model wraps `reduce` with the
/// side effects in fixed order: apply `newState` → persist if `changed` →
/// deliver `response`/`moments` to the character layer → push snapshot to
/// Watch if `changed`").
///
/// **The plan's steps are already the fixed order** — the executor iterates
/// `steps` in array order and performs each once; delivery is exactly-once
/// per application BY CONSTRUCTION (one array, consumed top to bottom).
/// `apply newState` is not a step: it is the executor's step 0 (the state
/// becomes the app model's state before any effect runs) — the plan carries
/// it as `appliedState`.
///
/// **Persist IFF changed, push IFF changed.** `changed == false` ⇒ neither
/// `.persist` nor `.pushWatchSnapshot` appears, but response/moments steps
/// still appear when the engine produced them (a declined interaction with
/// zero state effect still speaks — the steps below make that case
/// representable and pinned).
///
/// **The Watch-push slot is a RESERVED SEAM (EPIC-008).** `.pushWatchSnapshot`
/// exists as a documented no-op at the executor: NO WatchConnectivity code,
/// NO `WatchSnapshotBuilder` calls — the transport lands with EPIC-008 and
/// this step is where it hangs. The step's presence in changed plans is
/// pinned so the seam cannot silently vanish.
public struct AppModelPlan: Equatable, Sendable {

    /// One ordered side effect (05 §4.1's fixed order).
    public enum Step: Equatable, Sendable {

        /// Write-through persistence (`SnapshotStore.save(appliedState)`) —
        /// present IFF the engine reported `changed`.
        case persist

        /// Deliver the interaction's response plan to the character layer —
        /// present IFF the outcome carried one.
        case deliverResponse(ResponsePlan)

        /// Deliver the outcome's moments (greeting / questCompleted /
        /// bondStageReached) to the character layer — present IFF non-empty.
        case deliverMoments([CharacterMoment])

        /// Push the snapshot to the Watch — present IFF `changed`. RESERVED
        /// SEAM ONLY (EPIC-008): the executor performs this as a documented
        /// no-op this task.
        case pushWatchSnapshot
    }

    /// The state after the event — the executor's step 0 (apply).
    public let appliedState: EngineState

    /// The ordered effects, already in §4.1's fixed order.
    public let steps: [Step]

    /// The ONE next in-session boundary computed from the folded state
    /// (05 §4.2) — the executor re-schedules from this after applying the
    /// plan (never replaying the previous schedule). Nil only under the
    /// `NextBoundaryRules.next` degenerate-calendar caveat.
    public let nextBoundary: NextBoundary?

    public init(appliedState: EngineState, steps: [Step], nextBoundary: NextBoundary?) {
        self.appliedState = appliedState
        self.steps = steps
        self.nextBoundary = nextBoundary
    }
}

// MARK: - Trigger table (05 §4.2's five app-layer triggers)

/// 05 §4.2's trigger table, as values. The plan core maps each trigger to
/// the engine event the engine's own documented interface prescribes —
/// **fold-to-now is never synthesized here**: `.interaction` folds internally
/// to the intent's own timestamp and `.characterReport` folds to the clock's
/// `now()` (the `reduce` header is the authority). The facade's obligation
/// for those triggers is CORRECT SUBMISSION, and the tests pin the observable
/// (the facade's composition equals the manual reduce composition, step for
/// step and seed for seed).
///
/// Foreground / significant-time-change / scheduled-boundary triggers carry
/// the instant the EXECUTIVE read from the injected clock (or scheduled);
/// every engine time read still flows through an `EngineClock` — the
/// executor owns the reads, the plan core stays ambient-free.
public enum AppModelTrigger: Sendable {

    /// Foreground / scenePhase → active: the full catch-up fold — the open
    /// (`lastOpenedAt`, absence greeting), rollover, missed night/wake.
    case foreground(now: Instant)

    /// A user interaction (either device's intent, once delivered here):
    /// submitted as-is; the engine folds to `intent.timestamp` internally.
    case interaction(InteractionIntent)

    /// The character's completion/cancellation report: submitted as-is; the
    /// engine folds to `clock.now()` internally (its one clock read).
    case characterReport(CharacterReport)

    /// The scheduled boundary evaluation firing — the event folds to the
    /// boundary's OWN instant (not the wake-up instant), so a few
    /// milliseconds of scheduler slack never shift the fold target.
    case scheduledBoundary(instant: Instant)

    /// An OS significant time change (timezone/clock-change notification):
    /// re-folds at the current instant; the executor re-derives the local
    /// calendar before submitting (§4.2's "re-derive dayKey" row).
    case significantTimeChange(now: Instant)

    /// The onboarding Enter tap (TASK-032; FR-1 AC-2, FR-13 AC-1): the
    /// executor mints the final pet identity AT THE TAP and passes it in, so
    /// the plan core stays pure — no ambient randomness; determinism is
    /// testable with injected UUIDs. NOT an engine-routed trigger: `plan`
    /// dispatches it to the pure completion transformation (the settings
    /// flag and the pet identity ONLY — grants nothing, UX-6) without
    /// calling `reduce`, so no engine event exists for it and no response
    /// or moments are emitted. The executor sends it at most once (the
    /// onboarding gate makes a second send unreachable); the transformation
    /// itself is unconditional — applied to an already-complete state it
    /// still re-mints per the trigger and persists again (the pinned
    /// idempotence stance, disclosed in the completion tests).
    case onboardingCompleted(petID: UUID, name: String)
}

// MARK: - The plan core

/// The app model's PURE decision core (05 §4.1's "single evaluation entry
/// point" for the app layer): `(state, trigger, clock, calendar) → plan`.
/// No I/O, no timers, no actor, no SwiftUI (D-R2) — the executor performs
/// the plan's steps. Pure enough to run under `swift test` headlessly (the
/// 05 §10.1 architecture has no app-unit-test target; this split is that
/// constraint's whole point).
///
/// **Seed convention (05 §4.10; recorded here per Requirement 5).** The
/// engine derives its day-stable seeds internally for the fold's quest
/// domain and the interaction path's copy domain; the CHOREOGRAPHY stream
/// (the token-minting rng threaded through `reduce`'s `inout` parameter) is
/// the app layer's to seed, per the `reduce` header: a fresh
/// `SeededGenerator` seeded from `DaySeed.make(petID:localDayKey:epoch:
/// salt: .choreography)` per application — pet identity from the state, the
/// local day key of the application's fold instant (`DayKey.make` over the
/// injected calendar), and `AppModelPlanCore.choreographyEpoch`. The facade
/// performs NO other seed arithmetic — derivation lives in MomoCore's
/// `DaySeed`, the generator in MomoCore's `SeededGenerator`; this file only
/// assembles the documented call.
public enum AppModelPlanCore {

    /// The choreography stream's epoch (05 §4.10: "epoch = choreographyEpoch,
    /// changes only when the idle-variant catalog changes — 04 §5.1"). The
    /// character module does not yet own a code constant for this epoch (the
    /// idle-variant catalog is later EPIC-007/008 surface), so the app-model
    /// layer single-sources it here: THE one home — when the catalog lands
    /// its own epoch, this is the constant that re-points or merges.
    /// Starting value 1 (initial catalog), matching the other domains'
    /// epoch-1 starts (`CopyRules.copyEpoch`, `QuestGeneration.currentEpoch`).
    public static let choreographyEpoch = 1

    /// The choreography seed for one application (the documented convention,
    /// extracted so the tests can pin the composition seed-for-seed).
    public static func choreographySeed(
        petID: UUID,
        instant: Instant,
        calendar: Calendar
    ) -> UInt64 {
        DaySeed.make(
            petID: petID,
            localDayKey: DayKey.make(from: instant, calendar: calendar),
            epoch: choreographyEpoch,
            salt: .choreography
        )
    }

    /// Applies the app model: routes the trigger through the engine's own
    /// interface, then wraps the outcome as the fixed-order plan (see
    /// `AppModelPlan`'s header for the order and the IFF rules).
    ///
    /// The onboarding-completion trigger is dispatched BEFORE the engine
    /// path: it is not engine-routed (no `reduce`, no `EngineEvent` — the
    /// completion grants nothing, UX-6/R6) — see `onboardingPlan`.
    public static func plan(
        state: EngineState,
        trigger: AppModelTrigger,
        clock: any EngineClock,
        calendar: Calendar
    ) -> AppModelPlan {
        if case .onboardingCompleted(let petID, let name) = trigger {
            return onboardingPlan(
                state: state,
                petID: petID,
                name: name,
                clock: clock,
                calendar: calendar
            )
        }
        let event = engineEvent(for: trigger, clock: clock)
        let foldInstant = foldInstant(for: trigger, clock: clock)
        var rng = SeededGenerator(
            seed: choreographySeed(petID: state.pet.id, instant: foldInstant, calendar: calendar)
        )
        let outcome = reduce(state, event, clock: clock, calendar: calendar, rng: &rng)
        var steps: [AppModelPlan.Step] = []
        if outcome.changed { steps.append(.persist) }
        if let response = outcome.response { steps.append(.deliverResponse(response)) }
        if !outcome.moments.isEmpty { steps.append(.deliverMoments(outcome.moments)) }
        if outcome.changed { steps.append(.pushWatchSnapshot) }
        return AppModelPlan(
            appliedState: outcome.newState,
            steps: steps,
            nextBoundary: NextBoundaryRules.next(
                from: foldInstant,
                state: outcome.newState,
                calendar: calendar
            )
        )
    }

    // MARK: Trigger → engine-event routing (see `AppModelTrigger`'s header)

    private static func engineEvent(
        for trigger: AppModelTrigger,
        clock: any EngineClock
    ) -> EngineEvent {
        switch trigger {
        case .foreground(let now): return .evaluate(now: now)
        case .interaction(let intent): return .interaction(intent)
        case .characterReport(let report): return .characterReport(report)
        case .scheduledBoundary(let instant): return .evaluate(now: instant)
        case .significantTimeChange(let now): return .evaluate(now: now)
        case .onboardingCompleted:
            // Unreachable: `plan` dispatches `.onboardingCompleted` to
            // `onboardingPlan` BEFORE this routing table is consulted — the
            // completion is not engine-routed (no `EngineEvent` exists for a
            // transformation that grants nothing, R6/UX-6). The arm exists
            // to satisfy exhaustiveness; the clock-sourced fallback keeps
            // the function total without an ambient time read (the
            // QuestTick house shape).
            assertionFailure("AppModelPlanCore: onboarding trigger reached engine-event routing — invariant regression")
            return .evaluate(now: clock.now())
        }
    }

    /// The application's fold instant — the seed's day-key source and the
    /// next-boundary derivation's `now`. Interaction/report folds are the
    /// ENGINE's to target (intent timestamp / clock read, per `reduce`);
    /// this mirrors those targets ONLY for seeding and scheduling.
    private static func foldInstant(
        for trigger: AppModelTrigger,
        clock: any EngineClock
    ) -> Instant {
        switch trigger {
        case .foreground(let now): return now
        case .interaction(let intent): return intent.timestamp
        case .characterReport: return clock.now()
        case .scheduledBoundary(let instant): return instant
        case .significantTimeChange(let now): return now
        case .onboardingCompleted: return clock.now()
        }
    }

    // MARK: The onboarding completion (TASK-032; FR-1 AC-2, FR-13 AC-1)

    /// The completion transformation (R5/R6): the settings flag → true and
    /// the pet re-minted at the fold instant — and NOTHING else (the whole
    /// remaining state carries over field-for-field, so the completion
    /// grants no bond, no counters, no day records, no greeting stamp, no
    /// stage ceiling, no intent ledger change — UX §3's "Post-onboarding").
    /// No engine event exists for it: `reduce` is never called, no response
    /// or moments are emitted.
    ///
    /// The outcome is `changed` ⇒ the fixed-order steps are
    /// EXACTLY `[.persist, .pushWatchSnapshot]` — the persist IS the atomic
    /// completion write of FR-13 AC-1; the Watch push is the reserved
    /// EPIC-008 no-op. The trigger is unconditional (applied to an
    /// already-complete state it still re-mints per the trigger and
    /// persists again — the executor never sends it twice; the gate makes a
    /// second send unreachable).
    ///
    /// The `Pet` failable init (INV-1) is re-honored as a second guard: a
    /// whitespace-only name cannot mint a pet, so the plan falls back to
    /// the UNCHANGED state with NO steps (nothing persisted — a no-op
    /// completion). Unreachable from the product flow: the executor trims
    /// and rejects whitespace-only names at the tap, and the S2 button is
    /// disabled for them (INV-1's UI face).
    private static func onboardingPlan(
        state: EngineState,
        petID: UUID,
        name: String,
        clock: any EngineClock,
        calendar: Calendar
    ) -> AppModelPlan {
        let foldInstant = clock.now()
        guard let pet = Pet(id: petID, name: name, createdAt: foldInstant) else {
            return AppModelPlan(
                appliedState: state,
                steps: [],
                nextBoundary: NextBoundaryRules.next(
                    from: foldInstant,
                    state: state,
                    calendar: calendar
                )
            )
        }
        let completed = EngineState(
            pet: pet,
            state: state.state,
            days: state.days,
            settings: SettingsState(
                onboardingComplete: true,
                hapticsEnabled: state.settings.hapticsEnabled
            ),
            pendingHandshake: state.pendingHandshake,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: state.lastOpenedAt,
            lastEvaluatedAt: state.lastEvaluatedAt,
            lastGreeting: state.lastGreeting
        )
        return AppModelPlan(
            appliedState: completed,
            steps: [.persist, .pushWatchSnapshot],
            nextBoundary: NextBoundaryRules.next(
                from: foldInstant,
                state: completed,
                calendar: calendar
            )
        )
    }
}
