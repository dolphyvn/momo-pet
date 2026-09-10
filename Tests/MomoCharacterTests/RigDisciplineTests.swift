import Foundation
import SwiftUI
import Testing

@testable import MomoCharacter

/// The TASK-026 discipline scanners: pure string predicates over the
/// hand-written rig implementation files, fixture-tested so they are
/// non-vacuous in BOTH directions (they fire on real violation shapes, and
/// they demonstrably see real construction/purity sites in the codebase).
/// TASK-011 precedent (`TokenPurityTests`).
///
/// R1: rig view + model code never constructs or mutates geometry — every
/// path arrives from the generated namespaces (`MomoRig`/`MomoProps`) as a
/// transform target only. R4 defense-in-depth: no hex/RGB outside the two
/// palette files. R3 purity: the clock and view contain no ambient time —
/// every instant enters through the injected `EngineClock` or the
/// TimelineView context date.
enum RigDiscipline {

    // MARK: - The scanned set (explicit; extend deliberately)

    /// The hand-written rig implementation files (TASK-026's rig core plus
    /// TASK-027's idle stack: sampler, events, variants, expressions,
    /// sequencer). The pin on the count keeps the scanned set from silently
    /// shrinking; splitting or adding a file updates this list AND its pins
    /// deliberately.
    static let rigImplementationFiles: [String] = [
        "Sources/MomoCharacter/CharacterClock.swift",
        "Sources/MomoCharacter/MomoCurves.swift",
        "Sources/MomoCharacter/RigChannel.swift",
        "Sources/MomoCharacter/RigPose.swift",
        "Sources/MomoCharacter/RigMotionModel.swift",
        "Sources/MomoCharacter/RigLODTier.swift",
        "Sources/MomoCharacter/RigLayerTree.swift",
        "Sources/MomoCharacter/MomoRigView.swift",
        "Sources/MomoCharacter/MomoIdleRandom.swift",
        "Sources/MomoCharacter/MomoIdleEvents.swift",
        "Sources/MomoCharacter/MomoIdleVariants.swift",
        "Sources/MomoCharacter/MomoExpressions.swift",
        "Sources/MomoCharacter/MomoIdleSequencer.swift",
    ]

    // MARK: - R1: no Path construction or mutation

    /// Substrings that would mean NEW geometry is being built or mutated in
    /// rig code. None of the generated constants' consumers needs any of
    /// these: the layer tree stores paths, transforms values.
    static let pathConstructionPatterns: [String] = [
        "Path {",
        "Path(",
        ".move(to:",
        ".addLine(to:",
        ".addLine(between:",
        ".addQuadCurve(to:",
        ".addCurve(to:",
        ".addRect(",
        ".addArc(center:",
        ".addArc(tangentEnd:",
        ".addPath(",
        ".closeSubpath(",
        ".cgPath",
    ]

    static func pathConstructionViolations(in source: String) -> [String] {
        pathConstructionPatterns.filter { source.contains($0) }
    }

    // MARK: - R4: no hex / RGB constructor outside the palette files

    static let hexColorPatterns: [String] = [
        "0x", "0X",
        "Color(red:",
    ]

    static func hexColorViolations(in source: String) -> [String] {
        hexColorPatterns.filter { source.contains($0) }
    }

    // MARK: - R3: no ambient time in the clock or the rig view

    static let ambientTimePatterns: [String] = [
        "Date()",
        "Date.now",
        "ContinuousClock",
        "DiscreteClock",
        "DispatchTime",
        "uptimeNanoseconds",
        "CFAbsoluteTimeGetCurrent",
        "clock_gettime",
    ]

    static func ambientTimeViolations(in source: String) -> [String] {
        ambientTimePatterns.filter { source.contains($0) }
    }

    // MARK: - §9.4: no system randomness in the idle stack

    /// Substrings that would mean the character drew from the system's
    /// entropy (04 §9.4: every value flows from the injected idle seed).
    static let systemRandomnessPatterns: [String] = [
        "SystemRandomNumberGenerator",
        ".random(",
        "arc4random",
        "srand(",
        "drand48",
        "UUID(",
    ]

