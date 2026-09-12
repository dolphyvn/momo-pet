import Foundation

/// The TASK-044 launch-sweep scans over `Apps/MomoWatch` — pure text
/// predicates mirroring the `WatchPatScan` mechanism (duplicated per
/// test-support convention), pinning the seams that make the journal drain
/// genuinely §6.4's reconnect leg without ever outrunning a reset:
///
/// 1. **Sweep wiring (R1)** — the app model arms at activation completion
///    and drains at exactly the two receive decision legs: the init binds
///    the context sink, then the activation sink, then activates (the
///    sink-before-activate discipline extended to the arm); the consume
///    branch's flush follows its awaited `consumeWipe` (the persister's
///    mailbox must serve the sweep the POST-wipe journal) and the steady
///    branch's flush follows the watermark prune (already-applied entries
///    ride the prune's drop, sparing the wire); the decode-skip path
///    carries no flush call (it stays armed). The drain itself is one-shot
///    per arming, reads through the one-writer journal extension (O1)
///    BEFORE any send, and decides through `WatchSweepPlan`.
/// 2. **Transport arm signal (R1)** — the protocol declares the
///    `onActivation` sink and the activation delegate raises it: the
///    reconnect/cold-launch moment §6.1's VERIFY-AT-BUILD record pins as
///    the arm point (never a drain point — activation can precede the
///    pending context's delivery).
/// 3. **Event-driven only (§4.2)** — no `Timer(`/`scheduledTimer` token in
///    any production Watch source: the sweep fires at activation legs and
///    receive decisions, nothing else.
///
/// Every predicate scans COMMENT-STRIPPED text (`MomoKitDisciplineScan
/// .strippingComments`), and findings carry the guard's name so a mutation
/// bite can assert EXACTLY one guard went red.
enum WatchSweepScan {

    struct Finding: Equatable {
        let guardName: String
        let file: String
        let detail: String
    }

    static let sweepWiringGuard = "the launch sweep arms at activation and drains after a receive decision"
    static let transportArmGuard = "the transport raises activation completion to the executor"
    static let noTimersGuard = "the Watch target is event-driven only"

    static let appModelFileName = "MomoWatchAppModel.swift"
    static let transportFileName = "MomoWatchTransport.swift"
    static let journalFileName = "MomoWatchPersister+Journal.swift"

    // MARK: - Guard 1: the sweep wiring

