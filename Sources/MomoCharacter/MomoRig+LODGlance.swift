//
//  MomoRig+LODGlance.swift
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


/// The Direction-C rig's LODGlance layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **lodBody** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance body - same pear as the full rig (shared builders).
    public static let lodBody: Path = Path { p in
        p.move(to: CGPoint(x: 500.000, y: 940.000))
        p.addCurve(
            to: CGPoint(x: 764.000, y: 800.000),
            control1: CGPoint(x: 640.000, y: 940.000),
            control2: CGPoint(x: 752.000, y: 882.000))
        p.addCurve(
            to: CGPoint(x: 712.000, y: 548.000),
            control1: CGPoint(x: 776.000, y: 718.000),
            control2: CGPoint(x: 760.000, y: 610.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 428.000),
            control1: CGPoint(x: 668.000, y: 490.000),
            control2: CGPoint(x: 610.000, y: 448.000))
        p.addCurve(
            to: CGPoint(x: 288.000, y: 548.000),
            control1: CGPoint(x: 390.000, y: 448.000),
            control2: CGPoint(x: 332.000, y: 490.000))
        p.addCurve(
            to: CGPoint(x: 236.000, y: 800.000),
            control1: CGPoint(x: 240.000, y: 610.000),
            control2: CGPoint(x: 224.000, y: 718.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 940.000),
            control1: CGPoint(x: 248.000, y: 882.000),
            control2: CGPoint(x: 360.000, y: 940.000))
        p.closeSubpath()
    }

    /// **lodBellyPatch** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance belly patch.
    public static let lodBellyPatch: Path = Path { p in
        p.move(to: CGPoint(x: 686.000, y: 764.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 914.000),
            control1: CGPoint(x: 686.000, y: 846.843),
            control2: CGPoint(x: 602.725, y: 914.000))
        p.addCurve(
            to: CGPoint(x: 314.000, y: 764.000),
            control1: CGPoint(x: 397.275, y: 914.000),
            control2: CGPoint(x: 314.000, y: 846.843))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 614.000),
            control1: CGPoint(x: 314.000, y: 681.157),
            control2: CGPoint(x: 397.275, y: 614.000))
        p.addCurve(
            to: CGPoint(x: 686.000, y: 764.000),
            control1: CGPoint(x: 602.725, y: 614.000),
            control2: CGPoint(x: 686.000, y: 681.157))
        p.closeSubpath()
    }

    /// **lodHead** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance head.
    public static let lodHead: Path = Path { p in
        p.move(to: CGPoint(x: 500.000, y: 590.000))
        p.addCurve(
            to: CGPoint(x: 694.000, y: 412.000),
            control1: CGPoint(x: 628.000, y: 588.000),
            control2: CGPoint(x: 694.000, y: 520.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 224.000),
            control1: CGPoint(x: 694.000, y: 308.000),
            control2: CGPoint(x: 626.000, y: 226.000))
        p.addCurve(
            to: CGPoint(x: 306.000, y: 412.000),
            control1: CGPoint(x: 374.000, y: 226.000),
            control2: CGPoint(x: 306.000, y: 308.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 590.000),
            control1: CGPoint(x: 306.000, y: 520.000),
            control2: CGPoint(x: 372.000, y: 588.000))
        p.closeSubpath()
    }

    /// **lodEarLeft** - LODGlance group.
    /// Channels: rotation per ear retained (expression channel).
    /// LOD-glance left ear - ears stay separate at Watch stage size (60-80 pt keeps the thickness rule legible, ADR-001).
    public static let lodEarLeft: Path = Path { p in
        p.move(to: CGPoint(x: 481.143, y: 149.326))
        p.addCurve(
            to: CGPoint(x: 443.126, y: 267.727),
            control1: CGPoint(x: 491.693, y: 209.154),
            control2: CGPoint(x: 474.672, y: 262.164))
        p.addCurve(
            to: CGPoint(x: 366.906, y: 169.469),
            control1: CGPoint(x: 411.580, y: 273.289),
            control2: CGPoint(x: 377.455, y: 229.298))
        p.addCurve(
            to: CGPoint(x: 404.923, y: 51.069),
            control1: CGPoint(x: 356.356, y: 109.641),
            control2: CGPoint(x: 373.377, y: 56.631))
        p.addCurve(
            to: CGPoint(x: 481.143, y: 149.326),
            control1: CGPoint(x: 436.469, y: 45.506),
            control2: CGPoint(x: 470.594, y: 89.498))
        p.closeSubpath()
    }

    /// **lodEarRight** - LODGlance group.
    /// Channels: rotation per ear retained (expression channel).
    /// LOD-glance right ear.
    public static let lodEarRight: Path = Path { p in
        p.move(to: CGPoint(x: 633.094, y: 169.469))
        p.addCurve(
            to: CGPoint(x: 556.874, y: 267.727),
            control1: CGPoint(x: 622.545, y: 229.298),
            control2: CGPoint(x: 588.420, y: 273.289))
        p.addCurve(
            to: CGPoint(x: 518.857, y: 149.326),
            control1: CGPoint(x: 525.328, y: 262.164),
            control2: CGPoint(x: 508.307, y: 209.154))
        p.addCurve(
            to: CGPoint(x: 595.077, y: 51.069),
            control1: CGPoint(x: 529.406, y: 89.498),
            control2: CGPoint(x: 563.531, y: 45.506))
        p.addCurve(
            to: CGPoint(x: 633.094, y: 169.469),
            control1: CGPoint(x: 626.623, y: 56.631),
            control2: CGPoint(x: 643.644, y: 109.641))
        p.closeSubpath()
    }

    /// **lodTail** - LODGlance group.
    /// Channels: rotation (metronome) retained.
    /// LOD-glance puff tail.
    public static let lodTail: Path = Path { p in
        p.move(to: CGPoint(x: 830.000, y: 796.000))
        p.addCurve(
            to: CGPoint(x: 778.000, y: 852.000),
            control1: CGPoint(x: 830.000, y: 826.928),
            control2: CGPoint(x: 806.719, y: 852.000))
        p.addCurve(
            to: CGPoint(x: 726.000, y: 796.000),
            control1: CGPoint(x: 749.281, y: 852.000),
            control2: CGPoint(x: 726.000, y: 826.928))
        p.addCurve(
            to: CGPoint(x: 778.000, y: 740.000),
            control1: CGPoint(x: 726.000, y: 765.072),
            control2: CGPoint(x: 749.281, y: 740.000))
        p.addCurve(
            to: CGPoint(x: 830.000, y: 796.000),
            control1: CGPoint(x: 806.719, y: 740.000),
            control2: CGPoint(x: 830.000, y: 765.072))
        p.closeSubpath()
    }

    /// **lodHindFootLeft** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance hind foot (ADR-001 rest posture).
    public static let lodHindFootLeft: Path = Path { p in
        p.move(to: CGPoint(x: 438.000, y: 962.000))
        p.addCurve(
            to: CGPoint(x: 370.000, y: 1000.000),
            control1: CGPoint(x: 438.000, y: 982.987),
            control2: CGPoint(x: 407.555, y: 1000.000))
        p.addCurve(
            to: CGPoint(x: 302.000, y: 962.000),
            control1: CGPoint(x: 332.445, y: 1000.000),
            control2: CGPoint(x: 302.000, y: 982.987))
        p.addCurve(
            to: CGPoint(x: 370.000, y: 924.000),
            control1: CGPoint(x: 302.000, y: 941.013),
            control2: CGPoint(x: 332.445, y: 924.000))
        p.addCurve(
            to: CGPoint(x: 438.000, y: 962.000),
            control1: CGPoint(x: 407.555, y: 924.000),
            control2: CGPoint(x: 438.000, y: 941.013))
        p.closeSubpath()
    }

    /// **lodHindFootRight** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance hind foot (ADR-001 rest posture).
    public static let lodHindFootRight: Path = Path { p in
        p.move(to: CGPoint(x: 698.000, y: 962.000))
        p.addCurve(
            to: CGPoint(x: 630.000, y: 1000.000),
            control1: CGPoint(x: 698.000, y: 982.987),
            control2: CGPoint(x: 667.555, y: 1000.000))
        p.addCurve(
            to: CGPoint(x: 562.000, y: 962.000),
            control1: CGPoint(x: 592.445, y: 1000.000),
            control2: CGPoint(x: 562.000, y: 982.987))
        p.addCurve(
            to: CGPoint(x: 630.000, y: 924.000),
            control1: CGPoint(x: 562.000, y: 941.013),
            control2: CGPoint(x: 592.445, y: 924.000))
        p.addCurve(
            to: CGPoint(x: 698.000, y: 962.000),
            control1: CGPoint(x: 667.555, y: 924.000),
            control2: CGPoint(x: 698.000, y: 941.013))
        p.closeSubpath()
    }

    /// **lodEyeLeft** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance left eye - a single shape: the pupil-tracking split is removed below the iPhone tier (section 8.5).
    public static let lodEyeLeft: Path = Path { p in
        p.move(to: CGPoint(x: 480.000, y: 390.000))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 446.000),
            control1: CGPoint(x: 480.000, y: 420.928),
            control2: CGPoint(x: 457.614, y: 446.000))
        p.addCurve(
            to: CGPoint(x: 380.000, y: 390.000),
            control1: CGPoint(x: 402.386, y: 446.000),
            control2: CGPoint(x: 380.000, y: 420.928))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 334.000),
            control1: CGPoint(x: 380.000, y: 359.072),
            control2: CGPoint(x: 402.386, y: 334.000))
        p.addCurve(
            to: CGPoint(x: 480.000, y: 390.000),
            control1: CGPoint(x: 457.614, y: 334.000),
            control2: CGPoint(x: 480.000, y: 359.072))
        p.closeSubpath()
    }

    /// **lodEyeRight** - LODGlance group.
    /// Channels: static LOD layer.
    /// LOD-glance right eye - single shape, no pupil split.
    public static let lodEyeRight: Path = Path { p in
        p.move(to: CGPoint(x: 620.000, y: 390.000))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 446.000),
            control1: CGPoint(x: 620.000, y: 420.928),
            control2: CGPoint(x: 597.614, y: 446.000))
        p.addCurve(
            to: CGPoint(x: 520.000, y: 390.000),
            control1: CGPoint(x: 542.386, y: 446.000),
            control2: CGPoint(x: 520.000, y: 420.928))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 334.000),
            control1: CGPoint(x: 520.000, y: 359.072),
            control2: CGPoint(x: 542.386, y: 334.000))
        p.addCurve(
            to: CGPoint(x: 620.000, y: 390.000),
            control1: CGPoint(x: 597.614, y: 334.000),
            control2: CGPoint(x: 620.000, y: 359.072))
        p.closeSubpath()
    }

    /// **lodPawPair** - LODGlance group.
    /// Channels: static LOD layer.
    /// Simplified paws: one merged, non-animated pair shape (section 8.5 'simplified paws') - two subpaths in a single Path.
    public static let lodPawPair: Path = Path { p in
        p.move(to: CGPoint(x: 491.000, y: 894.000))
        p.addCurve(
            to: CGPoint(x: 447.000, y: 922.000),
            control1: CGPoint(x: 491.000, y: 909.464),
            control2: CGPoint(x: 471.301, y: 922.000))
        p.addCurve(
            to: CGPoint(x: 403.000, y: 894.000),
            control1: CGPoint(x: 422.699, y: 922.000),
            control2: CGPoint(x: 403.000, y: 909.464))
        p.addCurve(
            to: CGPoint(x: 447.000, y: 866.000),
            control1: CGPoint(x: 403.000, y: 878.536),
            control2: CGPoint(x: 422.699, y: 866.000))
        p.addCurve(
            to: CGPoint(x: 491.000, y: 894.000),
            control1: CGPoint(x: 471.301, y: 866.000),
            control2: CGPoint(x: 491.000, y: 878.536))
        p.closeSubpath()
        p.move(to: CGPoint(x: 597.000, y: 894.000))
        p.addCurve(
            to: CGPoint(x: 553.000, y: 922.000),
            control1: CGPoint(x: 597.000, y: 909.464),
            control2: CGPoint(x: 577.301, y: 922.000))
        p.addCurve(
            to: CGPoint(x: 509.000, y: 894.000),
            control1: CGPoint(x: 528.699, y: 922.000),
            control2: CGPoint(x: 509.000, y: 909.464))
        p.addCurve(
            to: CGPoint(x: 553.000, y: 866.000),
            control1: CGPoint(x: 509.000, y: 878.536),
            control2: CGPoint(x: 528.699, y: 866.000))
        p.addCurve(
            to: CGPoint(x: 597.000, y: 894.000),
            control1: CGPoint(x: 577.301, y: 866.000),
            control2: CGPoint(x: 597.000, y: 878.536))
        p.closeSubpath()
    }
}
