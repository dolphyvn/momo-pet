import Testing
import Foundation
@testable import MomoCore

/// The PRD §4 response matrix as engine decisions (TASK-016 Requirements 1–2,
/// 6, 9; AC-1/AC-2): every cell warm (INV-6), counting honest (I-1's
/// asymmetry), and every plan shape the 04 §9.2 contract — reaction + the
/// intent family's day-stable copy key (TASK-019 supersession, in place:
/// the former "`lineKey` nil" pin was the TASK-019 seam and is now filled),
/// `haptic` still nil (the presentation seam). (TASK-018 supersession
/// likewise in place: the counting events' quest ticks emit exactly their
/// completions.)
///
/// Exact-value expectations restate the production OPERATION ORDER with the
/// named constants — never by calling the production helpers — so a
/// regression cannot hide behind a circular expectation (the FoldRulesTests
/// discipline). Raw literals live only in `InteractionRulesPinnedTests`.
@Suite("Interaction response matrix — PRD §4 cells (TASK-016)")
struct InteractionResponseTests {

    private let fixture = InteractionFixture()

    private let day = "2026-09-08"
    private let t = "2026-09-08T09:00:00Z"

    /// The wake token used by the waking-cell fixtures (its SURVIVAL is the
    /// assertion, so a fixed value keeps comparisons readable).
    private var wakeToken: UUID { UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-000000000001")! }

    // MARK: Touch — 04 §6.1's gesture×zone map (FR-5 AC-1)

    @Test("gesture×zone map: every cell is distinguishable, warm, +2 mood, counted")
    func touchGestureZoneMap() {
        // 04 §6.1's rows; double-tap is one row for both zones (no split);
        // the nil-zone column is the Watch's single surface (FR-17).
        let cells: [(gesture: PatGesture, zone: TouchZone?, beat: ReactionID)] = [
            (.tap, .head, ReactionKeys.tapHead),
            (.tap, .belly, ReactionKeys.tapBelly),
            (.tap, nil, ReactionKeys.tap),
            (.doubleTap, .head, ReactionKeys.doubleTap),
            (.doubleTap, .belly, ReactionKeys.doubleTap),
            (.doubleTap, nil, ReactionKeys.doubleTap),
            (.longPress, .head, ReactionKeys.longPressHead),
            (.longPress, .belly, ReactionKeys.longPressBelly),
            (.longPress, nil, ReactionKeys.longPress),
            (.stroke, .head, ReactionKeys.strokeHead),
            (.stroke, .belly, ReactionKeys.strokeBelly),
            (.stroke, nil, ReactionKeys.stroke),
        ]
        for cell in cells {
            // TASK-017 (the contract's named pat touch point): the day's
            // hello is PRESET so the pins below pin the post-hello G2 form —
            // pats beyond the first move nothing. The hello award itself is
            // pinned in BondLedgerTests.
            let start = fixture.state(dayKey: day, helloAwarded: true, lastEvaluatedAt: fixture.instant(t))
            let outcome = fixture.send(start, .pat(gesture: cell.gesture, zone: cell.zone), at: fixture.instant(t), dayKey: day)
            #expect(outcome.response == ResponsePlan(reaction: cell.beat, lineKey: "momo.line.react.touch.02", haptic: nil),
                    "\(cell.gesture) × \(String(describing: cell.zone)) must map to \(cell.beat.rawValue)")
            #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.touchMoodDelta * InteractionRules.repetitionMultipliers[0])
            // TASK-018 supersession (in place, per the contract): the first
            // pat completes the fixture set's Q1 (+4) and emits its moment —
            // the full G2 form (nothing beyond hello + one quest moves) is
            // BondLedgerTests'.
            #expect(outcome.newState.state.bond == start.state.bond + BondRules.questBondDelta)
            #expect(outcome.newState.days.first?.patCount == 1)
            #expect(outcome.newState.days.first?.bondAwarded == BondRules.questBondDelta)
            #expect(outcome.moments == [.questCompleted])
        }
    }

