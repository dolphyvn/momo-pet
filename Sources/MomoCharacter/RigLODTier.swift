import CoreGraphics

/// The three LOD tiers of 04 §2.1's stage table (TASK-026 Requirement 4).
/// One creature, three fidelities: the full rig on iPhone; the glance rig on
/// Watch foreground; the glyph on AOD/complications — always the same
/// rabbit, never more detail than the surface affords (§7.4 rule 5).
public enum RigLODTier: String, CaseIterable, Sendable {
    /// The full 21-constant rig + the interaction-scoped props row.
    case full
    /// The 11-constant glance reduction (merged paws, no pupil split).
    case glance
    /// The 3-constant glyph — a static snapshot; stillness IS the AOD
    /// posture (§9.3), so this tier never binds a clock.
    case glyph
}

/// The render surfaces the rig appears on (04 §2.1 surface → stage rows).
public enum RigSurface: Hashable, Sendable, CaseIterable {
    case iphoneHome
    case watchForeground
    case watchAlwaysOn
    case complication
}

/// Pure, deterministic tier selection + the §2.1 stage bands + the
/// tier→generated-constant-set mapping. Nothing here touches a view.
public enum RigLOD {

    /// §2.1 / §7.4 rule 5: iPhone renders the full rig; Watch foreground the
    /// glance rig — and NO Watch surface ever renders the full rig (pinned
    /// in `RigLODTierTests.watchNeverFull`); AOD/complications the glyph.
    public static func tier(for surface: RigSurface) -> RigLODTier {
        switch surface {
        case .iphoneHome: return .full
        case .watchForeground: return .glance
        case .watchAlwaysOn, .complication: return .glyph
        }
    }

    // MARK: - §2.1 stage bands (raw-literal pinned)

    /// The creature's stage size on each tier, in points (§2.1: iPhone
    /// 220–280, Watch glance 60–80, glyph 24–32).
    public static let fullStagePoints: ClosedRange<CGFloat> = 220.0...280.0
    public static let glanceStagePoints: ClosedRange<CGFloat> = 60.0...80.0
    public static let glyphStagePoints: ClosedRange<CGFloat> = 24.0...32.0

    // MARK: - Tier → generated-constant sets

    /// The generated `Path` constants each tier composes, in §2.2 group
    /// order. The sets are disjoint — one creature per tier, no leakage
    /// (pinned) — and every name resolves in the compile-pinned TASK-025
    /// catalog (`GeneratedRigCatalog`).
    public static func partNames(for tier: RigLODTier) -> [String] {
        switch tier {
        case .full:
            return [
                "body", "bellyPatch", "hindFootLeft", "hindFootRight",
                "head", "earLeft", "earRight", "tail",
                "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
                "eyeRightBase", "eyeRightPupil", "eyeRightLid",
                "mouthNeutral", "mouthEat", "mouthRefuse",
                "cheekLeft", "cheekRight", "pawLeft", "pawRight",
            ]
        case .glance:
            return [
                "lodBody", "lodBellyPatch", "lodHead", "lodEarLeft",
                "lodEarRight", "lodTail", "lodHindFootLeft", "lodHindFootRight",
                "lodEyeLeft", "lodEyeRight", "lodPawPair",
            ]
        case .glyph:
            return ["glyphSilhouette", "glyphEyeLeft", "glyphEyeRight"]
        }
    }
}
