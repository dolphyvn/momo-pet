import Foundation

/// The TASK-041 glance scans over `Apps/MomoWatch` — pure text predicates
/// mirroring the `WatchWiringScan` mechanism (duplicated per test-support
/// convention), pinning the three W1 seams that make the Watch target
/// genuinely the thing EPIC-008's AC-5 describes — a renderer, not a
/// second engine:
///
/// 1. **Persist-on-receive** — the receive body must render latest-wins
///    (`self.snapshot = snapshot`) BEFORE persisting
///    (`persister.persist(directory:` — §6.3's instant local render, then
///    the §5.6 write), the background transition must persist too (TR9),
///    and the file must carry EXACTLY the two production persist legs (the
///    O1 census — a third call site is a new writer leg that must land
///    with its own disclosure, not silently).
/// 2. **No engine** — no `Apps/MomoWatch` source may name the engine's
///    derivation or plan surfaces in CODE (`makeCharacterDisplayState(`,
///    `makeDisplayState(`, `EngineState`, `AppModelPlanCore`,
///    `AppModelTrigger`, `QuestGeneration.generate(`,
///    `QuestGeneration.cascade(`, `apply(trigger:`). The Watch renders the
///    snapshot it is given through MomoKit's `makeWatchCharacterDisplay`
///    assembly; it derives nothing (EPIC-008 AC-5; D-R5). Comment-stripped,
///    so a doc citation of a banned token stays legal and can never fake
///    compliance.
/// 3. **AOD glyph branch** — `GlanceView`'s tier property must gate on the
///    luminance-reduced environment (`isLuminanceReduced` INSIDE the tier
///    body), must return the STATIC `.glyph` tier there, and must reach the
///    foreground tier through the `RigLOD.tier(for: .watchForeground)`
///    mapping (never a locally spelled tier). A revert that renders the
///    full glance rig in AOD — or that bypasses the RigLOD band — fails.
///
/// Every predicate scans COMMENT-STRIPPED text (`MomoKitDisciplineScan
/// .strippingComments`), and findings carry the guard's name so a mutation
/// bite can assert EXACTLY one guard went red.
enum WatchGlanceScan {

    struct Finding: Equatable {
        let guardName: String
        let file: String
        let detail: String
    }

    static let persistGuard = "receive + background → persisted"
    static let noEngineGuard = "no engine surface in the Watch target"
    static let aodGuard = "AOD renders the static glyph tier"

    /// The file expected to hold the receive + persistence seams.
    static let appModelFileName = "MomoWatchAppModel.swift"
    /// The file expected to hold the AOD tier selection.
    static let glanceFileName = "GlanceView.swift"

    /// The engine surfaces banned from the Watch target's CODE (the doc
    /// comments may cite them — the stripper sees to it).
    static let bannedEngineTokens: [String] = [
        "makeCharacterDisplayState(",
        "makeDisplayState(",
        "EngineState",
        "AppModelPlanCore",
        "AppModelTrigger",
        "QuestGeneration.generate(",
        "QuestGeneration.cascade(",
        "apply(trigger:",
    ]

    // MARK: - Guard 1: every production leg persists

