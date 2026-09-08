import SwiftUI
import MomoCharacter

/// Placeholder Home tab (UX-1, first tab) — the placeholder pet canvas is a
/// rectangle; the composed Home (status row, pet canvas, action row, quest card;
/// FR-2) arrives with TASK-033 and the rig with TASK-025/026.
///
/// TASK-011 plumbing proof: every rendered value resolves through the design
/// tokens (background, border, text, typography, spacing, radius, and the
/// `momo.fur.base` character slot) and the contextual line comes from the
/// String Catalog via `MomoCopy` (D12: no string literals; the DEBUG lookup
/// assertion would crash this surface if the catalog were missing, so the UI
/// smoke test doubles as the catalog-integration check). Remaining literals
/// ("Home — placeholder" caption below) are inert placeholder anchors, not
/// product copy; they are replaced by real composed UI in EPIC-007.
struct PlaceholderHomeView: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MomoSpacing.large) {
            // Placeholder pet canvas — replaced by the Direction-C rig (TASK-025/026).
            // Filled with the `momo.fur.base` token; the subtle §18 border keeps
            // the tonal surface legible against the warm ground.
            Rectangle()
                .fill(MomoCharacterPalette.furBase.resolve(colorScheme))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: 240)
                .clipShape(RoundedRectangle(cornerRadius: MomoRadius.large))
                .overlay(
                    RoundedRectangle(cornerRadius: MomoRadius.large)
                        .strokeBorder(MomoUIColors.border.resolve(colorScheme))
                )
            Text("Home — placeholder")
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
            Text(MomoCopy.resolve(CopyKey.line(.day, 0), bundle: .main))
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
        }
        .padding(MomoSpacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MomoUIColors.background.resolve(colorScheme))
    }
}
