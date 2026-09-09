import Foundation
import Testing
@testable import MomoCore

/// `reduce` event-path semantics + determinism probes (TASK-014 Requirements
/// 4/9 as adapted by TASK-015; 05 §4.1, §4.2, FR-13 AC-3).
///
/// TASK-015 replaced this task's bookkeeping-only `.evaluate` with the real
/// time fold and gave interactions/reports their engine-half semantics. The
/// adaptations, each minimal:
///
/// - every `reduce` call site carries the injected `calendar` (the documented
///   §4.1 signature deviation),
/// - `evaluateTouchesOnlyStamps` now pins the fields the fold genuinely does
///   not touch — `state`/`days` are fold-owned since TASK-015 (the original
///   untouched-everything pin was TASK-014's bookkeeping honesty, superseded
///   by contract),
/// - `handshakeCarrier`'s round-trip evaluate is zero-elapsed (a fold that
///   transitions wakefulness now proactively clears an orphaned handshake —
///   §4.7's never-stranded rule),
/// - `interactionPassThrough` pins the INV-10 belt (fresh ids recorded,
///   duplicates total no-ops) with PetState/days/response still untouched —
///   the TASK-016/017 seam,
/// - `characterReportPassThrough` gains `.wakeFinished` (the TASK-015
///   exact-type finalization of 04 §9.2) and stays the no-op-with-nothing-
///   pending pin.
///
/// The purity probes (rng untouched on non-minting paths, clock unread by
/// evaluate/interaction) pin that no hidden dynamics are smuggled in.
@Suite("reduce — engine core semantics + purity probes (TASK-014/015)")
struct EngineReduceTests {

    // MARK: - Fixtures

    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!

    /// Gregorian UTC calendar — injected, deterministic (D20's injected-
    /// calendar pattern; ambient calendars never appear in engine tests).
    private var calendar: Calendar {
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = TimeZone(identifier: "UTC")!
        return gregorian
    }

    /// Parses a UTC wall-clock string into the exact instant.
    private func utcInstant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// A zero-progress quest entry for fixtures (failable init unwrapped —
    /// zero of any target is always valid; TASK-012 tests own the invariants).
    private func quest(_ id: QuestID) -> QuestProgress {
        QuestProgress(questID: id, progress: 0, completed: false)!
    }

