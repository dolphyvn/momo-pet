import Testing
import Foundation
@testable import MomoCore

/// The §4.8 generator as engine decisions (TASK-018 Required Tests 2, 3, 4,
/// 8; AC-1/AC-2/AC-6): determinism twins, the two variation constraints
/// proven at the POOL level (by construction — no check-and-retry exists to
/// catch a violation), candidate-space non-emptiness (exhaustive over the
/// 225 ordered prior-pair configurations plus a randomized property), the
/// 30-day multi-seed simulation, and the rollover integration (seed
/// lineage, epoch stamp, exactly-once, prior-gap semantics).
///
/// House discipline: named constants only (`Thresholds.Quest`,
/// `QuestCatalog`, `QuestGeneration.currentEpoch`, `BondRules`) — raw spec
/// literals live in `QuestGenerationPinnedTests`.
@Suite("Quest generation — constraints, non-emptiness, simulation, rollover (TASK-018)")
struct QuestGenerationTests {

    private let fixture = InteractionFixture()
    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
    private let day = "2026-09-08"

    private func quest(_ id: QuestID) -> QuestProgress {
        QuestProgress(questID: id, progress: 0, completed: false)!
    }

    private func pair(_ a: QuestID, _ b: QuestID) -> [QuestProgress] {
        [quest(a), quest(b)]
    }

    // MARK: Determinism (AC-1; Required Test 1)

    @Test("identical (dayKey, seed, priorTwoSets, epoch) yield identical sets — twins", arguments: [UInt64(0), 7, 0xDEAD_BEEF])
    func generationTwins(seed: UInt64) {
        let priors: [[QuestProgress]] = [pair(.q3, .q6), pair(.q2, .q5)]
        let a = QuestGeneration.generate(dayKey: day, seed: seed, priorTwoSets: priors, questGenEpoch: QuestGeneration.currentEpoch)
        let b = QuestGeneration.generate(dayKey: day, seed: seed, priorTwoSets: priors, questGenEpoch: QuestGeneration.currentEpoch)
        #expect(a == b)
    }

    @Test("varying the seed varies the day (distinct sets arise across seeds; none rejects)")
    func seedsVaryTheDay() {
        let priors: [[QuestProgress]] = [pair(.q4, .q6), pair(.q3, .q7)]
        var seen: Set<Set<QuestID>> = []
        for seed: UInt64 in 0..<40 {
            seen.insert(Set(QuestGeneration.generate(dayKey: day, seed: seed, priorTwoSets: priors, questGenEpoch: QuestGeneration.currentEpoch).map(\.questID)))
        }
        #expect(seen.count > 1) // the mapping is seed-sensitive (twins pin the exact equality)
    }

    @Test("the shape is always the anchor plus a catalog-ordered distinct pair at zero progress")
    func generatedShape() {
        for seed: UInt64 in 0..<30 {
            let set = QuestGeneration.generate(dayKey: day, seed: seed, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch)
            #expect(set.count == Thresholds.Quest.questsPerDay)
            #expect(set.first?.questID == .q1) // the mandatory anchor (FR-14 AC-3)
            #expect(Set(set.map(\.questID)).count == Thresholds.Quest.questsPerDay) // no duplicates
            #expect(set.allSatisfy { !$0.completed && $0.progress == 0 }) // zero progress, not completed
            let catalog = QuestCatalog.all.map(\.id)
            let drawn = Array(set.dropFirst().map(\.questID))
            #expect(catalog.firstIndex(of: drawn[0])! < catalog.firstIndex(of: drawn[1])!) // catalog order
        }
    }

    // MARK: Constraint unit proofs at the pool level (AC-2; Required Test 2)

