import SwiftUI
import MomoCharacter
import MomoKit

/// The Home action row (TASK-033 Requirement 6; UX §5.1's action sketch,
/// §5.4's window rule): the read-model's `actionPills` — feed and play
/// always; tuck-in within its evening window; nap in the waking hours of a
/// drowsy/exhausted pet. Out-of-window actions are ABSENT, never disabled
/// ghosts (§5.4), and there is no presentation on tap: every pill routes
/// through `appModel.interact` — the ONE sanctioned view→engine path (D-R5).
///
/// The pill labels and glyphs are DISCLOSED view chrome (button text is not
/// engine copy); each pill is ≥44 pt tall (UX §10) and carries its own
/// accessibility identifier (`home.actionPill.<kind>`).
struct HomeActionRowView: View {

    @Environment(\.colorScheme) private var colorScheme

    /// The app model — every tap becomes an `InteractionIntent` (D-R5).
    let appModel: MomoAppModel

    /// The Home read-model slice this row renders (TASK-033 R1/R2).
    let model: HomeReadModel

    var body: some View {
        HStack(spacing: MomoSpacing.small) {
            ForEach(model.actionPills.indices, id: \.self) { index in
                pill(for: model.actionPills[index])
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.actionRow")
    }

    /// One pill: glyph + label, ≥44 pt, calm fill. The routing is the whole
    /// action — `interact` mints the intent envelope and applies it.
    private func pill(for kind: HomeActionPillKind) -> some View {
        Button {
            appModel.interact(kind)
        } label: {
            HStack(spacing: MomoSpacing.extraSmall) {
                Image(systemName: Self.glyph(for: kind))
                    .accessibilityHidden(true)
                Text(Self.label(for: kind))
            }
            .font(MomoTypography.body.weight(.medium))
            .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
            .padding(.horizontal, MomoSpacing.medium)
            .frame(minHeight: OnboardingLayout.minimumTapTarget)
            .background(
                Capsule().fill(MomoUIColors.surface.resolve(colorScheme))
            )
            .overlay(
                Capsule().strokeBorder(MomoUIColors.border.resolve(colorScheme))
            )
            .contentShape(Capsule())
        }
        .accessibilityLabel(Self.accessibilityLabel(for: kind))
        .accessibilityIdentifier("home.actionPill.\(Self.identifierName(for: kind))")
    }

    // MARK: Disclosed view chrome (labels/glyphs are presentation, not copy)

    private static func label(for kind: HomeActionPillKind) -> String {
        switch kind {
        case .pat: "Pat"
        case .feed: "Feed"
        case .play: "Play"
        case .tuckIn: "Tuck in"
        case .nap: "Nap"
        }
    }

    private static func glyph(for kind: HomeActionPillKind) -> String {
        switch kind {
        case .pat: "hand.tap"
        case .feed: "fork.knife"
        case .play: "figure.run"
        case .tuckIn: "moon.stars"
        case .nap: "zzz"
        }
    }

    /// The spoken label never abbreviates ("Tuck in" stays two words).
    private static func accessibilityLabel(for kind: HomeActionPillKind) -> String {
        label(for: kind)
    }

    /// The identifier fragment (`home.actionPill.<name>`).
    private static func identifierName(for kind: HomeActionPillKind) -> String {
        switch kind {
        case .pat: "pat"
        case .feed: "feed"
        case .play: "play"
        case .tuckIn: "tuckIn"
        case .nap: "nap"
        }
    }
}
