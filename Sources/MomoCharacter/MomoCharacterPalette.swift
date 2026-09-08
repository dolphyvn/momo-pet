import SwiftUI

/// The 8 character color slots of 04-character-system §8.4 (binding) — the
/// character's color contract (R4). Slot keys are **verbatim** from §8.4
/// (`momo.fur.base` … `momo.sparkle`); values are this task's single canonical
/// palette pass, assigned together with the UI colors so Momo's body and the
/// app chrome coordinate (04 §8.4 + Appendix B item 3). The rig consumes these
/// tokens; no hex may appear in rig code (R4).
///
/// Dark values are deliberate (not mechanically inverted): the fur stays warm
/// cream but is dimmed and warmed so the bedside/evening character does not
/// glare; blush, blanket and sparkle deepen just enough to keep reading on the
/// dark ground (project.md §18 calm premium).
public enum MomoCharacterPalette {

    /// §8.4 slot `momo.fur.base` — warm cream body coat.
    public static let furBase = MomoColorToken(light: 0xF1E3D0, dark: 0xE3D1BC)

    /// §8.4 slot `momo.fur.shade` — one step deeper warm brown; form and
    /// shadow modeling (keeps the silhouette legible on the tonal ground).
    public static let furShade = MomoColorToken(light: 0xE0CCB2, dark: 0xC6AD90)

    /// §8.4 slot `momo.ear.inner` — soft blush inner ear.
    public static let earInner = MomoColorToken(light: 0xEFBFB8, dark: 0xD89E96)

    /// §8.4 slot `momo.eye.base` — warm near-black; the expression's anchor
    /// (≥ 10:1 against the fur in both appearances; expression is
    /// color-independent per 04 §3.5, so color carries no state).
    public static let eyeBase = MomoColorToken(light: 0x372F2B, dark: 0x272120)

    /// §8.4 slot `momo.eye.highlight` — the eye glint; warm white in dark so
    /// it does not spark against the dimmed fur.
    public static let eyeHighlight = MomoColorToken(light: 0xFFFFFF, dark: 0xF7F1E8)

    /// §8.4 slot `momo.cheek` — gentle blush; deepened in dark to stay visible.
    public static let cheek = MomoColorToken(light: 0xF2B5AC, dark: 0xCE8B82)

    /// §8.4 slot `momo.blanket` — soft powder blue by day, muted slate by
    /// night (a deliberate calm shade, not a dimmed neon).
    public static let blanket = MomoColorToken(light: 0xB5CBDA, dark: 0x5E7C8F)

    /// §8.4 slot `momo.sparkle` — soft gold for moment sparkles.
    public static let sparkle = MomoColorToken(light: 0xEFCB7F, dark: 0xE3BA60)

    /// The 8 slots in 04 §8.4 document order — the pinning surface the
    /// design-token tests assert against (verbatim slot names).
    public static let allSlots: [(slot: String, token: MomoColorToken)] = [
        ("momo.fur.base", furBase),
        ("momo.fur.shade", furShade),
        ("momo.ear.inner", earInner),
        ("momo.eye.base", eyeBase),
        ("momo.eye.highlight", eyeHighlight),
        ("momo.cheek", cheek),
        ("momo.blanket", blanket),
        ("momo.sparkle", sparkle),
    ]
}
