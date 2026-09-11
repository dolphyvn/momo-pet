import Testing
import Foundation
@testable import MomoCore

/// The §4.6 bond ledger as engine decisions (TASK-017): clamp-at-award is the
/// only mechanism (INV-5/INV-3 structural), the hello is once-per-dayKey,
/// device-agnostic, never window-gated (UX-6/INV-7), the variety award fires
/// at exactly the trio-completing event on exactly the I-1 counting events,
/// the PRD's own cap arithmetics land exactly, the 1000 plateau holds (G2 /
/// FR-10 AC-3), and each stage crossing emits `momentRequest(.bondStageReached)`
/// exactly once on every event path (FR-10 AC-4, UX-10).
///
/// Exact-value expectations restate the OPERATION ORDER with the named
/// constants (never by calling the production award helpers) — the
/// FoldRulesTests discipline. Raw literals live only in
/// `BondRulesPinnedTests`.
@Suite("Bond ledger — §4.6 clamp-at-award, hello, variety, stage moments (TASK-017)")
struct BondLedgerTests {

    private let fixture = InteractionFixture()

    private let day = "2026-09-08"
    private let t = "2026-09-08T09:00:00Z"
    private let evening = "2026-09-08T20:00:00Z" // inside the tuck-in window
    private let afternoon = "2026-09-08T14:00:00Z" // Q1 expired, tuck-in closed
    private let lateNight = "2026-09-08T23:50:00Z"

    private let playToken = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000002")!
    private let settleToken = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000003")!

    // MARK: Hello — once per dayKey, device-agnostic, never window-gated (AC-6)

    @Test("first pat awards +8 once; every later pat moves nothing (G2)")
    func firstPatAwardsHelloExactlyOnce() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let first = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        // TASK-018 supersession (in place, per the contract): the fixture's
        // placeholder set carries Q1 at zero progress, so the first pat's
        // quest tick completes it (+4) on the same event as the hello.
        #expect(first.newState.state.bond == start.state.bond + BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(first.newState.days.first?.helloAwarded == true)
        #expect(first.newState.days.first?.bondAwarded == BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(first.newState.days.first?.patCount == 1)
        let second = fixture.send(first.newState, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(second.newState.state.bond == first.newState.state.bond) // G2: the 2nd pat banks nothing
        #expect(second.newState.days.first?.bondAwarded == BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(second.newState.days.first?.patCount == 2)
    }

    @Test("hello is device-agnostic: a .watch first pat awards identically (UX-6)")
    func helloIsDeviceAgnostic() {
        let phoneStart = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let phone = fixture.send(phoneStart, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        let watchStart = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let watch = fixture.send(watchStart, .pat(gesture: .tap, zone: nil), at: fixture.instant(t), dayKey: day, source: .watch)
        #expect(watch.newState.state.bond == phone.newState.state.bond)
        #expect(watch.newState.days.first?.helloAwarded == true)
        #expect(watch.newState.days.first?.bondAwarded == phone.newState.days.first?.bondAwarded)
    }

    @Test("hello is never window-gated: 14:00 (Q1 long expired) and 23:50 first touches award")
    func helloNeverWindowGated() {
        for stamp in [afternoon, lateNight] {
            let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(stamp))
            let outcome = fixture.send(start, .pat(gesture: .stroke, zone: .head), at: fixture.instant(stamp), dayKey: day)
            #expect(outcome.newState.state.bond == start.state.bond + BondRules.helloBondDelta)
            #expect(outcome.newState.days.first?.helloAwarded == true)
        }
    }

