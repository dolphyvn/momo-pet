import CoreGraphics
import SwiftUI
import Testing

@testable import MomoCharacter

/// Headless geometry pins over the committed `Path` constants (TASK-025):
/// the 04 §2.1 Direction-C landmarks, the ADR-001 hard rules (ear rule,
/// rounded tips, hind feet at rest, puff tail, pear body), and R2 continuity
/// — all measured from the emitted constants with the SAME tolerances the
/// pipeline verifies against its parametric source (Tools/character-pipeline/
/// verify_geometry.py). Double entry: if the generator and these pins ever
/// disagree, the pipeline's output cannot be trusted.
@Suite("MomoRig geometry pins (04 §2.1 landmarks, ADR-001 rules)")
struct MomoRigGeometryTests {

    /// 04 §2.1 landmarks (1000×1000 grid, y-down, ground y = 1000).
    private static let bodyCenter = CGPoint(x: 500, y: 640)
    private static let bodyRadius = 300.0
    private static let headCenter = CGPoint(x: 500, y: 400)
    private static let eyeLeft = CGPoint(x: 430, y: 390)
    private static let eyeRight = CGPoint(x: 570, y: 390)
    private static let eyeRadius = 52.0
    private static let earRootLeft = CGPoint(x: 440, y: 250)
    private static let earRootRight = CGPoint(x: 560, y: 250)
    private static let tailAnchor = CGPoint(x: 720, y: 800)
    private static let groundY = 1000.0

    /// Shared with verify_geometry.py.
    private static let tol = (
        bodyCenter: 60.0, bodyRadius: 60.0, headCenter: 40.0,
        eyeCenter: 20.0, eyeRadius: 12.0, earRoot: 30.0,
        tailAnchor: 30.0, ground: 1.0
    )

    private static let loops: [String: [[CGPoint]]] = {
        var result: [String: [[CGPoint]]] = [:]
        for (name, path) in GeneratedRigCatalog.constant {
            result[name] = PathMeasuring.flatten(path)
        }
        return result
    }()

    private static func box(_ name: String) -> CGRect {
        PathMeasuring.boundingBox(Self.loops[name] ?? [])
    }

    // MARK: - Body

