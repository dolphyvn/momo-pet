//
//  MomoRoom.swift
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


/// The static room scene (04 §8.5: charming, non-interactive),
/// grouped per the §8.4 bundled-data names: the `Room.base`
/// constants implement `momo.room.base`, the `Room.pom`
/// constants implement `momo.room.pom` (the pom as static
/// decor).

/// 1000×1000 normalized design space (04 §2.1). y-down; ground y = 1000.

extension MomoRoom {


    /// **floor** - Room.base group.
    /// Channels: static room decor.
    /// Room floor band; top corners rounded, full-bleed to the grid edges.
    public static let floor: Path = Path { p in
        p.move(to: CGPoint(x: 48.000, y: 880.000))
        p.addLine(to: CGPoint(x: 952.000, y: 880.000))
        p.addCurve(
            to: CGPoint(x: 1000.000, y: 928.000),
            control1: CGPoint(x: 978.510, y: 880.000),
            control2: CGPoint(x: 1000.000, y: 901.490))
        p.addLine(to: CGPoint(x: 1000.000, y: 952.000))
        p.addCurve(
            to: CGPoint(x: 952.000, y: 1000.000),
            control1: CGPoint(x: 1000.000, y: 978.510),
            control2: CGPoint(x: 978.510, y: 1000.000))
        p.addLine(to: CGPoint(x: 48.000, y: 1000.000))
        p.addCurve(
            to: CGPoint(x: 0.000, y: 952.000),
            control1: CGPoint(x: 21.490, y: 1000.000),
            control2: CGPoint(x: 0.000, y: 978.510))
        p.addLine(to: CGPoint(x: 0.000, y: 928.000))
        p.addCurve(
            to: CGPoint(x: 48.000, y: 880.000),
            control1: CGPoint(x: 0.000, y: 901.490),
            control2: CGPoint(x: 21.490, y: 880.000))
        p.closeSubpath()
    }