    @Test("the consecutive-pair ban alone removes exactly yesterday's pair (set equality)")
    func consecutiveRepeatBan() {
        // Both priors carry Q6 → Q6 credit is active → no restriction; the
        // ban alone shapes the pool.
        let priors: [[QuestProgress]] = [pair(.q2, .q6), pair(.q3, .q6)]
        let pool = QuestGeneration.candidatePool(priorTwoSets: priors)
        let full = QuestGeneration.allCandidatePairs()
        #expect(pool.count == full.count - 1)
        #expect(!pool.contains { Set($0) == Set([QuestID.q2, .q6]) })
        #expect(Set(pool.map(Set.init)) == Set(full.map(Set.init)).subtracting([[QuestID.q2, .q6]]))
    }

    @Test("the ban compares SETS: yesterday's pair in the other order is still banned")
    func banIsSetEquality() {
        // The catalog order of yesterday's drawn pair is [q2, q6]; a prior
        // recorded as [q6, q2] names the same set.
        let priors: [[QuestProgress]] = [pair(.q6, .q2), pair(.q3, .q6)]
        let pool = QuestGeneration.candidatePool(priorTwoSets: priors)
        #expect(!pool.contains { Set($0) == Set([QuestID.q2, .q6]) })
    }

    @Test("the ban combines with the Q6 restriction: the tightest case leaves exactly four pairs")
    func banCombinedWithRestriction() {
        // Yesterday [q2,q6] (contains Q6) but the OLDER prior [q3,q4] lacks
        // it → no Q6 credit → restriction active; the ban first removes the
        // Q6-carrying yesterday pair → the restricted pool keeps 5 − 1 = 4.
        let priors: [[QuestProgress]] = [pair(.q2, .q6), pair(.q3, .q4)]
        let pool = QuestGeneration.candidatePool(priorTwoSets: priors)
        #expect(pool.count == 4)
        #expect(pool.allSatisfy { $0.contains(.q6) })
        #expect(!pool.contains { Set($0) == Set([QuestID.q2, .q6]) })
        // …and the drawn set is still well-formed and carries Q6.
        let generated = QuestGeneration.generate(dayKey: day, seed: 7, priorTwoSets: priors, questGenEpoch: QuestGeneration.currentEpoch)
        #expect(generated.contains { $0.questID == .q6 })
    }

    @Test("the Q6 3-day window restricts to the Q6 pairs unless BOTH priors carry Q6")
    func q6WindowRestriction() {
        // One prior lacks Q6 → no credit → restriction.
        let mixedPriors: [[QuestProgress]] = [pair(.q2, .q6), pair(.q3, .q4)]
        #expect(QuestGeneration.candidatePool(priorTwoSets: mixedPriors).allSatisfy { $0.contains(.q6) })
        // Both lack Q6 → restriction.
        let q6lessPriors: [[QuestProgress]] = [pair(.q2, .q3), pair(.q4, .q5)]
        let restricted = QuestGeneration.candidatePool(priorTwoSets: q6lessPriors)
        #expect(restricted.count == 5)
        #expect(restricted.allSatisfy { $0.contains(.q6) })
        // Both carry Q6 → credit → no restriction (the ban may still apply).
        let creditedPriors: [[QuestProgress]] = [pair(.q5, .q6), pair(.q6, .q7)]
        let credited = QuestGeneration.candidatePool(priorTwoSets: creditedPriors)
        #expect(credited.count == QuestGeneration.allCandidatePairs().count - 1)
        #expect(!credited.allSatisfy { $0.contains(.q6) })
    }

    @Test("unknown or short priors count as no Q6 credit (fresh-install day 1 always includes Q6)")
    func unknownPriorsForceQ6() {
        // No priors at all.
        #expect(QuestGeneration.candidatePool(priorTwoSets: []).allSatisfy { $0.contains(.q6) })
        // One prior, even Q6-carrying: the missing tail is unknown prior.
        #expect(QuestGeneration.candidatePool(priorTwoSets: [pair(.q6, .q7)]).allSatisfy { $0.contains(.q6) })
        // …and through the generator itself, day 1 of a fresh install:
        for seed: UInt64 in 0..<20 {
            let set = QuestGeneration.generate(dayKey: day, seed: seed, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch)
            #expect(set.contains { $0.questID == .q6 })
        }
    }

