import Foundation
import Testing

@testable import MomoCharacter

/// The §8.4 naming law and emission layout, pinned against the committed
/// generated files (TASK-025). The compile-pinned constant table lives in
/// `GeneratedRigCatalog` (renames break compilation); this suite re-derives
/// the inventory from the FILES so the layout — which file carries which
/// parts, the part accounting, the GENERATED headers — cannot drift either.
@Suite("MomoRig inventory (naming law, part accounting, headers)")
struct MomoRigInventoryTests {

    /// `public static let <name>: Path` declarations in a generated file.
    private static func declaredNames(in contents: String) -> [String] {
        var names: [String] = []
        for rawLine in contents.split(separator: "\n") {
            let line = rawLine.trimmingCharacters(in: .whitespaces)
            guard line.hasPrefix("public static let "),
                  let colon = line.firstIndex(of: ":") else { continue }
            let prefix = "public static let "
            let start = line.index(line.startIndex, offsetBy: prefix.count)
            let name = line[start..<colon].trimmingCharacters(in: .whitespaces)
            if !name.isEmpty {
                names.append(String(name))
            }
        }
        return names
    }

    private static func namesByFile() throws -> [String: [String]] {
        var result: [String: [String]] = [:]
        for file in GeneratedRigCatalog.generatedFiles {
            result[file] = declaredNames(in: try GeneratedRigCatalog.readGeneratedFile(file))
        }
        return result
    }

    /// The 9 full-rig files exclude the two variant files.
    private static var fullRigFiles: [String] {
        GeneratedRigCatalog.generatedFiles.filter {
            $0.contains("MomoRig+") && !$0.contains("LOD") && !$0.contains("Glyph")
        }
    }

    // MARK: - Files exist and parse

    @Test("every generated file exists and declares the expected parts")
    func emissionLayout() throws {
        let actual = try Self.namesByFile()
        for (file, expected) in GeneratedRigCatalog.namesByFile.sorted(by: { $0.key < $1.key }) {
            let names = try #require(actual[file], "missing generated file \(file)")
            #expect(names == expected, "\(file) declares \(names), expected \(expected)")
        }
    }

    // MARK: - Part accounting

    @Test("part accounting: 44 constants — 21 + 11 + 3 + 5 + 4")
    func partAccounting() throws {
        let actual = try Self.namesByFile()
        let all = actual.values.flatMap { $0 }
        #expect(all.count == 44, "expected 44 generated Path constants, found \(all.count)")

        let rig = Self.fullRigFiles.flatMap { actual[$0] ?? [] }
        #expect(rig.count == 21,
                "full rig must emit 21 constants (§2.2's 17 counted parts + 2 ADR-001 hind feet, with the mouth slot shipping its 3 poses), found \(rig.count)")

        let lod = actual["Sources/MomoCharacter/MomoRig+LODGlance.swift"] ?? []
        #expect(lod.count == 11, "LOD-glance variant must emit 11 constants, found \(lod.count)")
        let glyph = actual["Sources/MomoCharacter/MomoRig+Glyph.swift"] ?? []
        #expect(glyph.count == 3, "glyph variant must emit 3 constants, found \(glyph.count)")
        let room = actual["Sources/MomoCharacter/MomoRoom.swift"] ?? []
        #expect(room.count == 5, "room must emit 5 constants, found \(room.count)")
        let props = actual["Sources/MomoCharacter/MomoProps.swift"] ?? []
        #expect(props.count == 4, "props must emit 4 constants, found \(props.count)")
    }

    @Test("§2.2 part roles are all present in the full rig")
    func sectionPartRoles() throws {
        let actual = try Self.namesByFile()
        let rig = Set(Self.fullRigFiles.flatMap { actual[$0] ?? [] })
        // §2.2 rows: body+belly, head, ears, tail, eyes (base+pupil+lid ×2),
        // mouth (3 pre-built poses), cheeks, front paws; ADR-001 hind feet.
        let expected: Set<String> = [
            "body", "bellyPatch", "head", "earLeft", "earRight", "tail",
            "eyeLeftBase", "eyeLeftPupil", "eyeLeftLid",
            "eyeRightBase", "eyeRightPupil", "eyeRightLid",
            "mouthNeutral", "mouthEat", "mouthRefuse",
            "cheekLeft", "cheekRight", "pawLeft", "pawRight",
            "hindFootLeft", "hindFootRight",
        ]
        #expect(rig == expected, "full-rig inventory \(rig.sorted()) != expected \(expected.sorted())")
    }

    // MARK: - Naming law (§8.4)

    @Test("all declared names follow the §8.4 lowerCamel part convention")
    func namingLaw() throws {
        let actual = try Self.namesByFile()
        let all = actual.values.flatMap { $0 }
        let bad = all.filter { name in
            guard let first = name.first, first.isLowercase else { return true }
            return name.contains { !$0.isLetter && !$0.isNumber }
        }
        #expect(bad.isEmpty, "names violating the MomoRig.<part> convention: \(bad)")
        #expect(all.count == 44, "naming scan must cover all 44 constants")
    }

    // MARK: - GENERATED header law

    @Test("every generated file carries the GENERATED header with the command")
    func generatedHeaders() throws {
        for file in GeneratedRigCatalog.generatedFiles {
            let contents = try GeneratedRigCatalog.readGeneratedFile(file)
            #expect(contents.contains("GENERATED FILE - DO NOT EDIT"),
                    "\(file) is missing its GENERATED header")
            #expect(contents.contains(GeneratedRigCatalog.generateCommand),
                    "\(file) header must carry the generate command")
            #expect(contents.contains("byte-identically"),
                    "\(file) header must state the byte-identical reproducibility pin")
        }
    }

    @Test("namespace files are hand-written anchors, not generated")
    func namespaceAnchors() throws {
        let anchor = try GeneratedRigCatalog.readGeneratedFile(
            "Sources/MomoCharacter/MomoRig.swift")
        // The anchor carries the HAND-WRITTEN marker and none of the
        // generated-header machinery (the regenerate command). It may mention
        // the header law in prose — the pin is on the machinery, not words.
        #expect(anchor.contains("HAND-WRITTEN FILE"),
                "MomoRig.swift must be marked as the hand-written anchor")
        #expect(!anchor.contains("Regenerate with:"),
                "the anchor is not pipeline output and must not carry a regenerate command")
        #expect(anchor.contains("public enum MomoRig")
                && anchor.contains("public enum MomoRoom")
                && anchor.contains("public enum MomoProps"),
                "the anchor file must declare all three namespaces")
    }
}
