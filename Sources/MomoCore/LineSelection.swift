import Foundation

// MARK: - LineSelection — the §4.9 copy-selection surface (05-technical-
// architecture §4.9–§4.10; 04-character-system §3.5, §8.4, §10.4; TASK-019
// Requirements 3–4)

/// The pure key-minting half of the copy-selection surface. INV-11
/// throughout: the engine outputs catalog KEYS, never composed prose — the
/// key strings below are namespace STRUCTURE (§8.4's dot convention), not
/// user-facing text; the catalog entries they name land in the presentation
/// era (EPIC-007) and `MomoCopy.xcstrings` stays untouched by this task.
///
/// Two selection classes live here:
///
/// - **Variational picks** (`reactLineKey` / `slotLineKey`): a day-stable
///   seeded draw per (pet, local day, context). The seed is §4.10's —
///   `DaySeed.make(petID:localDayKey:epoch:salt: .copy)` — and the draw is
///   the PINNED RECIPE below (exactly one draw of a locally-seeded
///   `SeededGenerator`; `pick` documents it). Identical (pet, dayKey,
///   context) ⇒ identical key all day (day-stable, 04 §10.1 rule 7); the
///   recipe is pinned so the seed→key mapping is stable (the TASK-018
///   `twoDrawPin` discipline). The generators here are ALWAYS local to the
///   call — the choreography rng passed through `reduce` is never touched
///   (the TASK-018 lineage discipline; pinned by
///   `InteractionResponseTests.rngDrawDiscipline` staying green).
/// - **The fixed state vocabulary** (`VocabularyKeys`, OBS-1): a lookup,
///   not a selection — one key per band/stage, zero variation.
///
/// Pure: value-in/value-out, no clocks, no ambient state, no system
/// randomness (each pick seeds its own generator from the given seed).
public enum LineSelection {

    /// The day's copy seed (05 §4.10): `DaySeed` over (pet, local day,
    /// copy epoch, `.copy` salt). The salt separates the copy domain from
    /// the choreography and quest domains — an epoch bump here resalts only
    /// this domain's picks.
    public static func copySeed(petID: UUID, dayKey: String) -> UInt64 {
        DaySeed.make(petID: petID, localDayKey: dayKey, epoch: CopyRules.copyEpoch, salt: .copy)
    }

    /// The pinned pick recipe (TASK-019 Requirement 4a): exactly ONE draw of
    /// a `SeededGenerator` freshly seeded with `seed`, reduced modulo the
    /// pool count. A reordered or extra draw changes the mapping and fails
    /// the recipe pin (`CopySelectionPinnedTests`). The pool count comes
    /// from the `CopyRules` constants home (never 0 there); the modulo of a
    /// zero pool would trap loudly rather than fabricate an index.
    public static func pick(seed: UInt64, poolCount: Int) -> Int {
        var rng = SeededGenerator(seed: seed)
        return Int(rng.next() % UInt64(poolCount))
    }

    /// The day-stable react line key for one interaction family:
    /// `momo.line.react.<family>.<nn>` (04 §10.4; TASK-016's documented nil
    /// seam on `ResponsePlan.lineKey`). Same (pet, dayKey, family) ⇒ same
    /// key for the whole local day.
    public static func reactLineKey(petID: UUID, dayKey: String, family: CopyRules.ReactFamily) -> String {
        let index = pick(seed: copySeed(petID: petID, dayKey: dayKey), poolCount: CopyRules.reactLineCount(for: family))
        return "momo.line.react.\(family.rawValue).\(formatted(index))"
    }

    /// The day-stable slot line key for one time slot:
    /// `momo.line.<slot>.<nn>` (04 §10.4's visual classes; OBS-2 scopes the
    /// 12-word rule to these and `momo.line.moment`, a catalog-era constraint
    /// the TASK-010 scanner enforces when real pools land).
    public static func slotLineKey(petID: UUID, dayKey: String, slot: CopyRules.LineSlot) -> String {
        let index = pick(seed: copySeed(petID: petID, dayKey: dayKey), poolCount: CopyRules.slotLineCount(for: slot))
        return "momo.line.\(slot.rawValue).\(formatted(index))"
    }

    /// The zero-padded two-digit zero-based index form (`00` in the
    /// placeholder era — TASK-011's catalog convention: index 00 is reserved
    /// for placeholders, real pools start at 01).
    private static func formatted(_ index: Int) -> String {
        String(format: "%02d", index)
    }
}

// MARK: - VocabularyKeys — the OBS-1 fixed lookup (04 §3.5; PRD §3.3)

/// The VoiceOver word/phrase/bond-descriptor keys (OBS-1's resolution: the
/// a11y formula renders from the catalog; `DisplayState` carries resolved
/// KEYS). A fixed lookup — one key per band/stage, ZERO variation — so it is
/// not one of §4.9's variational line classes; it gets its own keyspace
/// under §8.4's dot convention, `momo.line.vocab.<field>.<band>`, leaving the
/// three variational classes (`momo.line.<slot>`, `momo.line.react.<family>`,
/// `momo.line.moment`) pure (TASK-019 Requirement 3's recorded reading).
///
/// The catalog ENTRIES for these keys land in the presentation era; this home
/// mints the key strings only. The band names in the keys are the PRD band
/// names — including the mood key `momo.line.vocab.mood.wistful`, whose
/// catalog entry announces 04 §3.5's "quiet" (the Wistful→"quiet" remap is a
/// catalog-rendering obligation, pinned by name in `VocabularyKeyTests`; the
/// KEY stays band-named so the lookup is total and mechanical).
public enum VocabularyKeys {

    /// 04 §3.5's mood words, one key per mood band. The wistful key's catalog
    /// entry announces "quiet" (04 §3.5) — see the header.
    public static func moodWordKey(for band: MoodBand) -> String {
        switch band {
        case .joyful: return "momo.line.vocab.mood.joyful"
        case .content: return "momo.line.vocab.mood.content"
        case .wistful: return "momo.line.vocab.mood.wistful"
        case .low: return "momo.line.vocab.mood.low"
        }
    }

    /// 04 §3.5's energy phrases verbatim, mapped from the energy band in band
    /// order: "has plenty of energy" / "is relaxed" / "is getting sleepy" /
    /// "is very sleepy".
    public static func energyPhraseKey(for band: EnergyBand) -> String {
        switch band {
        case .energetic: return "momo.line.vocab.energy.energetic"
        case .relaxed: return "momo.line.vocab.energy.relaxed"
        case .drowsy: return "momo.line.vocab.energy.drowsy"
        case .exhausted: return "momo.line.vocab.energy.exhausted"
        }
    }

    /// PRD §3.3's four stage descriptor lines verbatim, mapped from the bond
    /// stage: "Just getting to know each other." / "Momo perks up when you
    /// arrive." / "Momo knows your rhythms." / "Quietly inseparable."
    public static func bondDescriptorKey(for stage: BondStage) -> String {
        switch stage {
        case .newFriends: return "momo.line.vocab.stage.newFriends"
        case .gettingClose: return "momo.line.vocab.stage.gettingClose"
        case .bestFriends: return "momo.line.vocab.stage.bestFriends"
        case .soulCompanions: return "momo.line.vocab.stage.soulCompanions"
        }
    }
}
