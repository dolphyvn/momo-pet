import SwiftUI
import MomoCharacter

// MARK: - Onboarding — the three calm, forward-only steps (TASK-032; UX §3)

/// The onboarding flow's steps (UX §3 S1/S2/S3) — strictly forward-only:
/// no skip, no back, no progress dots (UX-7).
enum OnboardingStep {
    case meet
    case name
    case enter
}

/// The flow's layout constants: the ≥44 pt touch-target floor (R9), the
/// step stage sizes (inside `RigLOD.fullStagePoints`'s 220–280 band), and
/// the authored step crossfade (R10 — substituted under Reduce Motion).
enum OnboardingLayout {
    /// R9's minimum touch-target edge.
    static let minimumTapTarget: CGFloat = 44
    /// S1 Meet's stage size — the canvas among equals.
    static let meetStageSide: CGFloat = 240
    /// S3 Enter's stage size — the payoff beat's full focus.
    static let enterStageSide: CGFloat = 280
    /// The authored step crossfade duration; R10 replaces it with an
    /// instant swap under Reduce Motion.
    static let stepCrossfadeDuration: Double = 0.25
}

/// The three-step, forward-only first-run flow (TASK-032 R1–R4; UX §3):
/// Meet → Name → Enter. Gate input is `MomoAppModel.requiresOnboarding`
/// (MomoApp's routing); the flow's typed name lives in view state only —
/// kill before Enter ⇒ restart from S1 (R7). Zero dialogs, zero network,
/// zero accounts (R8). Step changes crossfade (authored, presentation-
/// level) and swap instantly under Reduce Motion (R10).
struct OnboardingFlow: View {
    @Environment(MomoAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: OnboardingStep = .meet
    @State private var petName = "Momo"

    var body: some View {
        ZStack {
            MomoUIColors.background.resolve(colorScheme)
                .ignoresSafeArea()
            stepContent
        }
        .animation(
            reduceMotion
                ? nil
                : .easeInOut(duration: OnboardingLayout.stepCrossfadeDuration),
            value: step
        )
    }

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case .meet:
            OnboardingMeetView(onContinue: { step = .name })
                .transition(.opacity)
        case .name:
            OnboardingNameView(name: $petName, onContinue: { step = .enter })
                .transition(.opacity)
        case .enter:
            OnboardingEnterView(
                name: petName,
                onBegin: { appModel.completeOnboarding(name: petName) }
            )
            .transition(.opacity)
        }
    }
}

/// The flow's one primary CTA style: calm, token-pure, ≥44 pt tall (R9).
/// The palette's primary text color inverted as the fill keeps contrast
/// far above the accessibility floor; dimmed while disabled — the disabled
/// state IS the S2 validation signal (UX §3: no error copy, no shake).
struct OnboardingPrimaryButtonStyle: ButtonStyle {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(MomoTypography.body.weight(.semibold))
            .foregroundStyle(MomoUIColors.background.resolve(colorScheme))
            .frame(maxWidth: .infinity)
            .frame(minHeight: OnboardingLayout.minimumTapTarget)
            .background(
                RoundedRectangle(cornerRadius: MomoRadius.medium)
                    .fill(MomoUIColors.textPrimary.resolve(colorScheme))
            )
            .opacity(isEnabled ? 1 : 0.3)
            .contentShape(Rectangle())
    }
}
