import Foundation

// MARK: - Quest identifiers and families (PRD §5.2 catalog; 05 §3.1)

/// The seven Phase 1 quest identifiers (PRD §5.2 catalog — complete list,
/// FR-14 AC: exactly these, interaction-based only). Raw values match the
/// PRD's ID column byte-for-byte.
public enum QuestID: String, Equatable, Hashable, Sendable, CaseIterable {
    case q1 = "Q1"
    case q2 = "Q2"
    case q3 = "Q3"
    case q4 = "Q4"
    case q5 = "Q5"
    case q6 = "Q6"
    case q7 = "Q7"
}

/// Quest families (PRD §5.2 Family column). The variety bonus uses the
/// feed/play/care subset (PRD §3.3: "all three families (feed, play, care)") —
/// the engine records exactly those into `DayRecord.familiesUsed`; greet and
/// pet exist because the catalog's Q1/Q7 rows name them.
public enum QuestFamily: Equatable, Hashable, Sendable, CaseIterable {
    case greet
    case feed
    case play
    case care
    case pet
}

/// A quest's local-time availability window (PRD §5.2 Window column; the
/// windows are whole-hour aligned, so the local hour fully determines
/// membership). Which day an intent belongs to is D20 `dayKey` attribution —
/// engine/store territory (§4.8), not this type's concern.
public enum QuestWindow: Equatable, Sendable {

    /// All day (Q2–Q5, Q7): expires silently at local midnight (§5.1 rule 6).
    case allDay

    /// Until 12:00 local (Q1): the window closes at noon — silently, like any
    /// expiry (§5.1 rule 6 exception).
    case morningOnly

    /// 20:00–07:00 local (Q6): evening through the early-morning tail — the
    /// owner-amended §5.5 rule 1 window (2026-09-08).
    case eveningAndEarlyMorning

    /// Whether `hour` (0–23, local) is inside the window.
    public func contains(hour: Int) -> Bool {
        switch self {
        case .allDay:
            return true
        case .morningOnly:
            return hour < Thresholds.Quest.q1WindowClosesAtHour
        case .eveningAndEarlyMorning:
            return hour >= Thresholds.Quest.q6WindowStartHour || hour < Thresholds.Quest.q6WindowEndHour
        }
    }
}

/// One row of the quest catalog: identifier, family, target, window
/// (05 §3.1 "QuestCatalog: static table"; PRD §5.2 is the normative source).
///
/// Read-only by design (REVIEW-TASK-012 NITPICK-3): the initializer is
/// internal so `QuestCatalog` below is the sole source of entries — consumers
/// look rows up via `QuestCatalog.entry(for:)`, they never construct them.
public struct QuestCatalogEntry: Equatable, Sendable {
    public let id: QuestID
    public let family: QuestFamily
    public let target: Int
    public let window: QuestWindow
}

/// The static Phase 1 quest catalog (PRD §5.2, in table order Q1…Q7).
/// Static data only — set generation and window-checked completion are
/// engine-owned (§4.8, EPIC-004).
public enum QuestCatalog {

    /// The seven catalog entries, in PRD §5.2 table order.
    public static let all: [QuestCatalogEntry] = [
        QuestCatalogEntry(id: .q1, family: .greet, target: 1, window: .morningOnly),            // First touch of the day
        QuestCatalogEntry(id: .q2, family: .feed, target: 1, window: .allDay),                  // Feed ×1
        QuestCatalogEntry(id: .q3, family: .feed, target: 2, window: .allDay),                  // Feed ×2
        QuestCatalogEntry(id: .q4, family: .play, target: 2, window: .allDay),                  // Play ×2 rounds
        QuestCatalogEntry(id: .q5, family: .play, target: 3, window: .allDay),                  // Play ×3 rounds
        QuestCatalogEntry(id: .q6, family: .care, target: 1, window: .eveningAndEarlyMorning),  // Care ×1 (tuck in)
        QuestCatalogEntry(id: .q7, family: .pet, target: 3, window: .allDay),                   // Pet ×3
    ]

    /// The catalog entry for `id` (targets are INV-6's source of truth).
    public static func entry(for id: QuestID) -> QuestCatalogEntry {
        // Safe: `all` contains exactly one entry per QuestID (FR-14) —
        // pinned by QuestCatalogTests; the force-unwrap documents that
        // invariant rather than silently failing.
        all.first { $0.id == id }!
    }
}

// MARK: - QuestProgress

/// Per-quest progress within a day's set (05-technical-architecture §3.1).
///
/// INV-6 is enforced at this type boundary by the failable initializer:
/// progress ≤ target, and `completed == true` implies the target is met
/// (targets come from `QuestCatalog`). "Completion never reverses" is the
/// engine/store contract (FR-16, TR5) — the model makes a regressed record
/// constructible-by-accident impossible by immutability: the engine produces
/// a new value per tick.
public struct QuestProgress: Equatable, Sendable {

    /// Which catalog quest this is (static data, PRD §5.2).
    public let questID: QuestID

    /// Counted progress toward the catalog target (INV-6: ≤ target).
    public let progress: Int

    /// Automatic on reaching the target (FR-16); never un-completes.
    public let completed: Bool

    /// Fails (returns nil) on any INV-6 violation: negative progress, progress
    /// beyond the catalog target, or `completed` without the target met.
    public init?(questID: QuestID, progress: Int, completed: Bool) {
        let target = QuestCatalog.entry(for: questID).target
        guard progress >= 0, progress <= target else { return nil }
        if completed && progress < target { return nil }
        self.questID = questID
        self.progress = progress
        self.completed = completed
    }
}