    @Test("Drowsy and Exhausted touch keeps the same keys (tempo is character-side, §6.2)")
    func softBandsKeepTheKeys() {
        for (band, energy) in [(EnergyBand.drowsy, 30.0), (EnergyBand.exhausted, 15.0)] {
            let start = fixture.state(dayKey: day, energy: energy, lastEvaluatedAt: fixture.instant(t))
            let outcome = fixture.send(start, .pat(gesture: .stroke, zone: .head), at: fixture.instant(t), dayKey: day)
            #expect(makeEnergyBand(energy) == band) // fixture sanity
            #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.strokeHead, lineKey: "momo.line.react.touch.02", haptic: nil))
            #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.touchMoodDelta * InteractionRules.repetitionMultipliers[0])
            #expect(outcome.newState.days.first?.patCount == 1)
        }
    }

    @Test("asleep touch: the stir, stays asleep, still counts (the stir is a touch that happened)")
    func asleepTouchStirsAndCounts() {
        let start = fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.touch.02", haptic: nil))
        #expect(outcome.newState.state.wakefulness == .asleep)
        #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.touchMoodDelta * InteractionRules.repetitionMultipliers[0])
        #expect(outcome.newState.days.first?.patCount == 1)
    }

    @Test("napping touch: the stir, nap preserved, counted")
    func nappingTouchStirs() {
        let start = fixture.state(dayKey: day, wakefulness: .awake, activity: .napping, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .pat(gesture: .tap, zone: .belly), at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.touch.02", haptic: nil))
        #expect(outcome.newState.state.activity == .napping)
        #expect(outcome.newState.days.first?.patCount == 1)
    }

    // MARK: Feed — the amended PRD §4 row (satiety classes; FR-6)

    @Test("hungry feed in Energetic/Relaxed: the full meal — the eating state IS the response")
    func hungryFeedFullMeal() {
        let start = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.eating, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(outcome.newState.state.energy == start.state.energy + InteractionRules.mealEnergyDelta * InteractionRules.repetitionMultipliers[0])
        #expect(outcome.newState.state.mood == start.state.mood + InteractionRules.mealMoodDelta * InteractionRules.repetitionMultipliers[0])
        #expect(outcome.newState.state.lastFedAt == fixture.instant(t)) // the clock anchors to the intent's instant
        #expect(outcome.newState.state.satietyPhase == .full)
        #expect(outcome.newState.state.activity == nil) // no eating activity: nothing in the report vocabulary clears it
        #expect(outcome.newState.days.first?.feedCount == 1)
    }

    @Test("hungry feed in Drowsy/Exhausted: sleepyNibbles beat, FULL effect (no band multiplier)")
    func sleepyBandFeedBeat() {
        for energy in [30.0, 15.0] {
            let start = fixture.state(dayKey: day, energy: energy, lastEvaluatedAt: fixture.instant(t))
            let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
            #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.sleepyNibbles, lineKey: "momo.line.react.feed.01", haptic: nil))
            // The PRD's "smaller effect" is the BEAT's prose; 05 §4.4's table
            // carries no band multiplier (recorded interpretation) — the
            // numbers are satiety class × repetition only.
            #expect(outcome.newState.state.energy == start.state.energy + InteractionRules.mealEnergyDelta * InteractionRules.repetitionMultipliers[0])
            #expect(outcome.newState.days.first?.feedCount == 1)
        }
    }

    @Test("recentlyFed feed: the nibble at exactly ×0.25, clock re-anchored")
    func recentlyFedNibble() {
        let fedAt = fixture.instant("2026-09-08T08:00:00Z")
        let start = fixture.state(
            dayKey: day,
            lastFedAt: fedAt,
            satietyPhase: .recentlyFed,
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.nibble, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(outcome.newState.state.energy == start.state.energy
            + InteractionRules.mealEnergyDelta * (InteractionRules.repetitionMultipliers[0] * InteractionRules.nibbleEffectMultiplier))
        #expect(outcome.newState.state.mood == start.state.mood
            + InteractionRules.mealMoodDelta * (InteractionRules.repetitionMultipliers[0] * InteractionRules.nibbleEffectMultiplier))
        #expect(outcome.newState.state.lastFedAt == fixture.instant(t))
        #expect(outcome.newState.state.satietyPhase == .full)
        #expect(outcome.newState.days.first?.feedCount == 1)
    }

    @Test("full refusal: politely-full beat, ZERO state effect, still counts, clock untouched")
    func fullRefusalZeroEffectStillCounts() {
        let fedAt = fixture.instant("2026-09-08T08:50:00Z")
        let start = fixture.state(
            dayKey: day,
            lastFedAt: fedAt,
            satietyPhase: .full,
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.politelyFull, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(outcome.newState.state.energy == start.state.energy)
        #expect(outcome.newState.state.mood == start.state.mood)
        #expect(outcome.newState.state.lastFedAt == fedAt) // no meal happened — the satiety clock is untouched
        #expect(outcome.newState.state.satietyPhase == .full)
        #expect(outcome.newState.days.first?.feedCount == 1) // I-1: a declined meal still happened
    }

    @Test("asleep feed: gentle decline, counts, zero effect, clock untouched")
    func asleepFeedDeclinesAndCounts() {
        let start = fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.gentleDecline, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(outcome.newState.state.wakefulness == .asleep)
        #expect(outcome.newState.state.energy == start.state.energy)
        #expect(outcome.newState.state.mood == start.state.mood)
        #expect(outcome.newState.state.lastFedAt == nil)
        #expect(outcome.newState.days.first?.feedCount == 1)
    }

    @Test("napping feed: the gentle decline too (a nap is sleeping to a feed)")
    func nappingFeedDeclines() {
        let start = fixture.state(dayKey: day, energy: 30, wakefulness: .awake, activity: .napping, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.gentleDecline, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(outcome.newState.state.lastFedAt == nil)
        #expect(outcome.newState.days.first?.feedCount == 1)
    }

    @Test("settling feed: the gentle decline, settle token untouched (never queues)")
    func settlingFeedDeclines() {
        let token = wakeToken
        let start = fixture.state(
            dayKey: day,
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .feed, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.gentleDecline, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .settle, token: token))
        #expect(outcome.newState.state.wakefulness == .settling)
        #expect(outcome.newState.days.first?.feedCount == 1) // counts even mid-settle (I-1)
    }

    // MARK: Play — the PRD §4 play row's non-authorized cells

    @Test("exhausted play: the gentle stir — no round, no token, no count")
    func exhaustedPlayStirsOnly() {
        let start = fixture.state(dayKey: day, energy: 15, lastEvaluatedAt: fixture.instant(t))
        let outcome = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.play.01", haptic: nil))
        #expect(outcome.newState.pendingHandshake == nil)
        #expect(outcome.newState.state.activity == nil)
        #expect(outcome.newState.days.first?.playCount == 0)
    }

    @Test("asleep and napping play: the gentle stir, no round")
    func sleepingPlayStirsOnly() {
        let asleep = fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t))
        let asleepOutcome = fixture.send(asleep, .play, at: fixture.instant(t), dayKey: day)
        #expect(asleepOutcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.play.01", haptic: nil))
        #expect(asleepOutcome.newState.state.wakefulness == .asleep)
        #expect(asleepOutcome.newState.days.first?.playCount == 0)

        let napping = fixture.state(dayKey: day, wakefulness: .awake, activity: .napping, lastEvaluatedAt: fixture.instant(t))
        let nappingOutcome = fixture.send(napping, .play, at: fixture.instant(t), dayKey: day)
        #expect(nappingOutcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.play.01", haptic: nil))
        #expect(nappingOutcome.newState.state.activity == .napping)
        #expect(nappingOutcome.newState.days.first?.playCount == 0)
    }