    /// A valid, fully-populated state fixture (all counts zero; the exact
    /// invariants of the domain types are TASK-012's concern, not re-tested).
    private func fixtureState(
        lastOpenedAt: Instant,
        lastEvaluatedAt: Instant
    ) -> EngineState? {
        guard let pet = Pet(id: petID, name: "Momo", createdAt: utcInstant("2026-01-01T00:00:00Z")),
              let petState = PetState(
                  mood: 60,
                  energy: 80,
                  bond: 0,
                  wakefulness: .awake,
                  activity: nil,
                  lastFedAt: nil,
                  satietyPhase: .hungry
              ),
              let day = DayRecord(
                  dayKey: "2026-09-08",
                  feedCount: 0,
                  playCount: 0,
                  careCount: 0,
                  patCount: 0,
                  questSet: [quest(.q1), quest(.q2), quest(.q6)],
                  helloAwarded: false,
                  familiesUsed: [],
                  bondAwarded: 0,
                  questGenEpoch: 0
              )
        else { return nil }
        return EngineState(
            pet: pet,
            state: petState,
            days: [day],
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: lastOpenedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    /// A deterministic state for the tests that don't inspect the stamps.
    private var anyState: EngineState {
        fixtureState(
            lastOpenedAt: utcInstant("2026-09-07T10:00:00Z"),
            lastEvaluatedAt: utcInstant("2026-09-07T10:00:00Z")
        )!
    }

    // MARK: - .evaluate bookkeeping

    @Test("evaluate stamps lastOpenedAt and lastEvaluatedAt, changed = true")
    func evaluateStampsBoth() {
        let state = anyState
        let now = utcInstant("2026-09-08T09:00:00Z")
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(state, .evaluate(now: now), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
        #expect(outcome.newState.lastOpenedAt == now)
        #expect(outcome.newState.lastEvaluatedAt == now)
        #expect(outcome.changed)
        #expect(outcome.response == nil)
        #expect(outcome.moments.isEmpty)
    }

    @Test("evaluate at an instant that changes nothing reports changed = false")
    func evaluateNoChange() {
        let now = utcInstant("2026-09-08T09:00:00Z")
        let state = fixtureState(lastOpenedAt: now, lastEvaluatedAt: now)!
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(state, .evaluate(now: now), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
        #expect(outcome.newState == state)
        #expect(!outcome.changed)
    }

    @Test("evaluate leaves the fold-foreign fields untouched (identity, bookkeeping, ledger belts)")
    func evaluateTouchesOnlyStamps() {
        // TASK-015 supersession: `state` and `days` are fold-owned now — this
        // pin narrowed from "everything but the stamps" to the fields the
        // fold genuinely never touches (the original pin was TASK-014's
        // bookkeeping-only honesty).
        let state = anyState
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(state, .evaluate(now: utcInstant("2026-09-08T09:00:00Z")), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
        #expect(outcome.newState.pet == state.pet)
        #expect(outcome.newState.settings == state.settings)
        #expect(outcome.newState.pendingHandshake == state.pendingHandshake)
        #expect(outcome.newState.processedIntents == state.processedIntents)
        #expect(outcome.newState.highestCelebratedStage == state.highestCelebratedStage)
        #expect(outcome.newState.lastEvaluatedAt == utcInstant("2026-09-08T09:00:00Z"))
    }

    // MARK: - Handshake carrier (minimal §4.7 form; semantics are TASK-015's)

    @Test("the §4.1 processedIntents capacity bound is pinned (≤ 64)")
    func processedIntentsCapacityPinned() {
        #expect(EngineState.processedIntentsCapacity == 64,
                "05 §4.1 pins the ledger bound at ≤ 64 — changing it is a spec change, not a refactor")
    }

    @Test("Handshake carries kind + token; equality is by value")
    func handshakeCarrier() {
        let token = UUID()
        let settle = Handshake(kind: .settle, token: token)
        #expect(settle.kind == .settle)
        #expect(settle.token == token)
        #expect(settle == Handshake(kind: .settle, token: token))
        #expect(settle != Handshake(kind: .wake, token: token))
        #expect(settle != Handshake(kind: .settle, token: UUID()))

        // The state carries it and round-trips through a zero-elapsed
        // evaluate untouched (TASK-015 adaptation: a fold that TRANSITIONS
        // wakefulness now proactively clears an orphaned handshake — §4.7's
        // never-stranded rule — so the carrier pin uses an evaluation that
        // folds nothing).
        let state = anyState
        let pending = EngineState(
            pet: state.pet,
            state: state.state,
            days: state.days,
            settings: state.settings,
            pendingHandshake: settle,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: state.lastOpenedAt,
            lastEvaluatedAt: state.lastEvaluatedAt
        )
        let now = state.lastEvaluatedAt
        var rng = SeededGenerator(seed: 0)
        let outcome = reduce(pending, .evaluate(now: now), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
        #expect(outcome.newState.pendingHandshake == settle)
    }

    // MARK: - Interaction belt + pass-through seam (documented owners: TASK-016/017)

    @Test("fresh interactions record exactly-once ids; duplicates are total no-ops")
    func interactionPassThrough() {
        let state = anyState
        let intents: [InteractionIntent] = [
            InteractionIntent(id: UUID(), source: .iPhone, localDayKey: "2026-09-08", timestamp: utcInstant("2026-09-08T09:00:00Z"), kind: .pat(gesture: .tap, zone: .head)),
            InteractionIntent(id: UUID(), source: .iPhone, localDayKey: "2026-09-08", timestamp: utcInstant("2026-09-08T09:01:00Z"), kind: .feed),
            InteractionIntent(id: UUID(), source: .watch, localDayKey: "2026-09-08", timestamp: utcInstant("2026-09-08T09:02:00Z"), kind: .play),
            InteractionIntent(id: UUID(), source: .watch, localDayKey: "2026-09-08", timestamp: utcInstant("2026-09-08T09:03:00Z"), kind: .pat(gesture: .stroke, zone: nil)),
        ]
        var rng = SeededGenerator(seed: 0)
        var ledger: [UUID] = []
        var current = state
        for intent in intents {
            let outcome = reduce(current, .interaction(intent), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
            // TASK-016 supersession (in place, per the contract): the "no
            // response / no dynamics" half of this pin WAS the documented
            // TASK-016 seam and is now filled — every fresh intent yields
            // exactly one ResponsePlan (seam-nils stay nil: lineKey/haptic
            // are TASK-019/presentation; moments stay [] for TASK-017/018),
            // and effect/count writes touch `days`. What this pin still owns
            // is the INV-10 belt's honesty: exactly-once recording in arrival
            // order, identity untouched, `changed` honest. NITPICK-1's noted
            // case is now asserted for real: intent 1's ~23 h fold lands
            // .waking and mints the `.wake` handshake, and the remaining
            // intents run mid-waking WITHOUT displacing it (Req 9 — wake is
            // never cancelled; the play intent here is the waking-decline
            // cell).
            #expect(outcome.response != nil)
            #expect(outcome.response?.lineKey == nil)
            #expect(outcome.response?.haptic == nil)
            #expect(outcome.moments.isEmpty)
            #expect(outcome.newState.pet == current.pet)
            ledger.append(intent.id)
            #expect(outcome.newState.processedIntents == ledger)
            #expect(outcome.changed)
            current = outcome.newState
        }
        #expect(current.pendingHandshake?.kind == .wake) // minted after intent 1, survived intents 2–4

        // Replay of an already-processed id: total no-op (INV-10, FR-18 AC-1)
        // — no fold, no semantics, no response.
        let replay = reduce(current, .interaction(intents[1]), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
        #expect(replay.newState == current)
        #expect(!replay.changed)
        #expect(replay.response == nil)
    }

    @Test("character reports pass through with no dynamics when nothing is pending (incl. cancellation)")
    func characterReportPassThrough() {
        let state = anyState
        let reports: [CharacterReport] = [
            .settleFinished,
            .wakeFinished,
            .playRoundFinished,
            .reactionFinished(ReactionID(rawValue: "react.tap.head")),
            .handshakeCancelled(.settle),
            .handshakeCancelled(.play),
            .handshakeCancelled(.wake),
            .momentFinished(.greeting(.freshMorning)),
        ]
        var rng = SeededGenerator(seed: 0)
        for report in reports {
            let outcome = reduce(state, .characterReport(report), clock: ManualEngineClock(), calendar: calendar, rng: &rng)
            #expect(outcome.newState == state)
            #expect(!outcome.changed)
            #expect(outcome.response == nil)
            #expect(outcome.moments.isEmpty)
        }
    }

    // MARK: - Purity probes: no hidden inputs (FR-13 AC-3's mechanical half)

    @Test("reduce consumes zero rng draws on non-minting paths (the generator is untouched)")
    func rngUntouched() {
        let state = anyState
        let events: [EngineEvent] = [
            // Fold lands .waking but the fold itself never mints (the stretch
            // is the NEXT event's emission) — zero draws.
            .evaluate(now: utcInstant("2026-09-08T09:00:00Z")),
            // Nothing pending: a tolerated no-op report — zero draws.
            .characterReport(.settleFinished),
        ]
        var generator = SeededGenerator(seed: 0xE220A8397B1DCDAF)
        for event in events {
            _ = reduce(state, event, clock: ManualEngineClock(), calendar: calendar, rng: &generator)
        }
        var untouchedTwin = SeededGenerator(seed: 0xE220A8397B1DCDAF)
        #expect(generator.next() == untouchedTwin.next()) // first draw still the reference first draw
        #expect(generator.state == untouchedTwin.state)
    }

    @Test("evaluate and interactions read no wall time: wildly different clocks, identical outcomes")
    func clockUnread() {
        let state = anyState
        let event = EngineEvent.evaluate(now: utcInstant("2026-09-08T09:00:00Z"))
        let early = ManualEngineClock(at: utcInstant("2000-01-01T00:00:00Z"))
        let late = ManualEngineClock(at: utcInstant("2099-12-31T23:59:59Z"))
        var rngA = SeededGenerator(seed: 1)
        var rngB = SeededGenerator(seed: 1)
        let outcomeA = reduce(state, event, clock: early, calendar: calendar, rng: &rngA)
        let outcomeB = reduce(state, event, clock: late, calendar: calendar, rng: &rngB)
        #expect(outcomeA == outcomeB)
    }

    // MARK: - Determinism spot tests (FR-13 AC-3)

    @Test("identical (state, event, clock, calendar, seed) ⇒ identical outcome, every event kind")
    func determinismAcrossEventKinds() {
        let state = anyState
        let now = utcInstant("2026-09-08T09:00:00Z")
        // Fixed distinct id (REVIEW-TASK-014 NITPICK-2): never reuse petID
        // as an intent id — exactly-once tests key off id distinctness and
        // must not inherit the habit.
        let intentID = UUID(uuidString: "3F2B7A64-1D4E-4C9B-8E2A-5B6C7D8E9F01")!
        let intent = InteractionIntent(id: intentID, source: .iPhone, localDayKey: "2026-09-08", timestamp: now, kind: .feed)
        let events: [EngineEvent] = [
            .evaluate(now: now),
            .interaction(intent),
            .characterReport(.playRoundFinished),
        ]
        for event in events {
            let clockA = ManualEngineClock(at: now)
            let clockB = ManualEngineClock(at: now)
            var rngA = SeededGenerator(seed: 1234)
            var rngB = SeededGenerator(seed: 1234)
            let a = reduce(state, event, clock: clockA, calendar: calendar, rng: &rngA)
            let b = reduce(state, event, clock: clockB, calendar: calendar, rng: &rngB)
            #expect(a == b)
            #expect(a.newState == b.newState)
        }
    }
}
