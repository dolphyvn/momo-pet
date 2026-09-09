import CoreGraphics
import MomoCore

/// The rig's pure motion model (TASK-026 Requirement 2; 04 §2.2 + R1/R2):
/// clock time + display state IN, transform values OUT. No SwiftUI, no
/// `Path`, no per-frame geometry — the generated constants stay the single
/// source of shape, and this model only says where/how they sit (R1). One
/// creature (R2): one pose describes the whole rig.
///
/// TASK-026 drives exactly one reference channel end-to-end — the Content
/// breath (§7.1) as bottom-anchored body scaleY — as the executable proof of
/// the aliveness plumbing. Mood-band rates and every other channel's
/// choreography are TASK-027+, which is why `displayState` is carried in the
/// signature today (and deliberately unused until then).
public struct RigMotionModel: Sendable {

    /// Which channels currently contribute to the pose. The default `.all`
    /// is "everything the model knows how to drive"; TASK-027 choreography
    /// narrows/steers this, and TASK-029's Reduce Motion mapping lands as
    /// static poses by disabling motion channels.
    public var enabledChannels: RigChannel

    public init(enabledChannels: RigChannel = .all) {
        self.enabledChannels = enabledChannels
    }

    /// The pose at clock time `time` (seconds — `CharacterClock.elapsed()`).
    public func pose(
        at time: Double,
        displayState: CharacterDisplayState
    ) -> RigPose {
        var pose = RigPose.rest

        // The reference channel: Content breath (§7.1 Content row via the
        // canonical driver), bottom-anchored body scaleY, pure sine.
        if enabledChannels.contains(.bodyScale) {
            pose.body.scaleY = CGFloat(MomoCurves.breathScaleY(at: time))
        }

        // displayState is intentionally inert in TASK-026: band-specific
        // breath rates, expression poses and ear/tail choreography are
        // TASK-027's scope. The parameter exists now so the clock → model →
        // view plumbing is final and TASK-027 adds drivers, not signatures.

        return pose
    }

    /// §2.4's pupil clamp: gaze offsets never exceed 30 % of the eye radius.
    /// Magnitude is capped to the bound; direction is preserved exactly.
    /// The MODEL applies this (a channel-value law), so any pose the model
    /// emits — today's and TASK-027's — satisfies the bound.
    public static func clampedPupilOffset(
        _ offset: CGPoint, eyeRadius: CGFloat
    ) -> CGPoint {
        let bound = eyeRadius * 0.30
        let magnitude = (offset.x * offset.x + offset.y * offset.y).squareRoot()
        guard magnitude > bound, magnitude > 0 else { return offset }
        let scale = bound / magnitude
        return CGPoint(x: offset.x * scale, y: offset.y * scale)
    }
}
