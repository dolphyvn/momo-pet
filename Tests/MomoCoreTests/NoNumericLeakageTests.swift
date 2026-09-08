import Testing
@testable import MomoCore

/// FR-9's domain half of the no-numeric-leakage rule (TASK-013, AC-3): the UI
/// presents bands (label + glyph + line), never raw numbers (PRD §3.1/§3.3
/// legibility rules) — so the domain must offer bands/stages ONLY as
/// case-less enum types, with no raw value, no numeric payload, and no
/// numeric band/stage field on any read-model a consumer renders from.
///
/// METHOD (documented per Requirement 4) — runtime reflection + existential
/// casts over the compiled types, in three layers, plus one compile-time
/// case-set pin:
/// 1. `value as? any RawRepresentable` is nil for every case of `MoodBand`,
///    `EnergyBand`, `BondStage` — catches someone adding a raw value
///    (`enum MoodBand: Int`), which would hand consumers a branchable number.
/// 2. `Mirror(reflecting:).children` is empty for every case — catches an
///    associated-value payload (e.g. `case wistful(Double)`) and a
///    struct-ification with stored fields (e.g. `public let value: Int`;
///    enums cannot store properties, so that mutation necessarily reshapes
///    the type and shows up as a child).
/// 3. A field inventory of the two model types that carry band/stage state —
///    `PetState` and the character-facing read-model `CharacterDisplayState`
///    — plus the `.bondStageReached` moment payload: the band/stage-labeled
///    fields must be exactly their enum types, and the numeric-typed field
///    inventory must be exactly the D10 internal scalars (mood/energy/bond on
///    `PetState`, none on the read-model). Catches a field retyped to a
///    number (e.g. `moodBand: Int`) or a numeric band/stage field added.
/// 4. `prdCaseName(of:)` — one default-free exhaustive switch per type (INV-8's
///    pattern, no `default:` clause): adding or removing any case of
///    `MoodBand`, `EnergyBand`, or `BondStage` fails to BUILD this file, so
///    layers 1–2's "for every case" loops are compile-time total and a new
///    payload-bearing case (e.g. `case historic(Int)`) cannot slip past them
///    (REVIEW-TASK-013 MAJOR-1).
///
/// NON-VACUITY: each layer fails on a distinct mutation class (4: case
/// add/remove breaks the build; 1: raw value; 2: payload/struct reshape;
/// 3: numeric field add/retype), and the inventories assert exact label/type
/// sets — not membership — so additions fail too. Scope honesty: this pins
/// the domain-side guarantee (the only thing a UI *can* present comes from
/// these enum types); the UI-side rendering check ("no surface renders
/// numbers") is EPIC-007's job.
///
/// KNOWN BLIND SPOT (documented per REVIEW-TASK-013 MINOR-1): the reflection
/// layers inspect STORED fields only — `Mirror` reflects stored properties,
/// so computed members, subscripts, and extension members are invisible to
/// this method (the module currently defines none on its read-models). Those
/// are covered by review instead, via a standing note tracked in status.md
/// by the orchestrator.
@Suite("No numeric leakage out of bands/stages (TASK-013, FR-9 AC-1 domain half)")
struct NoNumericLeakageTests {

    // MARK: - Reflection helpers

    private func fields(of value: Any) -> [(label: String, value: Any)] {
        Mirror(reflecting: value).children.compactMap { child in
            child.label.map { ($0, child.value) }
        }
    }

    private func isNumeric(_ type: Any.Type) -> Bool {
        type is any FixedWidthInteger.Type || type is any BinaryFloatingPoint.Type
    }

    private func numericLabels(of value: Any) -> [String] {
        fields(of: value).filter { isNumeric(type(of: $0.value)) }.map(\.label)
    }

    // MARK: - Case-set pin: the closed PRD sets, compile-time (REVIEW-TASK-013 MAJOR-1)

    // One default-free exhaustive switch per band/stage type (INV-8's
    // pattern): a case added to or removed from any of the three types breaks
    // compilation of this file, so the "for every case" loops of layers 1–2
    // can never silently skip a new case. The Swift case names are asserted
    // against the PRD sets in `bandStageCaseSetsPinned` so the helpers cannot
    // rot into no-ops. (PRD display names in the trailing comments.)

    private func prdCaseName(of band: MoodBand) -> String {
        switch band {
        case .joyful: return "joyful" // PRD §3.1 "Joyful"
        case .content: return "content" // PRD §3.1 "Content"
        case .wistful: return "wistful" // PRD §3.1 "Wistful"
        case .low: return "low" // PRD §3.1 "Low"
        }
    }

    private func prdCaseName(of band: EnergyBand) -> String {
        switch band {
        case .energetic: return "energetic" // PRD §3.2 "Energetic"
        case .relaxed: return "relaxed" // PRD §3.2 "Relaxed"
        case .drowsy: return "drowsy" // PRD §3.2 "Drowsy"
        case .exhausted: return "exhausted" // PRD §3.2 "Exhausted"
        }
    }

    private func prdCaseName(of stage: BondStage) -> String {
        switch stage {
        case .newFriends: return "newFriends" // PRD §3.3 "New Friends"
        case .gettingClose: return "gettingClose" // PRD §3.3 "Getting Close"
        case .bestFriends: return "bestFriends" // PRD §3.3 "Best Friends"
        case .soulCompanions: return "soulCompanions" // PRD §3.3 "Soul Companions"
        }
    }

