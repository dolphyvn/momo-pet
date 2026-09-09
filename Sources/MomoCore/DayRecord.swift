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

// MARK: - Codable (TASK-021 persistence enabler — the one DISCLOSED
// hand-written conformance in the persisted graph)

/// Every other persisted type (the whole `EngineState` transitive closure)
/// takes the compiler-synthesized `Codable`. `DayRecord` cannot: the
/// synthesized encoding of `familiesUsed: Set<QuestFamily>` emits the set's
/// elements in the runtime's per-process hash-seeded iteration order, so the
/// payload's `.sortedKeys` JSON bytes (the snapshot checksum's input, 05 §5.2)
/// would differ run-to-run — a file written by one process would fail its own
/// checksum verification in the next one and silently fall through the
/// recovery chain. This conformance therefore encodes the set as a
/// declaration-ordered array (a stable total order, `persistenceOrder` below)
/// and decodes the array back into the set. Field names, types and values are
/// untouched; nothing else about the type changes.
///
/// Deliberate posture shared with the synthesized conformances: decoding does
/// NOT re-run the failable initializer's INV checks — the envelope checksum
/// (verified by the store before the payload is trusted) gates the bytes.
/// (The conformance is declared here in the extension, not on the struct,
/// because Swift rejects a main-declaration `Codable` alongside an
/// implementation extension as redundant.)
extension DayRecord: Codable {

    private enum CodingKeys: String, CodingKey {
        case dayKey, feedCount, playCount, careCount, patCount
        case questSet, helloAwarded, familiesUsed, bondAwarded, questGenEpoch
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dayKey = try container.decode(String.self, forKey: .dayKey)
        feedCount = try container.decode(Int.self, forKey: .feedCount)
        playCount = try container.decode(Int.self, forKey: .playCount)
        careCount = try container.decode(Int.self, forKey: .careCount)
        patCount = try container.decode(Int.self, forKey: .patCount)
        questSet = try container.decode([QuestProgress].self, forKey: .questSet)
        helloAwarded = try container.decode(Bool.self, forKey: .helloAwarded)
        familiesUsed = Set(try container.decode([QuestFamily].self, forKey: .familiesUsed))
        bondAwarded = try container.decode(Int.self, forKey: .bondAwarded)
        questGenEpoch = try container.decode(Int.self, forKey: .questGenEpoch)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(dayKey, forKey: .dayKey)
        try container.encode(feedCount, forKey: .feedCount)
        try container.encode(playCount, forKey: .playCount)
        try container.encode(careCount, forKey: .careCount)
        try container.encode(patCount, forKey: .patCount)
        try container.encode(questSet, forKey: .questSet)
        try container.encode(helloAwarded, forKey: .helloAwarded)
        try container.encode(
            familiesUsed.sorted(by: { $0.persistenceOrder < $1.persistenceOrder }),
            forKey: .familiesUsed
        )
        try container.encode(bondAwarded, forKey: .bondAwarded)
        try container.encode(questGenEpoch, forKey: .questGenEpoch)
    }
}

/// The stable total order used when encoding `familiesUsed` — the
/// `QuestFamily` declaration order in `Quest.swift`. Exhaustive without
/// `default`: a new family fails the build here, forcing the persistence
/// order to grow with the case set instead of silently reshuffling the
/// encoded bytes.
private extension QuestFamily {
    var persistenceOrder: Int {
        switch self {
        case .greet: 0
        case .feed: 1
        case .play: 2
        case .care: 3
        case .pet: 4
        }
    }
}
