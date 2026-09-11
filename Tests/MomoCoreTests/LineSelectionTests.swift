import Testing
import Foundation
@testable import MomoCore

/// The §4.9 variational picks' behavior contract (TASK-019 Requirement 4a;
/// Required Test 4–5): day-stability of every pick (twins, within-day,
/// cross-day variation over synthetic pools), the react lineKey riding the
/// engine's ResponsePlans per family (TASK-016's nil seam, filled), the
/// duplicate-intent replay carrying the same plan key, and the copy epoch's
/// participation in the seed (a bump resalts — the §4.10 obligation).
/// The one-draw recipe pin and the raw key literals live in
/// `CopySelectionPinnedTests`.
@Suite("Line selection — day-stable picks + plan integration (TASK-019)")
struct LineSelectionTests {

    private let fixture = InteractionFixture()
    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
    private let day = "2026-09-08"

    // MARK: Day-stability (Required Test 4)

    @Test("identical (pet, day, context) pick identically — the twin run")
    func twinPicksAreIdentical() {
        for family in CopyRules.ReactFamily.allCases {
            #expect(LineSelection.reactLineKey(petID: petID, dayKey: day, family: family)
                == LineSelection.reactLineKey(petID: petID, dayKey: day, family: family))
        }
        for slot in CopyRules.LineSlot.allCases {
            #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: slot)
                == LineSelection.slotLineKey(petID: petID, dayKey: day, slot: slot))
        }
    }

    /// Within-day stability over many hours of the same day: the pick is a
    /// function of (pet, DAY, context) — the wall clock never enters.
    @Test("the pick is stable across the day's hours — the hour never enters the seed")
    func withinDayStabilityAcrossHours() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let morningKey = LineSelection.reactLineKey(petID: petID, dayKey: day, family: .touch)
        for hour in 0...23 {
            let instant = fixture.instant(String(format: "%@T%02d:30:00Z", day, hour))
            #expect(DayKey.make(from: instant, calendar: calendar) == day) // sweep sanity
            let hourKey = LineSelection.reactLineKey(petID: petID, dayKey: day, family: .touch)
            #expect(hourKey == morningKey, "the pick moved with the hour — the seed stopped being day-stable")
        }
    }

    /// Cross-day variation: over synthetic pool sizes 1–5 (the constants
    /// home's placeholder pools are 1 — variation is exercised through the
    /// same `pick` the production keys use), consecutive days draw varying
    /// indices, while a pool of 1 is constant by arithmetic.
    @Test("consecutive days vary the draw for pools > 1 — synthetic pool sweep 1–5 over 30 days", arguments: [1, 2, 3, 4, 5])
    func crossDayVariationSweep(poolCount: Int) {
        let days = (0..<30).map { String(format: "2026-%02d-%02d", 8 + $0 / 24, 1 + $0 % 24) }
        let picks = days.map { LineSelection.pick(seed: LineSelection.copySeed(petID: petID, dayKey: $0), poolCount: poolCount) }
        #expect(picks.allSatisfy { $0 >= 0 && $0 < poolCount })
        if poolCount == 1 {
            #expect(Set(picks) == [0])
        } else {
            #expect(Set(picks).count >= 2,
                    "30 days of SHA-256-salted seeds collapsed onto one index of a \(poolCount)-slot pool — the seed stopped varying by day")
        }
    }

    /// The engine-side seed is §4.10's copy-domain derivation: pet + dayKey +
    /// the CURRENT copy epoch + the `.copy` salt. The epoch participates
    /// (any other epoch resalts — the bump obligation's teeth), and the salt
    /// separates the copy picks from the choreography and quest domains.
    @Test("copySeed wires the current epoch and the copy salt; any other epoch resalts")
    func epochAndSaltParticipate() {
        #expect(LineSelection.copySeed(petID: petID, dayKey: day)
            == DaySeed.make(petID: petID, localDayKey: day, epoch: CopyRules.copyEpoch, salt: .copy))
        for otherEpoch in [CopyRules.copyEpoch - 1, CopyRules.copyEpoch + 1] where otherEpoch >= 0 {
            #expect(DaySeed.make(petID: petID, localDayKey: day, epoch: otherEpoch, salt: .copy)
                != LineSelection.copySeed(petID: petID, dayKey: day),
                "epoch \(otherEpoch) produced the current seed — the epoch stopped participating (a bump would resalt nothing)")
        }
        #expect(DaySeed.make(petID: petID, localDayKey: day, epoch: CopyRules.copyEpoch, salt: .choreography)
            != LineSelection.copySeed(petID: petID, dayKey: day))
        #expect(DaySeed.make(petID: petID, localDayKey: day, epoch: CopyRules.copyEpoch, salt: .quest)
            != LineSelection.copySeed(petID: petID, dayKey: day))
    }

    // MARK: React lineKey integration (Required Test 5)

    /// One engine-minted plan per intent family carries the family's
    /// day-stable key — the TASK-016 nil seam, filled at every
    /// `InteractionSemantics` site. Since TASK-034's contracted touch-pool
    /// growth (1→5 copies), the key is pinned STRUCTURALLY: the react
    /// template naming the family, with a suffix inside the family's pool
    /// (the concrete day-stable draws stay raw in the pinned suite).
    @Test("one plan per family carries its day-stable react key", arguments: [
        (InteractionIntent.Kind.pat(gesture: .tap, zone: .head), CopyRules.ReactFamily.touch),
        (InteractionIntent.Kind.feed, CopyRules.ReactFamily.feed),
        (InteractionIntent.Kind.play, CopyRules.ReactFamily.play),
        (InteractionIntent.Kind.tuckIn, CopyRules.ReactFamily.care),
        (InteractionIntent.Kind.nap, CopyRules.ReactFamily.care),
    ])
    func planCarriesFamilyKey(kind: InteractionIntent.Kind, family: CopyRules.ReactFamily) throws {
        let state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        let outcome = fixture.send(state, kind, at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        let plan = try #require(outcome.response)
        let key = try #require(plan.lineKey, "the plan carries a line key")
        let prefix = "momo.line.react.\(family.rawValue)."
        #expect(key.hasPrefix(prefix), "\(key) must name its family under the react template")
        let index = Int(key.dropFirst(prefix.count))
        #expect(index != nil, "the key's suffix is a pool index — got '\(key)'")
        #expect((0..<CopyRules.reactLineCount(for: family)).contains(index ?? -1),
                "the draw stays inside the family's pool of \(CopyRules.reactLineCount(for: family))")
    }

    /// The day-stability contract THROUGH the engine: two distinct fresh
    /// intents of the same family on the same local day (the duplicate
    /// delivery shape §6.4 guards against at the sync layer) mint the SAME
    /// plan key — the day's pick, not a per-event pick.
    @Test("a duplicate-intent replay of the same family carries the same plan key")
    func duplicateIntentReplayCarriesSamePlanKey() throws {
        let state = fixture.state(dayKey: day, lastEvaluatedAt: fixture.instant("2026-09-08T09:00:00Z"))
        let first = fixture.intent(.pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day)
        let replay = fixture.intent(.pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:01:00Z"), dayKey: day)
        let firstOutcome = fixture.send(state, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:00:00Z"), dayKey: day, intentID: first.id)
        let replayOutcome = fixture.send(firstOutcome.newState, .pat(gesture: .tap, zone: .head), at: fixture.instant("2026-09-08T09:01:00Z"), dayKey: day, intentID: replay.id)
        let firstPlan = try #require(firstOutcome.response)
        let replayPlan = try #require(replayOutcome.response)
        #expect(firstPlan.lineKey != nil)
        #expect(replayPlan.lineKey == firstPlan.lineKey,
                "the second fresh intent drew a different key — the pick stopped being day-stable")
    }
}
