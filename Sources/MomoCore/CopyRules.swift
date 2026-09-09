import Foundation

// MARK: - CopyRules — the §4.9 copy-selection constants home
// (05-technical-architecture §4.9–§4.10; 04-character-system §10.1 rule 7 +
// §10.4; TASK-019 Requirement 4)

/// The single source of every number and name the copy-selection surface
/// applies — the `InteractionRules`/`QuestGeneration` discipline carried into
/// the copy era: one auditable home, per-constant authority labels, and raw
/// literals only in the pin tests (`CopySelectionPinnedTests`) — every
/// behavior test and every engine selection site references these constants,
/// so a spec change surfaces as exactly one pin failure plus one constants
/// edit.
///
/// **Authorities.**
///
/// - **D11-normative** (owner decision D11; 05 §4.2): the night window's
///   22:00 onset and 07:00 wake bound — owned by `FoldRules`
///   (`nightOnsetHour`/`morningWakeHour`) and REFERENCED here, never
///   restated, so the slot derivation and the fold cannot diverge.
/// - **Engine-owned starting value** (05 §4.9): the awake complement's
///   morning/day and day/evening cut-offs (12:00 / 18:00) — D11 normative
///   night plus "the engine subdivides the complement" is the whole
///   normative text; the hour numbers are TASK-019's tunable.
/// - **Placeholder-era pool counts** (04 §10.4's line classes; TASK-011's
///   catalog seed): every pool is 1 — the single catalog entry per class is
///   the index-`00` placeholder. Real pools land with EPIC-006/007, and the
///   bump obligation is §4.10's: **a catalog change ⇒ bump the copy epoch**
///   (`copyEpoch`), so every day-stable pick resalts and the mapping stays
///   auditable.
/// - **Epoch discipline** (05 §4.10, mirroring `QuestGeneration.currentEpoch`):
///   `1` is the current copy-selection epoch; `0` is the pre-selection
///   placeholder marker. The epoch flows into every `DaySeed` the selection
///   derives (`.copy` salt) — changing it reshuffles every pick.
public enum CopyRules {

    /// The current copy-selection epoch (05 §4.10's salt-epoch semantics;
    /// engine-owned). `0` is the pre-selection placeholder marker. Changing
    /// it resalts every day's copy seed (via the `DaySeed.make` derivation)
    /// and reshuffles every line pick.
    public static let copyEpoch: Int = 1

    // MARK: Time slots (04 §10.4; D11)

    /// Local hour that opens the DAY slot: 12:00 (engine-owned starting
    /// value — the morning/day cut-off of §4.9's subdivision; the cut-off
    /// hour opens the NEXT slot, so 12:00 is `day`).
    public static let daySlotStartHour: Int = 12

    /// Local hour that opens the EVENING slot: 18:00 (engine-owned starting
    /// value — the day/evening cut-off; 18:00 is `evening`).
    public static let eveningSlotStartHour: Int = 18

    /// The four time slots a local hour selects among — D11's night plus the
    /// engine-owned subdivision of the awake complement (boundary rule: the
    /// cut-off hour opens the next slot; see `timeSlot(forLocalHour:)`).
    ///
    /// The `greeting` and `care-moment` slots are CONTEXT slots (04 §10.4 —
    /// chosen by the presentation's priority, UX-12), not time slots: this
    /// enum enumerates them so the keyspace is exposed uniformly, but
    /// `timeSlot(forLocalHour:)` NEVER returns them (recorded reading,
    /// TASK-019 Requirement 4b — no time derivation lands on a context slot).
    public enum LineSlot: String, CaseIterable, Sendable {
        case morning
        case day
        case evening
        case night
        case greeting
        case careMoment = "care-moment"
    }

    /// The time slot for a local wall hour (0–23 — the caller derives it from
    /// the injected calendar). Night is D11's [22:00, 07:00) (the hours come
    /// from `FoldRules`, never restated); the awake complement subdivides as
    /// morning [07:00, 12:00), day [12:00, 18:00), evening [18:00, 22:00).
    /// Total over 0...23 and pure.
    public static func timeSlot(forLocalHour hour: Int) -> LineSlot {
        if hour >= FoldRules.nightOnsetHour || hour < FoldRules.morningWakeHour { return .night }
        if hour < daySlotStartHour { return .morning }
        if hour < eveningSlotStartHour { return .day }
        return .evening
    }

    // MARK: React families (04 §10.4: touch/feed/play/care)

    /// The react-line families (04 §10.4). The intent→family mapping is part
    /// of the constants home so the engine's plan minting and any test share
    /// one auditable table: pat (the greet/pet intents) → `touch`, feed →
    /// `feed`, play → `play`, tuck-in and nap → `care`.
    public enum ReactFamily: String, CaseIterable, Sendable {
        case touch
        case feed
        case play
        case care

        /// The family of an interaction intent (04 §10.4's mapping).
        public init(_ kind: InteractionIntent.Kind) {
            switch kind {
            case .pat: self = .touch
            case .feed: self = .feed
            case .play: self = .play
            case .tuckIn, .nap: self = .care
            }
        }
    }

    // MARK: Pool counts (placeholder era — see the header's bump obligation)

    /// The react-line pool size for `family`: 1 in the placeholder era (the
    /// single index-`00` catalog entry; real pools land EPIC-006/007 — and a
    /// catalog change bumps `copyEpoch` per §4.10). Explicit per-family input
    /// so tests exercise real variation with synthetic sizes.
    public static func reactLineCount(for family: ReactFamily) -> Int {
        1
    }

    /// The slot-line pool size for `slot`: 1 in the placeholder era (same
    /// discipline as `reactLineCount(for:)`; context slots expose the same
    /// count so the keyspace stays uniform, though no time derivation ever
    /// selects them).
    public static func slotLineCount(for slot: LineSlot) -> Int {
        1
    }
}
