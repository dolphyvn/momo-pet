import SwiftUI
import MomoCharacter
import MomoKit

/// The Home quest card (TASK-033 Requirement 6; UX §5.1's quest sketch,
/// §5.5's rendering law): "Today's little wishes" — one row per of-today's
/// quests whose local-time window is OPEN (silent absence for closed
/// windows — never a disabled ghost, §5.4/§11.2.4). Each row is
/// `glyph · wish · soft mark` with the per-wish mark only (○ pending /
/// ● done) — no aggregate progress bar (§5.5).
///
/// The header and the glyphs/marks are DISCLOSED view chrome; the wish text
/// is catalog copy (`momo.line.quest.q<n>`). Rows are ≥44 pt (UX §10) and
/// speak "{wish}, done/pending" — words, never symbols. Rows that would
/// truncate instead scale down to 80% and hold one line, so the card's
/// height is stable on the SE.
struct HomeQuestCardView: View {

    @Environment(\.colorScheme) private var colorScheme

    /// The Home read-model slice this card renders (TASK-033 R1/R2).
    let model: HomeReadModel

    /// The visible rows: the day's quests with an open window, in record
    /// (catalog) order.
    private var visibleRows: [HomeQuestRow] {
        model.questRows.filter(\.isWindowVisible)
    }

    var body: some View {
        VStack(spacing: MomoSpacing.extraSmall) {
            Text("Today's little wishes")
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(visibleRows) { row in
                questRow(row)
            }
        }
        .padding(MomoSpacing.small)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: MomoRadius.medium)
                .fill(MomoUIColors.surface.resolve(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MomoRadius.medium)
                .strokeBorder(MomoUIColors.border.resolve(colorScheme))
        )
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("home.questCard")
    }

    /// One wish row: family glyph, wish text, soft mark. The glyph and the
    /// mark are decorative — the label carries the state in words.
    private func questRow(_ row: HomeQuestRow) -> some View {
        HStack(spacing: MomoSpacing.small) {
            Image(systemName: Self.glyph(forWishIn: row))
                .foregroundStyle(MomoUIColors.accent.resolve(colorScheme))
                .accessibilityHidden(true)
            Text(MomoCopyText.render(row.wishKey))
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Image(systemName: row.isCompleted ? "circle.fill" : "circle")
                .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
                .accessibilityHidden(true)
        }
        .frame(minHeight: OnboardingLayout.minimumTapTarget)
        .padding(.horizontal, MomoSpacing.extraSmall)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(MomoCopyText.render(row.wishKey)), \(row.isCompleted ? "done" : "pending")")
        .accessibilityIdentifier("home.questRow.\(row.questID.rawValue.lowercased())")
    }

    // MARK: Disclosed view chrome (the quest-family glyphs)

    private static func glyph(forWishIn row: HomeQuestRow) -> String {
        switch row.questID {
        case .q1: "hand.wave"       // greet
        case .q2, .q3: "fork.knife" // feed
        case .q4, .q5: "figure.run" // play
        case .q6: "moon.stars"      // care
        case .q7: "heart"           // pet
        }
    }
}
