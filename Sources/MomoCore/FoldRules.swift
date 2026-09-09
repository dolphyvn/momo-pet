import Foundation

// MARK: - FoldRules — the time-fold constants home (05-technical-architecture §4.3;
// PRD §3.1–3.2 anchors; TASK-015 Requirement 1 / AC-1)

/// The single source of every number the §4.3 time fold applies — the engine's
/// dynamics constants, defined exactly once (AC-1's no-duplicated-literals
/// rule; the TASK-012 `Thresholds` discipline carried into the engine era).
///
/// **Why a second constants home beside `Thresholds`:** the two homes have
/// different change authorities, and conflating them would erase that from the
/// code. `Thresholds` holds PRD §3 *structure* numbers (band cut-offs, bond
/// caps/stages, quest windows) — PRD-revision-owned. `FoldRules` holds the
/// fold *dynamics*: each constant is labeled with its authority —
///
/// - **PRD-normative** (changes require a PRD revision): the mood attractor
///   target 60, the mood floor 25, the energy-coupling target 35 (PRD §3.1),
///   the wake-value clamp ≥ 75 (PRD §3.2 "restores to ≥ 75 by 07:00"), and the
///   night window bounds 22:00/07:00 (D11, PRD §3.2).
/// - **Engine-owned starting value** (05 §4.3 table "(starting value)"; the
///   direction is PRD-normative, the number is TASK-006's tunable): the
///   −1.5 pts/h waking decline (PRD 1–2 pts/h), the night-ramp target 85 at
///   07:00 (PRD "starts the day at 85 *(starting value)*"), τ = 3 h, and the
///   nap restore +20 (PRD §3.2 "~20 *(starting value)*", §4.4 table).
///
/// Every fold/test that needs one of these numbers references the constant —
/// raw literals appear only in the pin test (`FoldRulesPinnedTests`), never
/// in engine arithmetic or in the behavior tests (TASK-013's two-layer
/// discipline: constants feed the tests; only the pins restate values).
public enum FoldRules {

    // MARK: Night window (D11, PRD §3.2 — PRD-normative)

    /// Local hour the night window opens (22:00, D11). The engine sleeps the
    /// pet across [22:00, 07:00) local; §4.3's fold lands `.asleep` when a
    /// fold crosses the onset, `.waking` when it crosses the wake bound.
    public static let nightOnsetHour: Int = 22

    /// Local hour the night window closes (07:00, D11) — the wake boundary.
    public static let morningWakeHour: Int = 7

    // MARK: Passive energy decline (PRD §3.2 — starting value; direction normative)

    /// Waking-hours passive decline, points per hour (05 §4.3: "−1.5 pts/hour
    /// *(starting value; PRD 1–2)*"). Applied in waking segments only — never
    /// during the night window and never while napping (§4.3 decline row).
    public static let wakingEnergyDeclinePerHour: Double = -1.5

    // MARK: Night restore (PRD §3.2; 05 §4.3 — ramp target is a starting value,
    // the wake clamp is PRD-normative)

    /// The energy level a full night's sleep restores to (05 §4.3: "energy
    /// ramps linearly to **85** at 07:00"; PRD §3.2 "starts the day at **85**
    /// *(starting value)*"). The ramp's slope is anchored to the night's full
    /// local duration (onset→wake), so partial/late nights restore
    /// proportionally and the wake clamp below stays meaningful.
    public static let nightRestoreTarget: Double = 85

    /// The wake-value clamp (PRD §3.2 normative: "energy restores to **≥ 75**
    /// by 07:00"; 05 §4.3: "wake value clamped ≥ **75**"). Applied at the
    /// 07:00 boundary: whatever the proportional ramp produced, the pet wakes
    /// with at least this much energy.
    public static let wakeEnergyClamp: Double = 75

    // MARK: Mood attractor (PRD §3.1 — target/floor/coupling normative;
    // τ is a starting value)

    /// The calm attractor target (PRD §3.1: "mood eases toward **60**
    /// (Content)"): `mood += (target − mood) × (1 − e^(−Δt/τ))` per segment.
    public static let moodAttractorTarget: Double = 60

    /// The attractor's time constant in hours (05 §4.3: "τ = 3 h
    /// *(starting value)*").
    public static let moodAttractorTauHours: Double = 3

    /// The energy-coupled attractor target (PRD §3.1: "mood gains a gentle
    /// downward pull toward **35**") — active while energy ∈ Drowsy/Exhausted
    /// during waking hours and the pet is awake (a nap is the rest that
    /// relieves the pull).
    public static let moodCoupledTarget: Double = 35

    /// The mood floor (PRD §3.1 normative: "Phase 1 dynamics MUST NOT take
    /// mood below **25**"). Enforced as a post-fold clamp — with only downward
    /// pressure being a pull *toward* 35, the clamp is the structural guarantee.
    public static let moodFloor: Double = 25

    // MARK: Nap restore (PRD §3.2 "~20 (starting value)"; §4.4 table)

    /// The energy a nap restores, applied once when a fold observes the nap
    /// completed ("energy +20 over the nap *(starting)*", §4.4). The domain
    /// model records no nap-start instant (05 §3.1 has no field for one), so
    /// the fold applies the flat restore at nap completion — the implementable
    /// reading of "over the nap" without extending PetState (TASK-015
    /// Implementation Notes).
    public static let napRestoreEnergy: Double = 20
}
