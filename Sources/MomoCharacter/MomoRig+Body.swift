//
//  MomoRig+Body.swift
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


/// The Direction-C rig's Body layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **body** - Body group.
    /// Channels: scaleY/X (breath, squash), rotation (lean/rock), position (hop, settle).
    /// Pear body (ADR-001). Bottom-center anchor on the spine; ground contact is carried by the hind feet, not the body outline.
    public static let body: Path = Path { p in
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

    /// **bellyPatch** - Body group.
    /// Channels: static; rides the Body transform.
    /// Belly patch - the lower-front lighter zone (IV-5: never a state channel).
    public static let bellyPatch: Path = Path { p in
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

    /// **hindFootLeft** - Body group.
    /// Channels: static; rides the Body transform.
    /// Hind foot, visible at rest (ADR-001 Direction-C delta). Bottom edge lands exactly on the ground line y = 1000.
    public static let hindFootLeft: Path = Path { p in
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

    /// **hindFootRight** - Body group.
    /// Channels: static; rides the Body transform.
    /// Hind foot, visible at rest (ADR-001 Direction-C delta). Bottom edge lands exactly on the ground line y = 1000.
    public static let hindFootRight: Path = Path { p in
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
}
