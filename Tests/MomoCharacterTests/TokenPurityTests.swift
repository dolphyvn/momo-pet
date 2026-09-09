import Foundation
import Testing

/// Token-purity scan (TASK-011 AC-2 / R4: hex values live only in the token
/// files — "everything downstream resolves tokens"). Scans every Swift source
/// under `Sources/` and `Apps/` for hex color literals; only the two palette
/// files may contain them. Non-vacuous by construction: the allowlisted
/// palette files must themselves contain hex literals, and the scanned tree
/// must be non-trivial.
@Suite("Token purity (R4: hex only in the palette files)")
struct TokenPurityTests {

    /// The only files where hex color literals are permitted (the dispatch's
    /// "hex allowed ONLY in the token file(s)").
    private static let paletteFiles: Set<String> = [
        "Sources/MomoCharacter/MomoCharacterPalette.swift",
        "Sources/MomoCharacter/MomoUIColors.swift",
    ]

    /// Hex that is NOT a color (TASK-014): published algorithm constants in
    /// MomoCore — the repo-owned SHA-256 round/initial tables (FIPS 180-4
    /// §4.2.2/§5.3.3) and the SplitMix64 constants (the canonical reference).
    /// These are algorithm tables, never UI; the carve-out is pinned
    /// non-vacuously below (each file must still contain its hex) so it can
    /// neither silently widen nor survive a rename that empties it.
    private static let nonColorHexFiles: Set<String> = [
        "Sources/MomoCore/SHA256.swift",
        "Sources/MomoCore/SeededGenerator.swift",
    ]

    /// 0x… or #… followed by six or more hex digits (6+ so 0xRRGGBBAA also
    /// trips), not preceded by an identifier character. Lookbehind is ICU
    /// (NSRegularExpression) — supported.
    private static let hexLiteral = try! NSRegularExpression(
        pattern: "(?<![0-9A-Za-z])(?:0x|#)[0-9A-Fa-f]{6,}"
    )

    @Test("no hex color literal outside the two palette files")
    func hexLiteralsConfinedToPaletteFiles() throws {
        let files = try RepoTree.packageSources() + RepoTree.appSources()
        #expect(files.count > 10, "scanned tree is trivially small — check RepoTree anchors")

        var violations: [String] = []
        var paletteFileHits = 0
        var nonColorHitsByName: [String: Int] = [:]
        for file in files {
            let range = NSRange(file.contents.startIndex..., in: file.contents)
            let matches = Self.hexLiteral.numberOfMatches(in: file.contents, range: range)
            if Self.paletteFiles.contains(file.name) {
                paletteFileHits += matches
            } else if Self.nonColorHexFiles.contains(file.name) {
                nonColorHitsByName[file.name] = matches
            } else if matches > 0 {
                violations.append("\(file.name): \(matches) hex literal(s)")
            }
        }
        #expect(
            violations.isEmpty,
            "R4 violation — hex color literals outside \(Self.paletteFiles.sorted()): \(violations)"
        )
        // Non-vacuity: the palettes genuinely hold the literals.
        #expect(paletteFileHits >= 2, "palette files contain no hex literals — purity scan is vacuous")
        #expect(Self.paletteFiles.allSatisfy { name in files.contains { $0.name == name } },
                "a palette file is missing from the scanned tree")
        // Non-vacuity for the algorithm-constant carve-out, pinned to the
        // exact frozen counts (REVIEW-TASK-014 MINOR-1): SHA-256's FIPS
        // 180-4 tables are 64 K + 8 H constants; SplitMix64 has exactly
        // three (golden gamma + two mix multipliers). These tables are
        // normative and never legitimately change, so an ADDED hex in a
        // carved file — e.g. a stray color — alters the count and fails
        // here; a REPLACED constant fails the NIST/canonical vector pins
        // in SHA256Tests/SeededGeneratorTests. The carve-out therefore
        // cannot excuse anything beyond the frozen algorithm tables.
        #expect(nonColorHitsByName["Sources/MomoCore/SHA256.swift"] == 72,
                "SHA256.swift must hold exactly the FIPS tables (64 K + 8 H = 72 hex constants)")
        #expect(nonColorHitsByName["Sources/MomoCore/SeededGenerator.swift"] == 3,
                "SeededGenerator.swift must hold exactly SplitMix64's three constants")
        #expect(Self.nonColorHexFiles.allSatisfy { name in files.contains { $0.name == name } },
                "a non-color hex file is missing from the scanned tree")
    }
}