    @Test("the hello flag sets even when the award clamps to 0 (the touch still happened once)")
    func helloFlagSetsWhenClamped() {
        let start = fixture.state(
            dayKey: day,
            helloAwarded: false,
            bondAwarded: BondRules.dailyBondCap,
            bond: Thresholds.Bond.maximum,
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(outcome.newState.state.bond == Thresholds.Bond.maximum) // plateau holds
        #expect(outcome.newState.days.first?.helloAwarded == true) // flag truthfully records the touch
        #expect(outcome.newState.days.first?.bondAwarded == BondRules.dailyBondCap) // ledger unchanged
    }

    // MARK: Variety — family ledger on exactly the counting events (AC-7)

    @Test("feed → play cease → tuck-in: the +6 fires AT the trio-completing care event")
    func varietyFiresAtTrioCompletingEvent() {
        // Hello preset: the sequence isolates the variety arithmetic.
        let bondBefore = 0
        let feed = fixture.send(
            fixture.state(dayKey: day, helloAwarded: true, lastEvaluatedAt: fixture.instant(t)),
            .feed,
            at: fixture.instant(t),
            dayKey: day
        )
        #expect(feed.newState.days.first?.familiesUsed == [.feed])
        // TASK-018 supersession (in place, per the contract): the feed
        // completes the placeholder set's Q2 (+4) — no VARIETY award yet,
        // which is what this pin owns.
        #expect(feed.newState.state.bond == bondBefore + BondRules.questBondDelta)
        let play = fixture.report(
            fixture.state(
                dayKey: day,
                play: 1,
                helloAwarded: true,
                familiesUsed: [.feed],
                activity: .playing,
                pendingHandshake: Handshake(kind: .play, token: playToken),
                lastEvaluatedAt: fixture.instant(t)
            ),
            .playRoundFinished,
            at: fixture.instant(t)
        )
        #expect(play.newState.days.first?.familiesUsed == [.feed, .play])
        #expect(play.newState.state.bond == bondBefore) // still no award
        // The trio-completing tuck-in (in window, awake → settle authorization).
        let care = fixture.send(
            fixture.state(
                dayKey: day,
                feed: 1,
                play: 1,
                helloAwarded: true,
                familiesUsed: [.feed, .play],
                lastEvaluatedAt: fixture.instant(evening)
            ),
            .tuckIn,
            at: fixture.instant(evening),
            dayKey: day
        )
        #expect(care.newState.days.first?.familiesUsed == [.feed, .play, .care])
        // TASK-018 supersession (in place, per the contract): the in-window
        // care ALSO completes the placeholder set's Q6, so this one event
        // banks the +6 variety AND the +4 quest — +10, exactly here.
        #expect(care.newState.state.bond == bondBefore + BondRules.varietyBondDelta + BondRules.questBondDelta) // +6 +4 here, exactly
        #expect(care.newState.days.first?.bondAwarded == BondRules.varietyBondDelta + BondRules.questBondDelta)
    }

    @Test("every feed intent records the family — refusal included (I-1's asymmetry, §4.6)")
    func refusalFeedStillRecordsFamily() {
        let start = fixture.state(dayKey: day, satietyPhase: .full, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.newState.state.satietyPhase == .full) // refusal: zero state effect
        #expect(outcome.newState.days.first?.feedCount == 1) // but it counts
        #expect(outcome.newState.days.first?.familiesUsed == [.feed]) // and it records
    }

    @Test("play records at the unified cease only — both cease kinds; a round start records nothing")
    func playFamilyRecordsAtCease() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let authorized = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        #expect(authorized.newState.days.first?.familiesUsed.isEmpty == true) // no family at authorization
        let finished = fixture.report(authorized.newState, .playRoundFinished, at: fixture.instant(t))
        #expect(finished.newState.days.first?.familiesUsed == [.play])
        #expect(finished.newState.days.first?.playCount == 1)
        // The cancellation cease is the SAME unified cease.
        let cancelledStart = fixture.state(
            dayKey: day,
            activity: .playing,
            pendingHandshake: Handshake(kind: .play, token: playToken),
            lastEvaluatedAt: fixture.instant(t)
        )
        let cancelled = fixture.report(cancelledStart, .handshakeCancelled(.play), at: fixture.instant(t))
        #expect(cancelled.newState.days.first?.familiesUsed == [.play])
    }

