// Evidence renderer: compiles together with the GENERATED rig sources and
// draws the actual committed `Path` constants into PNG canvases via
// CoreGraphics (macOS build host only — same host role as `swift test`).
//
// This is the visual-evidence step for TASK-025: it proves the committed
// Swift constants themselves render the Direction-C rabbit (the SVG
// evidence canvases are projections of the parametric source; these PNGs
// are projections of the shipped bytes).
//
// Build & run (from the repository root):
//   swiftc Tools/character-pipeline/render_evidence.swift \
//       Sources/MomoCharacter/MomoRig*.swift \
//       Sources/MomoCharacter/MomoRoom.swift Sources/MomoCharacter/MomoProps.swift \
//       -o /tmp/momo-render-evidence
//   /tmp/momo-render-evidence --out docs/evidence/character
//
// The placeholder tones below are EVIDENCE-ONLY (this file is a repo tool,
// not shipped code; the rig itself stays colorless — R4 §2.2/§8.4).

import CoreGraphics
import Foundation
import ImageIO
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Evidence tones (never shipped)

private let background = CGColor(red: 0.984, green: 0.969, blue: 0.945, alpha: 1)
private let fur = CGColor(red: 0.929, green: 0.890, blue: 0.831, alpha: 1)
private let furShade = CGColor(red: 0.886, green: 0.835, blue: 0.761, alpha: 1)
private let belly = CGColor(red: 0.973, green: 0.949, blue: 0.914, alpha: 1)
private let eye = CGColor(red: 0.290, green: 0.251, blue: 0.220, alpha: 1)
private let cheek = CGColor(red: 0.941, green: 0.776, blue: 0.753, alpha: 1)
private let floorC = CGColor(red: 0.918, green: 0.882, blue: 0.824, alpha: 1)
private let rug = CGColor(red: 0.863, green: 0.894, blue: 0.859, alpha: 1)
private let windowC = CGColor(red: 0.965, green: 0.945, blue: 0.910, alpha: 1)
private let pom = CGColor(red: 0.906, green: 0.788, blue: 0.804, alpha: 1)
private let bowl = CGColor(red: 0.847, green: 0.804, blue: 0.741, alpha: 1)
private let blanket = CGColor(red: 0.847, green: 0.800, blue: 0.875, alpha: 1)
private let sparkle = CGColor(red: 0.937, green: 0.843, blue: 0.604, alpha: 1)

private func fill(_ name: String) -> CGColor {
    switch name {
    case "body", "head", "earLeft", "earRight", "eyeLeftLid", "eyeRightLid":
        return fur
    case "bellyPatch": return belly
    case "tail", "hindFootLeft", "hindFootRight", "pawLeft", "pawRight",
         "glyphSilhouette":
        return furShade
    case "eyeLeftBase", "eyeRightBase", "eyeLeftPupil", "eyeRightPupil",
         "mouthNeutral", "mouthEat", "mouthRefuse":
        return eye
    case "cheekLeft", "cheekRight": return cheek
    case "floor": return floorC
    case "rug": return rug
    case "window": return windowC
    case "pomString": return furShade
    case "pomPuff": return pom
    case "food": return bowl
    case "blanket": return blanket
    case "sparkleA", "sparkleB": return sparkle
    default: return fur
    }
}

// MARK: - Canvas

private func render(_ draw: (CGContext) -> Void, size: Int, to url: URL) {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("cannot create CGContext") }
    draw(ctx)
    guard let image = ctx.makeImage() else { fatalError("cannot make image") }
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("cannot create destination \(url.path)") }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("cannot write \(url.path)")
    }
    print("wrote \(url.path)")
}

/// Draws paths in grid space onto a size×size canvas (y-down flip: the
/// 1000×1000 grid's ground line y = 1000 lands at the canvas bottom).
/// `gridTranslation` shifts the drawing in grid units (composition-only
/// placement on the evidence canvas — never a geometry change).
private func drawParts(_ names: [((String) -> Path, String)], ctx: CGContext, size: Int,
                       gridTranslation: CGPoint = .zero) {
    let s = CGFloat(size) / 1000.0
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(size))
    ctx.scaleBy(x: s, y: -s)
    ctx.translateBy(x: gridTranslation.x, y: gridTranslation.y)
    for (pathFor, name) in names {
        ctx.addPath(pathFor(name).cgPath)
        ctx.setFillColor(fill(name))
        ctx.fillPath()
    }
    ctx.restoreGState()
}

private func rig(_ lookup: @escaping (String) -> Path) -> (CGContext) -> Void {
    let order = [
        "tail", "hindFootLeft", "hindFootRight", "body", "bellyPatch",
        "head", "earLeft", "earRight", "cheekLeft", "cheekRight",
        "mouthNeutral", "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
        "eyeRightBase", "eyeRightPupil", "eyeRightLid", "pawLeft", "pawRight",
    ]
    return { ctx in drawParts(order.map { (lookup, $0) }, ctx: ctx, size: ctx.width) }
}

