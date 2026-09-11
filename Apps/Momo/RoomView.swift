import SwiftUI
import MomoCharacter
import MomoKit

/// The Room tab (TASK-037; FR-3; UX §1.2 S5): one charming static room
/// scene — Momo has a *home*, not just a screen (D13/K4). The scene draws
/// TASK-025's five generated `MomoRoom` paths (floor, rug, window, and the
/// hanging pom string + puff — the room's static companion decor per 04
/// §8.5), the colorless geometry token-colored at render per the
/// MomoCharacter idiom (R4: no color literal ever leaves the palette
/// files), scaled aspect-preserving to the space the layout gives it
/// (UX §10 row 435: the scene scales).
///
/// **Static means static (FR-3 AC-1/AC-2).** Zero interactivity — no
/// actions, no gestures, no hit-testing surfaces — and no customization
/// UI. There is no state to encode and nothing to animate (a static scene
/// has no loop to pause), so no Reduce Motion substitution is owed; both
/// facts are pinned structurally by `RigDisciplineTests`' room guard.
///
/// **Momo is not rendered in the room (disclosed adjudication).** FR-3
/// says the pet MAY be visible; Home owns the live rig, and duplicating it
/// here would add composition and motion surfaces for zero product value —
/// the pom decor is the room's companion presence.
///
/// **VoiceOver (UX §10 row 435).** The scene is ONE element announced as
/// "{name}’s cozy room" (the catalog template, name-interpolated); the
/// caption renders beneath it as its own text element, and both scale with
/// Dynamic Type (the scene with its region, the caption with the type
/// size). The content surface carries the `room` identifier with
/// `.contain` semantics — one queryable region with zero interactive
/// descendants.
struct RoomView: View {

    @Environment(MomoAppModel.self) private var appModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(spacing: MomoSpacing.large) {
            RoomScene(petName: appModel.homeReadModel.petName)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Text(MomoCopyText.render(HomeCopyKeys.roomCaptionKey))
                .font(MomoTypography.caption)
                .foregroundStyle(MomoUIColors.textSecondary.resolve(colorScheme))
                .accessibilityIdentifier("room.caption")
        }
        .padding(.horizontal, MomoSpacing.large)
        .padding(.bottom, MomoSpacing.medium)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(MomoUIColors.background.resolve(colorScheme))
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("room")
    }
}

/// The room's scene canvas: the five generated paths drawn into ONE static
/// composition, each token-colored, scaled aspect-preserving and centered
/// in whatever region the layout leaves. Like the Home canvas, the REGION
/// (not the drawing) is the accessibility element — flattened to a single
/// image element carrying the composed label.
private struct RoomScene: View {

    @Environment(\.colorScheme) private var colorScheme

    /// The pet's name for the composed VoiceOver label.
    let petName: String

    var body: some View {
        Canvas { context, size in
            let scale = min(size.width, size.height) / RoomSceneLayout.gridSide
            context.translateBy(
                x: (size.width - RoomSceneLayout.gridSide * scale) / 2,
                y: (size.height - RoomSceneLayout.gridSide * scale) / 2)
            context.scaleBy(x: scale, y: scale)
            for layer in RoomSceneLayout.layers(colorScheme: colorScheme) {
                context.fill(layer.path, with: .color(layer.color))
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(
            String(
                format: MomoCopyText.render(HomeCopyKeys.roomSceneLabelTemplateKey),
                petName))
        .accessibilityIdentifier("room.scene")
    }
}

/// The scene's render table: the five `MomoRoom` constants in paint order
/// (floor, rug, window, then the hanging pom decor), each bound to its
/// token slot. Geometry is consumed READ-ONLY from the generated namespace
/// — never constructed here — and the window's counter-wound opening stays
/// a hole under the nonzero fill rule, showing the room's background.
private enum RoomSceneLayout {

    /// The 1000×1000 normalized design space (04 §2.1), in canvas points —
    /// the `RigCanvas.gridSide` convention.
    static let gridSide: CGFloat = 1000

    /// One drawable layer: geometry plus its resolved token color.
    /// (No access modifier: the enclosing enum's `private` caps it — and
    /// the function returning it — to file scope.)
    struct Layer {
        let path: Path
        let color: Color
    }

    /// Back-to-front paint order. The bindings coordinate body and chrome
    /// (the palette was assigned as one pass): the floor reads as a soft
    /// card surface on the app ground, the rug wears the blanket token,
    /// the window frame carries the decorative accent tint, and the pom
    /// hangs from a fur-shade cord with a warm cream puff.
    static func layers(colorScheme: ColorScheme) -> [Layer] {
        [
            Layer(path: MomoRoom.floor, color: MomoUIColors.surface.resolve(colorScheme)),
            Layer(path: MomoRoom.rug, color: MomoCharacterPalette.blanket.resolve(colorScheme)),
            Layer(path: MomoRoom.window, color: MomoUIColors.accent.resolve(colorScheme)),
            Layer(path: MomoRoom.pomString, color: MomoCharacterPalette.furShade.resolve(colorScheme)),
            Layer(path: MomoRoom.pomPuff, color: MomoCharacterPalette.furBase.resolve(colorScheme)),
        ]
    }
}
