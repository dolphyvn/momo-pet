import Foundation
import Testing

@testable import MomoCharacter

/// TASK-026 Requirement 4 (04 §2.1 stage table + §7.4 rule 5): pure,
/// deterministic LOD tier selection — iPhone renders the full rig; Watch
/// foreground renders the glance rig and NEVER the full rig (named pin);
/// AOD/complications render the glyph. Tier→part-set is cross-checked
/// against the compile-pinned TASK-025 catalog.
@Suite("RigLOD — tier selection, watch-never-full, stage bands, part sets")
struct RigLODTierTests {

    // MARK: - §2.1 surface → stage selection

    @Test("iPhone home → full rig")
    func iphoneRendersFull() {
        #expect(RigLOD.tier(for: .iphoneHome) == .full)
    }

    @Test("Watch foreground → glance rig")
    func watchForegroundRendersGlance() {
        #expect(RigLOD.tier(for: .watchForeground) == .glance)
    }

    @Test("AOD and complications → static glyph")
    func aodRendersGlyph() {
        #expect(RigLOD.tier(for: .watchAlwaysOn) == .glyph)
        #expect(RigLOD.tier(for: .complication) == .glyph)
    }

    @Test("WATCH-NEVER-FULL: no non-iPhone surface ever selects the full tier")
    func watchNeverFull() {
        // The pin is over the whole surface enumeration, so a new surface
        // added later without a mapping decision lands here too.
        for surface in RigSurface.allCases where surface != .iphoneHome {
            #expect(RigLOD.tier(for: surface) != .full,
                    "\(surface) must never render the full rig (§7.4 rule 5)")
        }
    }

    @Test("The surface enumeration is exactly the four §2.1 surfaces (pin totality)")
    func surfaceEnumerationIsTotal() {
        #expect(RigSurface.allCases.count == 4)
        #expect(RigLODTier.allCases == [.full, .glance, .glyph])
    }

    // MARK: - §2.1 stage bands (raw literals)

    @Test("Stage bands: full 220–280 pt, glance 60–80 pt, glyph 24–32 pt")
    func stageBands() {
        #expect(RigLOD.fullStagePoints == 220.0...280.0)
        #expect(RigLOD.glanceStagePoints == 60.0...80.0)
        #expect(RigLOD.glyphStagePoints == 24.0...32.0)
    }

    @Test("Stage bands are ascending and pairwise disjoint")
    func stageBandsAreDisjoint() {
        #expect(RigLOD.glyphStagePoints.upperBound < RigLOD.glanceStagePoints.lowerBound)
        #expect(RigLOD.glanceStagePoints.upperBound < RigLOD.fullStagePoints.lowerBound)
    }

    // MARK: - Tier ↔ constant-set mapping (TASK-025 catalog)

    @Test("Full tier resolves exactly the 21 full-rig constants")
    func fullTierPartSet() {
        let names = RigLOD.partNames(for: .full)
        #expect(names.count == 21)
        let expected: Set<String> = [
            "body", "bellyPatch", "hindFootLeft", "hindFootRight", "head",
            "earLeft", "earRight", "tail",
            "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
            "eyeRightBase", "eyeRightPupil", "eyeRightLid",
            "mouthNeutral", "mouthEat", "mouthRefuse",
            "cheekLeft", "cheekRight", "pawLeft", "pawRight",
        ]
        #expect(Set(names) == expected)
    }

    @Test("Glance tier resolves exactly the 11 lod* constants")
    func glanceTierPartSet() {
        let names = RigLOD.partNames(for: .glance)
        #expect(names.count == 11)
        let expected: Set<String> = [
            "lodBody", "lodBellyPatch", "lodHead", "lodEarLeft", "lodEarRight",
            "lodTail", "lodHindFootLeft", "lodHindFootRight", "lodEyeLeft",
            "lodEyeRight", "lodPawPair",
        ]
        #expect(Set(names) == expected)
    }

    @Test("Glyph tier resolves exactly the 3 glyph constants")
    func glyphTierPartSet() {
        let names = RigLOD.partNames(for: .glyph)
        #expect(names.count == 3)
        #expect(Set(names) == ["glyphSilhouette", "glyphEyeLeft", "glyphEyeRight"])
    }

    @Test("Every tier part name resolves in the compile-pinned generated catalog")
    func tierNamesResolveInTheGeneratedCatalog() throws {
        for tier in RigLODTier.allCases {
            for name in RigLOD.partNames(for: tier) {
                #expect(GeneratedRigCatalog.constant[name] != nil,
                        "\(tier) part \(name) is not a generated constant")
            }
        }
    }

    @Test("Tier part sets never leak across tiers (one creature per tier)")
    func tierPartSetsAreDisjoint() {
        let full = Set(RigLOD.partNames(for: .full))
        let glance = Set(RigLOD.partNames(for: .glance))
        let glyph = Set(RigLOD.partNames(for: .glyph))
        #expect(full.isDisjoint(with: glance))
        #expect(full.isDisjoint(with: glyph))
        #expect(glance.isDisjoint(with: glyph))
    }
}
