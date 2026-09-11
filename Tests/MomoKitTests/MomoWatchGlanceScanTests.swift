import Foundation
import Testing

/// The TASK-041 structural guards over `Apps/MomoWatch` (the W1 target):
/// every production leg persists (receive renders latest-wins THEN
/// persists; the background transition persists too; exactly the two
/// legs exist), the target runs no engine surface (EPIC-008 AC-5 — the
/// Watch renders, it never derives), and the AOD branch is the static
/// glyph tier gated on the luminance environment through the RigLOD
/// mapping. The same layered non-vacuity as `MomoWatchWiringScanTests`:
/// fixture self-tests prove every predicate turns red on its violation in
/// BOTH stub directions (the load-bearing token stripped, and the token
/// present only in a comment — the comment-stripper must let neither fake
/// compliance nor mute a citation), and the standing tests are the
/// restore-green halves over the real tree.
@Suite("Watch glance scan — the W1 target renders and persists, never derives")
struct MomoWatchGlanceScanTests {

    // MARK: - Fixture self-tests, guard 1 (persist-on-receive)

    @Test("stub direction: a receive that renders but never persists fails its leg and the census")
    func receiveWithoutPersistFails() {
        let model = Self.model(
            receive: [
                "    func receiveContext(_ data: Data) async {",
                "        self.snapshot = snapshot",
                "    }",
            ],
            phase: Self.phaseWithPersist
        )
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.count == 2, "\(findings)")
        #expect(findings.allSatisfy { $0.guardName == WatchGlanceScan.persistGuard })
        #expect(findings.contains { $0.detail.contains("never persists the received snapshot") })
        #expect(findings.contains { $0.detail.contains("expected exactly 2 persister.persist(") })
    }

    @Test("stub direction: a receive that persists BEFORE rendering fails the order leg alone")
    func receivePersistBeforeRenderFails() {
        let model = Self.model(
            receive: [
                "    func receiveContext(_ data: Data) async {",
                "        await persister.persist(directory: directory, snapshot: snapshot)",
                "        self.snapshot = snapshot",
                "    }",
            ],
            phase: Self.phaseWithPersist
        )
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("persists BEFORE rendering") == true)
    }

    @Test("stub direction: a background transition without a persist fails its leg and the census")
    func phaseWithoutPersistFails() {
        let model = Self.model(
            receive: Self.receiveGreen,
            phase: [
                "    func scenePhaseChanged(to phase: ScenePhase) {",
                "        guard phase == .background, let snapshot else { return }",
                "    }",
            ]
        )
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.count == 2, "\(findings)")
        #expect(findings.contains { $0.detail.contains("never persists on the background transition") })
        #expect(findings.contains { $0.detail.contains("expected exactly 2 persister.persist(") })
    }

    @Test("stub direction: a third persist leg breaks the O1 census alone")
    func thirdPersistLegFails() {
        let model = Self.model(
            receive: Self.receiveGreen,
            phase: Self.phaseWithPersist,
            extra: "        _ = 0 // third leg marker\n        await persister.persist(directory: directory, snapshot: snapshot)\n    }\n    func extraLeg() async {\n        await persister.persist(directory: directory, snapshot: snapshot)"
        )
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("expected exactly 2 persister.persist(") == true)
    }

    @Test("stub direction: a comment-only persist cannot green the receive leg")
    func receiveCommentOnlyPersistFails() {
        let model = Self.model(
            receive: [
                "    func receiveContext(_ data: Data) async {",
                "        self.snapshot = snapshot",
                "        // await persister.persist(directory: directory, snapshot: snapshot)",
                "    }",
            ],
            phase: Self.phaseWithPersist
        )
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.count == 2, "\(findings)")
        #expect(findings.contains { $0.detail.contains("never persists the received snapshot") })
    }

    @Test("stub direction: a background persist placed before the background gate fails the phase ordering leg")
    func phasePersistBeforeGateFails() {
        let model = Self.model(
            receive: Self.receiveGreen,
            phase: [
                "    func scenePhaseChanged(to phase: ScenePhase) {",
                "        Task { await persister.persist(directory: directory, snapshot: snapshot) }",
                "        guard phase == .background, let snapshot else { return }",
                "    }",
            ]
        )
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("persists before gating on background") == true)
    }

    @Test("green fixture: render-then-persist receive + gated background persist produce no finding")
    func persistGreenFixturePasses() {
        let model = Self.model(receive: Self.receiveGreen, phase: Self.phaseWithPersist)
        let findings = WatchGlanceScan.persistViolations(files: [(name: WatchGlanceScan.appModelFileName, contents: model)])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 2 (no engine surface)

    @Test("stub direction: the shared engine derivation named in Watch code fails")
    func engineDerivationNamedFails() {
        let model = [
            "func render() -> CharacterDisplayState? {",
            "    makeCharacterDisplayState(engineState)",
            "}",
        ].joined(separator: "\n")
        let findings = WatchGlanceScan.noEngineViolations(files: [
            (name: WatchGlanceScan.appModelFileName, contents: model),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchGlanceScan.noEngineGuard)
        #expect(findings.first?.detail.contains("makeCharacterDisplayState(") == true)
    }

    @Test("stub direction: the quest cascade named in Watch code fails")
    func questCascadeNamedFails() {
        let view = [
            "func recascade(_ set: [QuestProgress], hour: Int) -> QuestGeneration.QuestLine {",
            "    QuestGeneration.cascade(questSet: set, localHour: hour)",
            "}",
        ].joined(separator: "\n")
        let findings = WatchGlanceScan.noEngineViolations(files: [
            (name: WatchGlanceScan.glanceFileName, contents: view),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("QuestGeneration.cascade(") == true)
    }

    @Test("a banned token cited only in a doc comment stays legal (the stripper must not mute citations)")
    func engineTokenCommentOnlyPasses() {
        let model = [
            "func render() -> CharacterDisplayState? {",
            "    // Never makeCharacterDisplayState( or AppModelPlanCore here —",
            "    // the Watch derives nothing (EPIC-008 AC-5).",
            "    nil",
            "}",
        ].joined(separator: "\n")
        let findings = WatchGlanceScan.noEngineViolations(files: [
            (name: WatchGlanceScan.appModelFileName, contents: model),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    @Test("green fixture: the sanctioned Watch shape — assembly over the snapshot's own fields — produces no finding")
    func noEngineGreenFixturePasses() {
        let model = [
            "func render(_ display: DisplayState, _ character: WatchCharacterDTO?) -> CharacterDisplayState? {",
            "    makeWatchCharacterDisplay(display: display, character: character)",
            "}",
        ].joined(separator: "\n")
        let findings = WatchGlanceScan.noEngineViolations(files: [
            (name: WatchGlanceScan.appModelFileName, contents: model),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 3 (AOD glyph branch)

    @Test("stub direction: a tier property not gated on the luminance environment fails that leg alone")
    func aodWithoutLuminanceGateFails() {
        let glance = Self.glance(tier: [
            "    private var tier: RigLODTier {",
            "        if model.aodPreview {",
            "            return .glyph",
            "        }",
            "        return RigLOD.tier(for: .watchForeground)",
            "    }",
        ])
        let findings = WatchGlanceScan.aodViolations(files: [(name: WatchGlanceScan.glanceFileName, contents: glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("luminance-reduced environment") == true)
    }

    @Test("stub direction: an AOD branch reverted to the foreground tier fails the glyph leg alone")
    func aodRevertedToForegroundFails() {
        let glance = Self.glance(tier: [
            "    private var tier: RigLODTier {",
            "        if isLuminanceReduced || model.aodPreview {",
            "            return RigLOD.tier(for: .watchForeground)",
            "        }",
            "        return RigLOD.tier(for: .watchForeground)",
            "    }",
        ])
        let findings = WatchGlanceScan.aodViolations(files: [(name: WatchGlanceScan.glanceFileName, contents: glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("static .glyph tier") == true)
    }

    @Test("stub direction: a locally spelled foreground tier fails the RigLOD leg alone")
    func aodLocalTierFails() {
        let glance = Self.glance(tier: [
            "    private var tier: RigLODTier {",
            "        if isLuminanceReduced || model.aodPreview {",
            "            return .glyph",
            "        }",
            "        return .glance",
            "    }",
        ])
        let findings = WatchGlanceScan.aodViolations(files: [(name: WatchGlanceScan.glanceFileName, contents: glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("RigLOD.tier(for: .watchForeground)") == true)
    }

    @Test("stub direction: a rig handed a locally chosen constant fails the computed-tier leg")
    func rigNotReceivingComputedTierFails() {
        let glance = Self.glance(tier: Self.tierGreen, rig: "MomoRigView(displayState: character, tier: .glance, clock: clock)")
        let findings = WatchGlanceScan.aodViolations(files: [(name: WatchGlanceScan.glanceFileName, contents: glance)])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("computed tier") == true)
    }

    @Test("green fixture: the luminance-gated glyph branch through RigLOD produces no finding")
    func aodGreenFixturePasses() {
        let glance = Self.glance(tier: Self.tierGreen)
        let findings = WatchGlanceScan.aodViolations(files: [(name: WatchGlanceScan.glanceFileName, contents: glance)])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - The standing scans over the real Watch target
    // (the restore-green halves; the mutation bites are recorded in the task file)

    @Test("Apps/MomoWatch as it stands persists on every receive and every background transition")
    func realTreeReceivePersists() throws {
        let sources = try KitRepo.momoWatchSources()
        #expect(!sources.isEmpty, "Apps/MomoWatch must exist and contain Swift sources")
        let findings = WatchGlanceScan.persistViolations(files: sources)
        #expect(findings.isEmpty, "persist-leg violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands names no engine surface in code")
    func realTreeRunsNoEngine() throws {
        let sources = try KitRepo.momoWatchSources()
        let findings = WatchGlanceScan.noEngineViolations(files: sources)
        #expect(findings.isEmpty, "no-engine violation: \(findings)")
    }

    @Test("Apps/MomoWatch as it stands renders the static glyph in AOD through the RigLOD mapping")
    func realTreeAODIsGlyph() throws {
        let sources = try KitRepo.momoWatchSources()
        let findings = WatchGlanceScan.aodViolations(files: sources)
        #expect(findings.isEmpty, "AOD violation: \(findings)")
    }

    // MARK: - Fixtures

    /// Assembles a fixture app-model file: the receive body, the phase body,
    /// and (optionally) an extra trailing chunk (the census fixtures' third
    /// leg). Bodies sit at four-space member indent so the scanner's
    /// declaration anchors hold.
    private static func model(receive: [String], phase: [String], extra: String? = nil) -> String {
        var lines = receive + phase
        if let extra {
            lines.append(extra)
        }
        return lines.joined(separator: "\n")
    }

    /// The green receive body: latest-wins render, then persist.
    private static let receiveGreen = [
        "    func receiveContext(_ data: Data) async {",
        "        self.snapshot = snapshot",
        "        await persister.persist(directory: directory, snapshot: snapshot)",
        "    }",
    ]

    /// The green phase body: gated on background, then persist.
    private static let phaseWithPersist = [
        "    func scenePhaseChanged(to phase: ScenePhase) {",
        "        guard phase == .background, let snapshot else { return }",
        "        Task { await persister.persist(directory: directory, snapshot: snapshot) }",
        "    }",
    ]

    /// Assembles a fixture glance file: the tier property plus a rig call
    /// site (the rig leg scans the whole stripped file; the tier legs scan
    /// the extracted property body).
    private static func glance(tier: [String], rig: String = "MomoRigView(displayState: character, tier: tier, clock: clock)") -> String {
        (tier + [rig]).joined(separator: "\n")
    }

    /// The green tier property: luminance gate, static glyph, RigLOD mapping.
    private static let tierGreen = [
        "    private var tier: RigLODTier {",
        "        if isLuminanceReduced || model.aodPreview {",
        "            return .glyph",
        "        }",
        "        return RigLOD.tier(for: .watchForeground)",
        "    }",
    ]
}
