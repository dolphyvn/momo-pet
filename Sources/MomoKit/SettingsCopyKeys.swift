import Foundation

// MARK: - SettingsCopyKeys — the Settings surface's copy-key minting
// (TASK-038 R7; FR-19; UX §1.2 S6; INV-11)

/// Key-only minting for the Settings screen (INV-11: views resolve catalog
/// KEYS through `MomoCopy` — never composed prose, never literals). The
/// whole keyspace is FIXED lookups — `momo.settings.<group>[.<sub>]<part>`
/// — the `momo.line.moment`/`momo.tab.*` precedent: each row names ITS
/// string (a rename field must say the rename field), so there are no
/// seeded draws here and NO epoch involvement (the epoch-4 residue pins
/// stay untouched).
///
/// Pure constants only — nothing to select. No string here is user-facing
/// text; all are namespace structure under §8.4's dot convention. The
/// verbatim pins over the shipped catalog entries live in
/// `MomoCatalogScaffoldingTests`; the minting-surface pins (these
/// constants, the `%1$@` compositions) live in `SettingsCopyKeyTests`.
public enum SettingsCopyKeys {

    // MARK: Rename (S6.1 — inline; the flat-IA adjudication)

    /// The rename field's label — "Pet name" (S1/S2's naming convention).
    /// Doubles as the section header and the field's VoiceOver label.
    public static let renameFieldLabelKey = "momo.settings.rename.field.label"

    /// The rename Save button's label.
    public static let renameSaveKey = "momo.settings.rename.save"

    // MARK: Haptics

    /// The haptics toggle's label (the only audio-adjacent surface Phase 1
    /// ships; the sound row is adjudicated ABSENT — FR-19's conditional
    /// resolved by 04 §11's no-audio scope).
    public static let hapticsToggleKey = "momo.settings.haptics.toggle"

    // MARK: Erase all data (S6.2 — the product's ONLY modal)

    /// The Erase row's label. Destructive by ROLE (the row's Button), which
    /// is what gives VoiceOver its destructive trait (FR-19 AC-3).
    public static let eraseRowKey = "momo.settings.erase.row"

    /// The system alert's title — "Erase everything?", the UX message line's
    /// first sentence. The ASSEMBLED alert (title + composed message) must
    /// read the S6.2 copy verbatim; both halves are pinned.
    public static let eraseAlertTitleKey = "momo.settings.erase.alert.title"

    /// The system alert's message TEMPLATE — the S6.2 copy after the title,
    /// with the pet name interpolating TWICE. Positional `%1$@` placeholders
    /// reference argument 1 both times so a localized reordering stays
    /// locale-correct (the `moment.01`/`room.01` template precedent).
    public static let eraseAlertMessageTemplateKey =
        "momo.settings.erase.alert.message"

    /// The alert's destructive confirm button — "Erase".
    public static let eraseAlertConfirmKey = "momo.settings.erase.alert.confirm"

    /// The alert's cancel button TEMPLATE — "Keep %1$@" (the pet's name).
    /// Cancelling performs NOTHING: the store is untouched.
    public static let eraseAlertCancelTemplateKey =
        "momo.settings.erase.alert.cancel"

    // MARK: About

    /// The About section's version row label. The version NUMBER is a system
    /// value read from the bundle (`CFBundleShortVersionString`) — data, not
    /// copy; only this label string is catalog-sourced.
    public static let aboutVersionLabelKey = "momo.settings.about.version.label"

    /// The short privacy statement (verbatim in-contract; ≤ 12 words — the
    /// copy law scans it as body copy): everything local, nothing leaves.
    public static let aboutPrivacyKey = "momo.settings.about.privacy"
}
