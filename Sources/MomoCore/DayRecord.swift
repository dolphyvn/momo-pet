import Foundation

/// Per-local-day record (05-technical-architecture §3.1; 7-day retention is
/// the store's concern, §5.4). Named `DayRecord` here; ≡ project.md §24's
/// DailyProgress (§7's DailyProgress.steps extends it in Phase 2).
///
/// Invariants enforced at this type boundary by the failable initializer:
/// - INV-4: day counters ≥ 0 (monotonic-within-a-day is the engine contract,
///   FR-6 AC-3 — the model makes negative counts unrepresentable).
/// - INV-5: `bondAwarded` ∈ 0...20 (the clamp-at-award arithmetic itself is
///   engine-owned, §4.6 — the model caps the stored total).
/// - FR-14/15 (05 §3.1: "exactly 3"): `questSet` holds exactly
///   `Thresholds.Quest.questsPerDay` progress values with no duplicate quest.
/// - INV-7 (representation): the hello award is a single `Bool` slot per
///   record — at most once per dayKey, device-agnostic by construction; the
///   store guarantees one record per dayKey (EPIC-005).
///
/// All properties are `let`: value semantics, immutable by construction.
public struct DayRecord: Equatable, Sendable {

    /// `"YYYY-MM-DD"` in the user's local calendar (D20) — derived via
    /// `DayKey.make`, never stored as a timezone-dependent date type (INV-9).
    public let dayKey: String

    /// Feeds accepted this day. INV-4: ≥ 0.
    public let feedCount: Int

    /// Play rounds completed this day. INV-4: ≥ 0.
    public let playCount: Int

    /// Care interactions (tuck-in / nap) this day. INV-4: ≥ 0.
    public let careCount: Int

    /// Pat interactions this day. INV-4: ≥ 0 (petting banks no bond — G2 —
    /// this counter is presence, never a currency).
    public let patCount: Int

    /// The day's quest set (FR-14/15: exactly 3; generated once, persisted —
    /// generation is engine-owned, §4.8).
    public let questSet: [QuestProgress]

    /// Daily hello awarded — once per dayKey, either device (UX-6, INV-7),
    /// never window-gated (a first touch at 14:00 still earns it, §4.6).
    public let helloAwarded: Bool

    /// Families used this day — feed/play/care are the variety-bonus input
    /// (PRD §3.3; §4.6 fires the +6 when all three are present).
    public let familiesUsed: Set<QuestFamily>

    /// Bond awarded this day, 0...20 (INV-5 daily cap; PRD §3.3).
    public let bondAwarded: Int

    /// Generator version that produced `questSet` (§4.8) — unconstrained.
    public let questGenEpoch: Int

    /// Fails (returns nil) on any INV-4/INV-5 violation, on a `questSet` whose
    /// count is not exactly `Thresholds.Quest.questsPerDay`, or on duplicate
    /// quests within `questSet` (PRD §5.3 "no duplicate quests in one set").
    public init?(
        dayKey: String,
        feedCount: Int,
        playCount: Int,
        careCount: Int,
        patCount: Int,
        questSet: [QuestProgress],
        helloAwarded: Bool,
        familiesUsed: Set<QuestFamily>,
        bondAwarded: Int,
        questGenEpoch: Int
    ) {
        let counters = [feedCount, playCount, careCount, patCount]
        guard counters.allSatisfy({ $0 >= 0 }) else { return nil }               // INV-4
        guard (Thresholds.Bond.minimum...Thresholds.Bond.dailyCap).contains(bondAwarded) else { return nil } // INV-5
        guard questSet.count == Thresholds.Quest.questsPerDay else { return nil }      // FR-14/15
        guard Set(questSet.map(\.questID)).count == questSet.count else { return nil } // PRD §5.3
        self.dayKey = dayKey
        self.feedCount = feedCount
        self.playCount = playCount
        self.careCount = careCount
        self.patCount = patCount
        self.questSet = questSet
        self.helloAwarded = helloAwarded
        self.familiesUsed = familiesUsed
        self.bondAwarded = bondAwarded
        self.questGenEpoch = questGenEpoch
    }
}
