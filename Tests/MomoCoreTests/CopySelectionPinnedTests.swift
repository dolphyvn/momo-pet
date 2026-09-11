import Testing
import Foundation
@testable import MomoCore

/// §4.9's raw-literal pins (TASK-019 Requirement 4c + Required Test 7): this
/// suite is the ANTI-ECHO exception — the copy domain's numbers and key
/// templates appear here raw so a silent change to `CopyRules`,
/// `Thresholds.Greeting`, or the `LineSelection` recipe bites with exact
/// attribution (the `QuestGenerationPinnedTests`/`ThresholdsPinnedToPRDTests`
/// discipline). Behavior proofs over NAMED constants live in
/// `CopySlotTests`/`LineSelectionTests`/`GreetingSelectionTests`.
///
/// Bump obligations encoded by these pins:
/// - a POOL change (a real catalog landing) ⇒ bump `copyEpoch` §4.10 — the
///   full-key pins below fail until both move together;
/// - a CUT-OFF retune (12:00 / 18:00 are engine-owned starting values) ⇒
///   this boundary table fails and the constants edit is the one fix;
/// - a RECIPE change (extra/reordered draw) ⇒ the one-draw pin fails.
@Suite("Copy selection — §4.9 literals, one-draw recipe, raw keys (TASK-019)")
struct CopySelectionPinnedTests {

    private let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
    private let day = "2026-09-08"

    // MARK: The epoch + pool counts (TASK-033's slot catalog; TASK-034's touch pool; TASK-035's feed/play/care pools)

    @Test("the current copy-selection epoch is 4 (0 is the pre-selection placeholder marker; 1 the placeholder era, 2 the TASK-033 slot catalog, 3 the TASK-034 touch pool, 4 the TASK-035 feed/play/care pools)")
    func copyEpochIsFour() {
        #expect(CopyRules.copyEpoch == 4)
    }

    @Test("the pool counts: ten lines per time slot (TASK-033's catalog), five for touch (TASK-034's pool), six for feed/play/care (TASK-035's pools), 1 for the context slots")
    func poolCountsPinned() {
        for family in CopyRules.ReactFamily.allCases {
            let expected: Int
            switch family {
            case .touch: expected = 5
            case .feed, .play, .care: expected = 6
            }
            #expect(CopyRules.reactLineCount(for: family) == expected, "\(family)'s react pool drifted — a catalog change bumps the copy epoch with it (§4.10)")
        }
        for slot in CopyRules.LineSlot.allCases {
            let expected: Int
            switch slot {
            case .morning, .day, .evening, .night: expected = 10
            case .greeting, .careMoment: expected = 1
            }
            #expect(CopyRules.slotLineCount(for: slot) == expected, "\(slot)'s slot pool drifted — a catalog change bumps the copy epoch with it (§4.10)")
        }
    }

    // MARK: The slot-hour literals (engine-owned starting values)

    @Test("the day/evening cut-offs are exactly 12:00 and 18:00 (the night hours stay FoldRules')")
    func slotCutOffsPinned() {
        #expect(CopyRules.daySlotStartHour == 12)
        #expect(CopyRules.eveningSlotStartHour == 18)
    }

    /// The full raw hour table: 0–6 night, 7–11 morning, 12–17 day,
    /// 18–21 evening, 22–23 night. A cut-off retune or a FoldRules drift
    /// fails with the exact hour attributed.
    @Test("the raw slot table: every hour selects exactly the slot the spec text reads")
    func rawSlotTable() {
        let expected: [CopyRules.LineSlot] = [
            .night, .night, .night, .night, .night, .night, .night, // 0–6
            .morning, .morning, .morning, .morning, .morning,       // 7–11
            .day, .day, .day, .day, .day, .day,                     // 12–17
            .evening, .evening, .evening, .evening,                 // 18–21
            .night, .night,                                         // 22–23
        ]
        for hour in 0...23 {
            #expect(CopyRules.timeSlot(forLocalHour: hour) == expected[hour], "hour \(hour) drifted off the raw table")
        }
    }

    // MARK: The keyspace literals (04 §10.4's class names)

