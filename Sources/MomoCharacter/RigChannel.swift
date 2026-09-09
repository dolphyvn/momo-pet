import Foundation

/// The rig's animatable channels, one per §2.2 layer/channel-table entry
/// (TASK-026 Requirement 2). A channel is a GATE, not a value: the motion
/// model computes transform values and applies each through its channel, so
/// TASK-027 choreography and TASK-029's Reduce Motion static poses can
/// enable/disable any subset — including "everything", which is what the
/// CharacterClock's single pause achieves.
public struct RigChannel: OptionSet, Hashable, Sendable {

    public let rawValue: UInt64

    public init(rawValue: UInt64) {
        self.rawValue = rawValue
    }

    // MARK: - Body group (§2.2)

    /// Bottom-anchored body scaleY — the breath channel (§7.1).
    public static let bodyScale = RigChannel(rawValue: 1 << 0)
    public static let bodyRotation = RigChannel(rawValue: 1 << 1)
    public static let bodyPosition = RigChannel(rawValue: 1 << 2)

    // MARK: - Head group

    public static let headRotation = RigChannel(rawValue: 1 << 3)
    public static let headPosition = RigChannel(rawValue: 1 << 4)
    public static let headScaleY = RigChannel(rawValue: 1 << 5)

    // MARK: - Ears (per-ear; roots at the head's top)

    public static let earLeftRotation = RigChannel(rawValue: 1 << 6)
    public static let earLeftScaleY = RigChannel(rawValue: 1 << 7)
    public static let earRightRotation = RigChannel(rawValue: 1 << 8)
    public static let earRightScaleY = RigChannel(rawValue: 1 << 9)

    // MARK: - Tail

    public static let tailRotation = RigChannel(rawValue: 1 << 10)
    public static let tailScaleY = RigChannel(rawValue: 1 << 11)

    // MARK: - Eyes (lid scaleY + §2.4-clamped pupil offset + lower-lid pose)

    public static let eyeLeftLidScaleY = RigChannel(rawValue: 1 << 12)
    public static let eyeLeftPupilOffset = RigChannel(rawValue: 1 << 13)
    public static let eyeLeftLowerLid = RigChannel(rawValue: 1 << 14)
    public static let eyeRightLidScaleY = RigChannel(rawValue: 1 << 15)
    public static let eyeRightPupilOffset = RigChannel(rawValue: 1 << 16)
    public static let eyeRightLowerLid = RigChannel(rawValue: 1 << 17)

    // MARK: - Face details

    /// Crossfade/selection across the three pre-built mouth poses.
    public static let mouthPose = RigChannel(rawValue: 1 << 18)
    public static let cheekOpacity = RigChannel(rawValue: 1 << 19)

    // MARK: - Front paws (per-paw; wrist anchors)

    public static let pawLeftPosition = RigChannel(rawValue: 1 << 20)
    public static let pawLeftRotation = RigChannel(rawValue: 1 << 21)
    public static let pawRightPosition = RigChannel(rawValue: 1 << 22)
    public static let pawRightRotation = RigChannel(rawValue: 1 << 23)

    // MARK: - Interaction-scoped props row

    public static let propFood = RigChannel(rawValue: 1 << 24)
    public static let propBlanket = RigChannel(rawValue: 1 << 25)
    public static let propSparkleA = RigChannel(rawValue: 1 << 26)
    public static let propSparkleB = RigChannel(rawValue: 1 << 27)

    /// Every channel — the default enabled set.
    public static let all: RigChannel = [
        .bodyScale, .bodyRotation, .bodyPosition,
        .headRotation, .headPosition, .headScaleY,
        .earLeftRotation, .earLeftScaleY, .earRightRotation, .earRightScaleY,
        .tailRotation, .tailScaleY,
        .eyeLeftLidScaleY, .eyeLeftPupilOffset, .eyeLeftLowerLid,
        .eyeRightLidScaleY, .eyeRightPupilOffset, .eyeRightLowerLid,
        .mouthPose, .cheekOpacity,
        .pawLeftPosition, .pawLeftRotation, .pawRightPosition, .pawRightRotation,
        .propFood, .propBlanket, .propSparkleA, .propSparkleB,
    ]

    /// The channels in §2.2 table order, named — the name-for-name pin
    /// surface (`RigMotionModelTests` asserts this list against the doc's
    /// groups verbatim, so a channel added without a doc row — or the
    /// reverse — fails the build).
    public static let canonicalOrder: [(name: String, channel: RigChannel)] = [
        ("bodyScale", .bodyScale), ("bodyRotation", .bodyRotation),
        ("bodyPosition", .bodyPosition),
        ("headRotation", .headRotation), ("headPosition", .headPosition),
        ("headScaleY", .headScaleY),
        ("earLeftRotation", .earLeftRotation), ("earLeftScaleY", .earLeftScaleY),
        ("earRightRotation", .earRightRotation), ("earRightScaleY", .earRightScaleY),
        ("tailRotation", .tailRotation), ("tailScaleY", .tailScaleY),
        ("eyeLeftLidScaleY", .eyeLeftLidScaleY),
        ("eyeLeftPupilOffset", .eyeLeftPupilOffset),
        ("eyeLeftLowerLid", .eyeLeftLowerLid),
        ("eyeRightLidScaleY", .eyeRightLidScaleY),
        ("eyeRightPupilOffset", .eyeRightPupilOffset),
        ("eyeRightLowerLid", .eyeRightLowerLid),
        ("mouthPose", .mouthPose), ("cheekOpacity", .cheekOpacity),
        ("pawLeftPosition", .pawLeftPosition), ("pawLeftRotation", .pawLeftRotation),
        ("pawRightPosition", .pawRightPosition), ("pawRightRotation", .pawRightRotation),
        ("propFood", .propFood), ("propBlanket", .propBlanket),
        ("propSparkleA", .propSparkleA), ("propSparkleB", .propSparkleB),
    ]
}
