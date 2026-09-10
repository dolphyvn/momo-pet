import MomoCore
import SwiftUI

/// The scenePhase → clock mapping, extracted from the view so §7.4 rule 1's
/// wire is unit-testable without rendering (`RigDisciplineTests` pins the
/// mapping's behavior and the view's wiring structurally; device-level
/// scenePhase observation verification routes to EPIC-007/EPIC-008 per
/// 04 §9.3's authority split).
enum RigMotionViewMapping {

    /// What presentation asks of the clock.
    enum ClockAction: Equatable {
        case resume
        case pause
    }

    /// `.active` runs the character; anything else pauses it — the ONE
    /// global gate (04 §7.4 rule 1, §9.5: presentation owns whether the
    /// character runs).
    static func clockAction(for phase: ScenePhase) -> ClockAction {
        phase == .active ? .resume : .pause
    }
}

/// The composed, token-colored rig (TASK-026 Requirement 3): renders the
/// §2.2 layer tree for a tier — driven by ONE CharacterClock through the
/// pure motion model — with the pause contract visible (a stopped clock
/// zeroes the timeline, freezing the character at the t = 0 unaged band
/// pose — the band expression base with every motion channel at rest;
/// the glyph tier's stillness IS the AOD posture; scenePhase maps onto
/// the clock's single call).
///
/// Application discipline (R1/R4, TASK-027): per frame this view computes
/// transform VALUES only via the pure model, then composes each slot
/// through the NORMATIVE `RigLayerTree.affineTransform` matrix inside a
/// SwiftUI `Canvas` — one `drawLayer` per slot isolates the CTM, so the
/// view and the CoreGraphics evidence harness render the SAME composition
/// (point-probe- and pixel-probe-verified in `R1CompositionTests`; the
/// TASK-026 modifier-chain divergence is resolved). Every path arrives from
/// the generated namespaces via `RigLayerTree`; every color resolves from a
/// §8.4 palette slot. Colors never depend on state (INV-5).
public struct MomoRigView: View {

    private let displayState: CharacterDisplayState
    private let tier: RigLODTier
    private let clock: CharacterClock
    private let model: RigMotionModel
    private let stageSide: CGFloat
    private let reactionMotion: @Sendable (Double) -> MomoReactionMotion

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockRunning = false

    /// - Parameters:
    ///   - displayState: the engine's read-model (the character renders
    ///     exactly the state it is given — §9.3).
    ///   - tier: the LOD tier for the render surface.
    ///   - clock: the ONE character clock (injected; owned by presentation).
    ///   - model: the motion model (idle seed + channels steerable).
    ///   - stageSide: the §2.1 stage size in points (tier bands in `RigLOD`).
    ///   - reactionMotion: the TASK-028 overlay, sampled at the frame's
    ///     clock time (a session passes `{ state.overlay(at: $0) }` over
    ///     its `MomoDirectorState`; the default is the no-op overlay, whose
    ///     pose is exactly the pre-TASK-028 pose).
    public init(
        displayState: CharacterDisplayState,
        tier: RigLODTier,
        clock: CharacterClock,
        model: RigMotionModel = RigMotionModel(),
        stageSide: CGFloat = 260,
        reactionMotion: @escaping @Sendable (Double) -> MomoReactionMotion = { _ in .identity }
    ) {
        self.displayState = displayState
        self.tier = tier
        self.clock = clock
        self.model = model
        self.stageSide = stageSide
        self.reactionMotion = reactionMotion
    }

    public var body: some View {
        Group {
            if tier == .glyph {
                // The glyph tier is a static snapshot — stillness IS the
                // AOD posture, so this branch never binds the clock.
                rigCanvas(pose: .rest)
            } else {
                TimelineView(.animation(paused: !clockRunning)) { context in
                    let time = clock.elapsed(at: context.date)
                    rigCanvas(
                        pose: model.pose(
                            at: time,
                            displayState: displayState,
                            reactionMotion: reactionMotion(time)))
                }
            }
        }
        .onChange(of: scenePhase) { _, phase in
            apply(phase)
        }
        .onAppear {
            apply(scenePhase)
        }
    }

    /// §7.4 rule 1: the mapping's ONE call onto the ONE clock.
    private func apply(_ phase: ScenePhase) {
        switch RigMotionViewMapping.clockAction(for: phase) {
        case .resume: clock.resume()
        case .pause: clock.pause()
        }
        clockRunning = clock.isRunning
    }

    // MARK: - Layer rendering

    /// The whole tier drawn in one Canvas: each slot inside its own
    /// `drawLayer` (the CTM concatenation accumulates across draws, so the
    /// per-slot layer is what keeps one slot's matrix from leaking into the
    /// next), transformed by the normative matrix.
    private func rigCanvas(pose: RigPose) -> some View {
        Canvas { context, _ in
            for slot in RigLayerTree.slots(for: tier) {
                context.drawLayer { layer in
                    layer.concatenate(RigLayerTree.affineTransform(of: slot, at: pose))
                    let opacity = slot.opacity(pose)
                    layer.fill(
                        slot.path,
                        with: .color(slot.token.resolve(colorScheme).opacity(opacity)))
                }
            }
        }
        .frame(width: RigCanvas.gridSide, height: RigCanvas.gridSide)
        .scaleEffect(stageSide / RigCanvas.gridSide)
        .frame(width: stageSide, height: stageSide)
    }
}

/// Canvas plumbing for the rig view: the §2.1 grid side in canvas points.
enum RigCanvas {

    /// The §2.1 normalized grid, in canvas points.
    static let gridSide: CGFloat = 1000
}
