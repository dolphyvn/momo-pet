import Foundation

// MARK: - BondRules — the bond-ledger constants home (05-technical-architecture
// §4.6; PRD §3.3 earning table; FR-10; TASK-017 Requirement 1)

/// The single source of every number the §4.6 bond ledger applies — the
/// `FoldRules`/`InteractionRules` discipline (TASK-015/016) carried into the
/// bond era: one auditable home, per-constant authority labels, and raw
/// literals only in the pin test (`BondRulesPinnedTests`) — every behavior
/// test and every engine award site references these constants, so a spec
/// change surfaces as exactly one pin failure plus one constants edit.
///
/// **Authority:** all four award values are **PRD-normative** (PRD §3.3's
/// earning table is normative: hello +8, each quest +4, variety +6, daily cap
/// +20; 05 §4.6's table repeats them and adds the engine guard per row) —
/// changes require a PRD revision. The stage thresholds and the 0…1000 range
/// stay in `Thresholds.Bond` (TASK-012's home) and are NOT restated here; the
/// one constant this home shares a value with — the daily cap — is pinned
/// EQUAL to `Thresholds.Bond.dailyCap` in `BondRulesPinnedTests`, the same
/// cross-home equality discipline `InteractionRules.tuckInWindowStartHour`
/// uses for the Q6 window hour.
public enum BondRules {

    // MARK: The three daily award events (PRD §3.3 earning table — normative)

    /// The daily hello: +8, once per local dayKey on the first touch (pat)
    /// intent — either device, idempotent, never window-gated (UX-6, INV-7;
    /// §4.6's hello row). A first touch at 14:00 (Q1 expired) earns it exactly
    /// once all the same.
    public static let helloBondDelta: Int = 8

    /// Each completed quest: +4 (PRD §3.3 "Each quest completed (max 3/day):
    /// +4 each"; §4.6's quest row). The award MECHANISM only — completion
    /// detection, window checks, and ticking are TASK-018's (§4.8).
    public static let questBondDelta: Int = 4

    /// The variety bonus: +6, fired at the moment all three families below are
    /// used in one day (PRD §3.3 "Variety bonus — all three families (feed,
    /// play, care) used in one day"; §4.6's variety row) — set membership on
    /// `DayRecord.familiesUsed` makes it once-per-day by construction.
    public static let varietyBondDelta: Int = 6

    /// The per-local-day earning cap: +20 (PRD §3.3 "Daily cap +20 max —
    /// enforced"; INV-5). Applied by clamp-at-award, never by a post-hoc
    /// check: every award applies `min(event, cap − day.bondAwarded,
    /// 1000 − pet.bond)` (§4.6), which makes the cap, INV-3's monotonicity,
    /// and the 1000 plateau all structural.
    ///
    /// `Thresholds.Bond.dailyCap` is the same PRD number, kept as the stored
    /// range bound of `DayRecord.bondAwarded` (INV-5's model half); the two
    /// are pinned EQUAL in `BondRulesPinnedTests` so a PRD change to either
    /// surfaces loudly instead of silently diverging.
    public static let dailyBondCap: Int = 20

    // MARK: The variety trio (PRD §3.3 variety row — normative structure)

    /// The three families whose use in one local day fires the variety bonus:
    /// feed, play, care — exactly `QuestFamily`'s doc-comment trio (PRD §3.3;
    /// the catalog's greet/pet families are NOT variety input). The engine
    /// records exactly these into `DayRecord.familiesUsed`, on exactly the
    /// events that count (§4.4's I-1 counting rules): feed → every feed
    /// intent; play → the unified cease only; care → settle-authorization,
    /// blanket-adjust, nap-acceptance.
    public static let varietyTrio: Set<QuestFamily> = [.feed, .play, .care]
}
