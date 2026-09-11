import Testing
import Foundation
@testable import MomoKit
import MomoCore

// MARK: - CareMomentTests — the visual care-moment class's pins (TASK-035 R5;
// 04 §10.1 rule 7's "few care moments"; UX-12's priority top tier)

/// The care-moment surface's headless pins: the FIXED key lookup (01–03,
/// never a draw — a refusal line must say refusal) and the pure classifier's
/// disambiguation table (tuck-in vs nap-settling vs reaffirm vs
/// blanket-adjust). All carriers are literal (`AppModelFixture` discipline).
@Suite
struct CareMomentTests {

    /// The lookup is a fixed 01–03 by kind — mirroring
    /// `greetingLineKey`'s catalog-order shape.
    @Test("care-moment keys: the fixed lookup, one key per kind")
    func fixedLookupPinned() {
        #expect(HomeCopyKeys.careMomentLineKey(for: .tuckIn) == "momo.line.care-moment.01")
        #expect(HomeCopyKeys.careMomentLineKey(for: .refusal) == "momo.line.care-moment.02")
        #expect(HomeCopyKeys.careMomentLineKey(for: .blanketAdjust) == "momo.line.care-moment.03")
    }

    // MARK: The classifier

    private func state(
        wakefulness: Wakefulness = .awake,
        activity: Activity? = nil,
        pendingHandshake: Handshake? = nil
    ) -> EngineState {
        AppModelFixture.state(
            petID: AppModelFixture.petID,
            dayKey: "2026-09-10",
            lastEvaluatedAt: AppModelFixture.instant("2026-09-10T20:30:00Z"),
            wakefulness: wakefulness,
            activity: activity,
            pendingHandshake: pendingHandshake
        )
    }

    private func plan(_ reaction: ReactionID) -> ResponsePlan {
        ResponsePlan(reaction: reaction, lineKey: nil, haptic: nil)
    }

    @Test("classify: the politely-full feed refusal is the refusal moment")
    func refusalClassifies() {
        #expect(
            CareMoment.classify(response: plan(ReactionKeys.politelyFull), state: state())
                == .refusal)
        // The refusal is keyed on the REACTION alone — the surrounding state
        // cannot flip it.
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.politelyFull),
                state: state(wakefulness: .asleep, activity: .napping))
                == .refusal)
    }

    @Test("classify: the settle-authorized settling reaction is the tuck-in moment")
    func tuckInClassifies() {
        let settle = Handshake(kind: .settle, token: AppModelFixture.handshakeToken)
        #expect(
            CareMoment.classify(response: plan(ReactionKeys.settling), state: state(pendingHandshake: settle))
                == .tuckIn)
    }

    @Test("classify: a nap's settling (settling wakefulness, NO settle token) is NO moment")
    func napSettlingClassifiesNil() {
        // Nap mints the same reaction but touches no slot: no pending
        // settle handshake, so the tuck-in's authorization half is absent.
        #expect(
            CareMoment.classify(response: plan(ReactionKeys.settling), state: state())
                == nil)
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.settling),
                state: state(wakefulness: .settling))
                == nil)
        // Even a PLAY handshake in pending (settling minted some other way)
        // is not a tuck-in authorization.
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.settling),
                state: state(pendingHandshake: Handshake(kind: .play, token: AppModelFixture.handshakeToken)))
                == nil)
    }

    @Test("classify: the blanket-adjust on a SLEEPING pet is the blanket moment")
    func blanketAdjustClassifies() {
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.blanketAdjust),
                state: state(wakefulness: .asleep))
                == .blanketAdjust)
        // Mid-nap is the other sleeping clause (asleep ∨ .napping).
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.blanketAdjust),
                state: state(activity: .napping))
                == .blanketAdjust)
    }

    @Test("classify: the settling-reaffirm's blanketAdjust on an AWAKE pet is NO moment")
    func reaffirmClassifiesNil() {
        // The tuck-in reaffirm on an already-settling pet mints
        // `blanketAdjust` without the pet being asleep — animation only.
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.blanketAdjust),
                state: state(wakefulness: .settling))
                == nil)
        #expect(
            CareMoment.classify(
                response: plan(ReactionKeys.blanketAdjust),
                state: state())
                == nil)
    }

    @Test("classify: every non-care reaction is nil — feed-enjoys, nibbles, declines")
    func nonCareReactionsClassifyNil() {
        let states = [state(), state(wakefulness: .asleep), state(activity: .playing)]
        for petState in states {
            #expect(CareMoment.classify(response: plan(ReactionKeys.eating), state: petState) == nil)
            #expect(CareMoment.classify(response: plan(ReactionKeys.nibble), state: petState) == nil)
            #expect(CareMoment.classify(response: plan(ReactionKeys.sleepyNibbles), state: petState) == nil)
            #expect(CareMoment.classify(response: plan(ReactionKeys.playReady), state: petState) == nil)
            #expect(CareMoment.classify(response: plan(ReactionKeys.cheer), state: petState) == nil)
            #expect(CareMoment.classify(response: plan(ReactionKeys.decline), state: petState) == nil)
            #expect(CareMoment.classify(response: plan(ReactionKeys.gentleDecline), state: petState) == nil)
        }
    }
}
