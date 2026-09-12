import Foundation

/// The TASK-043 quest-cascade scans over `Apps/MomoWatch` — pure text
/// predicates mirroring the `WatchGlanceScan`/`WatchPatScan` mechanism
/// (duplicated per test-support convention), pinning the three seams that
/// make W1's live quest line genuinely the UX-13/UX §6.1 shape:
///
/// 1. **Display-only quest slot on the ONE live read** — `GlanceView`'s
///    quest slot body is a `Text` with NO action affordance (no `Button(`,
///    no `.onTapGesture`, no `.accessibilityAction` — UX §6.1's
///    display-only rule; the pat canvas and Pat pill stay the ONLY pat
///    targets, pinned by the whole-file census: exactly one of each). The
///    line's VALUE is the app model's stored live re-cascade: exactly one
///    `model.liveQuestLine` read and exactly one frozen
///    `.display.questLine` read (the belt-and-braces fallback) — a revert
///    to the frozen line, or a second unfallbacked read path, fails.
/// 2. **The four recompute legs** — `MomoWatchAppModel` defines
///    `recomputeQuestLine()` once and calls it at exactly FOUR legs (init,
///    receive steady shape, receive consume, scene activation). The
///    `scenePhaseChanged` body must gate the activation leg on
///    `phase == .active` BEFORE the recompute, and `receiveContext`'s body
///    must carry a call. A dropped leg (stale line after receive or
///    raise-to-wake) or an unreviewed fifth leg (an undeclared writer of
///    the stored state) fails.
/// 3. **No settings surface (UX-13)** — no `Apps/MomoWatch` source may name
///    a settings/toggle/navigation surface in CODE (`Toggle(`,
///    `SettingsLink(`, `NavigationStack(`, `TabView(`, `.sheet(`, `Form(`,
///    `navigationDestination`), and the whole target declares exactly ONE
///    `: View` (the glance). Settings are iPhone-owned and arrive via the
///    snapshot; a Watch settings screen — which would need its own view —
///    cannot appear without failing.
///
/// Every predicate scans COMMENT-STRIPPED text (`MomoKitDisciplineScan
/// .strippingComments`), and findings carry the guard's name so a mutation
/// bite can assert EXACTLY one guard went red.
enum WatchQuestScan {

    struct Finding: Equatable {
        let guardName: String
        let file: String
        let detail: String
    }

    static let questSlotGuard = "the quest slot is display-only on the one live read"
    static let recomputeLegsGuard = "the live line recomputes at the four legs"
    static let noSettingsSurfaceGuard = "no settings surface exists in the Watch target"

    /// The file expected to hold the quest slot + the pat-target census.
    static let glanceFileName = "GlanceView.swift"
    /// The file expected to hold the recompute legs.
    static let appModelFileName = "MomoWatchAppModel.swift"

    /// The settings/navigation surfaces banned from the Watch target's CODE
    /// (UX-13: settings are iPhone-owned; the doc comments may cite them —
    /// the stripper sees to it). The container types are banned in BOTH
    /// spellings — the init call (`Toggle(`) and the trailing-closure
    /// presentation (`NavigationStack {`) — since SwiftUI's ViewBuilder
    /// containers usually appear without a paren.
    static let bannedSettingsTokens: [String] = [
        "Toggle(",
        "SettingsLink(",
        "SettingsLink {",
        "NavigationStack(",
        "NavigationStack {",
        "TabView(",
        "TabView {",
        ".sheet(",
        ".sheet {",
        "Form(",
        "Form {",
        "navigationDestination",
    ]

    /// The action affordances banned from the quest SLOT's body (the whole
    /// file keeps exactly its two pat targets — censused below).
    static let slotBannedActionTokens: [String] = [
        "Button(",
        ".onTapGesture",
        ".accessibilityAction",
    ]

    // MARK: - Guard 1: the quest slot is display-only on the one live read