    static func sweepWiringViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let appModel = files.first(where: { $0.name == appModelFileName }) else {
            return [Finding(guardName: sweepWiringGuard, file: appModelFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: appModel.contents)

        // The init's binding order: context sink, activation sink, activate.
        if let initBody = body(of: "init(", in: stripped) {
            if let contextIndex = initBody.range(of: "transport.onContextData")?.lowerBound,
                let activationIndex = initBody.range(of: "transport.onActivation")?.lowerBound,
                let activateIndex = initBody.range(of: "transport.activate()")?.lowerBound {
                if !(contextIndex < activationIndex && activationIndex < activateIndex) {
                    findings.append(Finding(
                        guardName: sweepWiringGuard, file: appModelFileName,
                        detail: "init() must bind onContextData, then onActivation, then activate() — the sink-before-activate discipline, three-legged"
                    ))
                }
            } else {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "init() is missing a transport binding (onContextData / onActivation / activate)"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: sweepWiringGuard, file: appModelFileName, detail: "init( body not found"
            ))
        }

        // The ARM: raises the flag and records the consumption baseline.
        if let arm = body(of: "func armLaunchSweep(", in: stripped) {
            order(arm, "sweepArmed = true", before: "consumedEraseCountAtArm = consumedEraseCount") {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "armLaunchSweep() must raise the flag before (or with) recording the consumed-count baseline"
                ))
            }
            for required in ["sweepArmed = true", "consumedEraseCountAtArm = consumedEraseCount"]
            where !arm.contains(required) {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "armLaunchSweep() is missing a leg: \(required)"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: sweepWiringGuard, file: appModelFileName, detail: "armLaunchSweep() body not found"
            ))
        }

        // The DRAIN: one-shot, mailbox read before send, plan-mediated.
        if let flush = body(of: "func flushStrandedJournal(", in: stripped) {
            for required in [
                "guard sweepArmed", "sweepArmed = false", "persister.pendingEvents(",
                "WatchSweepPlan.drainableEvents(", "consumedEraseCountNow:",
                "transport.sendUserInfo(payload:",
            ] where !flush.contains(required) {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "flushStrandedJournal() is missing a leg: \(required)"
                ))
            }
            order(flush, "persister.pendingEvents(", before: "transport.sendUserInfo(payload:") {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "flushStrandedJournal() sends before (or regardless of) the one-writer journal read — only read-then-verified events drain"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: sweepWiringGuard, file: appModelFileName, detail: "flushStrandedJournal() body not found"
            ))
        }

        // The decision legs: exactly two awaited flush calls target-wide;
        // the first after the consume branch's awaited wipe, the second
        // after the steady branch's watermark prune.
        let flushSites = positions(of: "await flushStrandedJournal()", in: stripped)
        if flushSites.count != 2 {
            findings.append(Finding(
                guardName: sweepWiringGuard, file: appModelFileName,
                detail: "the launch sweep must fire at exactly 2 receive decision legs (consume + steady), found \(flushSites.count)"
            ))
        } else {
            let beforeFirst = String(stripped[..<flushSites[0]])
            let beforeSecond = String(stripped[..<flushSites[1]])
            if !beforeFirst.contains("persister.consumeWipe(") {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "the consume branch's sweep must follow its awaited consumeWipe — the mailbox must serve the sweep the POST-wipe journal"
                ))
            }
            if beforeFirst.contains("pruneJournal(") {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "the consume branch's sweep must run BEFORE the steady branch's — a post-prune-only sweep would leave the suppression leg unproven"
                ))
            }
            if !beforeSecond.contains("pruneJournal(") {
                findings.append(Finding(
                    guardName: sweepWiringGuard, file: appModelFileName,
                    detail: "the steady branch's sweep must follow the watermark prune — already-applied entries ride the prune's drop"
                ))
            }
        }

        // The read seam is the one-writer journal extension (O1).
        guard let journal = files.first(where: { $0.name == journalFileName }) else {
            findings.append(Finding(guardName: sweepWiringGuard, file: journalFileName, detail: "file missing from Apps/MomoWatch"))
            return findings
        }
        if !MomoKitDisciplineScan.strippingComments(from: journal.contents)
            .contains("func pendingEvents(directory: URL)") {
            findings.append(Finding(
                guardName: sweepWiringGuard, file: journalFileName,
                detail: "the sweep's journal read is missing from the one-writer extension (O1)"
            ))
        }
        return findings
    }

    // MARK: - Guard 2: the transport raises activation completion

    static func transportArmViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let transport = files.first(where: { $0.name == transportFileName }) else {
            return [Finding(guardName: transportArmGuard, file: transportFileName, detail: "file missing from Apps/MomoWatch")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: transport.contents)
        if !stripped.contains("var onActivation: (@Sendable () -> Void)? { get set }") {
            findings.append(Finding(
                guardName: transportArmGuard, file: transportFileName,
                detail: "the protocol's activation sink declaration is missing"
            ))
        }
        if !stripped.contains("var onActivation: (@Sendable () -> Void)?") {
            findings.append(Finding(
                guardName: transportArmGuard, file: transportFileName,
                detail: "the live conformance's activation sink storage is missing"
            ))
        }
        // The activation delegate raises the sink (the arm signal's source).
        if let delegate = body(of: "activationDidCompleteWith", in: stripped) {
            if !delegate.contains("onActivation?()") {
                findings.append(Finding(
                    guardName: transportArmGuard, file: transportFileName,
                    detail: "the activation delegate does not raise the onActivation sink — the launch sweep's arm signal has no source"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: transportArmGuard, file: transportFileName,
                detail: "session(_:activationDidCompleteWith:error:) body not found"
            ))
        }
        return findings
    }

    // MARK: - Guard 3: event-driven only (§4.2)

    /// No timer token in ANY production Watch source. The sanctioned clock
    /// surfaces (`CharacterClock`, the injected `EngineClock`) are not
    /// timers; a future leg that needs periodic work must arrive as an
    /// event, not a schedule.
    static func noTimersViolations(files: [(name: String, contents: String)]) -> [Finding] {
        files.flatMap { file -> [Finding] in
            let stripped = MomoKitDisciplineScan.strippingComments(from: file.contents)
            return ["Timer(", "scheduledTimer"].filter { stripped.contains($0) }.map { token in
                Finding(
                    guardName: noTimersGuard, file: file.name,
                    detail: "banned timer token in Apps/MomoWatch: \(token) — every leg is event-driven (§4.2)"
                )
            }
        }
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
    /// the type's closing brace (the `WatchGlanceScan.body` shape).
    private static func body(of marker: String, in stripped: String) -> Substring? {
        guard let markerRange = stripped.range(of: marker) else { return nil }
        let rest = stripped[markerRange.upperBound...]
        let end = ["\n    func ", "\n}"].compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<end]
    }

    /// Every occurrence of `token`'s lower bound in `text` (the
    /// Foundation `range(of:options:range:)` walk — no regex dependency).
    private static func positions(of token: String, in text: String) -> [String.Index] {
        var found: [String.Index] = []
        var lower = text.startIndex
        while let range = text.range(of: token, range: lower..<text.endIndex) {
            found.append(range.lowerBound)
            lower = range.upperBound
        }
        return found
    }
}