    @Test("the slot raw values are exactly the catalog class names — greeting and care-moment included, hyphenated")
    func slotRawValuesPinned() {
        #expect(CopyRules.LineSlot.allCases.map(\.rawValue)
            == ["morning", "day", "evening", "night", "greeting", "care-moment"])
    }

    @Test("the react family raw values are exactly the four catalog families")
    func familyRawValuesPinned() {
        #expect(CopyRules.ReactFamily.allCases.map(\.rawValue) == ["touch", "feed", "play", "care"])
    }

    // MARK: The full-key literals (template + the epoch-4 draw)

    /// The full keys for one (pet, day): at epoch 4 the draw (derived by
    /// the TASK-035 probe, run-then-deleted — seed `0xda4187ce48ff0bb7`,
    /// draw `0xfdb4bc3ce6f541d3`) lands index `07` over the ten-line TIME
    /// slots (`0xfdb4bc3ce6f541d3 % 10` — the epoch bump's designed
    /// reshuffle, §4.10), KEEPS index `02` over TASK-034's five-line touch
    /// pool (`% 5` — the residue survived the resalt), and draws index `01`
    /// over TASK-035's six-line feed/play/care pools (`% 6`), while the
    /// context slots (greeting, care-moment) stay at `00` — their pool of 1
    /// can only mint the zero index (care-moment's real lines resolve by
    /// the FIXED `HomeCopyKeys.careMomentLineKey` lookup, never through
    /// this draw). A pool bump, a draw-moving epoch bump, or a template
    /// change fails here with the exact key attributed.
    @Test("the raw keys for the pinned (pet, day): epoch 4 draws .07 in the ten-line slots, keeps .02 in the touch pool, draws .01 in the feed/play/care pools, .00 in the context slots")
    func rawKeysPinned() {
        #expect(LineSelection.reactLineKey(petID: petID, dayKey: day, family: .touch) == "momo.line.react.touch.02")
        #expect(LineSelection.reactLineKey(petID: petID, dayKey: day, family: .feed) == "momo.line.react.feed.01")
        #expect(LineSelection.reactLineKey(petID: petID, dayKey: day, family: .play) == "momo.line.react.play.01")
        #expect(LineSelection.reactLineKey(petID: petID, dayKey: day, family: .care) == "momo.line.react.care.01")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .morning) == "momo.line.morning.07")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .day) == "momo.line.day.07")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .evening) == "momo.line.evening.07")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .night) == "momo.line.night.07")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .greeting) == "momo.line.greeting.00")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .careMoment) == "momo.line.care-moment.00")
    }

    // MARK: The one-draw recipe (the TASK-018 twoDrawPin discipline)

    /// The recipe pin: `pick` consumes EXACTLY ONE draw of a generator
    /// seeded with the given seed, reduced modulo the pool count — replayed
    /// here independently of the production code. An extra draw, a
    /// reordered draw, or a different reduction fails with this pin.
    @Test("the seed→index mapping consumes exactly one draw, reduced modulo the pool count")
    func oneDrawRecipePin() {
        let seed: UInt64 = 0x5EED_5EED_5EED_5EED
        for poolCount in [1, 2, 3, 5, 8] {
            var rng = SeededGenerator(seed: seed)
            let expected = Int(rng.next() % UInt64(poolCount))
            #expect(LineSelection.pick(seed: seed, poolCount: poolCount) == expected,
                    "pool \(poolCount): the recipe moved off one-draw-modulo — a copy-epoch-class spec change")
        }
    }

    @Test("the greeting thresholds back the selection: floor 5 minutes, missed-you bound 36 hours")
    func greetingThresholdsRestated() {
        // Cross-home restatement for attribution: the values' primary raw
        // pins live in `ThresholdsPinnedToPRDTests`; this suite pins them
        // too because the greeting selector's TABLE SHAPE (which rule can
        // fire when) depends on their magnitudes.
        #expect(Thresholds.Greeting.regreetFloorMinutes == 5)
        #expect(Thresholds.Greeting.missedYouAfterHours == 36)
    }
}
