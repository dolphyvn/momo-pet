import CoreGraphics
import Foundation
import SwiftUI
import Testing

@testable import MomoCharacter

/// TASK-027's R1 reconciliation, proven numerically. `MomoRigView` renders
/// each slot by concatenating `RigLayerTree.affineTransform` inside one
/// `drawLayer` per slot — the proof has two teeth:
///
/// 1. POINT PROBES: the normative matrix maps probe points to the same
///    places as an independent step-by-step mapping of the §2.2 law —
///    per stage (p − anchor)·S·R·T·(+anchor), child stages applying before
///    ancestors — across a fully-loaded multi-channel pose (and the probe
///    is shown order-sensitive, so it can actually catch a swapped stage).
/// 2. PIXEL PROBES: the full rig at that pose renders through the view's
///    Canvas loop (drawLayer + concatenate + fill) pixel-for-pixel equal to
///    the same slots through a raw y-flipped CGContext applying the same
///    matrices — and demonstrably different from the `.rest` render, so the
///    probe is not comparing two still lifes.
@Suite("R1 composition — normative matrix, point-probed and pixel-probed")
@MainActor
struct R1CompositionTests {

    // MARK: - Fixtures

    /// A pose with EVERY channel live at once — beyond what the §7.4 arbiter
    /// would co-admit, deliberately: the matrix probe wants the fully-loaded
    /// case (scale + rotation + translation on body and head, opposed ear
    /// angles, tail swing, asymmetric lids, opposed pupil offsets).
    private let loadedPose = RigPose(
        body: RigGridTransform(
            scaleX: 1.02, scaleY: 0.99, rotationDegrees: 2.5,
            translation: CGPoint(x: 8, y: 0)),
        head: RigGridTransform(
            scaleX: 1, scaleY: 1, rotationDegrees: -3,
            translation: CGPoint(x: 0, y: 3)),
        earLeft: RigRotationScale(rotationDegrees: 12, scaleY: 1),
        earRight: RigRotationScale(rotationDegrees: -7, scaleY: 1.01),
        tail: RigRotationScale(rotationDegrees: 7, scaleY: 1),
        eyeLeft: RigEyePose(
            lidScaleY: 1.2, pupilOffset: CGPoint(x: -15, y: 0), lowerLid: .upturned),
        eyeRight: RigEyePose(
            lidScaleY: 0.8, pupilOffset: CGPoint(x: 0, y: -11), lowerLid: .relaxed),
        mouth: RigMouthWeights(neutral: 0.5, eat: 0.5, refuse: 0),
        cheekOpacity: 0.6)

    /// The §2.2 point law, derived here independently of CGAffineTransform:
    /// each stage pivots about its anchor — (p − a)·S·R·T·(+a) — and stages
    /// apply CHILD-FIRST. `reversed: true` walks the outermost-first stage
    /// list backwards (the law); `false` walks it forwards (the control the
    /// order-sensitivity probe measures against).
    private func mapped(
        _ point: CGPoint, through slot: RigLayerSlot, at pose: RigPose,
        reversed: Bool
    ) -> CGPoint {
        let stages = Array(slot.stages)
        var p = point
        for stage in reversed ? stages.reversed() : stages {
            let t = stage.value(pose)
            var q = CGPoint(x: p.x - stage.anchor.x, y: p.y - stage.anchor.y)
            q = CGPoint(x: q.x * t.scaleX, y: q.y * t.scaleY)
            let theta = CGFloat(t.rotationDegrees * Double.pi / 180)
            let cosine = cos(theta)
            let sine = sin(theta)
            q = CGPoint(x: q.x * cosine - q.y * sine, y: q.x * sine + q.y * cosine)
            p = CGPoint(
                x: q.x + t.translation.x + stage.anchor.x,
                y: q.y + t.translation.y + stage.anchor.y)
        }
        return p
    }

    private func handMapped(
        _ point: CGPoint, through slot: RigLayerSlot, at pose: RigPose
    ) -> CGPoint {
        mapped(point, through: slot, at: pose, reversed: true)
    }

