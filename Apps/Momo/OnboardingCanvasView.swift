import SwiftUI
import MomoCharacter

/// The shared pet canvas host (TASK-032 R12; EPIC-006's public view API):
/// `MomoRigView` at the full tier, fed by the app model's read-model and
/// presentation-owned clock, with the no-op overlay default — the
/// alive-at-rest blink/breath IS the whole "small greeting animation".
/// No director wiring, no report plumbing, no choreography (TASK-033's);
/// the character modules are consumed, never edited.
///
/// D-R5 by inference: the view binds through the environment's app model,
/// so no engine type name appears here — the rig's parameters infer.
/// ONE accessibility element with the UX §3 VoiceOver label (R9).
struct OnboardingCanvasView: View {
    @Environment(MomoAppModel.self) private var appModel

    /// The stage size in points — set by each step view, kept within the
    /// full tier's band (`RigLOD.fullStagePoints`, 220–280).
    let stageSide: CGFloat

    var body: some View {
        MomoRigView(
            displayState: appModel.characterDisplayState,
            tier: .full,
            clock: appModel.canvasClock,
            stageSide: stageSide
        )
        .accessibilityElement()
        .accessibilityLabel("A small creature looks up at you")
    }
}