private func glyph(_ lookup: @escaping (String) -> Path) -> (CGContext) -> Void {
    let order = ["glyphSilhouette", "glyphEyeLeft", "glyphEyeRight"]
    return { ctx in drawParts(order.map { (lookup, $0) }, ctx: ctx, size: ctx.width) }
}

private func room(_ lookup: @escaping (String) -> Path) -> (CGContext) -> Void {
    let order = [
        "floor", "rug", "window", "pomString", "pomPuff", "food", "blanket",
        "tail", "hindFootLeft", "hindFootRight", "body", "bellyPatch",
        "head", "earLeft", "earRight", "cheekLeft", "cheekRight",
        "mouthNeutral", "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
        "eyeRightBase", "eyeRightPupil", "eyeRightLid", "pawLeft", "pawRight",
    ]
    return { ctx in
        drawParts(order.map { (lookup, $0) }, ctx: ctx, size: ctx.width)
        // Canvas composition nudge (fix round 1, review O5): sparkleA's
        // authored spot overlaps the window frame on the evidence canvas;
        // translate it into the clear left-wall space. Composition only —
        // the prop's Path constant is untouched (same delta as
        // render_svg.py's SPARKLE_A_NUDGE).
        drawParts([(lookup, "sparkleA")], ctx: ctx, size: ctx.width,
                  gridTranslation: CGPoint(x: -100, y: 310))
        drawParts([(lookup, "sparkleB")], ctx: ctx, size: ctx.width)
    }
}

// MARK: - Main

@main
struct MomoRenderEvidence {
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outIndex = arguments.firstIndex(of: "--out"),
              arguments.count > outIndex + 1 else {
            FileHandle.standardError.write(
                Data("usage: momo-render-evidence --out <dir>\n".utf8))
            exit(2)
        }
        let outDir = URL(fileURLWithPath: arguments[outIndex + 1], isDirectory: true)
        try? FileManager.default.createDirectory(
            at: outDir, withIntermediateDirectories: true)

        render({ ctx in
            ctx.setFillColor(background)
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 800))
            rig(lookup)(ctx)
        }, size: 800, to: outDir.appendingPathComponent("rig-full.png"))

        render({ ctx in
            ctx.setFillColor(background)
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 800))
            glyph(lookup)(ctx)
        }, size: 800, to: outDir.appendingPathComponent("rig-glyph.png"))

        render({ ctx in
            ctx.setFillColor(background)
            ctx.fill(CGRect(x: 0, y: 0, width: 800, height: 800))
            room(lookup)(ctx)
        }, size: 800, to: outDir.appendingPathComponent("room-scene.png"))
    }
}

/// Name → Path mirror over the generated static-let tables, so the render
/// order lists above stay the single source of part names.
private func lookup(_ name: String) -> Path {
    let rig: [String: Path] = [
        "tail": MomoRig.tail, "hindFootLeft": MomoRig.hindFootLeft,
        "hindFootRight": MomoRig.hindFootRight, "body": MomoRig.body,
        "bellyPatch": MomoRig.bellyPatch, "head": MomoRig.head,
        "earLeft": MomoRig.earLeft, "earRight": MomoRig.earRight,
        "cheekLeft": MomoRig.cheekLeft, "cheekRight": MomoRig.cheekRight,
        "mouthNeutral": MomoRig.mouthNeutral, "mouthEat": MomoRig.mouthEat,
        "mouthRefuse": MomoRig.mouthRefuse,
        "eyeLeftBase": MomoRig.eyeLeftBase, "eyeLeftPupil": MomoRig.eyeLeftPupil,
        "eyeLeftLid": MomoRig.eyeLeftLid, "eyeRightBase": MomoRig.eyeRightBase,
        "eyeRightPupil": MomoRig.eyeRightPupil, "eyeRightLid": MomoRig.eyeRightLid,
        "pawLeft": MomoRig.pawLeft, "pawRight": MomoRig.pawRight,
        "glyphSilhouette": MomoRig.glyphSilhouette,
        "glyphEyeLeft": MomoRig.glyphEyeLeft, "glyphEyeRight": MomoRig.glyphEyeRight,
    ]
    let room: [String: Path] = [
        "floor": MomoRoom.floor, "rug": MomoRoom.rug, "window": MomoRoom.window,
        "pomString": MomoRoom.pomString, "pomPuff": MomoRoom.pomPuff,
        "food": MomoProps.food, "blanket": MomoProps.blanket,
        "sparkleA": MomoProps.sparkleA, "sparkleB": MomoProps.sparkleB,
    ]
    return rig[name] ?? room[name]!
}