    private func probePoints(of slot: RigLayerSlot) -> [CGPoint] {
        var points: [CGPoint] = []
        let bounds = slot.path.boundingRect
        points.append(contentsOf: [
            CGPoint(x: bounds.minX, y: bounds.minY),
            CGPoint(x: bounds.maxX, y: bounds.minY),
            CGPoint(x: bounds.minX, y: bounds.maxY),
            CGPoint(x: bounds.maxX, y: bounds.maxY),
            CGPoint(x: bounds.midX, y: bounds.midY),
        ])
        points.append(contentsOf: slot.stages.map { $0.anchor })
        return points
    }

    // MARK: - Point probes

    @Test("R1: at .rest every slot's matrix IS CGAffineTransform.identity — digit-for-digit")
    func restIsExactlyIdentity() {
        for tier in RigLODTier.allCases {
            for slot in RigLayerTree.slots(for: tier) {
                #expect(
                    RigLayerTree.affineTransform(of: slot, at: .rest) == .identity,
                    "\(tier)/\(slot.part) at rest is not exactly identity")
            }
        }
    }

    @Test("R1: the composed matrix matches the step-by-step §2.2 mapping at a loaded pose")
    func matrixMatchesPointLaw() {
        let tolerance: CGFloat = 1e-6 // grid units — 9 orders below a pixel
        var probedSlots = 0
        var probedPoints = 0
        for slot in RigLayerTree.slots(for: .full) where !slot.stages.isEmpty {
            probedSlots += 1
            for point in probePoints(of: slot) {
                probedPoints += 1
                let composed = point.applying(
                    RigLayerTree.affineTransform(of: slot, at: loadedPose))
                let law = handMapped(point, through: slot, at: loadedPose)
                #expect(
                    abs(composed.x - law.x) < tolerance
                        && abs(composed.y - law.y) < tolerance,
                    "\(slot.part) maps \(point) to \(composed), the §2.2 law says \(law)")
            }
        }
        #expect(probedSlots >= 15) // every staged slot of the full rig
        #expect(probedPoints > 75) // non-vacuous coverage
    }

    @Test("R1: the probe is order-sensitive — a swapped composition misses by units")
    func probeDetectsOrderErrors() {
        var worst: CGFloat = 0
        for slot in RigLayerTree.slots(for: .full) where slot.stages.count >= 2 {
            for point in probePoints(of: slot) {
                let composed = point.applying(
                    RigLayerTree.affineTransform(of: slot, at: loadedPose))
                let wrong = mapped(point, through: slot, at: loadedPose, reversed: false)
                worst = max(worst, abs(composed.x - wrong.x) + abs(composed.y - wrong.y))
            }
        }
        #expect(worst > 1.0, "an ancestor/child swap is invisible to the probe (worst \(worst))")
    }

    @Test("R1: anchors are fixed points of their own stage; children ride ancestors")
    func hierarchySemantics() {
        // The body stage's anchor (the ground line) cannot move under a
        // body-only rotation: breath/posture never lifts the feet's pivot.
        let bodyOnly = RigPose(
            body: RigGridTransform(
                scaleX: 1, scaleY: 1, rotationDegrees: 2.5, translation: .zero))
        let bodySlot = RigLayerTree.slots(for: .full).first { $0.part == "body" }!
        let ground = bodySlot.stages[0].anchor
        let mapped = ground.applying(
            RigLayerTree.affineTransform(of: bodySlot, at: bodyOnly))
        #expect(abs(mapped.x - ground.x) < 1e-9 && abs(mapped.y - ground.y) < 1e-9)

        // The head RIDES the body: under the same body rotation the head
        // anchor (far from the ground) moves — by exactly the §2.2 mapping.
        let headSlot = RigLayerTree.slots(for: .full).first { $0.part == "head" }!
        let neck = headSlot.stages[1].anchor
        let neckMoved = neck.applying(
            RigLayerTree.affineTransform(of: headSlot, at: bodyOnly))
        let expected = handMapped(neck, through: headSlot, at: bodyOnly)
        #expect(abs(neckMoved.x - expected.x) < 1e-9 && abs(neckMoved.y - expected.y) < 1e-9)
        #expect(abs(neckMoved.x - neck.x) > 1.0) // it really moved (~410·sin 2.5° ≈ 18)
    }

    // MARK: - Pixel probes

    private static func pixelData(of image: CGImage) throws -> [UInt8] {
        let width = image.width
        let height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8,
            bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return data
    }

    /// The view's render path, verbatim: one drawLayer per slot, the
    /// normative matrix concatenated in, the slot's path filled through the
    /// slot's opacity channel.
    private func renderThroughCanvas(pose: RigPose) throws -> CGImage {
        let side = RigCanvas.gridSide
        let view = Canvas { context, _ in
            for slot in RigLayerTree.slots(for: .full) {
                context.drawLayer { layer in
                    layer.concatenate(RigLayerTree.affineTransform(of: slot, at: pose))
                    let opacity = slot.opacity(pose)
                    layer.fill(slot.path, with: .color(.black.opacity(opacity)))
                }
            }
        }
        .frame(width: side, height: side)

        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        renderer.proposedSize = ProposedViewSize(width: side, height: side)
        return try #require(renderer.cgImage)
    }

    /// The evidence harness's path: the same slots, the same matrices, a raw
    /// y-flipped CGContext.
    private func renderThroughCGContext(pose: RigPose) throws -> CGImage {
        let side = Int(RigCanvas.gridSide)
        let context = CGContext(
            data: nil, width: side, height: side, bitsPerComponent: 8,
            bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.concatenate(CGAffineTransform(
            translationX: 0, y: CGFloat(side)).scaledBy(x: 1, y: -1))
        for slot in RigLayerTree.slots(for: .full) {
            context.saveGState()
            context.concatenate(RigLayerTree.affineTransform(of: slot, at: pose))
            context.addPath(slot.path.cgPath)
            context.setFillColor(
                CGColor(gray: 0, alpha: CGFloat(slot.opacity(pose))))
            context.fillPath()
            context.restoreGState()
        }
        return try #require(context.makeImage())
    }

    @Test("R1: the full rig at a loaded pose renders pixel-for-pixel equal across both paths")
    func pixelProbe() throws {
        let canvasImage = try renderThroughCanvas(pose: loadedPose)
        let cgImage = try renderThroughCGContext(pose: loadedPose)
        #expect(canvasImage.width == cgImage.width)
        #expect(canvasImage.height == cgImage.height)

        let canvasPixels = try Self.pixelData(of: canvasImage)
        let cgPixels = try Self.pixelData(of: cgImage)

        // Both renders are non-blank.
        let inked = stride(from: 3, to: canvasPixels.count, by: 4)
            .filter { canvasPixels[$0] > 200 }.count
        #expect(inked > 10_000)

        // And they agree: the two rasterizers differ only on path-boundary
        // antialiasing (observed: 2 pixels of ~10⁶ at a >64-alpha step). A
        // real composition error displaces whole limbs — the non-vacuous
        // control below shows a loaded-vs-rest signal above 1000 pixels.
        var disagreements = 0
        for i in stride(from: 3, to: canvasPixels.count, by: 4) {
            if abs(Int(canvasPixels[i]) - Int(cgPixels[i])) > 64 { disagreements += 1 }
        }
        #expect(disagreements <= 8, "\(disagreements) pixels disagree > 64 alpha")
    }

    @Test("R1: the loaded pose's render is demonstrably different from rest — non-vacuous")
    func pixelProbeIsNotVacuous() throws {
        let loaded = try Self.pixelData(of: renderThroughCanvas(pose: loadedPose))
        let rest = try Self.pixelData(of: renderThroughCanvas(pose: .rest))
        var differing = 0
        for i in stride(from: 3, to: loaded.count, by: 4) {
            if abs(Int(loaded[i]) - Int(rest[i])) > 64 { differing += 1 }
        }
        #expect(differing > 1_000, "a multi-channel pose must move real ink (\(differing) px)")
    }
}
