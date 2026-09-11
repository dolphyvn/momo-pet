import SwiftUI
import MomoKit

// MARK: - SettingsView — the real FR-19 Settings surface (TASK-038 R1;
// UX §1.2 S6; native list)

/// The Settings tab (TASK-038; FR-19; UX §1.2 S6): a NATIVE list (UX :436 —
/// native rows give 44-pt targets, Dynamic Type, and VoiceOver by
/// construction) with EXACTLY the FR-19 inventory and nothing else:
///
/// 1. **Rename** (S6.1) — an inline labeled `TextField` pre-filled with the
///    current name + `Save` (disabled while the trimmed field is empty —
///    the disabled state is the signal, never error copy).
/// 2. **Haptics** — a native `Toggle` (the plan-core `.hapticsToggled`
///    trigger through the app model).
/// 3. **Erase all data** — a destructive-role row opening the SYSTEM alert
///    (UX :103/:438: the product's ONLY modal; the flat-IA law bans every
///    other presentation), with the verbatim S6.2 copy and the
///    `Keep {name}` cancel.
/// 4. **About** — the bundle's version value + the short privacy statement.
///
/// **Inventory adjudications (the header the contract requires):**
/// - The sound row is ABSENT by adjudication: FR-19 ships it "only if
///   Phase 1 ships any audio", and 04 §11 shipped NO audio system — the
///   doc's own conditional resolves to absent. The haptics toggle is the
///   only audio-adjacent surface.
/// - S6.1 renders INLINE (this list) despite the UX IA tree's
///   "sub-screen" wording (:46): §2's flat-IA law (:103) bans push
///   navigation and names the erase alert the only modal — either a push
///   or a sheet for rename would violate it. Disclosed in the contract.
/// - NO account/sign-in, notification, HealthKit, or purchase row exists
///   (FR-19's MUST-NOT list) — enforced structurally by the R8
///   `RigDiscipline` guard over this very file, and on glass by the UI
///   census in `MomoSettingsUITests`.
///
/// D12: every user-facing string is a catalog key resolved through
/// `MomoCopyText.render` — the version NUMBER is the one system VALUE (the
/// R6/D11 carveout: data, not copy).
struct SettingsView: View {

    @Environment(MomoAppModel.self) private var appModel

    /// The rename field's text — pre-filled from the current pet name and
    /// re-synced whenever it changes (so a save is reflected in place).
    @State private var nameField = ""

    /// The erase alert's presentation flag — the product's one modal.
    @State private var isEraseAlertPresented = false

    /// The pet's current name — the alert copy interpolates it twice.
    private var petName: String { appModel.state.pet.name }

    /// INV-1's face in the UI (the S2 convention): the Save button is the
    /// rename's first gate — disabled while the trimmed field is empty.
    private var canSave: Bool {
        !nameField.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// The bundle's marketing version — a system VALUE (R6/D11 carveout:
    /// data, not copy), read once per render like any other read-model.
    private var versionString: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString")
            as? String ?? ""
    }

    var body: some View {
        Form {
            renameSection
            hapticsSection
            eraseSection
            aboutSection
        }
        .navigationTitle(MomoCopyText.render(HomeCopyKeys.tabLabelKey(for: .settings)))
        .onAppear { nameField = petName }
        .onChange(of: petName) { _, newName in nameField = newName }
        .alert(
            MomoCopyText.render(SettingsCopyKeys.eraseAlertTitleKey),
            isPresented: $isEraseAlertPresented
        ) {
            Button(
                MomoCopyText.render(SettingsCopyKeys.eraseAlertConfirmKey),
                role: .destructive
            ) {
                appModel.eraseAllData()
            }
            Button(
                String(
                    format: MomoCopyText.render(SettingsCopyKeys.eraseAlertCancelTemplateKey),
                    petName
                ),
                role: .cancel
            ) {
                // Keep performs NOTHING — the store is untouched (R5.6).
            }
        } message: {
            Text(String(
                format: MomoCopyText.render(SettingsCopyKeys.eraseAlertMessageTemplateKey),
                petName
            ))
        }
    }

    // MARK: The four inventory groups (FR-19's EXACT list)

    private var renameSection: some View {
        Section(MomoCopyText.render(SettingsCopyKeys.renameFieldLabelKey)) {
            TextField(
                MomoCopyText.render(SettingsCopyKeys.renameFieldLabelKey),
                text: $nameField
            )
            .accessibilityLabel(MomoCopyText.render(SettingsCopyKeys.renameFieldLabelKey))
            .accessibilityIdentifier("settings.name.field")
            Button(MomoCopyText.render(SettingsCopyKeys.renameSaveKey)) {
                // FR-19 AC-1's effective name: the executor trims, so a
                // Save attempt re-syncs the field to the TRIMMED value —
                // the displayed name is always the effective one (TASK-039
                // R7). `renamePet` performs its own trim (defense at the
                // executor); this re-sync is the observable contract.
                let trimmed = nameField.trimmingCharacters(in: .whitespacesAndNewlines)
                nameField = trimmed
                appModel.renamePet(to: trimmed)
            }
            .disabled(!canSave)
            .accessibilityIdentifier("settings.name.save")
        }
    }

    private var hapticsSection: some View {
        Section {
            Toggle(
                MomoCopyText.render(SettingsCopyKeys.hapticsToggleKey),
                isOn: hapticsBinding
            )
            .accessibilityIdentifier("settings.haptics.toggle")
        }
    }

    private var eraseSection: some View {
        Section {
            Button(role: .destructive) {
                isEraseAlertPresented = true
            } label: {
                Text(MomoCopyText.render(SettingsCopyKeys.eraseRowKey))
            }
            .accessibilityIdentifier("settings.erase.row")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent(
                MomoCopyText.render(SettingsCopyKeys.aboutVersionLabelKey),
                value: versionString
            )
            .accessibilityIdentifier("settings.about")
            Text(MomoCopyText.render(SettingsCopyKeys.aboutPrivacyKey))
        }
    }

    /// The Toggle's binding rides the app model (R4): the getter reads the
    /// plan-core state, the setter applies the `.hapticsToggled` trigger —
    /// the view never writes settings directly (D-R5).
    private var hapticsBinding: Binding<Bool> {
        Binding(
            get: { appModel.state.settings.hapticsEnabled },
            set: { appModel.setHapticsEnabled($0) }
        )
    }
}
