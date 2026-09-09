import Testing
import Foundation
@testable import MomoCore

/// The OBS-1 fixed vocabulary keys (TASK-019 Requirement 3; Required Tests 2):
/// the keyspace `momo.line.vocab.<field>.<band>` is pinned KEY-FOR-KEY as raw
/// literals — a lookup, not a selection, so there is nothing to anti-echo:
/// the key strings ARE the constants (the catalog entries they name land in
/// EPIC-006/007; `MomoCopy.xcstrings` stays untouched by this task).
///
/// The named Wistful→quiet pin records the catalog-rendering obligation: the
/// KEY is band-named (`…mood.wistful`) so the lookup is total and mechanical,
/// while its catalog entry announces 04 §3.5's "quiet" word — the remap is a
/// presentation-era obligation this suite pins BY NAME, not by prose.
@Suite("Vocabulary keys — OBS-1 fixed lookup, key-for-key (TASK-019)")
struct VocabularyKeyTests {

    private static let moods: [MoodBand] = [.joyful, .content, .wistful, .low]
    private static let energies: [EnergyBand] = [.energetic, .relaxed, .drowsy, .exhausted]
    private static let stages: [BondStage] = [.newFriends, .gettingClose, .bestFriends, .soulCompanions]

    // MARK: Mood word keys (04 §3.5)

    @Test("each mood band resolves to exactly its momo.line.vocab.mood key", arguments: zip(Self.moods, [
        "momo.line.vocab.mood.joyful",
        "momo.line.vocab.mood.content",
        "momo.line.vocab.mood.wistful",
        "momo.line.vocab.mood.low",
    ]))
    func moodKeysPinned(band: MoodBand, expected: String) {
        #expect(VocabularyKeys.moodWordKey(for: band) == expected)
    }

    /// The named pin: the wistful KEY stays band-named even though its
    /// catalog entry announces "quiet" (04 §3.5) — the key must NOT encode
    /// the display word, or the band→key lookup stops being mechanical and
    /// OBS-1's formula loses its total map.
    @Test("the wistful mood key is band-named; the Wistful→\"quiet\" remap is a catalog obligation, not a key change")
    func wistfulKeyStaysBandNamed() {
        let key = VocabularyKeys.moodWordKey(for: .wistful)
        #expect(key == "momo.line.vocab.mood.wistful")
        #expect(!key.lowercased().contains("quiet"),
                "the Wistful→quiet remap belongs to the catalog entry (EPIC-006/007), never to the key")
    }

    // MARK: Energy phrase keys (04 §3.5, verbatim phrases pinned in the catalog era)

    @Test("each energy band resolves to exactly its momo.line.vocab.energy key", arguments: zip(Self.energies, [
        "momo.line.vocab.energy.energetic",
        "momo.line.vocab.energy.relaxed",
        "momo.line.vocab.energy.drowsy",
        "momo.line.vocab.energy.exhausted",
    ]))
    func energyKeysPinned(band: EnergyBand, expected: String) {
        #expect(VocabularyKeys.energyPhraseKey(for: band) == expected)
    }

    // MARK: Bond descriptor keys (PRD §3.3's four lines)

    @Test("each bond stage resolves to exactly its momo.line.vocab.stage key", arguments: zip(Self.stages, [
        "momo.line.vocab.stage.newFriends",
        "momo.line.vocab.stage.gettingClose",
        "momo.line.vocab.stage.bestFriends",
        "momo.line.vocab.stage.soulCompanions",
    ]))
    func bondDescriptorKeysPinned(stage: BondStage, expected: String) {
        #expect(VocabularyKeys.bondDescriptorKey(for: stage) == expected)
    }

    // MARK: Keyspace shape (INV-11: keys, never prose)

    @Test("the lookup is total, mechanical, and disjoint — 12 distinct keys under the one vocab keyspace")
    func keysetIsTotalAndDisjoint() {
        let all = Self.moods.map { VocabularyKeys.moodWordKey(for: $0) }
            + Self.energies.map { VocabularyKeys.energyPhraseKey(for: $0) }
            + Self.stages.map { VocabularyKeys.bondDescriptorKey(for: $0) }
        #expect(all.count == 12)
        #expect(Set(all).count == 12, "two bands/stages collide on one key — the lookup stopped being total")
        #expect(all.allSatisfy { $0.hasPrefix("momo.line.vocab.") },
                "every vocabulary key lives under the momo.line.vocab keyspace")
        #expect(all.allSatisfy { !$0.contains(" ") },
                "a key carried prose — INV-11: keys, never composed text")
    }

    // MARK: Catalog-entry obligations (REVIEW-TASK-019 MINOR-1)

    /// The verbatim catalog text behind each energy/descriptor key, recorded
    /// HERE as the EPIC-007 catalog-entry contract (the
    /// `ThresholdsPinnedToPRDTests` precedent: pins may carry spec literals
    /// even though the engine outputs keys only — INV-11). The catalog entry
    /// for each key MUST read verbatim; changing these words is a PRD §3.3 /
    /// 04 §3.5 spec change, never a copy tweak.
    private static let catalogObligations: [(key: String, text: String)] = [
        ("momo.line.vocab.energy.energetic", "has plenty of energy"), // 04 §3.5
        ("momo.line.vocab.energy.relaxed", "is relaxed"),
        ("momo.line.vocab.energy.drowsy", "is getting sleepy"),
        ("momo.line.vocab.energy.exhausted", "is very sleepy"),
        ("momo.line.vocab.stage.newFriends", "Just getting to know each other."), // PRD §3.3
        ("momo.line.vocab.stage.gettingClose", "Momo perks up when you arrive."),
        ("momo.line.vocab.stage.bestFriends", "Momo knows your rhythms."),
        ("momo.line.vocab.stage.soulCompanions", "Quietly inseparable."),
    ]

    @Test("each energy/descriptor key's catalog entry is the verbatim 04 §3.5 / PRD §3.3 text — the EPIC-007 obligation (REVIEW-TASK-019 MINOR-1)")
    func catalogObligationsAreRecorded() {
        #expect(Self.catalogObligations.count == 8)
        // One-to-one with the minted keys, in band/stage order — the
        // obligation table cannot drift from the keyspace this engine mints.
        let minted = Self.energies.map { VocabularyKeys.energyPhraseKey(for: $0) }
            + Self.stages.map { VocabularyKeys.bondDescriptorKey(for: $0) }
        #expect(Self.catalogObligations.map(\.key) == minted)
        #expect(Self.catalogObligations.allSatisfy { !$0.text.isEmpty })
    }
}
