import Testing
@testable import MomoCore

/// Focused derivation tests for TASK-012 (AC-2): representative boundary
/// values at every PRD §3 cut-off, plus the quest-catalog table pin
/// (PRD §5.2 byte-level, backing `QuestCatalog.entry(for:)`'s one-entry-per-ID
/// invariant). Exhaustive 0…100 sweeps and the FR-9 AC-1 property test are
/// TASK-013 — deliberately not here.
@Suite("Band/stage derivations + quest catalog (TASK-012)")
struct BandDerivationTests {

    // MARK: - makeMoodBand (PRD §3.1: Low 0–19, Wistful 20–44, Content 45–74, Joyful 75–100)

    @Test("mood band boundaries match PRD §3.1 (cut-offs 20/45/75)")
    func moodBandBoundaries() {
        #expect(makeMoodBand(0) == .low)
        #expect(makeMoodBand(19) == .low)
        #expect(makeMoodBand(19.5) == .low)
        #expect(makeMoodBand(20) == .wistful)
        #expect(makeMoodBand(44) == .wistful)
        #expect(makeMoodBand(44.5) == .wistful)
        #expect(makeMoodBand(45) == .content)
        #expect(makeMoodBand(74) == .content)
        #expect(makeMoodBand(74.5) == .content)
        #expect(makeMoodBand(75) == .joyful)
        #expect(makeMoodBand(100) == .joyful)
    }

    @Test("mood band is total: out-of-range and NaN deterministically map to low")
    func moodBandTotality() {
        #expect(makeMoodBand(-0.5) == .low)
        #expect(makeMoodBand(100.5) == .joyful)
        #expect(makeMoodBand(Double.nan) == .low)
    }

    // MARK: - makeEnergyBand (PRD §3.2: Exhausted 0–19, Drowsy 20–44, Relaxed 45–74, Energetic 75–100)

    @Test("energy band boundaries match PRD §3.2 (same cut-off triple)")
    func energyBandBoundaries() {
        #expect(makeEnergyBand(0) == .exhausted)
        #expect(makeEnergyBand(19.5) == .exhausted)
        #expect(makeEnergyBand(20) == .drowsy)
        #expect(makeEnergyBand(44.5) == .drowsy)
        #expect(makeEnergyBand(45) == .relaxed)
        #expect(makeEnergyBand(74.5) == .relaxed)
        #expect(makeEnergyBand(75) == .energetic)
        #expect(makeEnergyBand(100) == .energetic)
    }

    // MARK: - makeBondStage (PRD §3.3: 0–149, 150–399, 400–749, 750–1000)

    @Test("bond stage boundaries match PRD §3.3 (thresholds 149/399/749)")
    func bondStageBoundaries() {
        #expect(makeBondStage(0) == .newFriends)
        #expect(makeBondStage(149) == .newFriends)
        #expect(makeBondStage(150) == .gettingClose)
        #expect(makeBondStage(399) == .gettingClose)
        #expect(makeBondStage(400) == .bestFriends)
        #expect(makeBondStage(749) == .bestFriends)
        #expect(makeBondStage(750) == .soulCompanions)
        #expect(makeBondStage(1000) == .soulCompanions)
    }

    // MARK: - Thresholds are the pinned single source (derivation inputs)

    @Test("Thresholds constants equal the PRD numbers exactly")
    func thresholdsMatchPRD() {
        #expect(Thresholds.Scalar.lower == 0.0)
        #expect(Thresholds.Scalar.upper == 100.0)
        #expect(Thresholds.Band.lowUpperBound == 20.0)
        #expect(Thresholds.Band.contentLowerBound == 45.0)
        #expect(Thresholds.Band.joyfulLowerBound == 75.0)
        #expect(Thresholds.Bond.gettingCloseAt == 150)
        #expect(Thresholds.Bond.bestFriendsAt == 400)
        #expect(Thresholds.Bond.soulCompanionsAt == 750)
        #expect(Thresholds.Bond.maximum == 1000)
        #expect(Thresholds.Bond.dailyCap == 20)
        #expect(Thresholds.Quest.questsPerDay == 3)
        #expect(Thresholds.Quest.q1WindowClosesAtHour == 12)
        #expect(Thresholds.Quest.q6WindowStartHour == 20)
        #expect(Thresholds.Quest.q6WindowEndHour == 7)
    }

    // MARK: - Quest catalog (PRD §5.2, byte-level table pin)

    @Test("catalog holds exactly the seven PRD §5.2 quests, in table order")
    func catalogTable() {
        #expect(QuestID.allCases.count == 7)
        #expect(QuestID.allCases.map(\.rawValue) == ["Q1", "Q2", "Q3", "Q4", "Q5", "Q6", "Q7"])
        #expect(QuestCatalog.all.map(\.id) == [.q1, .q2, .q3, .q4, .q5, .q6, .q7])
        #expect(QuestCatalog.all.map(\.family) == [.greet, .feed, .feed, .play, .play, .care, .pet])
        #expect(QuestCatalog.all.map(\.target) == [1, 1, 2, 2, 3, 1, 3])
        #expect(QuestCatalog.all.map(\.window) == [
            .morningOnly, .allDay, .allDay, .allDay, .allDay, .eveningAndEarlyMorning, .allDay,
        ])
    }

    @Test("entry(for:) resolves every quest ID exactly once")
    func entryLookup() {
        for id in QuestID.allCases {
            #expect(QuestCatalog.entry(for: id).id == id)
        }
    }

    @Test("quest windows match PRD §5.2 at the hour boundaries")
    func windowMembership() {
        // Q1: until 12:00 local.
        #expect(QuestWindow.morningOnly.contains(hour: 0))
        #expect(QuestWindow.morningOnly.contains(hour: 11))
        #expect(!QuestWindow.morningOnly.contains(hour: 12))
        #expect(!QuestWindow.morningOnly.contains(hour: 23))
        // Q6: 20:00–07:00 local (owner-amended §5.5 rule 1 — both tails open).
        #expect(!QuestWindow.eveningAndEarlyMorning.contains(hour: 19))
        #expect(QuestWindow.eveningAndEarlyMorning.contains(hour: 20))
        #expect(QuestWindow.eveningAndEarlyMorning.contains(hour: 23))
        #expect(QuestWindow.eveningAndEarlyMorning.contains(hour: 0))
        #expect(QuestWindow.eveningAndEarlyMorning.contains(hour: 6))
        #expect(!QuestWindow.eveningAndEarlyMorning.contains(hour: 7))
        // All-day quests never exclude an hour.
        for hour in 0...23 {
            #expect(QuestWindow.allDay.contains(hour: hour))
        }
    }
}