    // MARK: Non-emptiness (AC-2; Required Test 3)

    @Test("the pool is never empty, exhaustively over all 225 ordered prior-pair configurations")
    func exhaustiveNonEmptiness() {
        let pairs = QuestGeneration.allCandidatePairs()
        var tightest = Int.max
        for yesterday in pairs {
            for older in pairs {
                let priors = [yesterday.map { quest($0) }, older.map { quest($0) }]
                let pool = QuestGeneration.candidatePool(priorTwoSets: priors)
                #expect(!pool.isEmpty)
                tightest = min(tightest, pool.count)
            }
        }
        #expect(tightest == 4) // the contract's ≥ 4 bound, met exactly at the tightest case
    }

    @Test("property over randomized prior shapes (including short/empty priors): pool never empty")
    func randomizedNonEmptiness() {
        var rng = SeededGenerator(seed: 2_026)
        let pairs = QuestGeneration.allCandidatePairs()
        for _ in 0..<200 {
            let count = Int(rng.next() % 3) // 0, 1, or 2 priors
            let priors = (0..<count).map { _ in
                pairs[Int(rng.next() % UInt64(pairs.count))].map { quest($0) }
            }
            // Occasionally corrupt a prior's shape (progress/completed noise
            // the real ledger can hold mid-day).
            let noisy = priors.map { prior in
                prior.map { q in QuestProgress(questID: q.questID, progress: Int(rng.next() % 2), completed: false)! }
            }
            let pool = QuestGeneration.candidatePool(priorTwoSets: noisy)
            #expect(!pool.isEmpty)
        }
    }

    // MARK: The 30-day simulation (AC-2; Required Test 4)