    @Test("band and stage case sets are exactly the PRD §3.1–3.3 sets — a new case fails to build")
    func bandStageCaseSetsPinned() {
        // The exhaustive switches above turn case addition/removal into a
        // build failure; this assertion keeps their outputs honest — each
        // helper must still produce the PRD's case names, in order.
        #expect(
            [prdCaseName(of: MoodBand.joyful), prdCaseName(of: .content), prdCaseName(of: .wistful), prdCaseName(of: .low)]
                == ["joyful", "content", "wistful", "low"],
            "MoodBand's case set drifted from PRD §3.1"
        )
        #expect(
            [prdCaseName(of: EnergyBand.energetic), prdCaseName(of: .relaxed), prdCaseName(of: .drowsy), prdCaseName(of: .exhausted)]
                == ["energetic", "relaxed", "drowsy", "exhausted"],
            "EnergyBand's case set drifted from PRD §3.2"
        )
        #expect(
            [prdCaseName(of: BondStage.newFriends), prdCaseName(of: .gettingClose), prdCaseName(of: .bestFriends), prdCaseName(of: .soulCompanions)]
                == ["newFriends", "gettingClose", "bestFriends", "soulCompanions"],
            "BondStage's case set drifted from PRD §3.3"
        )
    }

    // MARK: - Layers 1–2: the band/stage types themselves

    @Test("bands and stages expose no raw value a consumer could read")
    func bandCasesExposeNoRawValue() {
        for band in [MoodBand.joyful, .content, .wistful, .low] {
            #expect(band as? any RawRepresentable == nil, "MoodBand gained a raw value — a branchable number leaks out")
        }
        for band in [EnergyBand.energetic, .relaxed, .drowsy, .exhausted] {
            #expect(band as? any RawRepresentable == nil, "EnergyBand gained a raw value — a branchable number leaks out")
        }
        for stage in [BondStage.newFriends, .gettingClose, .bestFriends, .soulCompanions] {
            #expect(stage as? any RawRepresentable == nil, "BondStage gained a raw value — a branchable number leaks out")
        }
    }

    @Test("bands and stages carry no associated payload or stored field")
    func bandCasesCarryNoPayload() {
        for band in [MoodBand.joyful, .content, .wistful, .low] {
            #expect(Mirror(reflecting: band).children.isEmpty, "MoodBand gained a payload — a numeric leakage path")
        }
        for band in [EnergyBand.energetic, .relaxed, .drowsy, .exhausted] {
            #expect(Mirror(reflecting: band).children.isEmpty, "EnergyBand gained a payload — a numeric leakage path")
        }
        for stage in [BondStage.newFriends, .gettingClose, .bestFriends, .soulCompanions] {
            #expect(Mirror(reflecting: stage).children.isEmpty, "BondStage gained a payload — a numeric leakage path")
        }
    }

    // MARK: - Layer 3: the read-model field inventories

    @Test("read-models expose bands/stages only as their enum types; the only numerics are the D10 internal scalars")
    func readModelFieldInventories() throws {
        let state = try #require(
            PetState(
                mood: 60, energy: 85, bond: 400,
                wakefulness: .awake, activity: nil, lastFedAt: nil, satietyPhase: .hungry
            )
        )
        let display = CharacterDisplayState(
            moodBand: .joyful, energyBand: .relaxed, bondStage: .bestFriends,
            wakefulness: .awake, activity: .playing, satietyHint: .recentlyFed,
            momentRequest: .bondStageReached(.soulCompanions)
        )

        // PetState: the D10 internal scalars are the ONLY numeric fields —
        // they are internal by design (PRD §3.1: "internal continuous scalar");
        // no numeric field carries band/stage semantics.
        #expect(
            fields(of: state).map(\.label)
                == ["mood", "energy", "bond", "wakefulness", "activity", "lastFedAt", "satietyPhase"],
            "PetState's field set changed — re-audit the numeric inventory"
        )
        #expect(numericLabels(of: state) == ["mood", "energy", "bond"])
        #expect(
            numericLabels(of: state).allSatisfy { label in
                !label.lowercased().contains("band") && !label.lowercased().contains("stage")
            },
            "a numeric band/stage field appeared on PetState"
        )
        let stateTypes = Dictionary(uniqueKeysWithValues: fields(of: state).map { ($0.label, type(of: $0.value)) })
        #expect(stateTypes["mood"] == Double.self)
        #expect(stateTypes["energy"] == Double.self)
        #expect(stateTypes["bond"] == Int.self)

        // CharacterDisplayState: what the renderer consumes — no numeric
        // field at all, and each band/stage field is exactly its enum type.
        #expect(
            fields(of: display).map(\.label)
                == ["moodBand", "energyBand", "bondStage", "wakefulness", "activity", "satietyHint", "momentRequest"],
            "CharacterDisplayState's field set changed — re-audit the numeric inventory"
        )
        #expect(numericLabels(of: display).isEmpty, "a numeric field appeared on the character-facing read-model")
        let displayTypes = Dictionary(uniqueKeysWithValues: fields(of: display).map { ($0.label, type(of: $0.value)) })
        #expect(displayTypes["moodBand"] == MoodBand.self, "moodBand was retyped — no longer the MoodBand enum")
        #expect(displayTypes["energyBand"] == EnergyBand.self, "energyBand was retyped — no longer the EnergyBand enum")
        #expect(displayTypes["bondStage"] == BondStage.self, "bondStage was retyped — no longer the BondStage enum")
        #expect(displayTypes["wakefulness"] == Wakefulness.self)

        // The stage-celebration moment request carries the stage as the enum,
        // never a number (FR-10 AC-4's payload).
        let payload = Mirror(reflecting: CharacterMoment.bondStageReached(.soulCompanions)).children.first
        #expect(payload != nil, "the moment request lost its payload entirely")
        #expect(payload?.value is BondStage, "bondStageReached no longer carries a BondStage")
    }
}
