// Rig evidence renderer (TASK-026): compiles together with the rig
// implementation, the GENERATED geometry, and MomoCore, and renders the
// §2.2 layer tree — `RigLayerTree.slots(for:)`, the same slot list the
// SwiftUI view consumes — through the composed per-stage transforms and
// the §8.4 palette tokens. These PNGs are the size-ladder evidence for the
// O2 (eye calm-not-drowsy) and O3 (tail legibility) judgments: the full rig
// at the iPhone stage band, the glance rig at the Watch stage band, and the
// glyph at the AOD band — each at 2× native, plus 4× nearest-neighbor zooms
// that show what the surface ACTUALLY paints.
//
// Build & run (from the repository root) — MomoCore is a module for the
// character sources' `import MomoCore`, so it builds first:
//   mkdir -p /tmp/momo-harness
//   swiftc -emit-library -emit-module -module-name MomoCore \
//       -emit-module-path /tmp/momo-harness/MomoCore.swiftmodule \
//       Sources/MomoCore/*.swift \
//       -o /tmp/momo-harness/libMomoCore.dylib
//   swiftc -I /tmp/momo-harness -L /tmp/momo-harness -lMomoCore \
//       Tools/character-pipeline/render_rig_evidence.swift \
//       Sources/MomoCharacter/CharacterClock.swift \
//       Sources/MomoCharacter/MomoCurves.swift \
//       Sources/MomoCharacter/RigChannel.swift \
//       Sources/MomoCharacter/RigPose.swift \
//       Sources/MomoCharacter/RigMotionModel.swift \
//       Sources/MomoCharacter/RigLODTier.swift \
//       Sources/MomoCharacter/RigLayerTree.swift \
//       Sources/MomoCharacter/MomoColorToken.swift \
//       Sources/MomoCharacter/MomoCharacterPalette.swift \
//       Sources/MomoCharacter/MomoUIColors.swift \
//       Sources/MomoCharacter/MomoRig*.swift \
//       Sources/MomoCharacter/MomoProps.swift \
//       -o /tmp/momo-render-rig-evidence
//   DYLD_LIBRARY_PATH=/tmp/momo-harness \
//       /tmp/momo-render-rig-evidence --out docs/evidence/character
//
// Colors are resolved THROUGH the palette tokens (`token.resolve(.light)`)
// — this harness ships no tones of its own; it paints exactly what the
// view paints in light mode.

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import MomoCore
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Stage sizes (§2.1 bands; in-band reference values)

/// The on-screen stage side in points for each tier's evidence canvas, and
/// the @2x backing scale (the size ladder is judged at native pixel sizes).
private let stagePoints: [RigLODTier: CGFloat] = [.full: 260, .glance: 70, .glyph: 28]
private let backingScale: CGFloat = 2

// MARK: - Canvas