    @Test("care records at settle-authorization, blanket-adjust, and nap-acceptance — nowhere else")
    func careFamilyRecordsAtItsEvents() {
        // Settle authorization (awake, in window).
        let awake = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(evening))
        let settled = fixture.send(awake, .tuckIn, at: fixture.instant(evening), dayKey: day)
        #expect(settled.newState.state.wakefulness == .settling)
        #expect(settled.newState.days.first?.familiesUsed == [.care])
        // Blanket-adjust (asleep, in window — still counts, still records).
        let asleep = fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(evening))
        let adjusted = fixture.send(asleep, .tuckIn, at: fixture.instant(evening), dayKey: day)
        #expect(adjusted.newState.state.wakefulness == .asleep)
        #expect(adjusted.newState.days.first?.familiesUsed == [.care])
        // Nap acceptance (drowsy, band-gated in).
        let drowsy = fixture.state(dayKey: day, energy: 30, lastEvaluatedAt: fixture.instant(t))
        let napping = fixture.send(drowsy, .nap, at: fixture.instant(t), dayKey: day)
        #expect(napping.newState.state.activity == .napping)
        #expect(napping.newState.days.first?.familiesUsed == [.care])
    }

    @Test("out-of-window tuck-in and declined nap start no family use")
    func declinedCareRecordsNothing() {
        let midday = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let declinedTuckIn = fixture.send(midday, .tuckIn, at: fixture.instant(t), dayKey: day)
        #expect(declinedTuckIn.newState.days.first?.familiesUsed.isEmpty == true)
        #expect(declinedTuckIn.newState.days.first?.careCount == 0)
        let energetic = fixture.state(dayKey: day, energy: 80, lastEvaluatedAt: fixture.instant(t))
        let declinedNap = fixture.send(energetic, .nap, at: fixture.instant(t), dayKey: day)
        #expect(declinedNap.newState.days.first?.familiesUsed.isEmpty == true)
        #expect(declinedNap.newState.days.first?.careCount == 0)
    }

    @Test("variety fires once per day: later trio-family events never re-award")
    func varietyFiresOncePerDay() {
        // Preset the completed trio WITH its award already in the ledger —
        // the structural proof is that set membership cannot re-fire, even
        // when a trio-family event ACCEPTS (the drowsy nap below is not a
        // decline).
        let state = fixture.state(
            dayKey: day,
            helloAwarded: true,
            familiesUsed: BondRules.varietyTrio,
            bondAwarded: BondRules.helloBondDelta + BondRules.varietyBondDelta,
            energy: 30,
            lastEvaluatedAt: fixture.instant(t)
        )
        let afterFeed = fixture.send(state, .feed, at: fixture.instant(t), dayKey: day)
        #expect(afterFeed.newState.days.first?.familiesUsed == BondRules.varietyTrio) // set unchanged
        // TASK-018 supersession (in place, per the contract): the feed
        // completes the placeholder set's Q2 (+4) — no SECOND +6, which is
        // the once-per-day property this pin owns.
        #expect(afterFeed.newState.state.bond == state.state.bond + BondRules.questBondDelta)
        let afterNap = fixture.send(afterFeed.newState, .nap, at: fixture.instant(t), dayKey: day)
        #expect(afterNap.newState.state.activity == .napping) // the care was accepted…
        #expect(afterNap.newState.days.first?.familiesUsed == BondRules.varietyTrio) // …and records nothing new
        #expect(afterNap.newState.state.bond == afterFeed.newState.state.bond) // no second +6; 09:00 is outside Q6's window, so no tick either
    }

    // MARK: The PRD's cap arithmetics (AC-7; quest mechanism, TASK-018 drives)

    @Test("3-quest day: 8 + 4·3 = 20 exactly, and the trio's variety adds 0")
    func threeQuestDayReachesCapExactly() {
        var state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        // Hello.
        state = fixture.send(state, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day).newState
        // TASK-018 supersession (in place, per the contract): the hello pat
        // also completes the placeholder set's Q1 (+4 → 12 banked); the
        // three direct completions below still land the day on exactly 20.
        #expect(state.state.bond == BondRules.helloBondDelta + BondRules.questBondDelta)
        // Three quest completions (direct mechanism calls).
        state = BondLedger.awardQuestCompletion(to: state, dayKey: day)
        state = BondLedger.awardQuestCompletion(to: state, dayKey: day)
        state = BondLedger.awardQuestCompletion(to: state, dayKey: day)
        #expect(state.state.bond == BondRules.helloBondDelta + 3 * BondRules.questBondDelta)
        #expect(state.days.first?.bondAwarded == BondRules.dailyBondCap) // exactly the cap
        // A later feed still records its family and applies zero bond.
        let fed = fixture.send(state, .feed, at: fixture.instant(t), dayKey: day)
        #expect(fed.newState.days.first?.familiesUsed == [.feed])
        #expect(fed.newState.state.bond == BondRules.dailyBondCap) // the cap holds structurally
        #expect(fed.newState.days.first?.bondAwarded == BondRules.dailyBondCap)
        // And when the trio completes on a capped day, the +6 truncates to 0
        // while the family still records (the PRD's "the +6 truncated" case
        // at its limit).
        let before = fixture.state(
            dayKey: day,
            helloAwarded: true,
            familiesUsed: [.feed, .play],
            bondAwarded: BondRules.dailyBondCap,
            bond: BondRules.dailyBondCap,
            lastEvaluatedAt: fixture.instant(t)
        )
        let completed = BondLedger.recordFamilyUse(.care, to: before, dayKey: day)
        #expect(completed.days.first?.familiesUsed == BondRules.varietyTrio)
        #expect(completed.state.bond == BondRules.dailyBondCap) // +6 truncated to +0
        #expect(completed.days.first?.bondAwarded == BondRules.dailyBondCap)
    }

    @Test("2-quest varied day: 8 + 4·2 + 6 → capped 20, the +6 truncated to +4")
    func twoQuestDayTruncatesVarietyToFour() {
        let before = fixture.state(
            dayKey: day,
            helloAwarded: true,
            familiesUsed: [.feed, .play],
            bondAwarded: BondRules.helloBondDelta + 2 * BondRules.questBondDelta,
            bond: BondRules.helloBondDelta + 2 * BondRules.questBondDelta,
            lastEvaluatedAt: fixture.instant(t)
        )
        #expect(before.state.bond == BondRules.helloBondDelta + 2 * BondRules.questBondDelta) // fixture sanity: 16
        // The trio-completing event (the ledger's own record path) — award
        // headroom is exactly 4.
        let awarded = BondLedger.recordFamilyUse(.care, to: before, dayKey: day)
        #expect(awarded.state.bond == BondRules.dailyBondCap) // 16 + truncated 4
        #expect(awarded.days.first?.bondAwarded == BondRules.dailyBondCap) // the ledger is EXACT
    }

    @Test("quest award mechanism clamps under the cap (TASK-018's calling contract)")
    func questAwardClamps() {
        let state = fixture.state(
            dayKey: day,
            helloAwarded: true,
            bondAwarded: BondRules.dailyBondCap - BondRules.questBondDelta + 2, // headroom 2
            lastEvaluatedAt: fixture.instant(t)
        )
        let awarded = BondLedger.awardQuestCompletion(to: state, dayKey: day)
        #expect(awarded.state.bond == state.state.bond + 2) // 4 requested, 2 applied
        #expect(awarded.days.first?.bondAwarded == BondRules.dailyBondCap)
    }

    // MARK: The 1000 plateau (AC-3, G2)

    @Test("1000 same-day pats move bond by exactly the day's hello + first quest: +12 once, then zero")
    func thousandPatsMoveExactlyTheHello() {
        var state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let startBond = state.state.bond
        for _ in 0..<1000 {
            state = fixture.send(state, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day).newState
        }
        // TASK-018 supersession (in place, per the contract): the first pat
        // also completes the placeholder set's Q1 (+4); every later pat —
        // the property this pin owns — banks nothing.
        #expect(state.state.bond == startBond + BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(state.days.first?.bondAwarded == BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(state.days.first?.patCount == 1000)
    }

    @Test("plateau at 1000: an award truncates to the remaining headroom and the ledger is exact")
    func plateauTruncatesAndLedgerIsExact() {
        let headroom = 5 // scenario: the pet stands 5 below the plateau
        let start = fixture.state(dayKey: day, bond: Thresholds.Bond.maximum - headroom, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(outcome.newState.state.bond == Thresholds.Bond.maximum) // the plateau, not past it
        #expect(outcome.newState.days.first?.bondAwarded == headroom) // min(hello, cap, headroom)
        #expect(outcome.newState.days.first?.helloAwarded == true)
    }

    // MARK: Stage crossing — exactly once, every path (AC-4, UX-10)

    @Test("a hello-carrying first pat crosses 150: one moment, guard advances with the emission")
    func patHelloCrossingEmitsExactlyOnce() {
        let start = fixture.state(dayKey: day, bond: 145, lastEvaluatedAt: fixture.instant(t))
        let first = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        // TASK-018 supersession (in place, per the contract): the first pat
        // completes the placeholder set's Q1 too (+4 → 157 ≥ 150), and the
        // completion moment composes FIRST — the crossing is its consequence.
        #expect(first.newState.state.bond == 145 + BondRules.helloBondDelta + BondRules.questBondDelta) // 157 ≥ 150
        #expect(first.moments == [.questCompleted, .bondStageReached(.gettingClose)])
        #expect(first.newState.highestCelebratedStage == .gettingClose)
        // The second pat re-derives the same stage: no moment, guard stays.
        let second = fixture.send(first.newState, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(second.moments.isEmpty)
        #expect(second.newState.highestCelebratedStage == .gettingClose)
    }

    @Test("a crossing made while closed surfaces at the next evaluation, exactly once (UX-10)")
    func crossingSurfacesAtNextEvaluation() {
        let closed = fixture.state(dayKey: day, bond: 200, lastEvaluatedAt: fixture.instant(t))
        let reopened = fixture.evaluate(closed, at: fixture.instant(t))
        #expect(reopened.moments == [.bondStageReached(.gettingClose)])
        #expect(reopened.newState.highestCelebratedStage == .gettingClose)
        let again = fixture.evaluate(reopened.newState, at: fixture.instant(t))
        #expect(again.moments.isEmpty)
        #expect(again.newState.highestCelebratedStage == .gettingClose)
    }

    @Test("a multi-stage jump emits ONE moment carrying the current stage")
    func multiStageJumpEmitsCurrentStageOnce() {
        let closed = fixture.state(dayKey: day, bond: 700, lastEvaluatedAt: fixture.instant(t))
        let reopened = fixture.evaluate(closed, at: fixture.instant(t))
        #expect(makeBondStage(700) == .bestFriends) // fixture sanity: 700 clears 400, not 750
        #expect(reopened.moments == [.bondStageReached(.bestFriends)])
        #expect(reopened.newState.highestCelebratedStage == .bestFriends)
    }

    @Test("a fresh state emits nothing: bond 0, guard .newFriends — reconciliation is silent")
    func freshStateEmitsNothing() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.evaluate(start, at: fixture.instant(t))
        #expect(outcome.moments.isEmpty)
        #expect(outcome.newState.highestCelebratedStage == .newFriends)
    }

    @Test("the report path reconciles too: a settle completion crossing emits on that path")
    func reportPathReconciles() {
        let start = fixture.state(
            dayKey: day,
            bond: 200,
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: settleToken),
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.report(start, .settleFinished, at: fixture.instant(t))
        #expect(outcome.newState.state.wakefulness == .asleep)
        #expect(outcome.moments == [.bondStageReached(.gettingClose)])
        #expect(outcome.newState.highestCelebratedStage == .gettingClose)
    }

    // MARK: Expired-dayKey disposition (Requirement 6)

    @Test("an expired-dayKey intent keeps its effects but earns NO bond and writes NO ledger")
    func expiredDayKeyEarnsNothing() {
        let state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let staleKey = "2026-01-01" // no ledger entry: pruned / pre-dating the pet
        let patted = fixture.send(state, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: staleKey)
        #expect(patted.newState.state.bond == state.state.bond) // no hello, no award
        #expect(patted.newState.days.count == 1) // no retroactive DayRecord
        #expect(patted.newState.days.first?.helloAwarded == false)
        #expect(patted.newState.days.first?.bondAwarded == 0)
        #expect(patted.newState.days.first?.patCount == 0) // no counter either (TASK-016 convention)
        let fed = fixture.send(state, .feed, at: fixture.instant(t), dayKey: staleKey)
        #expect(fed.newState.days.first?.familiesUsed.isEmpty == true) // no family off-ledger
        #expect(fed.newState.state.satietyPhase == .full) // current-state effects kept
    }

    // MARK: Hello × pat semantics (Requirement 3's no-disturbance clause)

    @Test("the hello rides the pat without disturbing its TASK-016 semantics")
    func helloDoesNotDisturbPatSemantics() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.tapHead, lineKey: "momo.line.react.touch.02", haptic: nil))
        #expect(outcome.newState.state.mood == start.state.mood
            + InteractionRules.touchMoodDelta * InteractionRules.repetitionMultipliers[0])
        #expect(outcome.newState.days.first?.patCount == 1)
        // …and the bond moved by exactly the hello plus the first pat's
        // quest completion (TASK-018 supersession, in place, per the
        // contract: the placeholder set carries Q1 at zero progress).
        #expect(outcome.newState.state.bond == start.state.bond + BondRules.helloBondDelta + BondRules.questBondDelta)
    }

    // MARK: Monotonic under replay (AC-2's replay clause — 05 §10.3 row 2, TASK-020)

    @Test("monotonic under replay: a re-delivered intent id is the total no-op — bond never decreases, the ledger never moves, the day never rolls")
    func monotonicUnderReplay() {
        let id = UUID(uuidString: "00000000-0000-0000-0000-0000000004D2")!
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let first = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day, intentID: id)
        #expect(first.newState.state.bond == start.state.bond + BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(first.newState.state.bond > start.state.bond) // there is an award for the replays to threaten

        // The SAME id re-delivered — later the same day, at the day's edge,
        // and past local midnight — is each time the INV-10 total no-op: the
        // belt answers BEFORE any fold, so a replay cannot even roll the day
        // over, let alone re-award or regress the bond (FR-10 AC-2 "no sync
        // conflict ever decreases bond", §10.3's "monotonicity incl. replay").
        var current = first.newState
        for replayAt in ["2026-09-08T11:00:00Z", "2026-09-08T23:30:00Z", "2026-09-09T00:30:00Z"] {
            let replayKey = DayKey.make(from: fixture.instant(replayAt), calendar: fixture.calendar)
            let replay = fixture.send(current, .pat(gesture: .tap, zone: .head), at: fixture.instant(replayAt), dayKey: replayKey, intentID: id)
            #expect(replay.newState == current)
            #expect(!replay.changed)
            #expect(replay.newState.state.bond >= current.state.bond)
            current = replay.newState
        }
        #expect(current.days.count == 1) // the past-midnight replay rolled nothing
        #expect(current.days.first?.bondAwarded == BondRules.helloBondDelta + BondRules.questBondDelta)
        #expect(current.days.first?.patCount == 1) // replays counted nothing either
    }

    // MARK: Determinism (AC-5)

    @Test("twin runs over identical tuples produce whole-state-equal outcomes, bond fields included")
    func twinRunsAreWholeStateEqual() {
        func run() -> EngineOutcome {
            var state = fixture.state(dayKey: day, bond: 145, lastEvaluatedAt: fixture.instant(t))
            let id = UUID(uuidString: "CCCCCCCC-DDDD-EEEE-FFFF-000000000004")!
            state = fixture.send(state, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day, intentID: id).newState
            return fixture.report(state, .playRoundFinished, at: fixture.instant(t))
        }
        let a = run()
        let b = run()
        #expect(a.newState == b.newState)
        #expect(a.moments == b.moments)
    }
}