    /// **rug** - Room.base group.
    /// Channels: static room decor.
    /// Round rug under the pet's ground contact.
    public static let rug: Path = Path { p in
        p.move(to: CGPoint(x: 830.000, y: 942.000))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 1000.000),
            control1: CGPoint(x: 830.000, y: 974.033),
            control2: CGPoint(x: 682.254, y: 1000.000))
        p.addCurve(
            to: CGPoint(x: 170.000, y: 942.000),
            control1: CGPoint(x: 317.746, y: 1000.000),
            control2: CGPoint(x: 170.000, y: 974.033))
        p.addCurve(
            to: CGPoint(x: 500.000, y: 884.000),
            control1: CGPoint(x: 170.000, y: 909.967),
            control2: CGPoint(x: 317.746, y: 884.000))
        p.addCurve(
            to: CGPoint(x: 830.000, y: 942.000),
            control1: CGPoint(x: 682.254, y: 884.000),
            control2: CGPoint(x: 830.000, y: 909.967))
        p.closeSubpath()
    }

    /// **window** - Room.base group.
    /// Channels: static room decor.
    /// Round-cornered window: outer frame, counter-wound opening (a hole under the nonzero fill rule), and the cross bars drawn over the opening - one compound Path.
    public static let window: Path = Path { p in
        p.move(to: CGPoint(x: 150.000, y: 110.000))
        p.addLine(to: CGPoint(x: 350.000, y: 110.000))
        p.addCurve(
            to: CGPoint(x: 380.000, y: 140.000),
            control1: CGPoint(x: 366.569, y: 110.000),
            control2: CGPoint(x: 380.000, y: 123.431))
        p.addLine(to: CGPoint(x: 380.000, y: 340.000))
        p.addCurve(
            to: CGPoint(x: 350.000, y: 370.000),
            control1: CGPoint(x: 380.000, y: 356.569),
            control2: CGPoint(x: 366.569, y: 370.000))
        p.addLine(to: CGPoint(x: 150.000, y: 370.000))
        p.addCurve(
            to: CGPoint(x: 120.000, y: 340.000),
            control1: CGPoint(x: 133.431, y: 370.000),
            control2: CGPoint(x: 120.000, y: 356.569))
        p.addLine(to: CGPoint(x: 120.000, y: 140.000))
        p.addCurve(
            to: CGPoint(x: 150.000, y: 110.000),
            control1: CGPoint(x: 120.000, y: 123.431),
            control2: CGPoint(x: 133.431, y: 110.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 166.000, y: 136.000))
        p.addCurve(
            to: CGPoint(x: 146.000, y: 156.000),
            control1: CGPoint(x: 154.954, y: 136.000),
            control2: CGPoint(x: 146.000, y: 144.954))
        p.addLine(to: CGPoint(x: 146.000, y: 324.000))
        p.addCurve(
            to: CGPoint(x: 166.000, y: 344.000),
            control1: CGPoint(x: 146.000, y: 335.046),
            control2: CGPoint(x: 154.954, y: 344.000))
        p.addLine(to: CGPoint(x: 334.000, y: 344.000))
        p.addCurve(
            to: CGPoint(x: 354.000, y: 324.000),
            control1: CGPoint(x: 345.046, y: 344.000),
            control2: CGPoint(x: 354.000, y: 335.046))
        p.addLine(to: CGPoint(x: 354.000, y: 156.000))
        p.addCurve(
            to: CGPoint(x: 334.000, y: 136.000),
            control1: CGPoint(x: 354.000, y: 144.954),
            control2: CGPoint(x: 345.046, y: 136.000))
        p.addLine(to: CGPoint(x: 166.000, y: 136.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 240.000, y: 122.000))
        p.addLine(to: CGPoint(x: 260.000, y: 122.000))
        p.addCurve(
            to: CGPoint(x: 264.000, y: 126.000),
            control1: CGPoint(x: 262.209, y: 122.000),
            control2: CGPoint(x: 264.000, y: 123.791))
        p.addLine(to: CGPoint(x: 264.000, y: 354.000))
        p.addCurve(
            to: CGPoint(x: 260.000, y: 358.000),
            control1: CGPoint(x: 264.000, y: 356.209),
            control2: CGPoint(x: 262.209, y: 358.000))
        p.addLine(to: CGPoint(x: 240.000, y: 358.000))
        p.addCurve(
            to: CGPoint(x: 236.000, y: 354.000),
            control1: CGPoint(x: 237.791, y: 358.000),
            control2: CGPoint(x: 236.000, y: 356.209))
        p.addLine(to: CGPoint(x: 236.000, y: 126.000))
        p.addCurve(
            to: CGPoint(x: 240.000, y: 122.000),
            control1: CGPoint(x: 236.000, y: 123.791),
            control2: CGPoint(x: 237.791, y: 122.000))
        p.closeSubpath()
        p.move(to: CGPoint(x: 126.000, y: 226.000))
        p.addLine(to: CGPoint(x: 374.000, y: 226.000))
        p.addCurve(
            to: CGPoint(x: 378.000, y: 230.000),
            control1: CGPoint(x: 376.209, y: 226.000),
            control2: CGPoint(x: 378.000, y: 227.791))
        p.addLine(to: CGPoint(x: 378.000, y: 250.000))
        p.addCurve(
            to: CGPoint(x: 374.000, y: 254.000),
            control1: CGPoint(x: 378.000, y: 252.209),
            control2: CGPoint(x: 376.209, y: 254.000))
        p.addLine(to: CGPoint(x: 126.000, y: 254.000))
        p.addCurve(
            to: CGPoint(x: 122.000, y: 250.000),
            control1: CGPoint(x: 123.791, y: 254.000),
            control2: CGPoint(x: 122.000, y: 252.209))
        p.addLine(to: CGPoint(x: 122.000, y: 230.000))
        p.addCurve(
            to: CGPoint(x: 126.000, y: 226.000),
            control1: CGPoint(x: 122.000, y: 227.791),
            control2: CGPoint(x: 123.791, y: 226.000))
        p.closeSubpath()
    }

    /// **pomString** - Room.pom group.
    /// Channels: static room decor.
    /// Hanging cord of the pom-pom decor, from the ceiling line.
    public static let pomString: Path = Path { p in
        p.move(to: CGPoint(x: 820.000, y: 0.000))
        p.addLine(to: CGPoint(x: 820.000, y: 0.000))
        p.addCurve(
            to: CGPoint(x: 824.000, y: 4.000),
            control1: CGPoint(x: 822.209, y: 0.000),
            control2: CGPoint(x: 824.000, y: 1.791))
        p.addLine(to: CGPoint(x: 824.000, y: 114.000))
        p.addCurve(
            to: CGPoint(x: 820.000, y: 118.000),
            control1: CGPoint(x: 824.000, y: 116.209),
            control2: CGPoint(x: 822.209, y: 118.000))
        p.addLine(to: CGPoint(x: 820.000, y: 118.000))
        p.addCurve(
            to: CGPoint(x: 816.000, y: 114.000),
            control1: CGPoint(x: 817.791, y: 118.000),
            control2: CGPoint(x: 816.000, y: 116.209))
        p.addLine(to: CGPoint(x: 816.000, y: 4.000))
        p.addCurve(
            to: CGPoint(x: 820.000, y: 0.000),
            control1: CGPoint(x: 816.000, y: 1.791),
            control2: CGPoint(x: 817.791, y: 0.000))
        p.closeSubpath()
    }

    /// **pomPuff** - Room.pom group.
    /// Channels: static room decor.
    /// The pom-pom itself: a cluster of overlapping circles filling as one puff (nonzero rule).
    public static let pomPuff: Path = Path { p in
        p.move(to: CGPoint(x: 856.000, y: 148.000))
        p.addCurve(
            to: CGPoint(x: 820.000, y: 184.000),
            control1: CGPoint(x: 856.000, y: 167.882),
            control2: CGPoint(x: 839.882, y: 184.000))
        p.addCurve(
            to: CGPoint(x: 784.000, y: 148.000),
            control1: CGPoint(x: 800.118, y: 184.000),
            control2: CGPoint(x: 784.000, y: 167.882))
        p.addCurve(
            to: CGPoint(x: 820.000, y: 112.000),
            control1: CGPoint(x: 784.000, y: 128.118),
            control2: CGPoint(x: 800.118, y: 112.000))
        p.addCurve(
            to: CGPoint(x: 856.000, y: 148.000),
            control1: CGPoint(x: 839.882, y: 112.000),
            control2: CGPoint(x: 856.000, y: 128.118))
        p.closeSubpath()
        p.move(to: CGPoint(x: 810.000, y: 126.000))
        p.addCurve(
            to: CGPoint(x: 786.000, y: 150.000),
            control1: CGPoint(x: 810.000, y: 139.255),
            control2: CGPoint(x: 799.255, y: 150.000))
        p.addCurve(
            to: CGPoint(x: 762.000, y: 126.000),
            control1: CGPoint(x: 772.745, y: 150.000),
            control2: CGPoint(x: 762.000, y: 139.255))
        p.addCurve(
            to: CGPoint(x: 786.000, y: 102.000),
            control1: CGPoint(x: 762.000, y: 112.745),
            control2: CGPoint(x: 772.745, y: 102.000))
        p.addCurve(
            to: CGPoint(x: 810.000, y: 126.000),
            control1: CGPoint(x: 799.255, y: 102.000),
            control2: CGPoint(x: 810.000, y: 112.745))
        p.closeSubpath()
        p.move(to: CGPoint(x: 878.000, y: 126.000))
        p.addCurve(
            to: CGPoint(x: 854.000, y: 150.000),
            control1: CGPoint(x: 878.000, y: 139.255),
            control2: CGPoint(x: 867.255, y: 150.000))
        p.addCurve(
            to: CGPoint(x: 830.000, y: 126.000),
            control1: CGPoint(x: 840.745, y: 150.000),
            control2: CGPoint(x: 830.000, y: 139.255))
        p.addCurve(
            to: CGPoint(x: 854.000, y: 102.000),
            control1: CGPoint(x: 830.000, y: 112.745),
            control2: CGPoint(x: 840.745, y: 102.000))
        p.addCurve(
            to: CGPoint(x: 878.000, y: 126.000),
            control1: CGPoint(x: 867.255, y: 102.000),
            control2: CGPoint(x: 878.000, y: 112.745))
        p.closeSubpath()
        p.move(to: CGPoint(x: 814.000, y: 170.000))
        p.addCurve(
            to: CGPoint(x: 790.000, y: 194.000),
            control1: CGPoint(x: 814.000, y: 183.255),
            control2: CGPoint(x: 803.255, y: 194.000))
        p.addCurve(
            to: CGPoint(x: 766.000, y: 170.000),
            control1: CGPoint(x: 776.745, y: 194.000),
            control2: CGPoint(x: 766.000, y: 183.255))
        p.addCurve(
            to: CGPoint(x: 790.000, y: 146.000),
            control1: CGPoint(x: 766.000, y: 156.745),
            control2: CGPoint(x: 776.745, y: 146.000))
        p.addCurve(
            to: CGPoint(x: 814.000, y: 170.000),
            control1: CGPoint(x: 803.255, y: 146.000),
            control2: CGPoint(x: 814.000, y: 156.745))
        p.closeSubpath()
        p.move(to: CGPoint(x: 874.000, y: 170.000))
        p.addCurve(
            to: CGPoint(x: 850.000, y: 194.000),
            control1: CGPoint(x: 874.000, y: 183.255),
            control2: CGPoint(x: 863.255, y: 194.000))
        p.addCurve(
            to: CGPoint(x: 826.000, y: 170.000),
            control1: CGPoint(x: 836.745, y: 194.000),
            control2: CGPoint(x: 826.000, y: 183.255))
        p.addCurve(
            to: CGPoint(x: 850.000, y: 146.000),
            control1: CGPoint(x: 826.000, y: 156.745),
            control2: CGPoint(x: 836.745, y: 146.000))
        p.addCurve(
            to: CGPoint(x: 874.000, y: 170.000),
            control1: CGPoint(x: 863.255, y: 146.000),
            control2: CGPoint(x: 874.000, y: 156.745))
        p.closeSubpath()
    }
}
