// Reduce Motion + grayscale evidence renderer (TASK-029): compiles together
// with the character implementation, the GENERATED geometry, and MomoCore,
// and renders the §3.2–3.3 expression states and the RM static end poses as
// the §3.5 grayscale review record — every palette token resolves to its
// light-mode tone, then to BT.709 luminance (hue removed). The RM rasters
// paint exactly what `RigMotionModel.pose(reduceMotion: true)` and
// `MomoDirectorState.reduceMotionOverlay(at:)` yield — the same values the
// SwiftUI view renders with the flag on.
//
// What this evidence IS: rasters of the mood statics (§3.2), the energy
// overlays (§3.3), the asleep static, and the reaction/state-change end
// poses (§7.3), with hue removed — the human-reviewable half of the
// grayscale legibility obligation (04 :248).
//
// What this evidence is NOT: a perceptual claim. State is never carried by
// color (INV-5) — distinguishability is carried by GEOMETRY (aperture, lid
// shape, ear angle, posture), and the honest numeric check over those
// channels is pinned pairwise in `MomoReduceMotionEndPoseTests` (R11/R12).
// The digest this script prints is a human-readable copy of those channels;
// grayscale pixels cannot carry a contrast-ratio claim and none is made.
//
// Build & run (from the repository root) — MomoCore is a module for the
// character sources' `import MomoCore`, so it builds first:
//   mkdir -p /tmp/momo-harness
//   swiftc -emit-library -emit-module -module-name MomoCore \
//       -emit-module-path /tmp/momo-harness/MomoCore.swiftmodule \
//       Sources/MomoCore/*.swift \
//       -o /tmp/momo-harness/libMomoCore.dylib
//   swiftc -I /tmp/momo-harness -L /tmp/momo-harness -lMomoCore \
//       Tools/character-pipeline/render_reduce_motion_evidence.swift \
//       Sources/MomoCharacter/*.swift \
//       -o /tmp/momo-render-rm-evidence
//   DYLD_LIBRARY_PATH=/tmp/momo-harness \
//       /tmp/momo-render-rm-evidence --out docs/evidence/character

import AppKit
import CoreGraphics
import Foundation
import ImageIO
import MomoCore
import UniformTypeIdentifiers

// MARK: - Canvas

/// Renders onto a pixels×pixels canvas and writes a PNG (deterministic: the
/// only inputs are the pose and the palette tones).
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

/// The palette tone with hue removed: the token resolves through the SAME
/// `resolve(.light)` the view uses, then collapses to BT.709 luminance. No
/// tone is authored here — grayscale is derived, never chosen (R4: no
/// hand-picked colors).
private func grayTone(_ token: MomoColorToken) -> CGColor {
    let srgb = NSColor(token.resolve(.light))
        .usingColorSpace(.sRGB) ?? { fatalError("cannot resolve a palette tone") }()
    let y = 0.2126 * srgb.redComponent
        + 0.7152 * srgb.greenComponent + 0.0722 * srgb.blueComponent
    return CGColor(gray: y, alpha: 1)
}

/// Draws the full tier's layer tree in grid space under the pose's composed
/// transforms, in the slot list's z-order, tinted by the grayscale tone.
private func drawTier(pose: RigPose, ctx: CGContext, pixels: Int) {
    let s = CGFloat(pixels) / 1000.0
    ctx.saveGState()
    ctx.translateBy(x: 0, y: CGFloat(pixels))
    ctx.scaleBy(x: s, y: -s)
    for slot in RigLayerTree.slots(for: .full) {
        ctx.saveGState()
        ctx.concatenate(RigLayerTree.affineTransform(of: slot, at: pose))
        ctx.addPath(slot.path.cgPath)
        let tone = grayTone(slot.token)
        ctx.setFillColor(tone.copy(alpha: CGFloat(slot.opacity(pose))) ?? tone)
        ctx.fillPath()
        ctx.restoreGState()
    }
    ctx.restoreGState()
}