    static func systemRandomnessViolations(in source: String) -> [String] {
        systemRandomnessPatterns.filter { source.contains($0) }
    }

    // MARK: - scenePhase → the ONE call (structural wire check)

    /// Presence check that the view wires scenePhase through the pure mapping
    /// (whose behavior is unit-tested against SwiftUI's ScenePhase directly).
    /// The mapping call `clockAction(for:` must appear inside an `onChange`.
    static func mentionsScenePhaseWiring(in source: String) -> Bool {
        source.contains("onChange(of:") &&
        source.contains("scenePhase") &&
        source.contains("clockAction(for:")
    }

    // MARK: - File access

    static func readRigFile(_ name: String) throws -> String {
        try String(contentsOf: URL(fileURLWithPath: RepoTree.repoRoot + "/" + name),
                   encoding: .utf8)
    }
}

@Suite("Rig discipline scans — R1 no geometry churn, R4 tokens, R3 no ambient time")
struct RigDisciplineTests {

    // MARK: - R1: path-construction scan

    @Test("The Path scanner flags construction and mutation fixtures")
    func pathScannerFiresOnViolations() {
        let construction = """
        let body = Path { p in
            p.move(to: CGPoint(x: 0, y: 0))
            p.addQuadCurve(to: CGPoint(x: 10, y: 10), control: .zero)
        }
        """
        #expect(RigDiscipline.pathConstructionViolations(in: construction)
                == ["Path {", ".move(to:", ".addQuadCurve(to:"])

