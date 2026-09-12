import Foundation

/// The TASK-044 clock scans over `Apps/MomoWatch` — pure text predicates
/// mirroring the `WatchPatScan` mechanism (duplicated per test-support
/// convention), pinning D20's "no ambient time" law in the Watch target:
///
/// 1. **Ambient-clock ban** — no `Apps/MomoWatch` production source may
///    READ ambient time: the tokens `Date()`, `Date.now`, and
///    `Calendar.current` are banned in comment-stripped code. Time enters
///    the Watch exclusively through injection (`EngineClock` / a
///    `Calendar` at the app model's seams), which is what keeps quest
///    cascades, journal timestamps, and the pat estimator deterministic
///    under test and correct across timezone changes and the 23:30
///    offline pat.
///    **Exclusion rule (documented):** the ban structurally covers the
///    production target only — every test target (`Tests/`, the UI-test
///    bundles) sits outside the scanned set because harness code
///    legitimately derives EXPECTED values from ambient time (the
///    stale-fixture hour derivation reads the runner's clock). Inside
///    `Apps/MomoWatch` there is NO DEBUG carve-out: the fixture seam ships
///    in the same files and needs no clock (verified as it stands); a
///    future DEBUG leg that needs time must take it through the same
///    injected seams, or this scan trips.
/// 2. **The recompute's injected read** — `recomputeQuestLine()`'s body
///    must read the injected wall clock (`wallClock.now()`): the quest
///    cascade is THE clock-sensitive computation (UX-9, §10.4's stale row),
///    and D20 pins its hour to the injected source — a future refactor
///    that reverts it to ambient time fails here even before the
///    ambient-token ban, because the injected read is gone.
///
/// Every predicate scans COMMENT-STRIPPED text (`MomoKitDisciplineScan
/// .strippingComments`), and findings carry the guard's name so a mutation
/// bite can assert EXACTLY one guard went red.
enum WatchClockScan {

    struct Finding: Equatable {
        let guardName: String
        let file: String
        let detail: String
    }

    static let ambientClockGuard = "the Watch target reads no ambient clock"
    static let injectedClockGuard = "the quest recompute reads the injected wall clock"

    /// The file expected to hold the clock-injected recompute.
    static let appModelFileName = "MomoWatchAppModel.swift"

    /// The ambient-time spellings banned from Watch code (D20). The bare
    /// static `Date.now` is banned beside the call spelling — it is the
    /// same ambient read without the parens.
    static let bannedClockTokens: [String] = ["Date()", "Date.now", "Calendar.current"]

    // MARK: - Guard 1: no ambient clock anywhere in the target

    static func ambientClockViolations(files: [(name: String, contents: String)]) -> [Finding] {
        files.flatMap { file -> [Finding] in
            let stripped = MomoKitDisciplineScan.strippingComments(from: file.contents)
            return bannedClockTokens.filter { stripped.contains($0) }.map { token in
                Finding(
                    guardName: ambientClockGuard, file: file.name,
                    detail: "banned ambient-clock token in Apps/MomoWatch: \(token) — time is injected (D20)"
                )
            }
        }
    }

    // MARK: - Guard 2: the recompute reads the injected wall clock

    static func injectedClockViolations(files: [(name: String, contents: String)]) -> [Finding] {
        guard let model = files.first(where: { $0.name == appModelFileName }) else {
            return [Finding(
                guardName: injectedClockGuard, file: appModelFileName,
                detail: "file missing from Apps/MomoWatch"
            )]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: model.contents)
        guard let recompute = body(of: "func recomputeQuestLine", in: stripped) else {
            return [Finding(
                guardName: injectedClockGuard, file: appModelFileName,
                detail: "recomputeQuestLine body not found"
            )]
        }
        if !recompute.contains("wallClock.now()") {
            return [Finding(
                guardName: injectedClockGuard, file: appModelFileName,
                detail: "recomputeQuestLine reads no injected clock — the cascade hour must come from wallClock.now() (D20), never ambient time"
            )]
        }
        return []
    }

    // MARK: - Body extraction

    /// The body from `marker` to the first member-level ender (the
    /// `WatchQuestScan.body` shape): both `func` spellings are enders
    /// because a following `private func` does not match the plain one.
    private static func body(of marker: String, in stripped: String) -> Substring? {
        guard let markerRange = stripped.range(of: marker) else { return nil }
        let rest = stripped[markerRange.upperBound...]
        let end = ["\n    func ", "\n    private func ", "\n    static func ", "\n}"]
            .compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<end]
    }
}
