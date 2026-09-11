import Testing
import Foundation
@testable import MomoKit

// MARK: - SettingsCopyKeyTests — the Settings tab's copy-key pins (TASK-038
// R2/R7; FR-19; UX §1.2 S6)

/// The KIT-side half of the settings copy's gluing: `SettingsCopyKeys` mints
/// FIXED catalog keys, and the catalog-side VERBATIM pins live in
/// `MomoCatalogScaffoldingTests` (character target) — these pin the minting
/// surface itself, so a key renamed on either side fails here or there and
/// never silently diverges. Includes the S6.2 composition pins: the alert
/// template resolves against the SHIPPED catalog file (the `KitRepo` anchor
/// — the headless target cannot reach the app bundle's compiled copy that
/// `MomoCopyText` reads), and the resolved TEMPLATE must compose through
/// `String(format:)` with the pet name in BOTH `%1$@` slots — the
/// name-interpolated alert copy is proven, not assumed. The assembled
/// title + message is pinned against the verbatim S6.2 UX string, and the
/// privacy statement against its verbatim line.
@Suite
struct SettingsCopyKeyTests {

    /// The S6.2 alert's ASSEMBLED copy for a pet named Mochi — the UX doc's
    /// verbatim line with the name interpolated twice (U+2019 apostrophes).
    private static let assembledAlertForMochi =
        "Erase everything? This deletes Mochi and all memories on this iPhone; "
            + "Mochi\u{2019}s Watch snapshot resets at its next sync. This can\u{2019}t be undone."

    /// Resolves a key against the shipped catalog file (the same two halves
    /// the view performs at render: key from the `SettingsCopyKeys` table,
    /// value from the catalog).
    private static func catalogValue(for key: String) throws -> String {
        let url = URL(fileURLWithPath: KitRepo.repoRoot + "/Apps/Shared/MomoCopy.xcstrings")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        let strings = try #require(root?["strings"] as? [String: Any])
        let entry = try #require(
            strings[key] as? [String: Any],
            "the minted key is missing from the shipped catalog")
        let unit = try #require(
            ((entry["localizations"] as? [String: Any])?["en"]
                as? [String: Any])?["stringUnit"] as? [String: Any])
        return try #require(unit["value"] as? String)
    }

    // MARK: The minting surface (the fixed keyspace)

    @Test("all ten settings keys are the fixed momo.settings.* lookups")
    func allKeysAreFixed() {
        #expect(SettingsCopyKeys.renameFieldLabelKey == "momo.settings.rename.field.label")
        #expect(SettingsCopyKeys.renameSaveKey == "momo.settings.rename.save")
        #expect(SettingsCopyKeys.hapticsToggleKey == "momo.settings.haptics.toggle")
        #expect(SettingsCopyKeys.eraseRowKey == "momo.settings.erase.row")
        #expect(SettingsCopyKeys.eraseAlertTitleKey == "momo.settings.erase.alert.title")
        #expect(SettingsCopyKeys.eraseAlertMessageTemplateKey == "momo.settings.erase.alert.message")
        #expect(SettingsCopyKeys.eraseAlertConfirmKey == "momo.settings.erase.alert.confirm")
        #expect(SettingsCopyKeys.eraseAlertCancelTemplateKey == "momo.settings.erase.alert.cancel")
        #expect(SettingsCopyKeys.aboutVersionLabelKey == "momo.settings.about.version.label")
        #expect(SettingsCopyKeys.aboutPrivacyKey == "momo.settings.about.privacy")
    }

    /// Every minted key resolves against the SHIPPED catalog to a non-empty
    /// English value — a constant/keyspace drift (a key renamed here but
    /// not landed, or landed under a typo) fails here before glass.
    @Test("every settings key resolves to a non-empty en value in the shipped catalog")
    func everyKeyResolves() throws {
        let keys = [
            SettingsCopyKeys.renameFieldLabelKey,
            SettingsCopyKeys.renameSaveKey,
            SettingsCopyKeys.hapticsToggleKey,
            SettingsCopyKeys.eraseRowKey,
            SettingsCopyKeys.eraseAlertTitleKey,
            SettingsCopyKeys.eraseAlertMessageTemplateKey,
            SettingsCopyKeys.eraseAlertConfirmKey,
            SettingsCopyKeys.eraseAlertCancelTemplateKey,
            SettingsCopyKeys.aboutVersionLabelKey,
            SettingsCopyKeys.aboutPrivacyKey,
        ]
        #expect(keys.count == 10)
        for key in keys {
            let value = try Self.catalogValue(for: key)
            #expect(!value.isEmpty, "\(key) resolves to a non-empty value")
        }
    }

    // MARK: The S6.2 alert composition (the name interpolates twice)

    /// The message template carries the POSITIONAL placeholder and composes
    /// the name into BOTH slots — S6.2 interpolates the pet twice (delete
    /// clause + Watch clause); a `%@` regression would put the name in one
    /// slot and garble the other.
    @Test("the alert message template composes the name into both %1$@ slots")
    func messageTemplateComposesTheNameTwice() throws {
        let template = try Self.catalogValue(for: SettingsCopyKeys.eraseAlertMessageTemplateKey)
        #expect(template.contains("%1$@"), "the template carries the positional placeholder")
        #expect(!template.contains("%2$@"), "the template has exactly one placeholder position")
        let composed = String(format: template, "Mochi")
        #expect(composed.contains("Mochi and all memories"))
        #expect(composed.contains("Mochi\u{2019}s Watch snapshot"))
    }

    /// The cancel template composes to `Keep Mochi` (S6.2's `Keep {name}`).
    @Test("the cancel template composes to Keep {name}")
    func cancelTemplateComposesTheName() throws {
        let template = try Self.catalogValue(for: SettingsCopyKeys.eraseAlertCancelTemplateKey)
        #expect(template.contains("%1$@"))
        #expect(String(format: template, "Mochi") == "Keep Mochi")
    }

    /// The ASSEMBLED alert — title + space + composed message — is the
    /// verbatim S6.2 UX string, name interpolated twice, U+2019 apostrophes
    /// included. A copy tweak anywhere in the alert's three keys fails this
    /// pin and forces the deliberate verbatim-table update.
    @Test("the assembled S6.2 alert reads the verbatim UX line")
    func assembledAlertIsTheVerbatimLine() throws {
        let title = try Self.catalogValue(for: SettingsCopyKeys.eraseAlertTitleKey)
        let message = String(
            format: try Self.catalogValue(for: SettingsCopyKeys.eraseAlertMessageTemplateKey),
            "Mochi")
        #expect(
            title + " " + message == Self.assembledAlertForMochi,
            "title + message assembles to the verbatim S6.2 string")
    }

    /// The confirm and cancel buttons read S6.2's `Erase` / `Keep {name}`
    /// (the cancel composition pinned above).
    @Test("the confirm button reads verbatim Erase")
    func confirmButtonIsErase() throws {
        #expect(
            try Self.catalogValue(for: SettingsCopyKeys.eraseAlertConfirmKey) == "Erase")
    }

    // MARK: The About privacy statement (verbatim)

    /// The privacy statement resolves to the verbatim UX line — the
    /// FR-19/FR-13 promise, pinned word-for-word.
    @Test("the privacy statement reads the verbatim line")
    func privacyStatementIsVerbatim() throws {
        #expect(
            try Self.catalogValue(for: SettingsCopyKeys.aboutPrivacyKey)
                == "Everything stays on this iPhone. Nothing about Momo ever leaves.")
    }
}