    @Test(
        "30-day simulation: exactly 3 daily, Q1 anchor, Q6 in every rolling 3-day window, no consecutive pair repeat",
        arguments: [UInt64(1), 7, 42, 2_026, 99_073]
    )
    func thirtyDaySimulation(seed: UInt64) {
        var priors: [[QuestProgress]] = [] // non-anchor pairs, NEWEST FIRST
        var sets: [[QuestProgress]] = []
        for index in 1...30 {
            let key = String(format: "sim-day-%03d", index)
            let daySeed = DaySeed.make(petID: petID, localDayKey: key, epoch: QuestGeneration.currentEpoch, salt: .quest)
            let set = QuestGeneration.generate(dayKey: key, seed: daySeed, priorTwoSets: priors, questGenEpoch: QuestGeneration.currentEpoch)

            // Per-day clauses (FR-15 AC-2).
            #expect(set.count == Thresholds.Quest.questsPerDay)
            #expect(set.first?.questID == .q1)
            #expect(Set(set.map(\.questID)).count == Thresholds.Quest.questsPerDay)
            let drawn = Array(set.dropFirst().map(\.questID))
            if let yesterday = priors.first {
                #expect(Set(yesterday.map(\.questID)) != Set(drawn)) // no consecutive-repeat pair
            }

            sets.append(set)
            priors = ([drawn.map { quest($0) }] + priors).prefix(2).map { $0 }
        }
        // The rolling 3-day window clause, over the whole month.
        for start in 0...(sets.count - Thresholds.Quest.questsPerDay) {
            let window = sets[start..<(start + Thresholds.Quest.questsPerDay)]
            #expect(
                window.contains { $0.contains { $0.questID == .q6 } },
                "days \(start + 1)…\(start + Thresholds.Quest.questsPerDay) lack Q6"
            )
        }
    }

    // MARK: Rollover integration (AC-6; Required Test 8)

    /// A state over an explicit ledger (the fold's origin).
    private func singleDayState(days: [DayRecord], lastEvaluatedAt: Instant, wakefulness: Wakefulness = .awake) -> EngineState {
        let pet = Pet(id: petID, name: "Momo", createdAt: fixture.instant("2026-01-01T00:00:00Z"))!
        return EngineState(
            pet: pet,
            state: PetState(mood: 60, energy: 80, bond: 0, wakefulness: wakefulness, activity: nil, lastFedAt: nil, satietyPhase: .hungry)!,
            days: days,
            settings: SettingsState(onboardingComplete: true, hapticsEnabled: true),
            pendingHandshake: nil,
            processedIntents: [],
            highestCelebratedStage: .newFriends,
            lastOpenedAt: lastEvaluatedAt,
            lastEvaluatedAt: lastEvaluatedAt
        )
    }

    private func record(dayKey: String, questSet: [QuestProgress]) -> DayRecord {
        DayRecord(
            dayKey: dayKey,
            feedCount: 0,
            playCount: 0,
            careCount: 0,
            patCount: 0,
            questSet: questSet,
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0,
            questGenEpoch: QuestGeneration.currentEpoch
        )!
    }

    @Test("midnight rollover generates the landing day's set from the quest-salt seed lineage")
    func rolloverGeneratesTheLandingDay() {
        let existing = [record(dayKey: "2026-09-08", questSet: QuestGeneration.generate(dayKey: "2026-09-08", seed: 11, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch))]
        let start = singleDayState(days: existing, lastEvaluatedAt: fixture.instant("2026-09-08T23:59:00Z"))
        let fold = TimeFold.apply(
            petState: start.state,
            days: start.days,
            pendingHandshake: nil,
            from: start.lastEvaluatedAt,
            to: fixture.instant("2026-09-09T00:01:00Z"),
            calendar: fixture.calendar,
            petID: petID
        )
        #expect(fold.days.count == 2)
        let landed = fold.days.last!
        #expect(landed.dayKey == "2026-09-09")
        // The seed lineage is exactly §4.8's: DaySeed over (pet, landing day,
        // current epoch, .quest salt), priors = the two most recent records'
        // non-anchor pairs, NEWEST FIRST. A different salt/epoch/prior order
        // would break this equality.
        let priorPairs = existing.suffix(2).reversed().map { $0.questSet.filter { $0.questID != .q1 } }
        let expected = QuestGeneration.generate(
            dayKey: "2026-09-09",
            seed: DaySeed.make(petID: petID, localDayKey: "2026-09-09", epoch: QuestGeneration.currentEpoch, salt: .quest),
            priorTwoSets: priorPairs,
            questGenEpoch: QuestGeneration.currentEpoch
        )
        #expect(landed.questSet == expected)
        #expect(landed.questGenEpoch == QuestGeneration.currentEpoch) // the placeholder era (0) is gone
        #expect(landed.bondAwarded == 0 && !landed.helloAwarded && landed.familiesUsed.isEmpty) // a fresh day's ledger
    }

    @Test("generation happens only at record creation: a re-landed past day is never regenerated")
    func rolloverNeverRegeneratesAPastDay() {
        let existing = [record(dayKey: "2026-09-08", questSet: [quest(.q1), quest(.q2), quest(.q6)])]
        let start = singleDayState(days: existing, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        // A pat completes Q1 during the day…
        let patted = fixture.send(start, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: "2026-09-08")
        #expect(patted.newState.days.first?.questSet.first?.completed == true)
        // …and a later fold that lands on the SAME day finds the key present:
        // no second record, no reset of the ticked set.
        let refolded = TimeFold.apply(
            petState: patted.newState.state,
            days: patted.newState.days,
            pendingHandshake: nil,
            from: patted.newState.lastEvaluatedAt,
            to: fixture.instant("2026-09-08T18:00:00Z"),
            calendar: fixture.calendar,
            petID: petID
        )
        #expect(refolded.days.count == 1)
        #expect(refolded.days.first?.questSet == patted.newState.days.first?.questSet)
        #expect(refolded.days.first?.patCount == 1)
    }

    @Test("prior-gap semantics: one known prior (unknown tail) forces Q6; absent days are never retro-created")
    func rolloverPriorGap() {
        // The ledger holds ONLY 2026-09-07; the fold spans 09-08 (absent —
        // stays absent) and lands 09-09. The 09-09 priors are [09-07's pair]
        // alone → the unknown tail counts as no Q6 credit.
        let priorSet = QuestGeneration.generate(dayKey: "2026-09-07", seed: 5, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch)
        let existing = [record(dayKey: "2026-09-07", questSet: priorSet)]
        let start = singleDayState(days: existing, lastEvaluatedAt: fixture.instant("2026-09-07T12:00:00Z"))
        let fold = TimeFold.apply(
            petState: start.state,
            days: start.days,
            pendingHandshake: nil,
            from: start.lastEvaluatedAt,
            to: fixture.instant("2026-09-09T00:01:00Z"),
            calendar: fixture.calendar,
            petID: petID
        )
        #expect(fold.days.map(\.dayKey) == ["2026-09-07", "2026-09-09"]) // the gap stays absent (FR-12 AC-1)
        let landed = fold.days.last!
        #expect(landed.questSet.contains { $0.questID == .q6 }) // unknown tail → Q6 forced
        let priors = [priorSet.filter { $0.questID != .q1 }]
        #expect(landed.questSet == QuestGeneration.generate(
            dayKey: "2026-09-09",
            seed: DaySeed.make(petID: petID, localDayKey: "2026-09-09", epoch: QuestGeneration.currentEpoch, salt: .quest),
            priorTwoSets: priors,
            questGenEpoch: QuestGeneration.currentEpoch
        ))
    }

    @Test("fresh install: the very first fold creates day 1 with Q6 in its generated set")
    func freshInstallDayOneContainsQ6() {
        let start = singleDayState(days: [], lastEvaluatedAt: fixture.instant("2026-09-08T22:00:00Z"))
        let fold = TimeFold.apply(
            petState: start.state,
            days: start.days,
            pendingHandshake: nil,
            from: start.lastEvaluatedAt,
            to: fixture.instant("2026-09-08T22:30:00Z"),
            calendar: fixture.calendar,
            petID: petID
        )
        #expect(fold.days.count == 1)
        let dayOne = fold.days.first!
        #expect(dayOne.questSet.contains { $0.questID == .q6 }) // day 1 always includes Q6
        #expect(dayOne.questSet.first?.questID == .q1)
        #expect(dayOne.questGenEpoch == QuestGeneration.currentEpoch)
    }

    @Test("exactly-once under a re-derived landing dayKey: the present record is found, never duplicated")
    func rolloverExactlyOnceUnderBackwardClock() {
        let generated = QuestGeneration.generate(dayKey: "2026-09-09", seed: 11, priorTwoSets: [], questGenEpoch: QuestGeneration.currentEpoch)
        let existing = [
            record(dayKey: "2026-09-08", questSet: [quest(.q1), quest(.q2), quest(.q6)]),
            record(dayKey: "2026-09-09", questSet: generated),
        ]
        let start = singleDayState(days: existing, lastEvaluatedAt: fixture.instant("2026-09-09T00:01:00Z"))
        // The ledger already holds the landing dayKey (created by an earlier
        // session); a fold re-deriving 2026-09-09 finds the key present — no
        // second record, and the stored generated set is untouched.
        let refolded = TimeFold.apply(
            petState: start.state,
            days: start.days,
            pendingHandshake: nil,
            from: start.lastEvaluatedAt,
            to: fixture.instant("2026-09-09T00:02:00Z"),
            calendar: fixture.calendar,
            petID: petID
        )
        #expect(refolded.days.count == 2)
        #expect(refolded.days.filter { $0.dayKey == "2026-09-09" }.count == 1)
        #expect(refolded.days.last?.questSet == generated)
    }
}
