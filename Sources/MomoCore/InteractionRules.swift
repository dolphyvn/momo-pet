import Foundation

// MARK: - InteractionRules — the interaction-semantics constants home
// (05-technical-architecture §4.4 numeric effects + §4.5 satiety window and
// repetition curve; PRD §4 matrix anchors; TASK-016 Requirement 3–5)

/// The single source of every number the interaction semantics apply — the
/// `FoldRules` discipline (TASK-015) carried into the interaction era: one
/// auditable home, per-constant authority labels, and raw literals only in
/// the pin test (`InteractionRulesPinnedTests`) — every behavior test and
/// every engine arithmetic site references these constants, so a spec change
/// surfaces as exactly one pin failure plus one constants edit.
///
/// **Authority vocabulary** (matching `FoldRules`' header):
///
/// - **PRD-normative** (changes require a PRD revision): the mood ceiling 92
///   (PRD §3.1), the tuck-in window's 20:00 open (FR-8 AC-1) and its 07:00
///   close (the D11 wake bound), the touch-does-not-touch-bond rule (G2 — a
///   rule, not a number), and the satiety response-class SPLIT at 30 minutes
///   (PRD §4 amended feed row; owner-confirmed I-2, 2026-09-08).
/// - **Engine-owned starting value** (05 §4.4 "(starting)" / §4.5 "(starting
///   value)"; the direction is PRD-normative, the number is TASK-006's
///   tunable): every effect delta (play −10/+6, meal +6/+4, nibble ×0.25,
///   touch +2, tuck-in +3/+2), the 90-minute window value (PRD §4 delegates
///   it, §4.5 DECISION), and the repetition curve 1.0/0.6/0.25/~0 (PRD §4
///   "starting curve"; "~0" lands as the exact 0.0 — a 4th+ repeat has no
///   numeric effect but still counts and still responds, TASK-016 Req 5).
public enum InteractionRules {

    // MARK: Numeric effects (05 §4.4 table — engine-owned starting values;
    // all writes additionally clamp to the INV-1/INV-2 0–100 domains)

    /// Play round, energy: −10 per completed round, applied at the unified
    /// cease instant (§4.4 table; §9.6 item 4).
    public static let playRoundEnergyDelta: Double = -10

    /// Play round, mood: +6 per completed round, applied at the unified cease
    /// instant and clamped by the mood ceiling below (§4.4 "normal play" is
    /// the representative ceiling case).
    public static let playRoundMoodDelta: Double = 6

    /// Hungry meal, energy: +6 (§4.4 table; multiplied by satiety class ×
    /// repetition curve).
    public static let mealEnergyDelta: Double = 6

    /// Hungry meal, mood: +4 (§4.4 table; multiplied by satiety class ×
    /// repetition curve, then ceiling-clamped).
    public static let mealMoodDelta: Double = 4

    /// The recently-fed nibble's effect multiplier ×0.25 (I-2 class,
    /// owner-confirmed 2026-09-08; the CLASS is PRD-normative — PRD FR-6/§4
    /// amended — the number is a starting value).
    public static let nibbleEffectMultiplier: Double = 0.25

    /// Pet/touch, mood: +2 in every state (§4.4 table — no state exemption is
    /// listed; the asleep stir is a touch that happened). Bond is NEVER
    /// touched by petting — G2, PRD-normative (a rule with no number here).
    public static let touchMoodDelta: Double = 2

    /// Tuck-in, mood: +3 (§4.4 table; no repetition multiplier — care is
    /// window/band-gated, §4.4's I-2 note).
    public static let tuckInMoodDelta: Double = 3

    /// Tuck-in, energy: +2 (§4.4 table; no repetition multiplier — care).
    public static let tuckInEnergyDelta: Double = 2

    // MARK: Mood ceiling (PRD §3.1 — PRD-normative)

    /// The interaction-path mood ceiling: "normal play clamps ≤ 92" (PRD
    /// §3.1; 05 §4.4 effects table's ceiling row). The fold's attractor can
    /// never approach it, so the clamp applies to interaction mood gains
    /// (TASK-016 Requirement 3's recorded interpretation) — and it clamps the
    /// GAIN, never the level: an interaction never lowers mood (D18), so a
    /// pet already above 92 holds instead of being pulled down.
    public static let interactionMoodCeiling: Double = 92

    // MARK: Satiety window (05 §4.5 DECISION)

    /// The satiety window: 90 minutes, after which the pet is hungry again
    /// (engine-owned starting value — PRD §4 delegates the window VALUE;
    /// §4.5 records the alternatives considered). Half-open: 90:00 after the
    /// last feed is hungry's first minute.
    public static let satietyWindowMinutes: Int = 90

    /// The full → recently-fed split: 30 minutes (PRD-owned — the response
    /// classes are PRD §4's; the 30–90 recentlyFed class was owner-confirmed
    /// I-2 / OPEN-5, 2026-09-08). Half-open: 30:00 after the last feed is
    /// recentlyFed's first minute.
    public static let satietySplitMinutes: Int = 30

    // MARK: Repetition curve (05 §4.5 — engine-owned starting values)

    /// Same-family repetition multipliers per local day, indexed by the
    /// 0-based instance count read BEFORE the interaction increments its
    /// family counter: 1.0 (1st) / 0.6 (2nd) / 0.25 (3rd) / 0.0 (4th+). Care
    /// is exempt (tuck-in and nap carry no multiplier — §4.4's I-2 note); the
    /// curve is independent of satiety (the 2nd meal is softer even 2 h
    /// later); petting banks no bond at any volume (G2).
    public static let repetitionMultipliers: [Double] = [1.0, 0.6, 0.25, 0.0]

    /// The multiplier for the 0-based `instanceIndex`th same-family instance
    /// (clamped at the curve's end — the 4th+ instance shares ~0).
    public static func repetitionMultiplier(instanceIndex: Int) -> Double {
        repetitionMultipliers[min(max(instanceIndex, 0), repetitionMultipliers.count - 1)]
    }

    // MARK: Tuck-in window (FR-8 AC-1 — PRD-normative)

    /// Local hour the tuck-in offer opens: 20:00, every waking band (PRD §4
    /// care row; FR-8 AC-1). The same PRD hour anchors Q6's window start —
    /// `Thresholds.Quest.q6WindowStartHour` — and the two constants are
    /// pinned EQUAL in `InteractionRulesPinnedTests` so a PRD change to
    /// either surfaces loudly instead of silently diverging.
    public static let tuckInWindowStartHour: Int = 20

    /// Whether `instant`'s local time is inside the tuck-in window
    /// [20:00, 07:00) local — the owner-amended Q6 window shape (§5.5 rule 1,
    /// OPEN-1) that FR-8's "through the night window" resolves to. The local
    /// hour comes from the INJECTED calendar (D20; DST-safe: `Calendar`
    /// resolves the wall hour of the instant, so a fall-back night's repeated
    /// hour and a spring-forward night's skipped hour are handled by
    /// construction).
    public static func isTuckInWindow(_ instant: Instant, calendar: Calendar) -> Bool {
        let hour = calendar.component(.hour, from: instant)
        return hour >= tuckInWindowStartHour || hour < FoldRules.morningWakeHour
    }
}
