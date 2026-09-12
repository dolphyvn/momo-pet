import Foundation

/// The TASK-042 pat scans over `Apps/MomoWatch` — pure text predicates
/// mirroring the `WatchGlanceScan` mechanism (duplicated per test-support
/// convention), pinning the three seams that make the Watch pat genuinely
/// 05-technical-architecture §6.4's offline-first flow:
///
/// 1. **Journal single-writer (O1)** — `IntentJournal(` may appear in
///    exactly ONE `Apps/MomoWatch` file, the `MomoWatchPersister+Journal`
///    extension. A second touch site — a direct journal read or write in
///    the app model or a view — reintroduces a concurrent writer the
///    one-writer actor was built to prevent (the seq derivation's
///    correctness leans on it).
/// 2. **Pat-flow order (R3 + §6.4)** — `pat()` is the IMMEDIATE leg: the
///    state-distinct reaction fold precedes the deferred task, and no
///    journal or send call may ride the synchronous path. `finishPat()` is
///    the durable leg IN ORDER: the estimate's pending read, the haptic
///    INSIDE the `hapticsEnabled` gate and BEFORE the journal I/O (the
///    haptic "fires first"), then the append, and the send ONLY after the
///    append landed (a send-before-append could emit a pat the journal
///    never held — a crash would strand a delivered intent with no durable
///    record). Exactly TWO send legs exist in the whole target, ENUMERATED
///    (TASK-044 R6): the pat drain in `finishPat()` and the launch sweep's
///    re-enqueue in `flushStrandedJournal()` — a THIRD site fails the
///    census, and the finishPat order pins are untouched.
/// 3. **Haptic seam (R6)** — the semantic seam protocol exists; the
///    platform touch (`WKInterfaceDevice.current().play(`) appears in
///    exactly one place, the live conformance; and the seam declares its
///    semantics-typed `play`, so the gate decision never leaks into it.
///
/// Every predicate scans COMMENT-STRIPPED text (`MomoKitDisciplineScan
/// .strippingComments`), and findings carry the guard's name so a mutation
/// bite can assert EXACTLY one guard went red.
enum WatchPatScan {

    struct Finding: Equatable {
        let guardName: String
        let file: String
        let detail: String
    }

    static let journalWriterGuard = "the intent journal has one writer"
    static let patFlowGuard = "the pat flow is immediate locally, durable in order"
    static let hapticSeamGuard = "the haptic seam is the single platform touch"

    /// The file expected to hold every journal touch (the O1 census target).
    static let journalFileName = "MomoWatchPersister+Journal.swift"
    /// The file expected to hold the pat flow and the haptic seam.
    static let patFileName = "MomoWatchPat.swift"

    // MARK: - Guard 1: the journal has one writer

