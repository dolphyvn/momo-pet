import SwiftUI
import MomoCharacter
import MomoKit

/// The Home status row (TASK-033 Requirement 6; UX §5.1's status sketch):
/// `{mood glyph} {mood word} · {energy glyph} {energy word} · ✨ {stage}` —
/// one calm caption line, everything resolved from the read-model's catalog
/// keys. UI chrome literals here are DISCLOSED view literals (the separator
/// dots and glyphs); every word is catalog copy.
///
/// VoiceOver (UX §10 / 04 §3.5's binding formula): the mood·energy pair is
/// ONE element announcing "{Name} feels {mood word} and {energy phrase}",
/// and the stage is ONE element announcing "{Stage name}. {descriptor}" —
/// the phrase/descriptor keys come from the OBS-1 vocabulary, the visible
/// row shows the compact words. The glyphs are decorative (hidden).
struct HomeStatusRowView: View {

    @Environment(\.colorScheme) private var colorScheme

    /// The Home read-model slice this row renders (TASK-033 R1/R2).
    let model: HomeReadModel

    var body: some View {
        HStack(spacing: MomoSpacing.small) {
            // The mood·energy pair — one VoiceOver element, one visible run.
            HStack(spacing: MomoSpacing.extraSmall) {
                Image(systemName: "face.smiling")
                    .foregroundStyle(MomoUIColors.accent.resolve(colorScheme))
                    .accessibilityHidden(true)
                Text(MomoCopyText.render(model.moodWordKey))
                Text("·").accessibilityHidden(true)
                Image(systemName: "bolt")
                    .foregroundStyle(MomoUIColors.accent.resolve(colorScheme))
                    .accessibilityHidden(true)
                Text(MomoCopyText.render(model.energyWordKey))
            }
            .font(MomoTypography.caption)
            .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(model.petName) feels \(MomoCopyText.render(model.moodWordKey)) and \(MomoCopyText.render(model.energyPhraseKey))")
            // Display text, never a control: the static-text trait is the
            // honest semantic declaration — VoiceOver reads it as text with
            // no activation, and the hit-area audit sees a non-interactive
            // node (the 44-pt floor governs TAPPABLE controls; TASK-039 R6).
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("home.statusRow.moodEnergy")

            // The bond stage — its own element, name + descriptor.
            HStack(spacing: MomoSpacing.extraSmall) {
                Image(systemName: "sparkles")
                    .foregroundStyle(MomoUIColors.accent.resolve(colorScheme))
                    .accessibilityHidden(true)
                Text(MomoCopyText.render(model.stageNameKey))
            }
            .font(MomoTypography.caption)
            .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(MomoCopyText.render(model.stageNameKey)). \(MomoCopyText.render(model.bondDescriptorKey))")
            .accessibilityAddTraits(.isStaticText)
            .accessibilityIdentifier("home.statusRow.stage")
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.statusRow")
    }
}