/// Crops the eye region from a rendered canvas and upscales it 4× with
/// NEAREST-NEIGHBOR interpolation — the aperture and lower-lid shape are
/// the §3.2 facial-warmth carriers, and the zoom shows the actual pixels.
private func eyeZoom(
    from image: CGImage, canvasPixels: Int, to url: URL
) {
    let s = CGFloat(canvasPixels) / 1000.0
    let eyeRegion = CGRect(x: 320, y: 250, width: 360, height: 270)
    let pixelRect = CGRect(
        x: eyeRegion.minX * s, y: eyeRegion.minY * s,
        width: eyeRegion.width * s, height: eyeRegion.height * s)
    guard let cropped = image.cropping(to: pixelRect) else {
        fatalError("cannot crop \(url.path)")
    }
    let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
    let w = Int(cropped.width) * 4
    let h = Int(cropped.height) * 4
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

// MARK: - The states (deterministic folds — no clock, no randomness)

private let stagePixels = 520 // the 260 pt iPhone band at @2x (TASK-026)

/// The §3.2/§3.3 display state (band names are the doc's normative ones).
private func state(
    mood: MoodBand = .content, energy: EnergyBand = .relaxed,
    wakefulness: Wakefulness = .awake, activity: Activity? = nil
) -> CharacterDisplayState {
    CharacterDisplayState(
        moodBand: mood, energyBand: energy, bondStage: .gettingClose,
        wakefulness: wakefulness, activity: activity, satietyHint: nil,
        momentRequest: nil)
}

/// The RM static: the expression base with the idle schedule empty and the
/// flag on — the R2 row's render, t-invariant (pinned in the mapping suite).
private func staticPose(_ display: CharacterDisplayState) -> RigPose {
    RigMotionModel().pose(
        at: 3.0, displayState: display, schedule: [],
        reactionMotion: .identity, reduceMotion: true)
}

/// A plan event for a reaction key (the engine's plan, D18).
private func plan(_ key: MomoReactionKey, at t: Double) -> MomoCharacterEvent {
    .plan(
        ResponsePlan(reaction: ReactionID(rawValue: key.rawValue), lineKey: nil,
                     haptic: nil),
        at: t)
}

/// A named raster: its pose and the channel digest line.
private struct Raster {
    let file: String
    let pose: RigPose
    let zoomEye: Bool
}

private func digest(_ name: String, _ pose: RigPose) -> String {
    let eye = pose.eyeLeft
    return String(
        format: "%-22@ aperture %.3f lowerLid %@ pupils (%.1f, %.1f) "
            + "earL %+.1f° earR %+.1f° tail %+.1f° posture scaleY %.3f "
            + "lean %+.1f° headY %+.1f cheek %.2f mouth(n/e/r) %.2f/%.2f/%.2f "
            + "blanket rot %+.1f° dy %+.1f sparkle %.2f/%.2f",
        name as NSString,
        eye.lidScaleY,
        String(describing: eye.lowerLid) as NSString,
        eye.pupilOffset.x, eye.pupilOffset.y,
        pose.earLeft.rotationDegrees, pose.earRight.rotationDegrees,
        pose.tail.rotationDegrees,
        pose.body.scaleY, pose.body.rotationDegrees,
        pose.head.translation.y, pose.cheekOpacity,
        pose.mouth.neutral, pose.mouth.eat, pose.mouth.refuse,
        pose.blanket.transform.rotationDegrees,
        pose.blanket.transform.translation.y,
        pose.sparkleA.opacity, pose.sparkleB.opacity)
}

// MARK: - Main

@main
struct MomoRenderReduceMotionEvidence {
    static func main() {
        let arguments = ProcessInfo.processInfo.arguments
        guard let outIndex = arguments.firstIndex(of: "--out"),
              arguments.count > outIndex + 1 else {
            FileHandle.standardError.write(
                Data("usage: momo-render-rm-evidence --out <dir>\n".utf8))
            exit(2)
        }
        let outDir = URL(fileURLWithPath: arguments[outIndex + 1], isDirectory: true)
        try? FileManager.default.createDirectory(
            at: outDir, withIntermediateDirectories: true)

        var rasters: [Raster] = []

        // --- §3.2 mood statics (the relaxed energy row is the Content
        // static itself — one raster carries both).
        let moods: [(String, MoodBand)] = [
            ("mood-joyful", .joyful), ("mood-content", .content),
            ("mood-wistful", .wistful), ("mood-low", .low),
        ]
        for (name, band) in moods {
            rasters.append(
                Raster(file: "rm-static-\(name)@2x",
                       pose: staticPose(state(mood: band)), zoomEye: true))
        }
        // --- §3.3 energy overlays (on the Content base; Relaxed = Content,
        // disclosed above).
        let energies: [(String, EnergyBand)] = [
            ("energy-energetic", .energetic), ("energy-drowsy", .drowsy),
            ("energy-exhausted", .exhausted),
        ]
        for (name, band) in energies {
            rasters.append(
                Raster(file: "rm-static-\(name)@2x",
                       pose: staticPose(state(energy: band)), zoomEye: true))
        }
        // --- the asleep static (§4.2's sleep state; the R2 row covers it).
        rasters.append(
            Raster(
                file: "rm-static-asleep@2x",
                pose: staticPose(state(wakefulness: .asleep)), zoomEye: true))

        // --- §7.3 end poses: the reaction state machine folded, then the RM
        // overlay's own output rendered (the exact motion the view receives).
        // The read instant defaults to the folded slot's resolved end —
        // mid-run the RM render holds the entrance keyframe, so a fixed t
        // would record the wrong pose.
        func endRaster(
            _ file: String, _ folds: [MomoCharacterEvent], readAt t: Double? = nil
        ) {
            var director = MomoDirectorState(displayState: state())
            for event in folds { director.apply(event) }
            let read = t ?? director.reactionSlots.first!.end! - 0.001
            let motion = director.reduceMotionOverlay(at: read)
            let pose = RigMotionModel().pose(
                at: read, displayState: state(), schedule: [],
                reactionMotion: motion, reduceMotion: true)
            rasters.append(Raster(file: file, pose: pose, zoomEye: false))
        }
        // The six one-shots whose resolved ends keep an expression (the
        // identity-ending nine render the band static — no raster).
        for (file, key) in [("tap-head", MomoReactionKey.tapHead),
                            ("tap", .tap), ("double-tap", .doubleTap),
                            ("cheer", .cheer), ("decline", .decline),
                            ("politely-full", .politelyFull)] {
            endRaster("rm-end-\(file)@2x", [plan(key, at: 1.0)])
        }
        // The in-meal glance-up plateau (held; Rule 5 under RM).
        endRaster(
            "rm-end-glance-up@2x",
            [.displayState(state(activity: .eating), at: 0.5),
             .touchBegan(zone: .head, at: 1.0),
             plan(.tapHead, at: 1.2)],
            readAt: 1.65) // slot start 1.2 + plateau 0.45 (of 0.5)
        // The press-hold keyframe (held while down; the 0.8 s lean-in).
        endRaster(
            "rm-end-press-hold@2x",
            [.touchBegan(zone: .head, at: 1.0),
             plan(.longPressHead, at: 1.2)],
            readAt: 3.2) // hold keyframe at 1.2 + 0.8 = 2.0, crossfade done
        // The settle handshake's end pose (blanket up, sunk posture — R8:
        // waking renders the awake static itself, no raster). The L2
        // handshake renders through the state layer, not a slot — the read
        // instant is authored (elapsed 2.0 of the 3.0 s fold; RM renders
        // the end static from the crossfade on).
        endRaster("rm-end-settle@2x", [plan(.settling, at: 1.0)], readAt: 3.0)

        // --- Render + digest.
        for raster in rasters {
            let url = outDir.appendingPathComponent("\(raster.file).png")
            var rendered: CGImage?
            render({ ctx in
                drawTier(pose: raster.pose, ctx: ctx, pixels: stagePixels)
                rendered = ctx.makeImage()
            }, pixels: stagePixels, to: url)
            if raster.zoomEye, let image = rendered {
                eyeZoom(
                    from: image, canvasPixels: stagePixels,
                    to: outDir.appendingPathComponent(
                        "\(raster.file)-eye-zoom4x.png"))
            }
            print(digest(raster.file, raster.pose))
        }

        // --- The honest disclosure.
        print(
            """

            --- What this records (§3.5 :248, R12) ---
            Grayscale rasters of the §3.2 mood statics, §3.3 energy overlays,
            the asleep static, and the §7.3 RM end poses; tones are the
            palette's light-mode tokens collapsed to BT.709 luminance. The
            numbers above are the pose-defining channels themselves — the
            pairwise-distinguishability law over those channels is pinned in
            Tests (MomoReduceMotionEndPoseTests): every static pair differs
            EXCEPT Content+Energetic == Content (Energetic's only rendered
            deltas are its breath cycle and scheduler intervals, both masked
            under RM — a disclosed expression-design gap, routed to the
            owner). Likewise decline and politely-full end at explicitly
            neutral values — their rasters match the Content static because
            the choreography's own authored decay settles them there (the
            full-motion render ends identically). No perceptual/contrast
            claim is made from pixels.
            """)
    }
}
