//
//  MomoProps.swift
//  MomoCharacter
//
//  GENERATED FILE - DO NOT EDIT.
//  Regenerate with: python3 Tools/character-pipeline/generate.py
//  (run from the repository root; output must reproduce this file
//  byte-identically - pinned by MomoPipelineReproducibilityTests)
//
//  Source of truth: Tools/character-pipeline/parts.py
//  Normative geometry: docs/design/04-character-system.md §2.1-2.2 (1000×1000
//  normalized grid, y-down, ground y = 1000), ADR-001 (Direction C).
//  Colorless geometry (R4): tokens are applied at render time (§8.4).
//

import SwiftUI


/// The four interaction-scoped props (04 §2.2 props row, §8.5):
/// food, blanket, and the two sparkles. Sparkles are
/// moment-scoped by consumers; placement transforms belong to the
/// consuming surfaces.

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoProps {


    /// **food** - Props group.
    /// Channels: position/rotation/opacity (interaction-scoped).
    /// Food bowl: body + full mound + two kibble dots as one compound Path, resting on the room floor left of the pet.
    public static let food: Path = Path { p in
        p.move(to: CGPoint(x: 178.000, y: 946.000))
        p.addCurve(
            to: CGPoint(x: 240.000, y: 988.000),
            control1: CGPoint(x: 178.000, y: 969.196),
            control2: CGPoint(x: 205.758, y: 988.000))
        p.addCurve(
            to: CGPoint(x: 302.000, y: 946.000),
            control1: CGPoint(x: 274.242, y: 988.000),
            control2: CGPoint(x: 302.000, y: 969.196))
        p.closeSubpath()
        p.move(to: CGPoint(x: 278.000, y: 942.000))
        p.addCurve(
            to: CGPoint(x: 240.000, y: 927.000),
            control1: CGPoint(x: 278.000, y: 933.716),
            control2: CGPoint(x: 260.987, y: 927.000))
        p.addCurve(
            to: CGPoint(x: 202.000, y: 942.000),
            control1: CGPoint(x: 219.013, y: 927.000),
            control2: CGPoint(x: 202.000, y: 933.716))
        p.addCurve(
            to: CGPoint(x: 240.000, y: 957.000),
            control1: CGPoint(x: 202.000, y: 950.284),
            control2: CGPoint(x: 219.013, y: 957.000))
        p.addCurve(
            to: CGPoint(x: 278.000, y: 942.000),
            control1: CGPoint(x: 260.987, y: 957.000),
            control2: CGPoint(x: 278.000, y: 950.284))
        p.closeSubpath()
        p.move(to: CGPoint(x: 232.000, y: 926.000))
        p.addCurve(
            to: CGPoint(x: 224.000, y: 919.000),
            control1: CGPoint(x: 232.000, y: 922.134),
            control2: CGPoint(x: 228.418, y: 919.000))
        p.addCurve(
            to: CGPoint(x: 216.000, y: 926.000),
            control1: CGPoint(x: 219.582, y: 919.000),
            control2: CGPoint(x: 216.000, y: 922.134))
        p.addCurve(
            to: CGPoint(x: 224.000, y: 933.000),
            control1: CGPoint(x: 216.000, y: 929.866),
            control2: CGPoint(x: 219.582, y: 933.000))
        p.addCurve(
            to: CGPoint(x: 232.000, y: 926.000),
            control1: CGPoint(x: 228.418, y: 933.000),
            control2: CGPoint(x: 232.000, y: 929.866))
        p.closeSubpath()
        p.move(to: CGPoint(x: 264.000, y: 922.000))
        p.addCurve(
            to: CGPoint(x: 256.000, y: 915.000),
            control1: CGPoint(x: 264.000, y: 918.134),
            control2: CGPoint(x: 260.418, y: 915.000))
        p.addCurve(
            to: CGPoint(x: 248.000, y: 922.000),
            control1: CGPoint(x: 251.582, y: 915.000),
            control2: CGPoint(x: 248.000, y: 918.134))
        p.addCurve(
            to: CGPoint(x: 256.000, y: 929.000),
            control1: CGPoint(x: 248.000, y: 925.866),
            control2: CGPoint(x: 251.582, y: 929.000))
        p.addCurve(
            to: CGPoint(x: 264.000, y: 922.000),
            control1: CGPoint(x: 260.418, y: 929.000),
            control2: CGPoint(x: 264.000, y: 925.866))
        p.closeSubpath()
    }

    /// **blanket** - Props group.
    /// Channels: position/rotation/opacity (interaction-scoped).
    /// Folded blanket: body + fold-edge strip, right of the pet.
    public static let blanket: Path = Path { p in
        p.move(to: CGPoint(x: 724.666, y: 883.131))
        p.addLine(to: CGPoint(x: 886.050, y: 897.250))
        p.addCurve(
            to: CGPoint(x: 916.957, y: 934.084),
            control1: CGPoint(x: 904.756, y: 898.886),
            control2: CGPoint(x: 918.593, y: 915.378))
        p.addLine(to: CGPoint(x: 914.168, y: 965.962))
        p.addCurve(
            to: CGPoint(x: 877.334, y: 996.869),
            control1: CGPoint(x: 912.531, y: 984.668),
            control2: CGPoint(x: 896.040, y: 998.506))
        p.addLine(to: CGPoint(x: 715.950, y: 982.750))
        p.addCurve(
            to: CGPoint(x: 685.043, y: 945.916),
            control1: CGPoint(x: 697.244, y: 981.114),
            control2: CGPoint(x: 683.407, y: 964.622))
        p.addLine(to: CGPoint(x: 687.832, y: 914.038))
        p.addCurve(
            to: CGPoint(x: 724.666, y: 883.131),
            control1: CGPoint(x: 689.469, y: 895.332),
            control2: CGPoint(x: 705.960, y: 881.494))
        p.closeSubpath()
        p.move(to: CGPoint(x: 698.354, y: 902.978))
        p.addLine(to: CGPoint(x: 905.563, y: 921.106))
        p.addCurve(
            to: CGPoint(x: 915.562, y: 933.023),
            control1: CGPoint(x: 911.615, y: 921.636),
            control2: CGPoint(x: 916.092, y: 926.971))
        p.addLine(to: CGPoint(x: 915.562, y: 933.023))
        p.addCurve(
            to: CGPoint(x: 903.646, y: 943.022),
            control1: CGPoint(x: 915.033, y: 939.075),
            control2: CGPoint(x: 909.698, y: 943.552))
        p.addLine(to: CGPoint(x: 696.437, y: 924.894))
        p.addCurve(
            to: CGPoint(x: 686.438, y: 912.977),
            control1: CGPoint(x: 690.385, y: 924.364),
            control2: CGPoint(x: 685.908, y: 919.029))
        p.addLine(to: CGPoint(x: 686.438, y: 912.977))
        p.addCurve(
            to: CGPoint(x: 698.354, y: 902.978),
            control1: CGPoint(x: 686.967, y: 906.925),
            control2: CGPoint(x: 692.302, y: 902.448))
        p.closeSubpath()
    }

    /// **sparkleA** - Props group.
    /// Channels: opacity (moment-scoped - celebration).
    /// Celebration sparkle A (larger of the pair).
    public static let sparkleA: Path = Path { p in
        p.move(to: CGPoint(x: 230.000, y: 155.000))
        p.addQuadCurve(
            to: CGPoint(x: 325.000, y: 250.000),
            control: CGPoint(x: 243.300, y: 236.700))
        p.addQuadCurve(
            to: CGPoint(x: 230.000, y: 345.000),
            control: CGPoint(x: 243.300, y: 263.300))
        p.addQuadCurve(
            to: CGPoint(x: 135.000, y: 250.000),
            control: CGPoint(x: 216.700, y: 263.300))
        p.addQuadCurve(
            to: CGPoint(x: 230.000, y: 155.000),
            control: CGPoint(x: 216.700, y: 236.700))
        p.closeSubpath()
    }

    /// **sparkleB** - Props group.
    /// Channels: opacity (moment-scoped - celebration).
    /// Celebration sparkle B.
    public static let sparkleB: Path = Path { p in
        p.move(to: CGPoint(x: 712.000, y: 258.000))
        p.addQuadCurve(
            to: CGPoint(x: 774.000, y: 320.000),
            control: CGPoint(x: 720.680, y: 311.320))
        p.addQuadCurve(
            to: CGPoint(x: 712.000, y: 382.000),
            control: CGPoint(x: 720.680, y: 328.680))
        p.addQuadCurve(
            to: CGPoint(x: 650.000, y: 320.000),
            control: CGPoint(x: 703.320, y: 328.680))
        p.addQuadCurve(
            to: CGPoint(x: 712.000, y: 258.000),
            control: CGPoint(x: 703.320, y: 311.320))
        p.closeSubpath()
    }
}
