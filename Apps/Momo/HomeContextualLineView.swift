import SwiftUI
import MomoCharacter
import MomoKit

/// The Home contextual line (TASK-033 Requirement 6; UX-12's single rotating
/// slot): ONE soft body-copy line between the canvas and the action row.
/// The read-model's `contextualLineKey` already carries UX-12's priority —
/// the greeting in effect, else the day-stable ambient draw — so this view
/// only renders it (reactions outrank greetings in UX-12 and arrive with the
/// TASK-034/035 surfaces, which extend `HomeCopyKeys.contextualLineKey`).
struct HomeContextualLineView: View {

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    /// The Home read-model slice this line renders (TASK-033 R1/R2).
    let model: HomeReadModel

    var body: some View {
        Text(MomoCopyText.render(model.contextualLineKey))
            .font(MomoTypography.body)
            .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
            .multilineTextAlignment(.center)
            // Two lines, not one, at DEFAULT type: every landed line is a
            // single line there (§5.1's one-line sketch) and the cap keeps
            // the composition's height stable (REVIEW-TASK-033 NITPICK-2).
            // At ACCESSIBILITY type sizes the cap lifts — the composition
            // is in its scrolling branch (AC-1b), so a long line WRAPS
            // instead of truncating, remediating the audit's text-clipped
            // finding for real (TASK-039 R6).
            .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
            .accessibilityIdentifier("home.contextualLine")
    }
}
