import SwiftUI
import MomoCharacter

/// Placeholder W1 glance (03-ux-architecture §6.1) — static content, no logic:
/// the four W1 slots (status · pet canvas · quest line · pat pill) rendered as
/// inert placeholders. Real snapshot rendering, the LOD character and pat
/// capture arrive in EPIC-008 (TASK-041/042).
///
/// TASK-011 plumbing proof: typography, text colors, spacing, radius and the
/// `momo.blanket` character slot all resolve through the design tokens, and
/// the pat capsule's VoiceOver label comes from the String Catalog via
/// `MomoCopy` (a react line is announced, never rendered — 04 §10.1 rule 7;
/// the DEBUG lookup assertion would crash this surface if the catalog were
/// missing, so the UI smoke test doubles as the catalog-integration check).
/// Remaining literals are inert placeholder anchors, not product copy. The
/// system ground is kept (watchOS owns its background); tokens color content.
struct PlaceholderGlanceView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: MomoSpacing.small) {
            Text("Feeling happy") // placeholder status slot
                .font(MomoTypography.heading)
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
            // Placeholder pet canvas — a fixed-height strip. (A flexible
            // `aspectRatio(.fit)` shape collapses to zero height in this
            // VStack at the glance's compact size, layoutPriority included;
            // a deterministic height is the honest placeholder. The real
            // snapshot canvas arrives with the EPIC-008 rig.)
            RoundedRectangle(cornerRadius: MomoRadius.medium)
                .fill(MomoCharacterPalette.blanket.resolve(colorScheme))
                .frame(height: 32)
            Text("Wish placeholder") // placeholder quest line
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
            Text("Pat") // placeholder pat pill — intentionally inert (no action in the shell)
                .font(MomoTypography.body.weight(.medium))
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                .frame(maxWidth: .infinity)
                .padding(.vertical, MomoSpacing.medium)
                .background(MomoUIColors.surface.resolve(colorScheme), in: Capsule())
                .accessibilityLabel(MomoCopy.resolve(CopyKey.react(.touch, 0), bundle: .main))
        }
        .padding(MomoSpacing.medium)
    }
}
