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
/// renders the rest pose; scenePhase maps onto the clock's single call).
///
/// Application discipline (R1/R4): per frame this view computes transform
/// VALUES only and applies them through `scaleEffect`/`rotationEffect`/
/// `offset` with explicit grid anchors (documented anchor semantics); every
/// path arrives from the generated namespaces via `RigLayerTree`; every
/// color resolves from a §8.4 palette slot. Colors never depend on state.
public struct MomoRigView: View {

    private let displayState: CharacterDisplayState
    private let tier: RigLODTier
    private let clock: CharacterClock
    private let model: RigMotionModel
    private let stageSide: CGFloat

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.colorScheme) private var colorScheme
    @State private var clockRunning = false

    /// - Parameters:
    ///   - displayState: the engine's read-model (rest interpretation in
    ///     TASK-026; band mapping is TASK-027).
    ///   - tier: the LOD tier for the render surface.
    ///   - clock: the ONE character clock (injected; owned by presentation).
    ///   - model: the motion model (channels steerable by later tasks).
    ///   - stageSide: the §2.1 stage size in points (tier bands in `RigLOD`).
    public init(
        displayState: CharacterDisplayState,
        tier: RigLODTier,
        clock: CharacterClock,
        model: RigMotionModel = RigMotionModel(),
        stageSide: CGFloat = 260
    ) {
        self.displayState = displayState
        self.tier = tier
        self.clock = clock
        self.model = model
        self.stageSide = stageSide
    }

    public var body: some View {
        Group {
            if tier == .glyph {
                // The glyph tier is a static snapshot — stillness IS the
                // AOD posture, so this branch never binds the clock.
                rigCanvas(pose: .rest)
            } else {
                TimelineView(.animation(paused: !clockRunning)) { context in
                    rigCanvas(
                        pose: model.pose(
                            at: clock.elapsed(at: context.date),
                            displayState: displayState))
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

    private func rigCanvas(pose: RigPose) -> some View {
        ZStack {
            ForEach(Array(RigLayerTree.slots(for: tier).enumerated()), id: \.offset) {
                layer($0.element, at: pose)
            }
        }
        .frame(width: RigCanvas.gridSide, height: RigCanvas.gridSide)
        .scaleEffect(stageSide / RigCanvas.gridSide)
        .frame(width: stageSide, height: stageSide)
    }

    /// One slot: filled with its token, transformed by its stages. SwiftUI
    /// modifiers apply to the content in listing order, so each stage
    /// contributes offset → rotation → scale about the stage's anchor, and
    /// the listed order ([body, head, ear]) runs ANCESTOR-first. That order
    /// differs from the normative `RigLayerTree.affineTransform`
    /// composition (child-local first, scale first): the two agree exactly
    /// while the only driven channel is the body's anchored pure scale
    /// (the TASK-026 breath — pin- and probe-verified); TASK-027 must
    /// reconcile the orders before driving head/ear/tail channels
    /// (REVIEW-TASK-026 MINOR-1).
    private func layer(_ slot: RigLayerSlot, at pose: RigPose) -> some View {
        let stages = RigCanvas.paddedStages(slot.stages, at: pose)
        return slot.path
            .fill(slot.token.resolve(colorScheme).opacity(slot.opacity(pose)))
            .frame(width: RigCanvas.gridSide, height: RigCanvas.gridSide)
            .offset(x: stages.0.transform.translation.x, y: stages.0.transform.translation.y)
            .rotationEffect(
                .degrees(stages.0.transform.rotationDegrees),
                anchor: RigCanvas.unitPoint(stages.0.anchor))
            .scaleEffect(
                x: stages.0.transform.scaleX, y: stages.0.transform.scaleY,
                anchor: RigCanvas.unitPoint(stages.0.anchor))
            .offset(x: stages.1.transform.translation.x, y: stages.1.transform.translation.y)
            .rotationEffect(
                .degrees(stages.1.transform.rotationDegrees),
                anchor: RigCanvas.unitPoint(stages.1.anchor))
            .scaleEffect(
                x: stages.1.transform.scaleX, y: stages.1.transform.scaleY,
                anchor: RigCanvas.unitPoint(stages.1.anchor))
            .offset(x: stages.2.transform.translation.x, y: stages.2.transform.translation.y)
            .rotationEffect(
                .degrees(stages.2.transform.rotationDegrees),
                anchor: RigCanvas.unitPoint(stages.2.anchor))
            .scaleEffect(
                x: stages.2.transform.scaleX, y: stages.2.transform.scaleY,
                anchor: RigCanvas.unitPoint(stages.2.anchor))
    }
}

/// Canvas plumbing for the rig view: the §2.1 grid side, grid-anchored
/// `UnitPoint`s, and the stage padding that keeps every slot's modifier
/// chain structurally identical (SwiftUI needs a static shape; identity
/// stages are exact no-ops).
enum RigCanvas {

    /// The §2.1 normalized grid, in canvas points.
    static let gridSide: CGFloat = 1000

    /// One resolved stage application for the modifier chain.
    struct StageApplication {
        let anchor: CGPoint
        let transform: RigGridTransform
    }

    /// No slot's hierarchy exceeds body → head → part (three stages).
    /// Padding fills the trailing positions with identity stages — exact
    /// no-ops about any anchor, so where they sit in the chain is
    /// behaviorally irrelevant; the padding exists only to keep every
    /// slot's modifier chain structurally identical.
    static func paddedStages(
        _ stages: [RigStage], at pose: RigPose
    ) -> (StageApplication, StageApplication, StageApplication) {
        let resolved = (0..<3).map { index -> StageApplication in
            guard index < stages.count else {
                return StageApplication(anchor: .zero, transform: .identity)
            }
            let stage = stages[index]
            return StageApplication(anchor: stage.anchor, transform: stage.value(pose))
        }
        return (resolved[0], resolved[1], resolved[2])
    }

    /// A grid anchor as a `UnitPoint` of the 1000-point canvas.
    static func unitPoint(_ anchor: CGPoint) -> UnitPoint {
        UnitPoint(x: anchor.x / gridSide, y: anchor.y / gridSide)
    }
}
