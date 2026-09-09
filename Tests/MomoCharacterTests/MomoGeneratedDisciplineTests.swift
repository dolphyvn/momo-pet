import CoreGraphics
import Foundation
import Testing

@testable import MomoCharacter

/// Generated-code discipline (TASK-025): every emitted constant stays on the
/// 1000×1000 normalized grid, the generated files carry zero hex colors (R4)
/// and import nothing beyond SwiftUI, and every file names its generator.
/// These pins travel WITH the generated files: any regeneration that breaks
/// the discipline fails here, not silently in a renderer.
@Suite("Generated discipline (normalized grid, R4 purity, header law)")
struct MomoGeneratedDisciplineTests {

    // MARK: - Normalized grid only

    @Test("every vertex of every constant stays within [0, 1000]")
    func normalizedGrid() {
        var offenders: [String] = []
        for (name, path) in GeneratedRigCatalog.constant.sorted(by: { $0.key < $1.key }) {
            for loop in PathMeasuring.flatten(path) {
                for p in loop where !(0...1000).contains(Double(p.x))
                    || !(0...1000).contains(Double(p.y)) {
                    offenders.append("\(name): (\(p.x), \(p.y))")
                }
            }
        }
        #expect(offenders.isEmpty,
                "coordinates off the 1000×1000 grid: \(offenders.prefix(8))")
        #expect(GeneratedRigCatalog.constant.count == 44,
                "catalog must pin all 44 constants for the grid scan to be non-vacuous")
    }

    // MARK: - R4: colorless geometry

    /// Same hex-literal shape TokenPurityTests scans for — restated here so
    /// the generated layer is policed even if the global allowlists change.
    private static let hexLiteral = try! NSRegularExpression(
        pattern: "(?<![0-9A-Za-z])(?:0x|#)[0-9A-Fa-f]{6,}"
    )

    @Test("generated files carry zero hex color literals (R4)")
    func generatedFilesAreColorless() throws {
        var violations: [String] = []
        for file in GeneratedRigCatalog.generatedFiles {
            let contents = try GeneratedRigCatalog.readGeneratedFile(file)
            let range = NSRange(contents.startIndex..., in: contents)
            let hits = Self.hexLiteral.numberOfMatches(in: contents, range: range)
            if hits > 0 { violations.append("\(file): \(hits) hex literal(s)") }
        }
        #expect(violations.isEmpty,
                "the rig is colorless geometry (R4) — tokens are applied at render time: \(violations)")

        // Non-vacuity: the scan really sees 11 non-trivial files.
        #expect(GeneratedRigCatalog.generatedFiles.count == 11)
        let totalBytes = try GeneratedRigCatalog.generatedFiles.reduce(0) {
            try $0 + GeneratedRigCatalog.readGeneratedFile($1).utf8.count
        }
        #expect(totalBytes > 40_000, "generated corpus is trivially small (\(totalBytes) bytes)")
    }

    // MARK: - Import hygiene

    @Test("generated files import nothing beyond SwiftUI")
    func generatedImports() throws {
        var violations: [String] = []
        for file in GeneratedRigCatalog.generatedFiles {
            let contents = try GeneratedRigCatalog.readGeneratedFile(file)
            let imports = contents.split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("import ") }
            if imports != ["import SwiftUI"] {
                violations.append("\(file): \(imports)")
            }
        }
        #expect(violations.isEmpty,
                "generated geometry must depend on SwiftUI only (ADR-007 zero runtime deps): \(violations)")
    }

    // MARK: - Regeneration pointer

    @Test("every generated file points at the parametric source of truth")
    func sourceOfTruthPointer() throws {
        for file in GeneratedRigCatalog.generatedFiles {
            let contents = try GeneratedRigCatalog.readGeneratedFile(file)
            #expect(contents.contains("Tools/character-pipeline/parts.py"),
                    "\(file) must point at the pipeline's source of truth")
        }
    }
}