    @Test("body sits on the §2.1 landmark within tolerance")
    func bodyLandmark() {
        let box = Self.box("body")
        let center = CGPoint(x: box.midX, y: box.midY)
        #expect(abs(center.x - Self.bodyCenter.x) <= Self.tol.bodyCenter
                && abs(center.y - Self.bodyCenter.y) <= Self.tol.bodyCenter,
                "body center \(center) off landmark \(Self.bodyCenter) (tol \(Self.tol.bodyCenter))")
        let radius = max(box.width, box.height) / 2
        #expect(abs(radius - Self.bodyRadius) <= Self.tol.bodyRadius,
                "body radius \(radius) off landmark \(Self.bodyRadius) (tol \(Self.tol.bodyRadius))")
    }

    @Test("pear silhouette: base tapers to a waist (ADR-001)")
    func pearTaper() throws {
        let body = try #require(GeneratedRigCatalog.constant["body"])
        let hip = PathMeasuring.widthAtY(body, atY: 780)
        let waist = PathMeasuring.widthAtY(body, atY: 470)
        #expect(hip >= 1.25 * waist,
                "pear taper missing: hip width \(hip) at y=780 vs waist \(waist) at y=470")
    }

    // MARK: - Head

    @Test("head sits on the §2.1 landmark; R2 overlap with the body")
    func headLandmarkAndContinuity() {
        let box = Self.box("head")
        let center = CGPoint(x: box.midX, y: box.midY)
        #expect(abs(center.x - Self.headCenter.x) <= Self.tol.headCenter
                && abs(center.y - Self.headCenter.y) <= Self.tol.headCenter,
                "head center \(center) off landmark \(Self.headCenter) (tol \(Self.tol.headCenter))")

        let body = Self.box("body")
        let overlap = min(box.maxY, body.maxY) - max(box.minY, body.minY)
        #expect(overlap >= 40, "head/body overlap \(overlap) < 40 — creature would read as two stacked shapes (R2)")
    }

    // MARK: - Eyes

    @Test("eye bases sit on the §2.1 landmarks at the landmark radius")
    func eyeLandmarks() {
        for (name, landmark) in [("eyeLeftBase", Self.eyeLeft), ("eyeRightBase", Self.eyeRight)] {
            let box = Self.box(name)
            let center = CGPoint(x: box.midX, y: box.midY)
            #expect(abs(center.x - landmark.x) <= Self.tol.eyeCenter
                    && abs(center.y - landmark.y) <= Self.tol.eyeCenter,
                    "\(name) center \(center) off landmark \(landmark) (tol \(Self.tol.eyeCenter))")
            #expect(abs(box.width / 2 - Self.eyeRadius) <= Self.tol.eyeRadius,
                    "\(name) radius \(box.width / 2) off landmark \(Self.eyeRadius) (tol \(Self.tol.eyeRadius))")
        }
    }

    // MARK: - Ears (ADR-001)

    @Test("ears root on the §2.1 anchors and clear the 12% base-width rule")
    func earRule() {
        let bodyWidth = Self.box("body").width
        for (name, root) in [("earLeft", Self.earRootLeft), ("earRight", Self.earRootRight)] {
            let box = Self.box(name)
            // Root anchor sits at the ear's base: the inflated bounding box
            // must contain it (the ear leans, so the anchor is near-but-not-at
            // the box bottom).
            let inflated = box.insetBy(
                dx: CGFloat(-Self.tol.earRoot), dy: CGFloat(-Self.tol.earRoot))
            #expect(inflated.contains(root),
                    "\(name) bbox \(box) does not contain root \(root) (tol \(Self.tol.earRoot))")

            // ADR-001 base rule = the chord across the ear AT the ear-root
            // landmark line — the at-base width. The bounding-box width is
            // the tilted shaft's mid-shaft maximum (120.5 vs the true 64.9
            // at-base here) and cannot catch a thin, strongly tilted ear.
            let ear = GeneratedRigCatalog.constant[name] ?? Path()
            let baseWidth = PathMeasuring.widthAtY(ear, atY: root.y)
            let ratio = baseWidth / Double(bodyWidth)
            #expect(ratio >= 0.12,
                    "\(name) at-base width \(baseWidth) at the ear-root line y=\(root.y) = \(ratio) of body width \(bodyWidth) < 0.12 (ADR-001)")
        }
    }

    @Test("ear tips are rounded, never pointed (ADR-001)")
    func earRoundedTips() throws {
        for name in ["earLeft", "earRight"] {
            let ear = try #require(GeneratedRigCatalog.constant[name])
            let box = Self.box(name)
            let height = box.height
            // Reference = the ear's max (bounding-box) width — the shaft's
            // shape property; the ADR-001 base rule is measured at the root
            // line in earRule.
            let maxWidth = box.width
            // Width profile down from the tip: a pointed tip collapses toward
            // zero quickly; an ellipse-capped ear keeps width.
            let w10 = PathMeasuring.widthAtY(ear, atY: box.minY + 0.10 * height)
            let w6 = PathMeasuring.widthAtY(ear, atY: box.minY + 0.06 * height)
            #expect(w10 >= 0.50 * maxWidth,
                    "\(name) tip not rounded: width \(w10) at 10% from tip < 50% of max width \(maxWidth)")
            #expect(w6 >= 0.30 * maxWidth,
                    "\(name) tip not rounded: width \(w6) at 6% from tip < 30% of max width \(maxWidth)")
        }
    }

    // MARK: - Tail

    @Test("puff tail anchors near the §2.1 tail anchor")
    func tailAnchor() {
        let box = Self.box("tail")
        let inflated = box.insetBy(
            dx: CGFloat(-Self.tol.tailAnchor), dy: CGFloat(-Self.tol.tailAnchor))
        #expect(inflated.contains(Self.tailAnchor),
                "tail bbox \(box) does not contain anchor \(Self.tailAnchor) (tol \(Self.tol.tailAnchor))")
    }

    // MARK: - Hind feet (ADR-001 rest posture)

    @Test("hind feet stand on the ground line and connect to the body")
    func hindFeet() {
        let body = Self.box("body")
        for name in ["hindFootLeft", "hindFootRight"] {
            let box = Self.box(name)
            #expect(abs(box.maxY - Self.groundY) <= Self.tol.ground,
                    "\(name) bottom \(box.maxY) not on the ground line \(Self.groundY)")
            #expect(box.minY <= body.maxY - 10,
                    "\(name) floats below the body (top \(box.minY) vs body bottom \(body.maxY)) — nothing may float (R2)")
        }
    }

    // MARK: - Face + belly containment

    @Test("face details stay inside the head outline")
    func faceDetailsInsideHead() {
        let head = Self.box("head")
        for name in ["mouthNeutral", "mouthEat", "mouthRefuse", "cheekLeft", "cheekRight"] {
            let box = Self.box(name)
            #expect(
                box.minX >= head.minX && box.maxX <= head.maxX
                    && box.minY >= head.minY && box.maxY <= head.maxY,
                "\(name) bbox \(box) escapes the head \(head)")
        }
    }

    @Test("belly patch stays inside the body outline")
    func bellyInsideBody() throws {
        let body = try #require(GeneratedRigCatalog.constant["body"])
        let belly = Self.loops["bellyPatch"] ?? []
        // Sample the patch's flattened outline; every sample must be inside
        // the body loops (the patch must never poke through the silhouette).
        let escapes = belly.flatMap { $0 }.filter { !PathMeasuring.contains(body, $0) }
        #expect(escapes.isEmpty,
                "bellyPatch escapes the body outline at \(escapes.prefix(5))")
    }
}
