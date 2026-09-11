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

    /// The hand-written rig implementation files (TASK-026's rig core,
    /// TASK-027's idle stack: sampler, events, variants, expressions,
    /// sequencer, plus TASK-028's reaction/state stack: motion vocabulary,
    /// clip table, choreography, handshakes, moments, director, overlay).
    /// The pin on the count keeps the scanned set from silently shrinking;
    /// splitting or adding a file updates this list AND its pins
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
        "Sources/MomoCharacter/MomoReactionMotion.swift",
        "Sources/MomoCharacter/MomoReactionClips.swift",
        "Sources/MomoCharacter/MomoReactionClipMotion.swift",
        "Sources/MomoCharacter/MomoHandshakeChoreography.swift",
        "Sources/MomoCharacter/MomoMoments.swift",
        "Sources/MomoCharacter/MomoReactionDirector.swift",
        "Sources/MomoCharacter/MomoReactionState.swift",
        "Sources/MomoCharacter/MomoReactionOverlay.swift",
        "Sources/MomoCharacter/MomoReduceMotion.swift",
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

    // MARK: - TASK-034: the composed Home samples the director (wire check)

    /// Presence check that the composed Home canvas passes the rig's
    /// `reactionMotion` closure (TASK-034 R3). The director machinery is
    /// fully headless-tested, but the one leg every green suite missed
    /// (REVIEW-TASK-034 F-1) was the view→rig wiring itself — the frozen
    /// identity default served every frame — so the wire is pinned
    /// structurally at its construction site: the rig must be constructed
    /// with the app model's closure factory.
    static func mentionsHomeReactionWiring(in source: String) -> Bool {
        source.contains("MomoRigView(") &&
        source.contains("reactionMotion: appModel.reactionMotion()")
    }

    // MARK: - TASK-035 R9: the care loop's four structural wires
    // (the F-1 rule again: headless suites cannot see a view wire)

    /// (a) The report drain: the app model's director fold must drain the
    /// successor's reports and submit each one — the exactly-once bridge
    /// from the pure director to the engine (R1). A fold that applies but
    /// never submits (or submits the PRE-fold state's reports, double-
    /// delivering) fails the shape.
    static func mentionsReportDrain(in source: String) -> Bool {
        source.contains("successor.drainReports()") &&
        source.contains("submit(entry.report)")
    }

    /// (b) The play surface: the canvas gesture layer must gate on the
    /// round being in flight and route to the app model's fingertip
    /// stream there (R2) — a drag during a round never dispatches a pat
    /// intent. Absent either half (no gate, or no stream), the check
    /// fails.
    static func mentionsPlayFingertipSurface(in source: String) -> Bool {
        source.contains("appModel.isPlayRoundInFlight") &&
        source.contains("appModel.sendFingertip(offset:")
    }

    /// (c) The Done pill: the quiet pill must exist under its layout
    /// identity AND route its tap through the app model's stop event (R6)
    /// — never a UI-only dismissal, never an `.appHidden` stand-in.
    static func mentionsDonePillStopWire(in source: String) -> Bool {
        source.contains("home.playDonePill") &&
        source.contains("appModel.stopPlayRound()")
    }

    /// (d) The stillness ticker (REVIEW-TASK-035 F-1): while a round is in
    /// flight the app model folds a `moving: false` fingertip sample every
    /// authored second — the passive round's ONLY fold source, and the
    /// thing that advances the solo pacer to its payoff and
    /// `playRoundFinished` report (R2). Display-state folds are
    /// edge-gated, so a finger-less round never completes without it:
    /// delete or disconnect any leg and every suite stays green while no
    /// solo round ever auto-ends. Each leg names one breakage shape — the
    /// authored cadence constant (ticker deleted), the sleep that reads it
    /// (cadence decoupled to a literal), the stillness payload folded
    /// into the director (fold disconnected from the event path), and the
    /// reconcile's start wire (gating broken — never started).
    static func mentionsPlayStillnessTicker(in source: String) -> Bool {
        source.contains("static let playTickerSeconds") &&
        source.contains("Task.sleep(for: .seconds(Self.playTickerSeconds))") &&
        source.contains("moving: false,") &&
        source.contains("playTickerTask = Task { await runPlayTicker() }")
    }

    // MARK: - TASK-036 R9: the quest moments' structural wires
    // (the F-1 rule again: headless suites cannot see a view wire)

    /// (e) The `.deliverMoments` arm: the greeting EXCLUDED from the event
    /// fold (the state-born `.displayState` door keeps it — folding it here
    /// too would double-render through both doors), the remainder folded
    /// through the director's `.moments` event, and the haptic kinds gated
    /// on the user's setting read AT DELIVERY. Absent any leg the fan-out
    /// degrades silently — the greeting double-fires, moments drop on the
    /// floor, or haptics play past the setting.
    static func mentionsMomentFanOut(in source: String) -> Bool {
        source.contains("case .deliverMoments(let moments):") &&
        source.contains("QuestMomentSupport.eventBornMoments(moments)") &&
        source.contains("foldDirector(.moments(eventBorn") &&
        source.contains("hapticsEnabled: state.settings.hapticsEnabled")
    }

    /// (f) The director's completion advance: the L4 completion block must
    /// release the queue at the completion instant — the vacated-slot site
    /// of the three advance sites. (The FIFO behavior is also pinned in
    /// `MomoMomentQueueTests`; this is the F-1 defense-in-depth — a deleted
    /// advance leg is a silent stall no other suite's SHAPE can name.)
    static func mentionsMomentQueueAdvance(in source: String) -> Bool {
        source.contains(
            "advanceMomentQueue(at: moment.start + MomoMoments.duration(for: moment.moment))")
    }

    /// (g) The banner's two wires: the auto-fade TASK starts when a
    /// celebration shows (the authored ~4 s fade — not a detached timer),
    /// and the banner view's tap routes through the app model's
    /// `dismissCelebration()` — never a UI-only dismissal.
    static func mentionsCelebrationAutoFade(in source: String) -> Bool {
        source.contains("activeCelebrationStage = stage") &&
        source.contains("celebrationTask = Task { await autoFadeCelebration() }")
    }

    static func mentionsBannerDismissWire(in source: String) -> Bool {
        source.contains("home.celebrationBanner") &&
        source.contains("appModel.dismissCelebration()")
    }

    // MARK: - TASK-037 R5: the room scene's static-scene discipline
    // (the F-1 rule again: headless suites cannot see a view's construction)

    /// Substrings that would mean the room scene carries an interactive
    /// surface (FR-3 AC-2: zero interactivity — no actions, no gestures, no
    /// hit-testing). Over-matching is the safe direction for a defense
    /// scan: any hit fails.
    static let roomInteractiveTokens: [String] = [
        "Button(",
        ".onTapGesture",
        ".gesture(",
        ".highPriorityGesture(",
        ".simultaneousGesture(",
        "allowsHitTesting(",
        "LongPressGesture",
        "DragGesture",
    ]

    static func roomInteractiveViolations(in source: String) -> [String] {
        roomInteractiveTokens.filter { source.contains($0) }
    }

    /// Presence check that the room scene is ONE accessibility element
    /// carrying the image trait and a composed label (FR-3 AC-3 / UX §10
    /// row 435): the region flattened with `.ignore`, announced as an
    /// image, carrying the label. Absent any leg the scene reads as bare
    /// canvas or as traversable children.
    static func mentionsRoomSceneAccessibility(in source: String) -> Bool {
        source.contains(".accessibilityElement(children: .ignore)") &&
        source.contains(".accessibilityAddTraits(.isImage)") &&
        source.contains(".accessibilityLabel(")
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
        #expect(RigDiscipline.rigImplementationFiles.count == 22) // scanned set pinned
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

    @Test("The composed Home wires the rig's reaction closure (structural presence pin)")
    func homeWiresReactionMotion() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/HomeView.swift")
        #expect(RigDiscipline.mentionsHomeReactionWiring(in: source))

        // Non-vacuity of the presence check itself: the F-1 shape — a
        // MomoRigView construction with the closure argument absent — must
        // fail the check.
        #expect(!RigDiscipline.mentionsHomeReactionWiring(in: """
            MomoRigView(
                displayState: state,
                tier: .full,
                clock: clock,
                stageSide: 260
            )
            """))
    }

    // MARK: - TASK-035 R9: the care loop's four structural wires

    @Test("The app model drains the director's reports into the engine (R1 wire pin)")
    func appModelDrainsReports() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/MomoAppModel.swift")
        #expect(RigDiscipline.mentionsReportDrain(in: source))

        // Non-vacuity: a fold that applies but never drains fails — the
        // reports would silently vanish (and the exactly-once bridge with
        // them).
        #expect(!RigDiscipline.mentionsReportDrain(in: """
            var successor = director
            successor.apply(event)
            director = successor
            """))
    }

    @Test("The in-flight-play drag branch streams fingertips (R2 wire pin)")
    func playSurfaceStreamsFingertips() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/HomeCanvasTouchLayer.swift")
        #expect(RigDiscipline.mentionsPlayFingertipSurface(in: source))

        // Non-vacuity: a gesture layer without the gate (or without the
        // stream) fails — the TASK-034 shape where every drag classifies.
        #expect(!RigDiscipline.mentionsPlayFingertipSurface(in: """
            .onChanged { value in
                guard !touchIsDown else { noteMovement(value); return }
                touchIsDown = true
                downStamp = appModel.touchBegan(zone: zone(at: value.startLocation))
            }
            """))
    }

    @Test("The Done pill routes the stop event through the app model (R6 wire pin)")
    func donePillRoutesStop() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/HomeView.swift")
        #expect(RigDiscipline.mentionsDonePillStopWire(in: source))

        // Non-vacuity: a pill that exists but dismisses LOCALLY (no stop
        // route) fails the shape — the lie R6 forbids.
        #expect(!RigDiscipline.mentionsDonePillStopWire(in: """
            Button { isPillShown = false } label: { Text("Done") }
                .accessibilityIdentifier("home.playDonePill")
            """))
    }

    @Test("The passive round's stillness ticker folds on the authored cadence (R2 wire pin)")
    func playStillnessTickerDrivesTheSoloRound() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/MomoAppModel.swift")
        #expect(RigDiscipline.mentionsPlayStillnessTicker(in: source))

        // Non-vacuity: the F-1 shape — a loop that still sleeps on the
        // authored cadence but never folds the stillness sample into the
        // director and is never started. Every suite stays green (the
        // solo pacer simply never advances), so the guard must fail it.
        #expect(!RigDiscipline.mentionsPlayStillnessTicker(in: """
            private func runPlayTicker() async {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(Self.playTickerSeconds))
                    lastPlayFingertipOffset = nil
                }
            }
            """))
    }

    // MARK: - TASK-036 R9: the quest moments' structural wires

    @Test("The .deliverMoments arm excludes the greeting, folds the rest, gates the haptics (R9e)")
    func deliverMomentsArmWiring() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/MomoAppModel.swift")
        #expect(RigDiscipline.mentionsMomentFanOut(in: source))

        // Non-vacuity: an arm that folds the WHOLE batch (the greeting
        // would double-render through both doors) and fires the haptics
        // ungated fails every leg but the fold.
        #expect(!RigDiscipline.mentionsMomentFanOut(in: """
            case .deliverMoments(let moments):
                foldDirector(.moments(moments, at: 0))
                for kind in MomentHapticKind.deliveryKinds(for: moments, hapticsEnabled: true) {
                    momentHapticSink(kind)
                }
            """))
    }

    @Test("The L4 completion block releases the moment queue (R9f)")
    func completionAdvancesQueue() throws {
        let source = try RigDiscipline.readRigFile(
            "Sources/MomoCharacter/MomoReactionDirector.swift")
        #expect(RigDiscipline.mentionsMomentQueueAdvance(in: source))

        // Non-vacuity: a completion block that reports and nils the slot
        // but never advances (the silent stall — the queue waits forever)
        // fails the shape.
        #expect(!RigDiscipline.mentionsMomentQueueAdvance(in: """
            if var moment, t >= moment.start + MomoMoments.duration(for: moment.moment) {
                if !moment.reported {
                    report(.momentFinished(moment.moment), at: moment.start)
                    moment.reported = true
                }
                self.moment = nil
            }
            """))
    }

    @Test("The banner's fade task and tap-dismiss route through the app model (R9g)")
    func celebrationWires() throws {
        let appModel = try RigDiscipline.readRigFile("Apps/Momo/MomoAppModel.swift")
        let view = try RigDiscipline.readRigFile("Apps/Momo/HomeView.swift")
        #expect(RigDiscipline.mentionsCelebrationAutoFade(in: appModel))
        #expect(RigDiscipline.mentionsBannerDismissWire(in: view))

        // Non-vacuity, both directions: a banner that dismisses through
        // local view state (a UI-only dismissal) fails the wire, and a
        // celebration shown with a detached timer instead of the fade
        // task fails the model half.
        #expect(!RigDiscipline.mentionsBannerDismissWire(in: """
            Button { bannerVisible = false } label: { Text(line) }
                .accessibilityIdentifier("home.celebrationBanner")
            """))
        #expect(!RigDiscipline.mentionsCelebrationAutoFade(in: """
            activeCelebrationStage = stage
            DispatchQueue.main.asyncAfter(deadline: .now() + 4) { bannerVisible = false }
            """))
    }

    // MARK: - TASK-037 R5: the room scene's static-scene discipline

    @Test("The Room tab is interaction-free and ONE labeled image element (R5)")
    func roomSceneIsStaticAndSingleElement() throws {
        let source = try RigDiscipline.readRigFile("Apps/Momo/RoomView.swift")
        #expect(RigDiscipline.roomInteractiveViolations(in: source).isEmpty,
                "RoomView carries an interactive surface (FR-3 AC-2: static means static)")
        #expect(RigDiscipline.mentionsRoomSceneAccessibility(in: source),
                "RoomView's scene must be ONE image element with a composed label (FR-3 AC-3)")

        // Non-vacuity, both directions — a fixture with SOME legs but not
        // all must fail. (a) The one-element construction wrapped around a
        // Button: the a11y shape is right, the interactivity is not, so the
        // interaction scan fires.
        #expect(!RigDiscipline.roomInteractiveViolations(in: """
            .accessibilityElement(children: .ignore)
            .accessibilityAddTraits(.isImage)
            .accessibilityLabel("room")
            Button("Decorate") { }
            """).isEmpty)
        // (b) An interaction-free canvas flattened only as a container —
        // no `.ignore`, no image trait, no label: the scene would read as
        // traversable chrome, so the presence check fails.
        #expect(!RigDiscipline.mentionsRoomSceneAccessibility(in: """
            Canvas { context, size in context.fill(path, with: .color(token)) }
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("room.scene")
            """))
    }

    // MARK: - TASK-029: the RM environment read is the view's alone (R1)

    @Test("accessibilityReduceMotion is read ONLY in the view's environment mapping")
    func reduceMotionEnvironmentReadIsViewScoped() throws {
        // The `scenePhase` firewall, extended to the RM flag: no pure
        // layer may read ambient accessibility state — the flag arrives
        // INJECTED (the view's environment read is its only source).
        let characterDir = "Sources/MomoCharacter"
        let files = try FileManager.default
            .contentsOfDirectory(atPath: characterDir)
            .filter { $0.hasSuffix(".swift") }
        #expect(!files.isEmpty)
        for file in files {
            let source = try RigDiscipline.readRigFile("\(characterDir)/\(file)")
            let reads = source.contains("accessibilityReduceMotion")
            if file == "MomoRigView.swift" {
                #expect(reads, "the view's default source should be present")
            } else {
                #expect(!reads, "\(file) reads ambient accessibility state (R1)")
            }
        }
    }

    @Test("RM leaves the glyph tier byte-identical: the AOD branch renders the .rest constant")
    func glyphTierIsFlagFree() throws {
        // The glyph tier is already static (TASK-026) — the view's AOD
        // branch renders the CONSTANT rest pose (no clock, no model, no
        // flag input), so RM cannot change what it paints. Pinned as a
        // structural wire check (the branch's exact shape), plus the
        // painted transforms are a pure function of `.rest` (recomputed —
        // identical, no ambient input).
        let source = try RigDiscipline.readRigFile("Sources/MomoCharacter/MomoRigView.swift")
        #expect(source.contains("tier == .glyph"))
        #expect(source.contains("rigCanvas(pose: .rest)"))
        let transforms = RigLayerTree.slots(for: .glyph).map {
            RigLayerTree.affineTransform(of: $0, at: .rest)
        }
        let again = RigLayerTree.slots(for: .glyph).map {
            RigLayerTree.affineTransform(of: $0, at: .rest)
        }
        #expect(transforms == again)
        // Non-vacuity: the shape pin fires on the real file.
        #expect(try !RigDiscipline.readRigFile("Sources/MomoCharacter/RigLayerTree.swift")
            .contains("rigCanvas(pose: .rest)"))
    }
}
