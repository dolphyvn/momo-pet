import SwiftUI
import MomoCharacter

/// S2 — Name (TASK-032 R3; UX §3 S2; INV-1): the question line, the
/// pre-filled text field with a clear affordance, and Continue — enabled
/// only while the trimmed input holds at least one non-whitespace
/// character. The disabled button IS the signal (calm: no error copy, no
/// shake); the UX-given hint tells VoiceOver users why while disabled.
/// The typed name lives in the flow's view state only (R7).
struct OnboardingNameView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var name: String
    let onContinue: () -> Void

    /// INV-1's face in the UI: empty or whitespace-only is not a name.
    private var canContinue: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Spacer(minLength: 0)
            VStack(spacing: MomoSpacing.medium) {
                Text("What should your new friend be called?")
                    .font(MomoTypography.heading)
                    .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                    .multilineTextAlignment(.center)
                nameField
                Button("Continue", action: onContinue)
                    .buttonStyle(OnboardingPrimaryButtonStyle())
                    .disabled(!canContinue)
                    .accessibilityHint(
                        canContinue ? "" : "A name with at least one letter is needed"
                    )
            }
            .padding(.horizontal, MomoSpacing.large)
            .padding(.bottom, MomoSpacing.extraLarge)
        }
    }

    private var nameField: some View {
        HStack(spacing: 0) {
            TextField("Momo", text: $name)
                .font(MomoTypography.body)
                .foregroundStyle(MomoUIColors.textPrimary.resolve(colorScheme))
                .accessibilityLabel("Pet name")
            if !name.isEmpty {
                Button {
                    name = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
                        .frame(
                            width: OnboardingLayout.minimumTapTarget,
                            height: OnboardingLayout.minimumTapTarget
                        )
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear name")
            }
        }
        .padding(.leading, MomoSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: MomoRadius.medium)
                .fill(MomoUIColors.surface.resolve(colorScheme))
        )
        .overlay(
            RoundedRectangle(cornerRadius: MomoRadius.medium)
                .strokeBorder(MomoUIColors.border.resolve(colorScheme))
        )
    }
}
