import SwiftUI
import MomoCharacter
import MomoKit

/// The composed Home tab (TASK-033 Requirements 6 and 8; FR-2; UX §5.1):
/// status row → pet canvas → contextual line → action row → quest card, in
/// UX §5.1's S4 order, everything bound through the app model's
/// `homeReadModel` (D-R5: no engine type appears here).
///
/// **The canvas budget (FR-2 AC-1a/AC-1b).** At default type sizes the
/// canvas region is the composition's flexible absorber: it is bounded
/// below by an absolute 305-pt floor — just above 45% of the iPhone SE's
/// 667-pt screen, so AC-1a holds even at the floor — scaled up with the
/// content height on larger devices, and it flexes upward with any slack.
/// At accessibility type sizes (AC-1b) the whole composition scrolls
/// instead: the canvas steps down to a fixed 260 pt (inside
/// `RigLOD.fullStagePoints`'s 220–280 band — "the pet flexes with a
/// preserved minimum", UX §5.1) and every control stays reachable and
/// functional inside the scroll.
///
/// **VoiceOver (UX §10).** The canvas is ONE element labeled with the pet's
/// name, carrying TASK-034's "Pat"/"Cuddle" custom actions; the
/// rows expose their own labels (`HomeStatusRowView`'s formula,
/// `HomeQuestCardView`'s per-wish lines).
struct HomeView: View {

    @Environment(MomoAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                ScrollView {
                    sections(canvasHeight: HomeLayout.accessibilityCanvasHeight)
                        .padding(.horizontal, MomoSpacing.medium)
                        .padding(.bottom, MomoSpacing.medium)
                }
            } else {
                GeometryReader { proxy in
                    sections(
                        canvasHeight: nil,
                        canvasMinHeight: max(
                            HomeLayout.canvasMinimumHeight,
                            proxy.size.height * HomeLayout.canvasMinimumFraction
                        )
                    )
                    .padding(.horizontal, MomoSpacing.medium)
                }
            }
        }
        .background(MomoUIColors.background.resolve(colorScheme))
    }

    /// The S4 composition. In the default branch `canvasHeight` is nil and
    /// the canvas flexes (bounded below by `canvasMinHeight`); in the
    /// scrolling branch it is fixed.
    @ViewBuilder
    private func sections(canvasHeight: CGFloat?, canvasMinHeight: CGFloat? = nil) -> some View {
        let model = appModel.homeReadModel
        VStack(spacing: MomoSpacing.small) {
            HomeStatusRowView(model: model)
            canvas(model: model, height: canvasHeight, minHeight: canvasMinHeight)
            HomeContextualLineView(model: model)
            HomeActionRowView(appModel: appModel, model: model)
            HomeQuestCardView(model: model)
        }
        .padding(.top, MomoSpacing.small)
    }

    /// The pet canvas: the rig at the full tier over the presentation-owned
    /// character clock, centered in its REGION. The region — not the rig —
    /// is the accessibility element and carries the layout identity
    /// (`home.canvas`): FR-2 AC-1's 45% budget is the region's height, and
    /// an element built OVER the rig would report the rig's fixed
    /// `stageSide` frame instead of the flexed region it sits in. The clear
    /// rect gives the element the region's geometry; the rig is inert
    /// canvas drawing overlaid into it.
    @ViewBuilder
    private func canvas(model: HomeReadModel, height: CGFloat?, minHeight: CGFloat?) -> some View {
        Group {
            if let minHeight {
                Color.clear
                    .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity)
            } else if let height {
                Color.clear
                    .frame(maxWidth: .infinity)
                    .frame(height: height)
            } else {
                Color.clear
                    .frame(maxWidth: .infinity)
            }
        }
        .overlay { canvasBody }
        .overlay { HomeCanvasTouchSurface(stageSide: HomeLayout.standardStageSide) }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(model.petName)
        .accessibilityIdentifier("home.canvas")
        .accessibilityActions { canvasCustomActions }
    }

    /// TASK-034 R6: the canvas's VoiceOver custom actions — the touch
    /// vocabulary's gesture ANALOGS, assembled from MomoKit's ONE pinned
    /// `CanvasCustomAction` name list (the doc's "Pat"/"Cuddle" labels, 03
    /// §5.1) and routed through the app model as the zone-less intents (no
    /// rotor geometry; feed/play/care stay the labeled action row, 04 §10's
    /// no-duplication resolution). SwiftUI surfaces them as the element's
    /// named actions (the rotor's "actions" row).
    @ViewBuilder
    private var canvasCustomActions: some View {
        ForEach(CanvasCustomAction.allCases, id: \.self) { action in
            Button(action.rawValue) {
                appModel.interact(action.intent)
            }
        }
    }

    private var canvasBody: some View {
        MomoRigView(
            displayState: appModel.characterDisplayState,
            tier: .full,
            clock: appModel.canvasClock,
            stageSide: HomeLayout.standardStageSide,
            reactionMotion: appModel.reactionMotion()
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// The Home composition's layout constants (the `OnboardingLayout`
/// convention): the composed stage size inside `RigLOD.fullStagePoints`'s
/// 220–280 band, the scrolling branch's fixed canvas height, and the
/// default branch's canvas minimum — pinned so FR-2 AC-1a's 45%-of-screen
/// floor holds on the SE class even when the flex leaves the canvas at its
/// minimum (45% of the SE's 667-pt screen is ~300 pt, while 45% of its
/// safe-area content height is only ~269 pt — the floor must key off the
/// SCREEN, not the content region).
private enum HomeLayout {
    /// The composed canvas height in the scrolling (accessibility-sizes)
    /// branch — AC-1b's preserved minimum.
    static let accessibilityCanvasHeight: CGFloat = 260
    /// The rig stage size (both branches).
    static let standardStageSide: CGFloat = 260
    /// The default branch's absolute canvas floor (TASK-033 R6): just above
    /// AC-1a's 45% of the iPhone SE's 667-pt screen, so the floor alone
    /// satisfies the criterion on the smallest supported device.
    static let canvasMinimumHeight: CGFloat = 305
    /// The canvas minimum as a fraction of the content height (default-type
    /// branch) — scales the floor proportionally up from the SE.
    static let canvasMinimumFraction: CGFloat = 0.46
}