    static func questSlotViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let glance = files.first(where: { $0.name == glanceFileName }) else {
            return [Finding(guardName: questSlotGuard, file: glanceFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: glance.contents)

        // The slot's body: a Text, never an action affordance.
        if let slot = body(of: "func questSlot", in: stripped, enders: ["\n    private func ", "\n    private var ", "\n}"]) {
            if !slot.contains("Text(") {
                findings.append(Finding(
                    guardName: questSlotGuard, file: glanceFileName,
                    detail: "the quest slot does not render a Text — the slot is display-only"
                ))
            }
            for token in slotBannedActionTokens where slot.contains(token) {
                findings.append(Finding(
                    guardName: questSlotGuard, file: glanceFileName,
                    detail: "the quest slot carries an action affordance: \(token) — display-only (UX §6.1)"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: questSlotGuard, file: glanceFileName,
                detail: "questSlot body not found"
            ))
        }

        // The whole-file pat-target census: exactly the two targets.
        let buttonCount = stripped.components(separatedBy: "Button(").count - 1
        if buttonCount != 1 {
            findings.append(Finding(
                guardName: questSlotGuard, file: glanceFileName,
                detail: "expected exactly 1 Button( in GlanceView (the Pat pill), found \(buttonCount)"
            ))
        }
        let tapCount = stripped.components(separatedBy: ".onTapGesture").count - 1
        if tapCount != 1 {
            findings.append(Finding(
                guardName: questSlotGuard, file: glanceFileName,
                detail: "expected exactly 1 .onTapGesture in GlanceView (the pat canvas), found \(tapCount)"
            ))
        }

        // The one live read + the one frozen fallback.
        let liveReadCount = stripped.components(separatedBy: "model.liveQuestLine").count - 1
        if liveReadCount != 1 {
            findings.append(Finding(
                guardName: questSlotGuard, file: glanceFileName,
                detail: "expected exactly 1 model.liveQuestLine read (the stored re-cascade), found \(liveReadCount)"
            ))
        }
        let frozenCount = stripped.components(separatedBy: ".display.questLine").count - 1
        if frozenCount != 1 {
            findings.append(Finding(
                guardName: questSlotGuard, file: glanceFileName,
                detail: "expected exactly 1 .display.questLine read (the belt-and-braces fallback), found \(frozenCount)"
            ))
        }
        return findings
    }

    // MARK: - Guard 2: the four recompute legs

    /// One definition, exactly four call legs, the receive body carries a
    /// call, and the activation leg sits behind the `.active` gate.
    static func recomputeLegsViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let model = files.first(where: { $0.name == appModelFileName }) else {
            return [Finding(guardName: recomputeLegsGuard, file: appModelFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: model.contents)

        let definitionCount = stripped.components(separatedBy: "func recomputeQuestLine").count - 1
        if definitionCount != 1 {
            findings.append(Finding(
                guardName: recomputeLegsGuard, file: appModelFileName,
                detail: "expected exactly 1 recomputeQuestLine definition, found \(definitionCount)"
            ))
        }
        let totalCount = stripped.components(separatedBy: "recomputeQuestLine()").count - 1
        let callCount = totalCount - definitionCount
        if callCount != 4 {
            findings.append(Finding(
                guardName: recomputeLegsGuard, file: appModelFileName,
                detail: "expected exactly 4 recomputeQuestLine() call legs (init + receive steady + receive consume + scene activation), found \(callCount)"
            ))
        }

        // The receive body must carry a call (both receive legs live there).
        if let receive = body(of: "func receiveContext", in: stripped, enders: ["\n    func ", "\n    static func "]) {
            if !receive.contains("recomputeQuestLine()") {
                findings.append(Finding(
                    guardName: recomputeLegsGuard, file: appModelFileName,
                    detail: "receiveContext never recomputes the line — a receive must re-cascade the carried inputs"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: recomputeLegsGuard, file: appModelFileName,
                detail: "receiveContext body not found"
            ))
        }

        // The activation leg: gated on .active BEFORE the recompute.
        if let phase = body(of: "func scenePhaseChanged", in: stripped, enders: ["\n    func ", "\n    static func "]) {
            let activeIndex = phase.range(of: "phase == .active")?.lowerBound
            let recomputeIndex = phase.range(of: "recomputeQuestLine()")?.lowerBound
            if activeIndex == nil {
                findings.append(Finding(
                    guardName: recomputeLegsGuard, file: appModelFileName,
                    detail: "scenePhaseChanged does not gate the activation leg on the active phase"
                ))
            }
            if let activeIndex, let recomputeIndex, activeIndex > recomputeIndex {
                findings.append(Finding(
                    guardName: recomputeLegsGuard, file: appModelFileName,
                    detail: "scenePhaseChanged recomputes before gating on the active phase — the leg must be activation-scoped"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: recomputeLegsGuard, file: appModelFileName,
                detail: "scenePhaseChanged body not found"
            ))
        }
        return findings
    }

    // MARK: - Guard 3: no settings surface (UX-13)

    /// No settings/navigation surface in ANY Watch source's code, and the
    /// whole target declares exactly one `: View`.
    static func noSettingsViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        var viewCount = 0
        for file in files {
            let stripped = MomoKitDisciplineScan.strippingComments(from: file.contents)
            for token in bannedSettingsTokens where stripped.contains(token) {
                findings.append(Finding(
                    guardName: noSettingsSurfaceGuard, file: file.name,
                    detail: "settings/navigation surface named in Watch code: \(token) (UX-13 — settings are iPhone-owned)"
                ))
            }
            viewCount += stripped.components(separatedBy: ": View").count - 1
        }
        if viewCount != 1 {
            findings.append(Finding(
                guardName: noSettingsSurfaceGuard,
                file: viewCount == 1 ? glanceFileName : "\(viewCount) views",
                detail: "expected exactly 1 : View declaration in Apps/MomoWatch (the glance — a settings surface needs its own view), found \(viewCount)"
            ))
        }
        return findings
    }

    // MARK: - Body extraction

    /// The body from `marker` to the first `ender` occurrence (the
    /// `WatchGlanceScan.body` shape): members sit at four-space indent, so
    /// the next declaration anchors the body's end.
    private static func body(of marker: String, in stripped: String, enders: [String]) -> Substring? {
        guard let markerRange = stripped.range(of: marker) else { return nil }
        let rest = stripped[markerRange.upperBound...]
        let end = enders.compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<end]
    }
}
