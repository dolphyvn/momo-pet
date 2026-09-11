import Testing
import Foundation
import MomoCore
@testable import MomoKit

/// The pat plan's bond semantics at the facade layer (TASK-034's G2
/// reading): pats are an emotional-companion surface, not a bond pump —
/// the day's first pat awards the once-daily hello (+8) and nothing else,
/// and every later pat moves ZERO bond. The quest tick a counting pat
/// carries (TASK-018) is the interaction-counting contract, not touch
/// economics — pinned here as the +4 rider it is. The fixture day record
/// carries zeroed quests with `helloAwarded: false`, so the FIRST pat
/// exercises the full first-touch shape (hello + Q1 completion) and the
/// SECOND pins the steady state.
@Suite("Pat plan bond semantics — the zero-bond pin (TASK-034)")
struct PatPlanBondTests {

    private let calendar = AppModelFixture.calendar()
    private let day = "2026-09-08"

    private func patPlan(
        from state: EngineState,
        id: UUID,
        at instant: Instant
    ) -> AppModelPlan {
        AppModelPlanCore.plan(
            state: state,
            trigger: .interaction(AppModelFixture.intent(
                id: id,
                dayKey: day,
                timestamp: instant,
                kind: .pat(gesture: .tap, zone: .head)
            )),
            clock: ManualEngineClock(at: instant),
            calendar: calendar
        )
    }

    private func response(of plan: AppModelPlan) -> ResponsePlan? {
        plan.steps.compactMap { step in
            if case .deliverResponse(let response) = step { return response }
            return nil
        }.first
    }

    @Test("the day's first pat: +8 hello once (+4 quest rider), the touch key, the counted pat")
    func firstPatAwardsHelloExactlyOnce() {
        let start = AppModelFixture.state(
            dayKey: day,
            lastEvaluatedAt: AppModelFixture.instant("2026-09-08T09:00:00Z")
        )
        #expect(start.days.first?.helloAwarded == false, "fixture sanity: the day has not yet said hello")

        let first = patPlan(
            from: start,
            id: AppModelFixture.intentID1,
            at: AppModelFixture.instant("2026-09-08T09:00:30Z")
        )

        // The hello, exactly once: +8, then the day's flag is set.
        #expect(first.appliedState.days.first?.helloAwarded == true)
        // The counting rider: the first pat ticks the fixture set's Q1 to
        // completion (+4) and emits its moment — the interaction-counting
        // contract, not touch economics.
        #expect(first.appliedState.state.bond
            == start.state.bond + BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(first.appliedState.days.first?.patCount == 1)

        // The plan carries the day-stable touch line key (epoch 3's .02
        // draw over this fixture's (petID, day)) — the announcement seam's
        // input.
        #expect(response(of: first)?.lineKey == "momo.line.react.touch.02")
    }

    @Test("every later pat moves zero bond (G2: petting is not a bond pump)")
    func secondPatMovesZeroBond() {
        let start = AppModelFixture.state(
            dayKey: day,
            lastEvaluatedAt: AppModelFixture.instant("2026-09-08T09:00:00Z")
        )
        let first = patPlan(
            from: start,
            id: AppModelFixture.intentID1,
            at: AppModelFixture.instant("2026-09-08T09:00:30Z")
        )
        let second = patPlan(
            from: first.appliedState,
            id: AppModelFixture.intentID2,
            at: AppModelFixture.instant("2026-09-08T09:01:30Z")
        )

        // THE pin: bond after pat 2 == bond after pat 1. N pats beyond the
        // day's hello move nothing (the quest rider is spent with Q1).
        #expect(second.appliedState.state.bond == first.appliedState.state.bond)
        #expect(second.appliedState.days.first?.bondAwarded == first.appliedState.days.first?.bondAwarded)

        // Counting stays honest (I-1): the pat counted even though the
        // bond did not move.
        #expect(second.appliedState.days.first?.patCount == 2)

        // The line key is day-stable across the day's pats.
        #expect(response(of: second)?.lineKey == response(of: first)?.lineKey)
    }
}
