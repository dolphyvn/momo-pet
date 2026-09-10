import Testing
import Foundation
@testable import MomoKit
@testable import MomoCore

/// The onboarding-completion suites (TASK-032; FR-1 AC-2, FR-13 AC-1; the
/// task's R5/R6): the sixth trigger's transformation over the fresh
/// carrier — the atomic flag write and the pet re-mint, the grants-nothing
/// field pins, the completion path's purity/determinism, the second INV-1
/// guard, the disclosed idempotence stance, and the trigger-set census.
/// All time literal over injected clocks/calendars; all identity injected
/// (the executor mints the UUID at the real tap — the plan core stays
/// ambient-free).
@Suite
struct AppModelOnboardingPlanTests {

    private let calendar = AppModelFixture.calendar()

    /// The completion tests' carrier mint / fold instant: mid-morning UTC,
    /// awake, so the derived boundary is the same-day night onset.
    private var mintInstant: Instant {
        AppModelFixture.instant("2026-03-03T09:00:00Z")
    }

    private func completionClock() -> ManualEngineClock {
        ManualEngineClock(at: mintInstant)
    }

    // MARK: The completion transform (Required Test 1)

    /// The Enter tap's plan: the flag flips, the pet re-mints with the
    /// injected identity at the fold instant, and the §4.1 emission rules
    /// yield steps EXACTLY [persist → the reserved Watch seam] — no
    /// response, no moments (the completion grants nothing, R6).
    @Test("completion: flag true, pet re-minted, steps exactly persist → watch seam")
    func completionTransform() {
        let plan = AppModelPlanCore.plan(
            state: AppModelFixture.freshCarrier(at: mintInstant),
            trigger: .onboardingCompleted(petID: AppModelFixture.onboardedPetID, name: "Mochi"),
            clock: completionClock(),
            calendar: calendar
        )
        #expect(plan.appliedState.settings.onboardingComplete)
        #expect(plan.appliedState.pet.id == AppModelFixture.onboardedPetID)
        #expect(plan.appliedState.pet.name == "Mochi")
        #expect(plan.appliedState.pet.createdAt == mintInstant)
        #expect(plan.steps == [.persist, .pushWatchSnapshot])
        // The next boundary derives from the COMPLETED state (awake pet):
        // the same-day night onset.
        #expect(plan.nextBoundary == NextBoundary(
            kind: .nightOnset,
            instant: AppModelFixture.instant("2026-03-03T22:00:00Z")
        ))
    }

    // MARK: Grants nothing (Required Test 2; R6/AC-6)

    /// Whole-state diff outside {settings flag, pet identity} is EMPTY —
    /// asserted field-by-field: no bond, no counters, no day fabrication
    /// (the ledger stays empty; `rollover` owns records), no greeting
    /// stamp, no stage-ceiling movement, no intent-ledger or handshake
    /// change, the stamps and haptics carried, every `PetState` field
    /// carried.
    @Test("grants nothing: every field outside {flag, pet identity} carries over")
    func grantsNothing() {
        let carrier = AppModelFixture.freshCarrier(at: mintInstant)
        let plan = AppModelPlanCore.plan(
            state: carrier,
            trigger: .onboardingCompleted(petID: AppModelFixture.onboardedPetID, name: "Mochi"),
            clock: completionClock(),
            calendar: calendar
        )
        let after = plan.appliedState
        // The two intended writes.
        #expect(after.settings.onboardingComplete)
        #expect(after.pet.id == AppModelFixture.onboardedPetID)
        #expect(after.pet.name == "Mochi")
        // Everything else, field-by-field:
        #expect(after.state == carrier.state)
        #expect(after.state.bond == carrier.state.bond)
        #expect(after.state.mood == carrier.state.mood)
        #expect(after.state.energy == carrier.state.energy)
        #expect(after.state.wakefulness == carrier.state.wakefulness)
        #expect(after.state.activity == carrier.state.activity)
        #expect(after.state.lastFedAt == carrier.state.lastFedAt)
        #expect(after.state.satietyPhase == carrier.state.satietyPhase)
        #expect(after.days == carrier.days)
        #expect(after.days.isEmpty)
        #expect(after.settings.hapticsEnabled == carrier.settings.hapticsEnabled)
        #expect(after.pendingHandshake == carrier.pendingHandshake)
        #expect(after.pendingHandshake == nil)
        #expect(after.processedIntents == carrier.processedIntents)
        #expect(after.processedIntents.isEmpty)
        #expect(after.highestCelebratedStage == carrier.highestCelebratedStage)
        #expect(after.lastOpenedAt == carrier.lastOpenedAt)
        #expect(after.lastEvaluatedAt == carrier.lastEvaluatedAt)
        #expect(after.lastGreeting == carrier.lastGreeting)
        #expect(after.lastGreeting == nil)
        // REVIEW-TASK-032 NOTE-2 hardening: the fresh carrier's days are
        // EMPTY, so the asserts above cannot distinguish "carried" from
        // "reset to empty" — the populated fixture makes the days-carry
        // pin bite a `days: []` mutation on its own.
        let populated = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: mintInstant,
            lastOpenedAt: mintInstant
        )
        #expect(!populated.days.isEmpty)
        let populatedPlan = AppModelPlanCore.plan(
            state: populated,
            trigger: .onboardingCompleted(petID: AppModelFixture.onboardedPetID, name: "Mochi"),
            clock: completionClock(),
            calendar: calendar
        )
        #expect(populatedPlan.appliedState.days == populated.days)
    }

    // MARK: Purity / determinism (Required Test 3)

    /// Identical (state, trigger, clock, calendar) ⇒ identical plan; the
    /// injected identity is the only mint — a different UUID yields a
    /// different pet and a different plan, with no ambient randomness
    /// anywhere in the completion path.
    @Test("purity: identical inputs ⇒ identical plan; a different injected id ⇒ a different pet")
    func determinism() {
        let carrier = AppModelFixture.freshCarrier(at: mintInstant)
        let trigger = AppModelTrigger.onboardingCompleted(
            petID: AppModelFixture.onboardedPetID,
            name: "Mochi"
        )
        let first = AppModelPlanCore.plan(
            state: carrier, trigger: trigger, clock: completionClock(), calendar: calendar
        )
        let second = AppModelPlanCore.plan(
            state: carrier, trigger: trigger, clock: completionClock(), calendar: calendar
        )
        #expect(first == second)
        let other = AppModelPlanCore.plan(
            state: carrier,
            trigger: .onboardingCompleted(
                petID: AppModelFixture.onboardedPetIDOther,
                name: "Mochi"
            ),
            clock: completionClock(),
            calendar: calendar
        )
        #expect(first != other)
        #expect(first.appliedState.pet.id == AppModelFixture.onboardedPetID)
        #expect(other.appliedState.pet.id == AppModelFixture.onboardedPetIDOther)
    }

    // MARK: The second INV-1 guard

    /// A whitespace-only name cannot mint a pet (INV-1's failable init) —
    /// the plan core's guard falls back to the UNCHANGED state with NO
    /// steps (nothing persisted). Unreachable from the product flow: the
    /// executor trims and rejects at the tap, and the S2 button is
    /// disabled for whitespace-only input.
    @Test("whitespace-only name: no pet mints, empty plan, state untouched")
    func whitespaceNameIsTheSecondGuard() {
        let carrier = AppModelFixture.freshCarrier(at: mintInstant)
        let plan = AppModelPlanCore.plan(
            state: carrier,
            trigger: .onboardingCompleted(petID: AppModelFixture.onboardedPetID, name: "   "),
            clock: completionClock(),
            calendar: calendar
        )
        #expect(plan.steps.isEmpty)
        #expect(plan.appliedState == carrier)
        #expect(!plan.appliedState.settings.onboardingComplete)
    }

    // MARK: The idempotence stance (Required Test 4, disclosed)

    /// The DISCLOSED stance: the trigger is UNCONDITIONAL. Applied to an
    /// already-complete state it still re-mints per the trigger (identity
    /// and createdAt re-derived at THIS trigger's fold instant) and yields
    /// the changed plan. The mutation set is exactly {settings flag, pet}
    /// on an already-complete carrier too — the flag has no second writer
    /// and the core second-guesses no caller. The executor never sends it
    /// twice: the gate makes a second send unreachable.
    @Test("already-complete: the trigger still re-mints (unconditional; executor sends once)")
    func alreadyCompleteStillReMints() {
        let later = AppModelFixture.instant("2026-03-03T15:00:00Z")
        let completed = AppModelFixture.state(
            dayKey: "2026-03-03",
            lastEvaluatedAt: mintInstant,
            lastOpenedAt: mintInstant
        )
        let plan = AppModelPlanCore.plan(
            state: completed,
            trigger: .onboardingCompleted(petID: AppModelFixture.onboardedPetID, name: "Mochi"),
            clock: ManualEngineClock(at: later),
            calendar: calendar
        )
        #expect(plan.steps == [.persist, .pushWatchSnapshot])
        #expect(plan.appliedState.settings.onboardingComplete)
        #expect(plan.appliedState.pet.id == AppModelFixture.onboardedPetID)
        #expect(plan.appliedState.pet.name == "Mochi")
        #expect(plan.appliedState.pet.createdAt == later)
        // Outside {flag, pet}: carried, exactly as on the fresh carrier.
        #expect(plan.appliedState.days == completed.days)
        #expect(plan.appliedState.state == completed.state)
        #expect(plan.appliedState.processedIntents == completed.processedIntents)
        #expect(plan.appliedState.pendingHandshake == completed.pendingHandshake)
        #expect(plan.appliedState.highestCelebratedStage == completed.highestCelebratedStage)
        #expect(plan.appliedState.lastOpenedAt == completed.lastOpenedAt)
        #expect(plan.appliedState.lastEvaluatedAt == completed.lastEvaluatedAt)
        #expect(plan.appliedState.lastGreeting == completed.lastGreeting)
    }

    // MARK: The census (Required Test 5)

    /// The trigger's full case set, mapped through an exhaustive,
    /// default-free switch: a seventh case breaks this BUILD — the census
    /// law's belt, now covering the sixth case too.
    @Test("trigger census: six cases, exhaustively handled")
    func triggerCensus() {
        let minted = mintInstant
        let cases: [AppModelTrigger] = [
            .foreground(now: minted),
            .interaction(AppModelFixture.intent(
                dayKey: "2026-03-03",
                timestamp: minted,
                kind: .play
            )),
            .characterReport(.settleFinished),
            .scheduledBoundary(instant: minted),
            .significantTimeChange(now: minted),
            .onboardingCompleted(petID: AppModelFixture.onboardedPetID, name: "Mochi"),
        ]
        #expect(cases.count == 6)
        #expect(cases.map(label(of:)) == [
            "foreground",
            "interaction",
            "characterReport",
            "scheduledBoundary",
            "significantTimeChange",
            "onboardingCompleted",
        ])
    }

    /// Exhaustive, default-free — the compiler is the census.
    private func label(of trigger: AppModelTrigger) -> String {
        switch trigger {
        case .foreground: return "foreground"
        case .interaction: return "interaction"
        case .characterReport: return "characterReport"
        case .scheduledBoundary: return "scheduledBoundary"
        case .significantTimeChange: return "significantTimeChange"
        case .onboardingCompleted: return "onboardingCompleted"
        }
    }
}
