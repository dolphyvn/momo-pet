import Testing
import Foundation
@testable import MomoCore

/// §4.8's raw-literal pins (TASK-018 Required Tests 1, 5, 7, 10; AC-3/AC-5):
/// this suite is the ANTI-ECHO exception — the spec's numbers (the epoch
/// value, the candidate count, the window hours) appear here raw so a silent
/// change to `Thresholds.Quest`/`QuestCatalog`/`QuestGeneration` bites with
/// exact attribution. Behavior proofs over NAMED constants live in
/// `QuestGenerationTests`/`QuestTickTests`/`QuestCascadeTests`.
@Suite("QuestGeneration — §4.8 literals, draw recipe, window boundaries (TASK-018)")
struct QuestGenerationPinnedTests {

    private let fixture = InteractionFixture()
    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
    private let day = "2026-09-08"

    private func quest(_ id: QuestID) -> QuestProgress {
        QuestProgress(questID: id, progress: 0, completed: false)!
    }

    /// A state whose single day carries an arbitrary quest set (the tick
    /// pins below need sets the `InteractionFixture` placeholder can't
    /// express).
    private func state(
        questSet: [QuestProgress],
        dayKey: String,
        bond: Int = 0,
        helloAwarded: Bool = false,
        lastEvaluatedAt: Instant
    ) -> EngineState {
        fixture.state(
            bond: bond,
            days: [DayRecord(
                dayKey: dayKey,
                feedCount: 0,
                playCount: 0,
                careCount: 0,
                patCount: 0,
                questSet: questSet,
                helloAwarded: helloAwarded,
                familiesUsed: [],
                bondAwarded: 0,
                questGenEpoch: QuestGeneration.currentEpoch
            )!],
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    // MARK: The epoch + candidate space (Required Test 10; Req 1)

    @Test("the current quest generator epoch is 1 (0 is the pre-generation placeholder marker)")
    func currentEpochIsOne() {
        #expect(QuestGeneration.currentEpoch == 1)
    }

    @Test("the candidate space is exactly the 15 unordered pairs of Q2…Q7; Q1 is never drawn")
    func candidateSpaceIsFifteenPairs() {
        let pairs = QuestGeneration.allCandidatePairs()
        #expect(pairs.count == 15)
        let expected: Set<Set<QuestID>> = [
            [.q2, .q3], [.q2, .q4], [.q2, .q5], [.q2, .q6], [.q2, .q7],
            [.q3, .q4], [.q3, .q5], [.q3, .q6], [.q3, .q7],
            [.q4, .q5], [.q4, .q6], [.q4, .q7],
            [.q5, .q6], [.q5, .q7],
            [.q6, .q7],
        ]
        #expect(Set(pairs.map(Set.init)) == expected)
        #expect(pairs.allSatisfy { !$0.contains(.q1) && $0.count == 2 && $0[0] != $0[1] })
    }

    // MARK: The draw recipe — exactly two seeded draws (Required Test 1)

    @Test("the seed→set mapping consumes exactly two draws in the documented recipe")
    func twoDrawPin() {
        let seed: UInt64 = 0x00FF_00FF_00FF_00FF
        let priors: [[QuestProgress]] = [[quest(.q2), quest(.q6)], [quest(.q4), quest(.q6)]]
        let generated = QuestGeneration.generate(
            dayKey: day, seed: seed, priorTwoSets: priors, questGenEpoch: QuestGeneration.currentEpoch
        )
        // Independently replay `generate`'s documented recipe: draw 1 from
        // the pool's quest universe (catalog order), draw 2 from the first
        // pick's in-pool partners (catalog order), catalog-order the pair,
        // prepend the anchor. Equality pins BOTH the draw count (a third
        // draw, or reordered draws, would change the mapping) and the
        // distribution's shape (universe-then-partners).
        let pool = QuestGeneration.candidatePool(priorTwoSets: priors)
        let catalog = QuestCatalog.all.map(\.id)
        let universe = catalog.filter { id in pool.contains { $0.contains(id) } }
        var rng = SeededGenerator(seed: seed)
        let first = universe[Int(rng.next() % UInt64(universe.count))]
        let partners = catalog.filter { partner in
            partner != first && pool.contains { $0.contains(first) && $0.contains(partner) }
        }
        let second = partners[Int(rng.next() % UInt64(partners.count))]
        let drawn = [first, second].sorted { catalog.firstIndex(of: $0)! < catalog.firstIndex(of: $1)! }
        #expect(generated == [quest(.q1), quest(drawn[0]), quest(drawn[1])])
    }

    @Test("the same (pet, day, epoch) quest-salt seed maps to the identical set (caller lineage)")
    func questSeedDeterminism() {
        let seedA = DaySeed.make(petID: petID, localDayKey: day, epoch: QuestGeneration.currentEpoch, salt: .quest)
        let seedB = DaySeed.make(petID: petID, localDayKey: day, epoch: QuestGeneration.currentEpoch, salt: .quest)
        #expect(seedA == seedB)
        let a = QuestGeneration.generate(dayKey: day, seed: seedA, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch)
        let b = QuestGeneration.generate(dayKey: day, seed: seedB, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch)
        #expect(a == b)
    }

    // MARK: Window boundaries (AC-3) — `QuestWindow.contains(hour:)` table

    @Test("Q1's window is morningOnly: hours 0–11 inside, 12–23 outside")
    func q1BoundaryTable() {
        #expect((0...11).allSatisfy { QuestCatalog.entry(for: .q1).window.contains(hour: $0) })
        #expect((12...23).allSatisfy { !QuestCatalog.entry(for: .q1).window.contains(hour: $0) })
        #expect(!QuestCatalog.entry(for: .q1).window.contains(hour: 11 + 1)) // 12:00 is the first closed hour
    }

    @Test("Q6's window is eveningAndEarlyMorning: ≥20 ∨ <7; the other quests are allDay")
    func q6BoundaryTable() {
        let inside = [0, 1, 2, 3, 4, 5, 6, 20, 21, 22, 23]
        let outside = [7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19]
        #expect(inside.allSatisfy { QuestCatalog.entry(for: .q6).window.contains(hour: $0) })
        #expect(outside.allSatisfy { !QuestCatalog.entry(for: .q6).window.contains(hour: $0) })
        #expect((2...5).allSatisfy { QuestCatalog.entry(for: .q2).window.contains(hour: $0) }) // allDay rows
    }

    // MARK: Tick-level boundaries + the event's OWN time (AC-3)

    @Test("Q1: an 11:59 pat completes, a 12:00 pat does not (first closed hour)")
    func q1TickBoundaries() {
        let before = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T11:59:00Z")
        )
        let ticked = fixture.send(before, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T11:59:00Z"), dayKey: day)
        #expect(ticked.moments == [.questCompleted])
        #expect(ticked.newState.days.first?.questSet.first?.completed == true)

        let at = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T12:00:00Z")
        )
        let quiet = fixture.send(at, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T12:00:00Z"), dayKey: day)
        #expect(quiet.moments.isEmpty)
        #expect(quiet.newState.days.first?.questSet.first?.progress == 0) // the window never re-opens
    }

    @Test("Q6: 19:59 no / 20:00 yes / 06:59 yes / 07:00 no (in-window care events tick)")
    func q6TickBoundaries() {
        // 19:59: the tuck-in offer does not exist yet — no count, no tick.
        let before = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            lastEvaluatedAt: fixture.instant("2026-09-08T19:59:00Z")
        )
        let declined = fixture.send(before, .tuckIn, at: fixture.instant("2026-09-08T19:59:00Z"), dayKey: day)
        #expect(declined.moments.isEmpty)
        #expect(declined.newState.days.first?.questSet.last?.progress == 0)

        // 20:00: in window — the tick completes Q6.
        let open = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            lastEvaluatedAt: fixture.instant("2026-09-08T20:00:00Z")
        )
        let ticked = fixture.send(open, .tuckIn, at: fixture.instant("2026-09-08T20:00:00Z"), dayKey: day)
        #expect(ticked.moments == [.questCompleted])
        #expect(ticked.newState.days.first?.questSet.last?.completed == true)

        // 06:59: the early-morning tail is INSIDE the window.
        let tail = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            lastEvaluatedAt: fixture.instant("2026-09-08T06:59:00Z")
        )
        let tailTicked = fixture.send(tail, .tuckIn, at: fixture.instant("2026-09-08T06:59:00Z"), dayKey: day)
        #expect(tailTicked.moments == [.questCompleted])