        let mutation = "other.addPath(sneaky.cgPath)"
        // The scanner reports PATTERNS that fired; "addPath(" contains
        // "Path(" as a substring — over-matching is the safe direction for
        // a defense scan.
        #expect(RigDiscipline.pathConstructionViolations(in: mutation)
                == ["Path(", ".addPath(", ".cgPath"])
    }

    @Test("The Path scanner passes legitimate path CONSUMPTION")
    func pathScannerPassesLegitimateUse() {
        let consumer = """
        struct Slot { let path: Path; let name: String }
        let drawn = MomoRig.body.fill(color).frame(width: 1000, height: 1000)
        let t = RigLayerTree.affineTransform(of: slot, at: pose)
        """
        #expect(RigDiscipline.pathConstructionViolations(in: consumer).isEmpty)
    }

    @Test("The Path scanner sees real construction sites in a GENERATED file")
    func pathScannerSeesGeneratedSites() throws {
        // Non-vacuity, direction B: the scanner demonstrably fires on the
        // generated geometry's actual construction shape.
        let generated = try RigDiscipline.readRigFile(
            "Sources/MomoCharacter/MomoRig+Body.swift")
        #expect(!RigDiscipline.pathConstructionViolations(in: generated).isEmpty)
    }

    @Test("NO hand-written rig file constructs or mutates geometry (R1)")
    func rigFilesAreGeometryFree() throws {
        #expect(RigDiscipline.rigImplementationFiles.count == 13) // scanned set pinned
        for name in RigDiscipline.rigImplementationFiles {
            let source = try RigDiscipline.readRigFile(name)
            #expect(RigDiscipline.pathConstructionViolations(in: source).isEmpty,
                    "\(name) constructs or mutates geometry (R1)")
        }
    }

    // MARK: - §9.4: seeded randomness only

    @Test("The system-randomness scanner fires on every entropy shape")
    func randomnessScannerFiresOnViolations() {
        #expect(
            RigDiscipline.systemRandomnessViolations(
                in: "let d = Double.random(in: 0..<1)")
                == [".random("])
        #expect(
            !RigDiscipline.systemRandomnessViolations(
                in: "var g = SystemRandomNumberGenerator()").isEmpty)
        #expect(
            RigDiscipline.systemRandomnessViolations(
                in: "let id = UUID(); let r = arc4random()")
                == ["arc4random", "UUID("])
        #expect(
            RigDiscipline.systemRandomnessViolations(
                in: "let draw = sampler.nextUniform()").isEmpty)
    }

    @Test("NO idle-stack file touches system randomness (§9.4)")
    func idleStackIsSeededOnly() throws {
        for name in RigDiscipline.rigImplementationFiles {
            let source = try RigDiscipline.readRigFile(name)
            #expect(
                RigDiscipline.systemRandomnessViolations(in: source).isEmpty,
                "\(name) draws from system entropy (§9.4: seeded idleSeed only)")
        }

        // Non-vacuity, direction B: the scanner demonstrably sees the SEEDED
        // construction the idle stack actually uses (the fixture above
        // covers the firing direction).
        let sampler = try RigDiscipline.readRigFile(
            "Sources/MomoCharacter/MomoIdleRandom.swift")
        #expect(sampler.contains("SeededGenerator"))
    }

    // MARK: - R4: hex confinement (defense-in-depth over the new files)

    @Test("The hex scanner fires on palette-style literals and passes token use")
    func hexScannerFixture() {
        // The scanner reports PATTERNS that fired (a file-level defense
        // scan): two hex literals still mean the one "0x" pattern — any hit
        // fails the scan.
        #expect(RigDiscipline.hexColorViolations(
            in: "MomoColorToken(light: 0xF1E3D0, dark: 0xE3D1BC)") == ["0x"])
        #expect(RigDiscipline.hexColorViolations(
            in: "Color(red: 0.5, green: 0.4, blue: 0.3)") == ["Color(red:"])
        #expect(RigDiscipline.hexColorViolations(
            in: "let c = token.resolve(.light)").isEmpty)
    }

    @Test("NO hand-written rig file carries hex or RGB literals (R4)")
    func rigFilesAreHexFree() throws {
        for name in RigDiscipline.rigImplementationFiles {
            let source = try RigDiscipline.readRigFile(name)
            #expect(RigDiscipline.hexColorViolations(in: source).isEmpty,
                    "\(name) carries a color literal (R4: palette files only)")
        }
    }

    @Test("The hex scanner sees the sanctioned palette sites (non-vacuity)")
    func hexScannerSeesThePalette() throws {
        let palette = try RigDiscipline.readRigFile(
            "Sources/MomoCharacter/MomoCharacterPalette.swift")
        #expect(!RigDiscipline.hexColorViolations(in: palette).isEmpty)
    }

    // MARK: - R3: ambient-time purity

    @Test("The ambient-time scanner fires on direct clock reads")
    func ambientScannerFixture() {
        #expect(RigDiscipline.ambientTimeViolations(in: "let t = Date.now") == ["Date.now"])
        #expect(RigDiscipline.ambientTimeViolations(in: "Date()").count == 1)
        #expect(RigDiscipline.ambientTimeViolations(in: "timeSource.now()").isEmpty)
    }

    @Test("The clock and rig view contain NO ambient time reads (R3)")
    func clockAndViewAreAmbientFree() throws {
        let scanned = [
            "Sources/MomoCharacter/CharacterClock.swift",
            "Sources/MomoCharacter/MomoRigView.swift",
        ]
        for name in scanned {
            let source = try RigDiscipline.readRigFile(name)
            #expect(RigDiscipline.ambientTimeViolations(in: source).isEmpty,
                    "\(name) reads ambient time (R3: injected time source only)")
        }
    }

    // MARK: - scenePhase → the one call

    @Test("The pure mapping: .active resumes; .inactive and .background pause")
    func scenePhaseMapping() {
        #expect(RigMotionViewMapping.clockAction(for: .active) == .resume)
        #expect(RigMotionViewMapping.clockAction(for: .inactive) == .pause)
        #expect(RigMotionViewMapping.clockAction(for: .background) == .pause)
    }

    @Test("The view wires scenePhase through the mapping (structural presence pin)")
    func viewWiresScenePhase() throws {
        let source = try RigDiscipline.readRigFile("Sources/MomoCharacter/MomoRigView.swift")
        #expect(RigDiscipline.mentionsScenePhaseWiring(in: source))

        // Non-vacuity of the presence check itself.
        #expect(!RigDiscipline.mentionsScenePhaseWiring(in: "struct V: View { var body: some View { EmptyView() } }"))
        #expect(!RigDiscipline.mentionsScenePhaseWiring(in: "onChange(of: x) { clock.resume() }"))
    }
}
