import SwiftUI
import MomoCharacter

/// S3 — Enter, the payoff beat (TASK-032 R4/R5; UX §3 S3): the canvas at
/// full focus, the meet lines with the carried name interpolated, and
/// "Begin" — whose tap IS the completion event. The tap routes through the
/// app model's `completeOnboarding(name:)`, which mints the final pet
/// identity and applies the completion trigger; the plan's `.persist`
/// step is the atomic completion write (FR-13 AC-1). VoiceOver: the
/// canvas is one element, both lines read as text, the button is labeled
/// by its title.
struct OnboardingEnterView: View {
    @Environment(\.colorScheme) private var colorScheme
    let name: String
    let onBegin: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            OnboardingCanvasView(stageSide: OnboardingLayout.enterStageSide)
            Spacer(minLength: 0)
            VStack(spacing: MomoSpacing.medium) {
                Text("Meet your new friend.")
                    .font(MomoTypography.heading)
                    .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                    .multilineTextAlignment(.center)
                Text("This is \(name).")
                    .font(MomoTypography.body)
                    .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
                    .multilineTextAlignment(.center)
                Button("Begin", action: onBegin)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .padding(.horizontal, MomoSpacing.large)
            .padding(.bottom, MomoSpacing.extraLarge)
        }
    }
}