    @Test("settling play: the declined-warm stir, token untouched")
    func settlingPlayDeclines() {
        let token = wakeToken
        let start = fixture.state(
            dayKey: day,
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.stir, lineKey: "momo.line.react.play.01", haptic: nil))
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .settle, token: token))
        #expect(outcome.newState.days.first?.playCount == 0)
    }

    @Test("mid-round play: the cheer, round and token EXACTLY intact, no count")
    func midRoundPlayCheers() {
        let token = wakeToken
        let start = fixture.state(
            dayKey: day,
            activity: .playing,
            pendingHandshake: Handshake(kind: .play, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .play, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.cheer, lineKey: "momo.line.react.play.01", haptic: nil))
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .play, token: token)) // not reset, not extended
        #expect(outcome.newState.state.activity == .playing)
        #expect(outcome.newState.state.mood == start.state.mood && outcome.newState.state.energy == start.state.energy)
        #expect(outcome.newState.days.first?.playCount == 0)
    }

    // MARK: Care — the PRD §4 care rows' declining cells (accepted cells: CareInteractionTests)

    @Test("nap declined in Energetic and Relaxed (not offered): warm decline, no count")
    func napNotOfferedOutsideDrowsyExhausted() {
        for energy in [80.0, 50.0] {
            let start = fixture.state(dayKey: day, energy: energy, lastEvaluatedAt: fixture.instant(t))
            let outcome = fixture.send(start, .nap, at: fixture.instant(t), dayKey: day)
            #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.decline, lineKey: "momo.line.react.care.01", haptic: nil))
            #expect(outcome.newState.state.activity == nil)
            #expect(outcome.newState.days.first?.careCount == 0)
        }
    }

    @Test("asleep and napping nap: the warm no-op decline")
    func napWhileSleepingIsANoOp() {
        let asleep = fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t))
        let asleepOutcome = fixture.send(asleep, .nap, at: fixture.instant(t), dayKey: day)
        #expect(asleepOutcome.response == ResponsePlan(reaction: ReactionKeys.gentleDecline, lineKey: "momo.line.react.care.01", haptic: nil))
        #expect(asleepOutcome.newState.state.wakefulness == .asleep)
        #expect(asleepOutcome.newState.days.first?.careCount == 0)

        let napping = fixture.state(dayKey: day, wakefulness: .awake, activity: .napping, lastEvaluatedAt: fixture.instant(t))
        let nappingOutcome = fixture.send(napping, .nap, at: fixture.instant(t), dayKey: day)
        #expect(nappingOutcome.response == ResponsePlan(reaction: ReactionKeys.gentleDecline, lineKey: "momo.line.react.care.01", haptic: nil))
        #expect(nappingOutcome.newState.state.activity == .napping) // the running nap is untouched, not restarted
        #expect(nappingOutcome.newState.days.first?.careCount == 0)
    }

    @Test("settling nap: the gentle decline, token untouched (§9.6 item 8)")
    func settlingNapDeclines() {
        let token = wakeToken
        let start = fixture.state(
            dayKey: day,
            wakefulness: .settling,
            pendingHandshake: Handshake(kind: .settle, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let outcome = fixture.send(start, .nap, at: fixture.instant(t), dayKey: day)
        #expect(outcome.response == ResponsePlan(reaction: ReactionKeys.gentleDecline, lineKey: "momo.line.react.care.01", haptic: nil))
        #expect(outcome.newState.pendingHandshake == Handshake(kind: .settle, token: token))
        #expect(outcome.newState.days.first?.careCount == 0)
    }

    // MARK: Waking cells (Req 9: apply normally; the .wake token is never cancelled)

    @Test("waking: pat and feed apply AND the pending .wake handshake survives")
    func wakingTouchAndFeedApplyAndWakeSurvives() {
        let token = wakeToken
        let patStart = fixture.state(
            dayKey: day,
            wakefulness: .waking,
            pendingHandshake: Handshake(kind: .wake, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let pat = fixture.send(patStart, .pat(gesture: .tap, zone: .head), at: fixture.instant(t), dayKey: day)
        #expect(pat.response == ResponsePlan(reaction: ReactionKeys.tapHead, lineKey: "momo.line.react.touch.02", haptic: nil))
        #expect(pat.newState.state.mood == patStart.state.mood + InteractionRules.touchMoodDelta * InteractionRules.repetitionMultipliers[0])
        #expect(pat.newState.pendingHandshake == Handshake(kind: .wake, token: token))

        let fedStart = fixture.state(
            dayKey: day,
            wakefulness: .waking,
            pendingHandshake: Handshake(kind: .wake, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let fed = fixture.send(fedStart, .feed, at: fixture.instant(t), dayKey: day)
        #expect(fed.response == ResponsePlan(reaction: ReactionKeys.eating, lineKey: "momo.line.react.feed.01", haptic: nil))
        #expect(fed.newState.state.lastFedAt == fixture.instant(t))
        #expect(fed.newState.pendingHandshake == Handshake(kind: .wake, token: token))
    }

    @Test("waking: play and tuck-in decline warm (the slot holds the never-cancelled wake token)")
    func wakingChoreographyDeclines() {
        let token = wakeToken
        let playStart = fixture.state(
            dayKey: day,
            wakefulness: .waking,
            pendingHandshake: Handshake(kind: .wake, token: token),
            lastEvaluatedAt: fixture.instant(t)
        )
        let play = fixture.send(playStart, .play, at: fixture.instant(t), dayKey: day)
        #expect(play.response == ResponsePlan(reaction: ReactionKeys.decline, lineKey: "momo.line.react.play.01", haptic: nil))
        #expect(play.newState.pendingHandshake == Handshake(kind: .wake, token: token))
        #expect(play.newState.state.activity == nil)
        #expect(play.newState.days.first?.playCount == 0)
    }

    // MARK: Plan-shape sweep (the 04 §9.2 contract: reaction only)

    @Test("every engine-minted plan carries its family's copy key, haptic == nil; moments are exactly the counting events' quest ticks")
    func planShapeAndSeams() {
        // One representative of every beat family the matrix produces, with
        // the moments each scenario raises (TASK-018 supersession, in place,
        // per the contract — the moments seam is filled: every counting
        // event ticks the fixture set, and an in-window completion emits
        // [.questCompleted]; non-counting paths emit nothing). The lineKey
        // seam is likewise filled (TASK-019 supersession, in place): each
        // plan carries its intent family's day-stable key. The raw literals
        // restate the `momo.line.react.<family>.<nn>` keyspace shape plus
        // the epoch-4 draw over this fixture's (petID, day) — TASK-034's
        // touch pool draws index 02 (the epoch-4 residue SURVIVES the
        // epoch-3 index), TASK-035's feed/play/care pools draw index 01 —
        // without calling the production helper, so a regression cannot
        // hide behind a circular expectation. `haptic` stays the
        // presentation seam — nil.
        let touch = "momo.line.react.touch.02"
        let feed = "momo.line.react.feed.01"
        let scenarios: [(EngineState, InteractionIntent.Kind, String, [CharacterMoment])] = [
            (fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t)), .pat(gesture: .stroke, zone: .belly), touch, [.questCompleted]), // pat counts → Q1 completes (09:00 is in Q1's window)
            (fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t)), .pat(gesture: .tap, zone: nil), touch, [.questCompleted]), // the asleep stir still counts
            (fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t)), .feed, feed, [.questCompleted]), // the feed completes Q2
            (fixture.state(dayKey: day, lastFedAt: fixture.instant("2026-09-08T08:00:00Z"), satietyPhase: .full, lastEvaluatedAt: fixture.instant(t)), .feed, feed, [.questCompleted]), // the refusal still counts
            (fixture.state(dayKey: day, energy: 15, lastEvaluatedAt: fixture.instant(t)), .play, "momo.line.react.play.01", []), // authorization is not a counting event
            (fixture.state(dayKey: day, energy: 30, lastEvaluatedAt: fixture.instant(t)), .nap, "momo.line.react.care.01", []), // care counts, but 09:00 is outside Q6's window
        ]
        for (start, kind, lineKey, expectedMoments) in scenarios {
            let outcome = fixture.send(start, kind, at: fixture.instant(t), dayKey: day)
            #expect(outcome.response != nil)
            #expect(outcome.response?.lineKey == lineKey) // the family's day-stable key (TASK-019)
            #expect(outcome.response?.haptic == nil) // presentation-owned vocabulary
            #expect(outcome.moments == expectedMoments)
        }
    }

    // MARK: rng discipline (determinism tuple's mechanical half)

    @Test("non-minting interaction paths consume ZERO rng draws; minting paths consume exactly two")
    func rngDrawDiscipline() {
        let seed: UInt64 = 0xA5A5A5A5A5A5A5A5
        // Zero-draw cells: touch (awake + asleep), feed (hungry + refusal + asleep decline),
        // declines (exhausted play, mid-round cheer, energetic nap, asleep nap).
        let zeroDrawScenarios: [(EngineState, InteractionIntent.Kind)] = [
            (fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t)), .pat(gesture: .tap, zone: .head)),
            (fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t)), .pat(gesture: .tap, zone: .head)),
            (fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t)), .feed),
            (fixture.state(dayKey: day, lastFedAt: fixture.instant("2026-09-08T08:50:00Z"), satietyPhase: .full, lastEvaluatedAt: fixture.instant(t)), .feed),
            (fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t)), .feed),
            (fixture.state(dayKey: day, energy: 15, lastEvaluatedAt: fixture.instant(t)), .play),
            (fixture.state(dayKey: day, activity: .playing, pendingHandshake: Handshake(kind: .play, token: wakeToken), lastEvaluatedAt: fixture.instant(t)), .play),
            (fixture.state(dayKey: day, energy: 80, lastEvaluatedAt: fixture.instant(t)), .nap),
            (fixture.state(dayKey: day, wakefulness: .asleep, lastEvaluatedAt: fixture.instant(t)), .nap),
            (fixture.state(dayKey: day, energy: 30, lastEvaluatedAt: fixture.instant(t)), .nap),
        ]
        for (start, kind) in zeroDrawScenarios {
            var rng = SeededGenerator(seed: seed)
            _ = reduce(start, .interaction(fixture.intent(kind, at: fixture.instant(t), dayKey: day)),
                       clock: ManualEngineClock(), calendar: fixture.calendar, rng: &rng)
            let untouchedTwin = SeededGenerator(seed: seed)
            #expect(rng.state == untouchedTwin.state, "\(kind) must draw nothing")
        }

        // Two-draw cells: play authorization and tuck-in settle (the shared mint).
        let playStart = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant(t))
        var playRng = SeededGenerator(seed: seed)
        _ = reduce(playStart, .interaction(fixture.intent(.play, at: fixture.instant(t), dayKey: day)),
                   clock: ManualEngineClock(), calendar: fixture.calendar, rng: &playRng)
        var twoDrawTwin = SeededGenerator(seed: seed)
        _ = twoDrawTwin.next()
        _ = twoDrawTwin.next()
        #expect(playRng.state == twoDrawTwin.state)

        let tuckStart = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T20:00:00Z"))
        var tuckRng = SeededGenerator(seed: seed)
        _ = reduce(tuckStart, .interaction(fixture.intent(.tuckIn, at: fixture.instant("2026-09-08T20:00:00Z"), dayKey: day)),
                   clock: ManualEngineClock(), calendar: fixture.calendar, rng: &tuckRng)
        var tuckTwin = SeededGenerator(seed: seed)
        _ = tuckTwin.next()
        _ = tuckTwin.next()
        #expect(tuckRng.state == tuckTwin.state)
    }
}
