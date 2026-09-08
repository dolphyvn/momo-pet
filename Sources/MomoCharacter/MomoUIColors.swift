import SwiftUI

/// Semantic UI color tokens (project.md §18 visual language: warm/off-white
/// backgrounds, soft pastel accents, restrained color, subtle borders —
/// calm premium). Values were assigned in the same pass as the character
/// palette (04 §8.4 / Appendix B item 3) so body and chrome share one system.
///
/// Dark values are deliberate (not inverted): warm near-blacks instead of
/// pure black, warmed whites instead of pure white — evening use is Momo's
/// primary context, so dark mode is a first-class look, not a fallback.
///
/// Contrast baselines (WCAG, computed; full audit is TASK-047 — intent
/// recorded here, all ≥ 4.5:1 body-text target): textPrimary/background
/// 13.57 (light) and 14.64 (dark); textPrimary/surface 14.51 and 13.09;
/// textSecondary/background 5.41 and 6.56; textSecondary/surface 5.78 and
/// 5.86.
public enum MomoUIColors {

    /// Warm off-white app ground (§18); dark is warm near-black.
    public static let background = MomoColorToken(light: 0xFAF7F1, dark: 0x1B1815)

    /// Card / sheet surface above the ground.
    public static let surface = MomoColorToken(light: 0xFFFFFF, dark: 0x26221D)

    /// Subtle border (§18) for tonal surfaces that need a whisper of edge.
    public static let border = MomoColorToken(light: 0xE7DFD3, dark: 0x3B342C)

    /// Primary text — warm near-black / warm off-white.
    public static let textPrimary = MomoColorToken(light: 0x2F2822, dark: 0xEFE9DF)

    /// Secondary text — captions, hints (≥ 4.5:1 on both grounds).
    public static let textSecondary = MomoColorToken(light: 0x6E6459, dark: 0xA79C8E)

    /// Soft pastel accent (§18) — decorative tint only (icons, glints, small
    /// fills); body text never renders in the accent.
    public static let accent = MomoColorToken(light: 0xC98B6F, dark: 0xD6A183)
}
