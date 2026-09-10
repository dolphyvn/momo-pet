import SwiftUI
import MomoCharacter

/// S1 — Meet (TASK-032 R2; UX §3 S1): the pet canvas, the move-in line,
/// and the flow's first button. The button is a FLOW button, never a pet
/// touch (UX-6): it routes no interaction intent, completes nothing in the
/// engine — it only advances the flow. VoiceOver: the canvas is one
/// element ("A small creature looks up at you", see the shared canvas),
/// the line reads as text, the button is labeled by its title.
struct OnboardingMeetView: View {
    @Environment(\.colorScheme) private var colorScheme
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            OnboardingCanvasView(stageSide: OnboardingLayout.meetStageSide)
            Spacer(minLength: 0)
            VStack(spacing: MomoSpacing.medium) {
                Text("This little one just moved in.")
                    .font(MomoTypography.heading)
                    .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                    .multilineTextAlignment(.center)
                Button("Say hello", action: onContinue)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
            }
            .padding(.horizontal, MomoSpacing.large)
            .padding(.bottom, MomoSpacing.extraLarge)
        }
    }
}
