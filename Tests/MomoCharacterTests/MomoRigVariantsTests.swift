import CoreGraphics
import SwiftUI
import Testing

@testable import MomoCharacter

/// Variant distinctions (TASK-025, 04 §8.5 + ADR-001): the glyph merges the
/// ears into the silhouette (and drops everything else), LOD-glance drops the
/// pupil split and simplifies the paws, and the mouth slot ships three
/// distinct pre-built poses (R1: crossfaded, never re-tessellated).
@Suite("MomoRig variants (glyph merge, LOD-glance reduction, mouth poses)")
struct MomoRigVariantsTests {

    private static func loops(_ name: String) -> [[CGPoint]] {
        PathMeasuring.flatten(GeneratedRigCatalog.constant[name] ?? Path())
    }

    private static func box(_ name: String) -> CGRect {
        PathMeasuring.boundingBox(loops(name))
    }

    // MARK: - Glyph (ADR-001 below ~32 pt)

    @Test("glyph carries no separate ear parts — the merge is structural")
    func glyphMergedEars() throws {
        let names = Set(GeneratedRigCatalog.namesByFile[
            "Sources/MomoCharacter/MomoRig+Glyph.swift"] ?? [])
        #expect(names == ["glyphSilhouette", "glyphEyeLeft", "glyphEyeRight"],
                "glyph inventory must be silhouette + two eye dots")
        #expect(!names.contains { $0.localizedCaseInsensitiveContains("ear") },
                "glyph must not carry a separate ear channel (ADR-001 merge)")
    }

    @Test("glyph silhouette keeps the ear bumps above the head and ground contact")
    func glyphSilhouetteShape() {
        let silhouette = GeneratedRigCatalog.constant["glyphSilhouette"] ?? Path()
        // Six merged subpaths: head, body, ear ×2, hind foot ×2.
        let subpaths = PathMeasuring.flatten(silhouette)
        #expect(subpaths.count == 6,
                "silhouette must merge exactly 6 subpaths, found \(subpaths.count)")

        let head = Self.box("head")
        let aboveHeadY = head.minY - 100
        let extent = PathMeasuring.widthAtY(silhouette, atY: aboveHeadY)
        #expect(extent >= 160,
                "no visible ear bumps: extent \(extent) at y=\(aboveHeadY), 100 units above the head top")

        let box = PathMeasuring.boundingBox(subpaths)
        #expect(abs(box.maxY - 1000) <= 1.0,
                "glyph lost ground contact (bottom \(box.maxY) != 1000)")
        #expect(abs(box.minX - Self.box("body").minX) <= 1.0,
                "glyph silhouette must retain the pear body's footprint")
    }

    @Test("glyph overlap seams are filled, not cancellation holes (nonzero union)")
    func glyphSeamsFill() {
        // Winding rationale: a compound Path fills under the nonzero rule,
        // which CANCELS the overlap of opposite-wound subpaths to a literal
        // hole. Every non-hole subpath of the compound must therefore share
        // one winding so its overlaps fill as one union — that is what makes
        // the ears "merged" into the silhouette rather than notched at the
        // seams. The points below were computed from the committed geometry
        // to lie strictly inside BOTH overlapping subpaths of each seam (the
        // tightest, the foot/body bands, keeps ~0.8 units of margin to either
        // outline); under the pre-fix mixed winding each summed to winding 0,
        // i.e. a hole. `Path.contains` defaults to the nonzero rule — the
        // render truth.
        let silhouette = GeneratedRigCatalog.constant["glyphSilhouette"] ?? Path()
        let seams: [(CGPoint, String)] = [
            (CGPoint(x: 455, y: 245), "left ear/head lens"),
            (CGPoint(x: 545, y: 245), "right ear/head lens"),
            (CGPoint(x: 396, y: 927.65), "left foot/body band"),
            (CGPoint(x: 604, y: 927.65), "right foot/body band"),
        ]
        for (point, label) in seams {
            #expect(silhouette.contains(point),
                    "glyph seam \(label) at \(point) is NOT inside the filled silhouette — cancellation hole")
        }
    }

    @Test("the food mound fills through the bowl overlap (nonzero union)")
    func foodMoundFills() {
        // Same winding discipline as the glyph compound: the mound overlaps
        // the bowl body (mound spans y 927..957; the bowl's chord line is
        // y = 946), so the seam must fill, not cancel. Point computed from
        // the committed geometry, strictly inside both overlapping subpaths.
        let food = GeneratedRigCatalog.constant["food"] ?? Path()
        #expect(food.contains(CGPoint(x: 240, y: 952)),
                "food mound/bowl seam at (240, 952) is NOT inside the filled compound — cancellation hole")
    }

    @Test("glyph eyes are simplified dots, smaller than the full-rig bases")
    func glyphEyesAreDots() {
        for (glyphName, rigName) in [("glyphEyeLeft", "eyeLeftBase"),
                                     ("glyphEyeRight", "eyeRightBase")] {
            let glyphWidth = Self.box(glyphName).width
            let rigWidth = Self.box(rigName).width
            #expect(glyphWidth < rigWidth,
                    "\(glyphName) (\(glyphWidth)) must simplify below the rig base \(rigWidth)")
        }
    }

    // MARK: - LOD-glance

    @Test("LOD-glance drops the pupil split and simplifies the paws")
    func lodReductions() {
        let names = GeneratedRigCatalog.namesByFile[
            "Sources/MomoCharacter/MomoRig+LODGlance.swift"] ?? []
        #expect(!names.contains { $0.localizedCaseInsensitiveContains("pupil")
                || $0.localizedCaseInsensitiveContains("lid") },
                "LOD-glance must not split the eye into pupil/lid channels")
        let pawNames = names.filter { $0.localizedCaseInsensitiveContains("paw") }
        #expect(pawNames == ["lodPawPair"],
                "LOD-glance paws must collapse into one merged pair part, found \(pawNames)")
    }

    @Test("lodPawPair is one Path carrying both paws")
    func lodPawPairMergesBothPaws() {
        let pair = PathMeasuring.flatten(GeneratedRigCatalog.constant["lodPawPair"] ?? Path())
        #expect(pair.count == 2, "lodPawPair must carry exactly 2 subpaths, found \(pair.count)")

        // The pair covers the same ground as the full rig's two paw parts.
        let rigPaws = Self.box("pawLeft").union(Self.box("pawRight"))
        let lodBox = PathMeasuring.boundingBox(pair)
        #expect(abs(lodBox.minX - rigPaws.minX) <= 1 && abs(lodBox.maxX - rigPaws.maxX) <= 1
                && abs(lodBox.minY - rigPaws.minY) <= 1 && abs(lodBox.maxY - rigPaws.maxY) <= 1,
                "lodPawPair footprint \(lodBox) diverges from the rig paws \(rigPaws)")
    }

    @Test("LOD-glance retains the core silhouette: ears stay separate parts")
    func lodRetainsEars() {
        let names = GeneratedRigCatalog.namesByFile[
            "Sources/MomoCharacter/MomoRig+LODGlance.swift"] ?? []
        #expect(names.contains("lodEarLeft") && names.contains("lodEarRight"),
                "the per-ear expression channel is core — LOD keeps separate ears (ADR-001)")
    }

    // MARK: - Mouth slot (R1 pre-built poses)

    @Test("the mouth slot ships three distinct pre-built poses")
    func mouthPosesAreDistinct() {
        let neutral = GeneratedRigCatalog.constant["mouthNeutral"] ?? Path()
        let eat = GeneratedRigCatalog.constant["mouthEat"] ?? Path()
        let refuse = GeneratedRigCatalog.constant["mouthRefuse"] ?? Path()
        // The eat pose is a closed oval; the two crescents are wide and flat
        // (neutral bows up, refuse bows down).
        let neutralBox = PathMeasuring.boundingBox(of: neutral)
        let eatBox = PathMeasuring.boundingBox(of: eat)
        let refuseBox = PathMeasuring.boundingBox(of: refuse)
        #expect(eatBox.height / eatBox.width > 0.5,
                "the eat pose must be an open oval, found aspect \(eatBox.height / eatBox.width)")
        #expect(neutralBox.height / neutralBox.width < 0.5,
                "the neutral pose must be a flat crescent")
        #expect(refuseBox.height / refuseBox.width < 0.5,
                "the refuse pose must be a flat crescent")
        #expect(abs(neutralBox.height - refuseBox.height) > 0.001,
                "neutral and refuse crescents must not be copies of one another")
    }
}