    /// `IntentJournal(` must appear in exactly one `Apps/MomoWatch` file —
    /// the persister's journal extension.
    static func journalWriterViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        let touching = files.filter { file in
            MomoKitDisciplineScan.strippingComments(from: file.contents)
                .contains("IntentJournal(")
        }
        if touching.count != 1 || touching.first?.name != journalFileName {
            let names = touching.map(\.name).sorted().joined(separator: ", ")
            findings.append(Finding(
                guardName: journalWriterGuard,
                file: touching.count == 1 ? touching[0].name : "\(touching.count) files",
                detail: "IntentJournal( must be touched in exactly one file (\(journalFileName)), found in: \(names.isEmpty ? "none" : names)"
            ))
        }
        return findings
    }

    // MARK: - Guard 2: the pat flow's shape and order

    /// The two legs' internal order, pinned above.
    static func patFlowViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let patFile = files.first(where: { $0.name == patFileName }) else {
            return [Finding(guardName: patFlowGuard, file: patFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: patFile.contents)

        // The immediate leg: reaction fold BEFORE the deferred durable leg;
        // no journal append and no send on the synchronous path.
        if let pat = body(of: "func pat(", in: stripped) {
            if let foldIndex = pat.range(of: "WatchPatPlan.reactionKind(for:")?.lowerBound,
               let taskIndex = pat.range(of: "Task {")?.lowerBound {
                if foldIndex > taskIndex {
                    findings.append(Finding(
                        guardName: patFlowGuard, file: patFileName,
                        detail: "pat() defers the reaction behind the durable task — the local answer must fold FIRST"
                    ))
                }
            } else {
                findings.append(Finding(
                    guardName: patFlowGuard, file: patFileName,
                    detail: "pat() is missing its reaction fold or its deferred leg"
                ))
            }
            for banned in ["appendPat", "sendUserInfo"] where pat.contains(banned) {
                findings.append(Finding(
                    guardName: patFlowGuard, file: patFileName,
                    detail: "pat() runs durable-leg work inline: \(banned) — the immediate leg must never wait on I/O"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: patFlowGuard, file: patFileName,
                detail: "pat() body not found"
            ))
        }

        // The durable leg, in order: estimate read → gate → haptic →
        // append → send.
        if let finish = body(of: "func finishPat(", in: stripped) {
            for required in ["persister.pendingPatCount(", "persister.appendPat(", "transport.sendUserInfo(payload:"] {
                if !finish.contains(required) {
                    findings.append(Finding(
                        guardName: patFlowGuard, file: patFileName,
                        detail: "finishPat() is missing a durable leg: \(required)"
                    ))
                }
            }
            order(finish, "if snapshot.hapticsEnabled", before: "haptics.play(") {
                findings.append(Finding(
                    guardName: patFlowGuard, file: patFileName,
                    detail: "finishPat() plays the haptic OUTSIDE the hapticsEnabled gate — the toggle is read at pat time"
                ))
            }
            order(finish, "haptics.play(", before: "persister.appendPat(") {
                findings.append(Finding(
                    guardName: patFlowGuard, file: patFileName,
                    detail: "finishPat() journals before the haptic — the haptic fires FIRST (R3)"
                ))
            }
            order(finish, "persister.appendPat(", before: "transport.sendUserInfo(payload:") {
                findings.append(Finding(
                    guardName: patFlowGuard, file: patFileName,
                    detail: "finishPat() sends before (or regardless of) the journal append — only journaled events drain"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: patFlowGuard, file: patFileName,
                detail: "finishPat() body not found"
            ))
        }

        // Exactly the TWO enumerated send legs in the whole target (R6):
        // the pat drain in finishPat() and the launch sweep's re-enqueue in
        // flushStrandedJournal() — a third (or forged) site fails.
        let sendCount = files.reduce(0) { count, file in
            count + MomoKitDisciplineScan.strippingComments(from: file.contents)
                .components(separatedBy: "transport.sendUserInfo(payload:").count - 1
        }
        if sendCount != 2 {
            findings.append(Finding(
                guardName: patFlowGuard, file: patFileName,
                detail: "expected exactly 2 transport.sendUserInfo( legs in Apps/MomoWatch (the pat drain + the launch sweep), found \(sendCount)"
            ))
        }
        return findings
    }

    // MARK: - Guard 3: the haptic seam is the single platform touch

    /// The semantic seam protocol exists, the platform call lives in
    /// exactly one place, and the seam's method is the semantics-typed
    /// `play` (the gate never leaks into the seam — it stays the caller's).
    static func hapticSeamViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let patFile = files.first(where: { $0.name == patFileName }) else {
            return [Finding(guardName: hapticSeamGuard, file: patFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: patFile.contents)
        if !stripped.contains("protocol MomoWatchHaptics") {
            findings.append(Finding(
                guardName: hapticSeamGuard, file: patFileName,
                detail: "the injectable haptic seam protocol is missing"
            ))
        }
        if !stripped.contains("func play(_ haptic: WatchPatHaptic)") {
            findings.append(Finding(
                guardName: hapticSeamGuard, file: patFileName,
                detail: "the seam's method is not the semantics-typed play(_ haptic: WatchPatHaptic)"
            ))
        }
        let platformTouching = files.filter { file in
            MomoKitDisciplineScan.strippingComments(from: file.contents)
                .contains("WKInterfaceDevice.current().play(")
        }
        if platformTouching.count != 1 || platformTouching.first?.name != patFileName {
            let names = platformTouching.map(\.name).sorted().joined(separator: ", ")
            findings.append(Finding(
                guardName: hapticSeamGuard,
                file: platformTouching.count == 1 ? platformTouching[0].name : "\(platformTouching.count) files",
                detail: "WKInterfaceDevice.current().play( must appear in exactly one place (LiveWatchHaptics in \(patFileName)), found in: \(names.isEmpty ? "none" : names)"
            ))
        }
        return findings
    }

    // MARK: - Helpers

    /// Appends `violation` when `first` does not appear strictly before
    /// `then` in `text` (either missing fails too — the caller's required
    /// legs already report absences).
    private static func order(
        _ text: Substring,
        _ first: String,
        before then: String,
        _ violation: () -> Void
    ) {
        guard let firstIndex = text.range(of: first)?.lowerBound,
            let thenIndex = text.range(of: then)?.lowerBound else {
            return
        }
        if firstIndex > thenIndex {
            violation()
        }
    }

    /// The body from `marker` to the next four-space member declaration or
    /// the extension's closing brace (the `WatchGlanceScan.body` shape).
    private static func body(of marker: String, in stripped: String) -> Substring? {
        guard let markerRange = stripped.range(of: marker) else { return nil }
        let rest = stripped[markerRange.upperBound...]
        let end = ["\n    func ", "\n}"].compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<end]
    }
}