    /// The receive body must render latest-wins then persist (in that
    /// order), the background transition must persist, and the file must
    /// carry exactly the two production persist calls.
    static func persistViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let model = files.first(where: { $0.name == appModelFileName }) else {
            return [Finding(guardName: persistGuard, file: appModelFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: model.contents)
        // The receive body: from `func receiveContext` to the next method
        // declaration (members sit at four-space indent).
        if let receive = body(of: "func receiveContext", in: stripped, enders: ["\n    func ", "\n    static func "]) {
            if !receive.contains("self.snapshot = snapshot") {
                findings.append(Finding(
                    guardName: persistGuard, file: appModelFileName,
                    detail: "receiveContext does not render the snapshot latest-wins"
                ))
            }
            let persistIndex = receive.range(of: "persister.persist(directory:")?.lowerBound
            if persistIndex == nil {
                findings.append(Finding(
                    guardName: persistGuard, file: appModelFileName,
                    detail: "receiveContext never persists the received snapshot"
                ))
            }
            if let renderIndex = receive.range(of: "self.snapshot = snapshot")?.lowerBound,
               let persistIndex, renderIndex > persistIndex {
                findings.append(Finding(
                    guardName: persistGuard, file: appModelFileName,
                    detail: "receiveContext persists BEFORE rendering — §6.3's instant local render must come first"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: persistGuard, file: appModelFileName,
                detail: "receiveContext body not found"
            ))
        }
        // The background leg (TR9): the transition handler persists.
        if let phase = body(of: "func scenePhaseChanged", in: stripped, enders: ["\n    func ", "\n    static func "]) {
            let backgroundIndex = phase.range(of: "phase == .background")?.lowerBound
            let persistIndex = phase.range(of: "persister.persist(directory:")?.lowerBound
            if backgroundIndex == nil {
                findings.append(Finding(
                    guardName: persistGuard, file: appModelFileName,
                    detail: "scenePhaseChanged does not gate on the background phase"
                ))
            }
            if persistIndex == nil {
                findings.append(Finding(
                    guardName: persistGuard, file: appModelFileName,
                    detail: "scenePhaseChanged never persists on the background transition"
                ))
            }
            if let backgroundIndex, let persistIndex, backgroundIndex > persistIndex {
                findings.append(Finding(
                    guardName: persistGuard, file: appModelFileName,
                    detail: "scenePhaseChanged persists before gating on background — the foreground transition would write"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: persistGuard, file: appModelFileName,
                detail: "scenePhaseChanged body not found"
            ))
        }
        // The O1 census: exactly the two production persist legs.
        let persistCount = stripped.components(separatedBy: "persister.persist(directory:").count - 1
        if persistCount != 2 {
            findings.append(Finding(
                guardName: persistGuard, file: appModelFileName,
                detail: "expected exactly 2 persister.persist( legs (receive + background), found \(persistCount)"
            ))
        }
        return findings
    }

    // MARK: - Guard 2: the Watch target runs no engine

    /// No `Apps/MomoWatch` source may name the engine's derivation or plan
    /// surfaces in comment-stripped code.
    static func noEngineViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        for file in files {
            let stripped = MomoKitDisciplineScan.strippingComments(from: file.contents)
            for token in bannedEngineTokens where stripped.contains(token) {
                findings.append(Finding(
                    guardName: noEngineGuard, file: file.name,
                    detail: "engine surface named in Watch code: \(token)"
                ))
            }
        }
        return findings
    }

    // MARK: - Guard 3: the AOD branch is the static glyph

    /// The tier property must gate on the luminance environment INSIDE its
    /// body, return the static glyph there, and reach the foreground tier
    /// only through the RigLOD mapping; the rig view must receive that
    /// computed tier (`tier: tier`), never a locally chosen constant.
    static func aodViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let glance = files.first(where: { $0.name == glanceFileName }) else {
            return [Finding(guardName: aodGuard, file: glanceFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: glance.contents)
        guard let tier = body(of: "private var tier", in: stripped, enders: ["\n    private var ", "\n    private func "]) else {
            return [Finding(guardName: aodGuard, file: glanceFileName, detail: "the tier property body not found")]
        }
        if !tier.contains("isLuminanceReduced") {
            findings.append(Finding(
                guardName: aodGuard, file: glanceFileName,
                detail: "the tier property does not gate on the luminance-reduced environment"
            ))
        }
        if !tier.contains("return .glyph") {
            findings.append(Finding(
                guardName: aodGuard, file: glanceFileName,
                detail: "the AOD branch does not return the static .glyph tier"
            ))
        }
        if !tier.contains("RigLOD.tier(for: .watchForeground)") {
            findings.append(Finding(
                guardName: aodGuard, file: glanceFileName,
                detail: "the foreground tier is not taken through RigLOD.tier(for: .watchForeground)"
            ))
        }
        if !stripped.contains("tier: tier") {
            findings.append(Finding(
                guardName: aodGuard, file: glanceFileName,
                detail: "the rig view does not receive the computed tier (tier: tier)"
            ))
        }
        return findings
    }

    // MARK: - Body extraction

    /// The body from `marker` to the first `ender` occurrence (the
    /// `WatchWiringScan.pushArmBody` pattern generalized): members sit at
    /// four-space indent, so the next declaration anchors the body's end.
    private static func body(of marker: String, in stripped: String, enders: [String]) -> Substring? {
        guard let markerRange = stripped.range(of: marker) else { return nil }
        let rest = stripped[markerRange.upperBound...]
        let end = enders.compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<end]
    }
}