private func render(_ draw: (CGContext) -> Void, pixels: Int, to url: URL) {
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    guard let ctx = CGContext(
        data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
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

/// Draws one tier's layer tree in grid space onto a pixels×pixels canvas
/// (y-down flip: the 1000×1000 grid's ground line y = 1000 lands at the
/// canvas bottom). Each slot paints its generated constant under its
/// composed transform — `RigLayerTree.affineTransform` — in TASK-025
/// evidence z-order (the slot list's order), tinted by its palette token.
private func drawTier(
    _ tier: RigLODTier, pose: RigPose, ctx: CGContext, pixels: Int
) {
    let s = CGFloat(pixels) / 1000.0
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: s, y: -s)
    for slot in RigLayerTree.slots(for: tier) {
        ctx.saveGState()
        ctx.concatenate(RigLayerTree.affineTransform(of: slot, at: pose))
        ctx.addPath(slot.path.cgPath)
        let tone = NSColor(slot.token.resolve(.light))
            .usingColorSpace(.sRGB)?.cgColor
            ?? fallbackTone
        ctx.setFillColor(tone.copy(alpha: CGFloat(slot.opacity(pose))) ?? tone)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

/// Unreachable on any sane host — a guard so `drawTier` stays total. A soft
/// neutral from the palette's own light value would be wrong to ship, so a
/// loud magenta shouts if token resolution ever fails.
private let fallbackTone = CGColor(red: 1, green: 0, blue: 1, alpha: 1)

/// Crops a grid-space rect from a rendered canvas and upscales it 4× with
/// NEAREST-NEIGHBOR interpolation — the zoom shows the actual painted
/// pixels, not a resampled idealization.
private func zoom(
    from image: CGImage, canvasPixels: Int, grid rect: CGRect, factor: Int,
    to url: URL
) {
    let s = CGFloat(canvasPixels) / 1000.0
    // `CGImage.cropping` works in the image's top-left-origin (y-down)
    // space — the same orientation as the grid, so this is a plain scale
    // (no flip; the canvas bitmap row 0 is grid y = 0).
    let pixelRect = CGRect(
        x: rect.minX * s,
        y: rect.minY * s,
        width: rect.width * s,
        height: rect.height * s)
    guard let cropped = image.cropping(to: pixelRect) else {
        fatalError("cannot crop \(url.path)")
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let w = Int(cropped.width) * factor
    let h = Int(cropped.height) * factor
    guard let ctx = CGContext(
        data: nil, width: w, height: h, bitsPerComponent: 8,
        bytesPerRow: 0, space: colorSpace,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { fatalError("cannot create zoom context") }
    ctx.interpolationQuality = .none
    ctx.draw(cropped, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let zoomed = ctx.makeImage() else { fatalError("cannot make zoom") }
    guard let dest = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { fatalError("cannot create destination \(url.path)") }
    CGImageDestinationAddImage(dest, zoomed, nil)
    guard CGImageDestinationFinalize(dest) else {
        fatalError("cannot write \(url.path)")
    }
    print("wrote \(url.path)")
}

// MARK: - Measurements (the O2 / O3 numeric readouts)

private func grid(_ p: Path) -> CGRect {
    p.cgPath.boundingBox
}

private func printMeasurements() {
    let full = stagePoints[.full]!, glance = stagePoints[.glance]!
    let glyph = stagePoints[.glyph]!
    func pt(_ gridUnits: CGFloat, at stage: CGFloat) -> CGFloat {
        gridUnits * stage / 1000
    }

    print("\n--- O2: eye geometry (calm-not-drowsy judgment) ---")
    let eyeBase = grid(MomoRig.eyeLeftBase)
    let pupil = grid(MomoRig.eyeLeftPupil)
    let lid = grid(MomoRig.eyeLeftLid)
    print("full eye base:  \(pt(eyeBase.width, at: full).rounded(.toNearestOrEven)) × "
          + "\(pt(eyeBase.height, at: full).rounded(.toNearestOrEven)) pt (grid \(eyeBase.width)×\(eyeBase.height))")
    print("full pupil:     \(pt(pupil.width, at: full)) × \(pt(pupil.height, at: full)) pt")
    print("rest lid span:  grid y[\(lid.minY)…\(lid.maxY)] vs eye base y[\(eyeBase.minY)…\(eyeBase.maxY)]")
    print("                (lid scaleY = 1 at rest = authored open eye; the lid sits above the pupil)")
    let lodEye = grid(MomoRig.lodEyeLeft)
    print("glance eye:     \(pt(lodEye.width, at: glance)) × \(pt(lodEye.height, at: glance)) pt (grid \(lodEye.width)×\(lodEye.height))")
    let glyphEye = grid(MomoRig.glyphEyeLeft)
    print("glyph eye:      \(pt(glyphEye.width, at: glyph)) × \(pt(glyphEye.height, at: glyph)) pt (grid \(glyphEye.width)×\(glyphEye.height))")

    print("\n--- O3: tail geometry (legibility judgment) ---")
    let tail = grid(MomoRig.tail)
    print("full tail:      \(pt(tail.width, at: full)) × \(pt(tail.height, at: full)) pt (grid \(tail.width)×\(tail.height))")
    let lodTail = grid(MomoRig.lodTail)
    print("glance tail:    \(pt(lodTail.width, at: glance)) × \(pt(lodTail.height, at: glance)) pt (grid \(lodTail.width)×\(lodTail.height))")

    print("\n--- §7.1 breath (Content, cycle \(MomoCurves.breathCycleSeconds)s, amplitude \(MomoCurves.breathAmplitude)) ---")
    let body = grid(MomoRig.body)
    let topGrid = body.minY
    let riseGrid = MomoCurves.breathAmplitude * (1000 - topGrid)
    print("body top:       grid y=\(topGrid); inhale rise \(riseGrid) grid units")
    print("                = \(pt(riseGrid, at: full)) pt at the \(Int(full)) pt full stage (rest vs inhale pair)")
}

// MARK: - Main

@main
struct MomoRenderRigEvidence {
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outIndex = arguments.firstIndex(of: "--out"),
              arguments.count > outIndex + 1 else {
            FileHandle.standardError.write(
                Data("usage: momo-render-rig-evidence --out <dir>\n".utf8))
            exit(2)
        }
        let outDir = URL(fileURLWithPath: arguments[outIndex + 1], isDirectory: true)
        try? FileManager.default.createDirectory(
            at: outDir, withIntermediateDirectories: true)

        let state = CharacterDisplayState(
            moodBand: .content, energyBand: .relaxed, bondStage: .gettingClose,
            wakefulness: .awake, activity: nil, satietyHint: nil,
            momentRequest: nil)
        let model = RigMotionModel()
        let rest = model.pose(at: 0, displayState: state)
        let inhale = model.pose(
            at: MomoCurves.breathCycleSeconds / 4, displayState: state)

        // Full tier at the iPhone stage: rest + inhale (the §7.1 pair).
        let fullPixels = Int(stagePoints[.full]! * backingScale)
        render({ ctx in
            drawTier(.full, pose: rest, ctx: ctx, pixels: fullPixels)
        }, pixels: fullPixels, to: outDir.appendingPathComponent("rig-tree-full-rest@2x.png"))
        render({ ctx in
            drawTier(.full, pose: inhale, ctx: ctx, pixels: fullPixels)
        }, pixels: fullPixels, to: outDir.appendingPathComponent("rig-tree-full-inhale@2x.png"))

        // Glance tier at the Watch stage; glyph at the AOD stage.
        let glancePixels = Int(stagePoints[.glance]! * backingScale)
        render({ ctx in
            drawTier(.glance, pose: rest, ctx: ctx, pixels: glancePixels)
        }, pixels: glancePixels, to: outDir.appendingPathComponent("rig-tree-glance-rest@2x.png"))
        let glyphPixels = Int(stagePoints[.glyph]! * backingScale)
        render({ ctx in
            drawTier(.glyph, pose: rest, ctx: ctx, pixels: glyphPixels)
        }, pixels: glyphPixels, to: outDir.appendingPathComponent("rig-tree-glyph@2x.png"))

        // 4× nearest-neighbor zooms of the O2/O3 regions, from the @2x
        // renders (what the surface actually paints).
        let fullImageDest = outDir.appendingPathComponent("rig-tree-full-rest@2x.png")
        guard let fullImage = CGImageSourceCreateWithURL(fullImageDest as CFURL, nil)
            .flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else {
            fatalError("cannot reopen full render")
        }
        zoom(from: fullImage, canvasPixels: fullPixels,
             grid: CGRect(x: 320, y: 250, width: 360, height: 270), factor: 4,
             to: outDir.appendingPathComponent("rig-tree-full-eye-zoom4x.png"))
        zoom(from: fullImage, canvasPixels: fullPixels,
             grid: CGRect(x: 600, y: 610, width: 340, height: 370), factor: 4,
             to: outDir.appendingPathComponent("rig-tree-full-tail-zoom4x.png"))
        guard let glanceImage = CGImageSourceCreateWithURL(
            outDir.appendingPathComponent("rig-tree-glance-rest@2x.png") as CFURL, nil)
            .flatMap({ CGImageSourceCreateImageAtIndex($0, 0, nil) }) else {
            fatalError("cannot reopen glance render")
        }
        zoom(from: glanceImage, canvasPixels: glancePixels,
             grid: CGRect(x: 320, y: 250, width: 360, height: 270), factor: 4,
             to: outDir.appendingPathComponent("rig-tree-glance-eye-zoom4x.png"))
        zoom(from: glanceImage, canvasPixels: glancePixels,
             grid: CGRect(x: 600, y: 610, width: 340, height: 370), factor: 4,
             to: outDir.appendingPathComponent("rig-tree-glance-tail-zoom4x.png"))

        printMeasurements()
    }
}