        // 07:00: the tail closes — the offer is gone and the quest window with it.
        let closed = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            lastEvaluatedAt: fixture.instant("2026-09-08T07:00:00Z")
        )
        let closedOutcome = fixture.send(closed, .tuckIn, at: fixture.instant("2026-09-08T07:00:00Z"), dayKey: day)
        #expect(closedOutcome.moments.isEmpty)
        #expect(closedOutcome.newState.days.first?.questSet.last?.progress == 0)
    }

    @Test("the §4.8 offline-pat case, verbatim: an 11:30 pat applied at 12:30 ticks Q1")
    func offlinePatTicksAtItsOwnTimestamp() {
        // The pet returns online at 12:30 and delivers a pat that happened
        // at 11:30 (forward-only folds mean 11:30 is IN the past of the
        // 12:30 high-water mark — the interaction still applies; its own
        // timestamp is what the window check reads).
        let online = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: day,
            helloAwarded: true,
            lastEvaluatedAt: fixture.instant("2026-09-08T12:30:00Z")
        )
        let outcome = fixture.send(online, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T11:30:00Z"), dayKey: day)
        #expect(outcome.moments == [.questCompleted]) // the 11:30 hour is what ticked
        #expect(outcome.newState.days.first?.questSet.first?.completed == true)
    }

    @Test("D20 day-ownership, verbatim: a 00:30 tuck-in completes the NEW day's Q6")
    func tuckInAtHalfPastMidnightAttributesToTheNewDay() {
        let newDay = "2026-09-09"
        let carried = state(
            questSet: [quest(.q1), quest(.q2), quest(.q6)],
            dayKey: newDay,
            lastEvaluatedAt: fixture.instant("2026-09-09T00:30:00Z")
        )
        let outcome = fixture.send(carried, .tuckIn, at: fixture.instant("2026-09-09T00:30:00Z"), dayKey: newDay)
        #expect(outcome.moments == [.questCompleted])
        #expect(outcome.newState.days.first?.dayKey == newDay)
        #expect(outcome.newState.days.first?.questSet.last?.completed == true)
        #expect(outcome.newState.days.first?.careCount == 1) // counted on the NEW day too
    }

    // MARK: The named cascade test (AC-5)

    @Test("a 02:00 tuck-in with Q1 done selects Q6")
    func tuckInAtTwoAMWithQ1DoneSelectsQ6() {
        let q1Done = QuestProgress(questID: .q1, progress: 1, completed: true)!
        let set = [q1Done, quest(.q2), quest(.q6)]
        #expect(QuestGeneration.cascade(questSet: set, localHour: 2) == .wish(.q6))
    }
}
