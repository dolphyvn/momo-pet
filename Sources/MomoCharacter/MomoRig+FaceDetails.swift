//
//  MomoRig+FaceDetails.swift
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


/// The Direction-C rig's FaceDetails layer group(s) (04 §2.2).
///
/// The full rig's part accounting: 04 §2.2 counts 17 parts
/// (mouth counted once as a 3-pose slot); ADR-001's Direction-C
/// delta adds the two hind feet. The mouth slot ships its three
/// pre-built poses as separate constants (R1: crossfaded, never
/// re-tessellated).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRig {


    /// **mouthNeutral** - FaceDetails group.
    /// Channels: opacity/swap (pre-built pose shapes - never re-tessellated, R1).
    /// Neutral mouth: a subtle small crescent (the resting face reads calm; section 1.3 keeps the mouth for eating/refusal).
    public static let mouthNeutral: Path = Path { p in
        p.move(to: CGPoint(x: 490.000, y: 465.000))
        p.addQuadCurve(
            to: CGPoint(x: 510.000, y: 465.000),
            control: CGPoint(x: 500.000, y: 474.000))
        p.addQuadCurve(
            to: CGPoint(x: 490.000, y: 465.000),
            control: CGPoint(x: 500.000, y: 470.000))
        p.closeSubpath()
    }

    /// **mouthEat** - FaceDetails group.
    /// Channels: opacity/swap (pre-built pose shapes - never re-tessellated, R1).
    /// Eating mouth: a small open oval (nibbling pose).
    public static let mouthEat: Path = Path { p in
        p.move(to: CGPoint(x: 513.000, y: 471.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 480.000),
            control1: CGPoint(x: 513.000, y: 475.971),
            control2: CGPoint(x: 507.180, y: 480.000))
        p.addCurve(
            to: CGPoint(x: 487.000, y: 471.000),
            control1: CGPoint(x: 492.820, y: 480.000),
            control2: CGPoint(x: 487.000, y: 475.971))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 462.000),
            control1: CGPoint(x: 487.000, y: 466.029),
            control2: CGPoint(x: 492.820, y: 462.000))
        p.addCurve(
            to: CGPoint(x: 513.000, y: 471.000),
            control1: CGPoint(x: 507.180, y: 462.000),
            control2: CGPoint(x: 513.000, y: 466.029))
        p.closeSubpath()
    }

    /// **mouthRefuse** - FaceDetails group.
    /// Channels: opacity/swap (pre-built pose shapes - never re-tessellated, R1).
    /// Refusing mouth: a gentle downturned crescent (the warm refusal register - never a sad face, INV-6).
    public static let mouthRefuse: Path = Path { p in
        p.move(to: CGPoint(x: 490.000, y: 469.000))
        p.addQuadCurve(
            to: CGPoint(x: 510.000, y: 469.000),
            control: CGPoint(x: 500.000, y: 461.000))
        p.addQuadCurve(
            to: CGPoint(x: 490.000, y: 469.000),
            control: CGPoint(x: 500.000, y: 465.000))
        p.closeSubpath()
    }

    /// **cheekLeft** - FaceDetails group.
    /// Channels: opacity (celebration-only - section 2.2 face-details row).
    /// Left cheek accent, celebration moments only (INV-5: never a state channel).
    public static let cheekLeft: Path = Path { p in
        p.move(to: CGPoint(x: 430.000, y: 450.000))
        p.addCurve(
            to: CGPoint(x: 398.000, y: 472.000),
            control1: CGPoint(x: 430.000, y: 462.150),
            control2: CGPoint(x: 415.673, y: 472.000))
        p.addCurve(
            to: CGPoint(x: 366.000, y: 450.000),
            control1: CGPoint(x: 380.327, y: 472.000),
            control2: CGPoint(x: 366.000, y: 462.150))
        p.addCurve(
            to: CGPoint(x: 398.000, y: 428.000),
            control1: CGPoint(x: 366.000, y: 437.850),
            control2: CGPoint(x: 380.327, y: 428.000))
        p.addCurve(
            to: CGPoint(x: 430.000, y: 450.000),
            control1: CGPoint(x: 415.673, y: 428.000),
            control2: CGPoint(x: 430.000, y: 437.850))
        p.closeSubpath()
    }

    /// **cheekRight** - FaceDetails group.
    /// Channels: opacity (celebration-only - section 2.2 face-details row).
    /// Right cheek accent, celebration moments only (INV-5).
    public static let cheekRight: Path = Path { p in
        p.move(to: CGPoint(x: 634.000, y: 450.000))
        p.addCurve(
            to: CGPoint(x: 602.000, y: 472.000),
            control1: CGPoint(x: 634.000, y: 462.150),
            control2: CGPoint(x: 619.673, y: 472.000))
        p.addCurve(
            to: CGPoint(x: 570.000, y: 450.000),
            control1: CGPoint(x: 584.327, y: 472.000),
            control2: CGPoint(x: 570.000, y: 462.150))
        p.addCurve(
            to: CGPoint(x: 602.000, y: 428.000),
            control1: CGPoint(x: 570.000, y: 437.850),
            control2: CGPoint(x: 584.327, y: 428.000))
        p.addCurve(
            to: CGPoint(x: 634.000, y: 450.000),
            control1: CGPoint(x: 619.673, y: 428.000),
            control2: CGPoint(x: 634.000, y: 437.850))
        p.closeSubpath()
    }
}
