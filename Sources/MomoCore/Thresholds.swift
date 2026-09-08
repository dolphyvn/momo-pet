import Foundation

/// The PRD §3 numeric single source (TASK-012 constraint: every cut-off /
/// threshold is defined exactly once, here — all other code references these
/// constants and must not restate the literals).
///
/// The tables these encode:
/// - PRD §3.1 Mood bands: Low 0–19, Wistful 20–44, Content 45–74, Joyful 75–100.
/// - PRD §3.2 Energy bands: Exhausted 0–19, Drowsy 20–44, Relaxed 45–74, Energetic 75–100.
/// - PRD §3.3 Bond stages: New Friends 0–149, Getting Close 150–399,
///   Best Friends 400–749, Soul Companions 750–1000; daily earning cap +20.
/// - PRD §5.1–5.2 quest windows: Q1 until 12:00 local, Q6 20:00–07:00 local.
public enum Thresholds {

    /// The mood/energy scalar range (D10, PRD §3.1–3.2: "internal continuous
    /// scalar 0–100"). INV-2 keeps both scalars inside it at every transition.
    public enum Scalar {
        public static let lower: Double = 0
        public static let upper: Double = 100
    }

    /// Band cut-offs shared by mood (§3.1) and energy (§3.2) — one triple,
    /// because the two PRD tables use identical ranges. The value at a cut-off
    /// belongs to the band above it (20 is Wistful/Drowsy, 45 Content/Relaxed,
    /// 75 Joyful/Energetic — the PRD ranges are lower-inclusive).
    public enum Band {
        /// First Wistful (mood) / Drowsy (energy) value.
        public static let lowUpperBound: Double = 20
        /// First Content (mood) / Relaxed (energy) value.
        public static let contentLowerBound: Double = 45
        /// First Joyful (mood) / Energetic (energy) value.
        public static let joyfulLowerBound: Double = 75
    }

    /// Bond (§3.3, FR-10): cumulative, monotonic non-decreasing, 0–1000.
    /// The stage constants are the first value of each stage (the PRD ranges
    /// 0–149 / 150–399 / 400–749 / 750–1000 expressed as lower bounds).
    public enum Bond {
        /// The range floor (PRD: cumulative scalar 0–1000).
        public static let minimum: Int = 0
        /// First Getting Close value (PRD: stage starts at 150).
        public static let gettingCloseAt: Int = 150
        /// First Best Friends value (PRD: stage starts at 400).
        public static let bestFriendsAt: Int = 400
        /// First Soul Companions value (PRD: stage starts at 750).
        public static let soulCompanionsAt: Int = 750
        /// The plateau (INV-3 upper bound; FR-10 AC-2).
        public static let maximum: Int = 1000
        /// The per-local-day earning cap (INV-5; PRD §3.3 "Daily cap +20",
        /// enforced by clamp-at-award — engine side, §4.6).
        public static let dailyCap: Int = 20
    }

    /// Quest catalog shape (PRD §5, FR-14).
    public enum Quest {
        /// Exactly 3 quests per daily set (PRD §5.1 rule 5, FR-14/15).
        public static let questsPerDay: Int = 3
        /// Q1 "Morning hello" window closes at 12:00 local (PRD §5.2).
        public static let q1WindowClosesAtHour: Int = 12
        /// Q6 "Tuck-in" window opens at 20:00 local (PRD §5.2; owner-amended
        /// §5.5 rule 1, 2026-09-08 — the window also covers 00:00–07:00).
        public static let q6WindowStartHour: Int = 20
        /// Q6 "Tuck-in" window ends at 07:00 local (PRD §5.2).
        public static let q6WindowEndHour: Int = 7
    }
}
