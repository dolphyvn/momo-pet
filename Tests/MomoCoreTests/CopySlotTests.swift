import Testing
import Foundation
@testable import MomoCore

/// The §4.9 slot derivation + react-family mapping as BEHAVIOR over the
/// named constants (TASK-019 Requirement 4b; Required Test 3): the boundary
/// table is expressed through `FoldRules`/`CopyRules` so a retuned cut-off
/// moves the table with it — the raw-literal pins with exact attribution
/// live in `CopySelectionPinnedTests` (the TASK-018 discipline).
@Suite("Copy slots — time-slot derivation + react families (TASK-019)")
struct CopySlotTests {

    // MARK: Slot boundary table (AC-4's eight rows, over named constants)

    /// The cut-off rule: the cut-off HOUR opens the NEXT slot — so each row
    /// pairs the last hour of a slot with the first hour of the next.
    @Test("the slot boundary table: night→morning→day→evening→night at the named cut-offs", arguments: [
        (FoldRules.morningWakeHour - 1, CopyRules.LineSlot.night),
        (FoldRules.morningWakeHour, CopyRules.LineSlot.morning),
        (CopyRules.daySlotStartHour - 1, CopyRules.LineSlot.morning),
        (CopyRules.daySlotStartHour, CopyRules.LineSlot.day),
        (CopyRules.eveningSlotStartHour - 1, CopyRules.LineSlot.day),
        (CopyRules.eveningSlotStartHour, CopyRules.LineSlot.evening),
        (FoldRules.nightOnsetHour - 1, CopyRules.LineSlot.evening),
        (FoldRules.nightOnsetHour, CopyRules.LineSlot.night),
    ])
    func slotBoundaryTable(hour: Int, expected: CopyRules.LineSlot) {
        #expect(CopyRules.timeSlot(forLocalHour: hour) == expected,
                "hour \(hour) must select \(expected) — the cut-off hour opens the next slot")
    }

    // MARK: Totality over the clock

    @Test("every wall hour selects exactly one TIME slot — never a context slot")
    func totalOverTwentyFourHours() {
        let timeSlots: Set<CopyRules.LineSlot> = [.morning, .day, .evening, .night]
        for hour in 0...23 {
            let slot = CopyRules.timeSlot(forLocalHour: hour)
            #expect(timeSlots.contains(slot), "hour \(hour) selected the non-time slot \(slot)")
        }
    }

    /// Recorded reading (Requirement 4b): the `greeting` and `care-moment`
    /// CONTEXT slots are chosen by the presentation's priority (UX-12), not
    /// by time — no hour can ever derive onto them.
    @Test("timeSlot never returns the greeting or care-moment context slots")
    func timeSlotNeverSelectsContextSlots() {
        for hour in 0...23 {
            #expect(CopyRules.timeSlot(forLocalHour: hour) != .greeting)
            #expect(CopyRules.timeSlot(forLocalHour: hour) != .careMoment)
        }
    }

    // MARK: The context slots' keyspace (exposed, never time-derived)

    /// Keyspace exposure only (Requirement 4b): the context slots mint keys
    /// under the same `momo.line.<slot>.<nn>` template so the catalog stays
    /// uniform — with the same rawValues the template spells, including the
    /// hyphenated `care-moment`. The index is the single-slot pool's only
    /// index (count − 1, zero-based) from the constants home — the raw `.00`
    /// literals live in `CopySelectionPinnedTests`.
    @Test("the context slots' keys are spelled by the one slot template (rawValues participate)")
    func contextSlotKeySpellings() {
        let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
        let day = "2026-09-08"
        let onlyIndex = String(format: "%02d", CopyRules.slotLineCount(for: .greeting) - 1)
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .greeting)
            == "momo.line.\(CopyRules.LineSlot.greeting.rawValue).\(onlyIndex)")
        #expect(LineSelection.slotLineKey(petID: petID, dayKey: day, slot: .careMoment)
            == "momo.line.\(CopyRules.LineSlot.careMoment.rawValue).\(onlyIndex)")
        #expect(CopyRules.LineSlot.careMoment.rawValue == "care-moment")
    }

    // MARK: React families (04 §10.4's intent→family mapping)

    @Test("every interaction intent maps to its copy family — pat→touch, feed→feed, play→play, tuckIn/nap→care", arguments: [
        (InteractionIntent.Kind.pat(gesture: .tap, zone: .head), CopyRules.ReactFamily.touch),
        (InteractionIntent.Kind.pat(gesture: .stroke, zone: .belly), CopyRules.ReactFamily.touch),
        (InteractionIntent.Kind.feed, CopyRules.ReactFamily.feed),
        (InteractionIntent.Kind.play, CopyRules.ReactFamily.play),
        (InteractionIntent.Kind.tuckIn, CopyRules.ReactFamily.care),
        (InteractionIntent.Kind.nap, CopyRules.ReactFamily.care),
    ])
    func intentFamilyMapping(kind: InteractionIntent.Kind, expected: CopyRules.ReactFamily) {
        #expect(CopyRules.ReactFamily(kind) == expected)
    }

    /// Each family's key names the family — the rawValue is the template's
    /// middle segment, so a renamed case shifts the keyspace (a catalog-era
    /// event, never a silent one). Since TASK-034's contracted touch-pool
    /// growth (1→5 copies), no family has a single "only" index, so the law
    /// here is structural: the key is the react template with a suffix
    /// INSIDE the family's pool. The concrete day-stable draws stay raw in
    /// `CopySelectionPinnedTests`.
    @Test("each family's react key names its family under the react template")
    func familyKeySpellings() {
        let petID = UUID(uuidString: "7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D")!
        let day = "2026-09-08"
        for family in CopyRules.ReactFamily.allCases {
            let key = LineSelection.reactLineKey(petID: petID, dayKey: day, family: family)
            let prefix = "momo.line.react.\(family.rawValue)."
            #expect(key.hasPrefix(prefix), "\(key) must name its family under the react template")
            let index = Int(key.dropFirst(prefix.count))
            #expect(index != nil, "the key's suffix is a pool index — got '\(key)'")
            #expect((0..<CopyRules.reactLineCount(for: family)).contains(index ?? -1),
                    "the draw stays inside the family's pool of \(CopyRules.reactLineCount(for: family))")
        }
    }
}
