import Foundation

/// The TASK-040 wiring scans over `Apps/Momo` — pure text predicates
/// mirroring the `MomoKitDisciplineScan` mechanism (duplicated per test-
/// support convention), pinning the three executor seams that make the
/// Watch session LOAD-BEARING rather than decorative:
///
/// 1. **Push arm** — the reserved `.pushWatchSnapshot` step must actually
///    CALL the executor's push (`MomoAppModel.swift`'s switch arm), and that
///    push must actually deliver through the transport
///    (`watchTransport.send(contextData:)` in `MomoAppModel+Watch.swift`).
///    A stubbed arm or a send-less push both fail.
/// 2. **Receive gate** — the intent-receive path must decide through the
///    accessor-driven plan core (`WatchReceivePlan.decide(`), and the RAW
///    `WatchSyncGate` must appear in NO app-target code (O5: the app names
///    the plan, never the gate — call-site watermarks are the documented
///    foot-gun).
/// 3. **Erase marker** — `eraseAllData()` must write the §6.6 reset marker
///    (`WatchResetMarkerStore` save) BEFORE deleting the store tree —
///    signal-first ordering, the marker's persistence must be durable by
///    the time pet data is gone.
/// 4. **Marker directory** — the reset marker's launch-LOAD derivation and
///    its erase-SAVE derivation must cite the SAME rule
///    (`StoreRules.watchResetMarkerDirectory()` — the Application Support
///    root, OUTSIDE the store tree), and the init must route its load
///    through the `+Watch` helper. A one-sided edit makes the two sites
///    diverge and the marker can never survive a relaunch (REVIEW-TASK-040
///    F-1: the launch load read the store tree while the erase wrote the
///    root — the suite was structurally blind to it, Probe C).
///
/// Every predicate scans COMMENT-STRIPPED text (`MomoKitDisciplineScan
/// .strippingComments`), so a doc citation of a banned token can never fake
/// compliance — and equally can never mute a violation. Findings carry the
/// guard's name so a mutation bite can assert EXACTLY one guard went red.
enum WatchWiringScan {

    struct Finding: Equatable {
        let guardName: String
        let file: String
        let detail: String
    }

    static let pushGuard = "push arm → transport call"
    static let receiveGuard = "receive path → plan-core gate"
    static let eraseGuard = "erase → reset marker first"
    static let markerDirectoryGuard = "reset marker → one directory rule"

    /// The file expected to hold the armed switch (the executor's main file).
    static let mainFileName = "MomoAppModel.swift"
    /// The file expected to hold the push/receive executor bodies.
    static let watchFileName = "MomoAppModel+Watch.swift"
    /// The file expected to hold the erase operation.
    static let settingsFileName = "MomoAppModel+Settings.swift"

    // MARK: - Guard 1: the push arm delivers through the transport

    /// The `.pushWatchSnapshot` arm must call `pushWatchSnapshot()` (not a
    /// stub, not a comment mention), and `pushWatchSnapshot()`'s body must
    /// deliver via `watchTransport.send(contextData:)`.
    static func pushArmViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        let main = files.first { $0.name == mainFileName }
        let strippedMain = main.map { MomoKitDisciplineScan.strippingComments(from: $0.contents) }
        // The arm label must exist exactly once — a duplicate arm or a
        // renamed seam both break the single reserved step.
        let labelCount = strippedMain.map {
            $0.components(separatedBy: "case .pushWatchSnapshot:").count - 1
        } ?? 0
        if labelCount != 1 {
            findings.append(Finding(
                guardName: pushGuard, file: mainFileName,
                detail: "expected exactly one `case .pushWatchSnapshot:` arm, found \(labelCount)"
            ))
        }
        if let strippedMain, let body = pushArmBody(in: strippedMain),
            !body.contains("pushWatchSnapshot()") {
            findings.append(Finding(
                guardName: pushGuard, file: mainFileName,
                detail: "the .pushWatchSnapshot arm does not call pushWatchSnapshot()"
            ))
        }
        // The push body must reach the transport — a send-less push would
        // leave the seam armed in name only.
        if let watch = files.first(where: { $0.name == watchFileName }) {
            let strippedWatch = MomoKitDisciplineScan.strippingComments(from: watch.contents)
            if !strippedWatch.contains("watchTransport.send(contextData:") {
                findings.append(Finding(
                    guardName: pushGuard, file: watchFileName,
                    detail: "pushWatchSnapshot() never calls watchTransport.send(contextData:)"
                ))
            }
        } else {
            findings.append(Finding(
                guardName: pushGuard, file: watchFileName,
                detail: "file missing from Apps/Momo"
            ))
        }
        return findings
    }

    /// The arm's body: from the end of the `case .pushWatchSnapshot:` label
    /// to the next label or closing brace at the switch's indentation (the
    /// arms sit at 12 spaces in the executor's switch).
    private static func pushArmBody(in stripped: String) -> Substring? {
        guard let labelRange = stripped.range(of: "case .pushWatchSnapshot:") else { return nil }
        let rest = stripped[labelRange.upperBound...]
        let anchors = ["\n            case ", "\n            }"]
        let end = anchors.compactMap { rest.range(of: $0)?.lowerBound }.min() ?? rest.endIndex
        return rest[..<end]
    }

    // MARK: - Guard 2: the receive path decides through the plan core

    /// The receive body must call `WatchReceivePlan.decide(`, and NO
    /// app-target source may name `WatchSyncGate` in CODE (comments are
    /// stripped first — the +Watch doc deliberately cites the banned raw
    /// gate, and that citation must stay legal).
    static func receiveGateViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let watch = files.first(where: { $0.name == watchFileName }) else {
            return [Finding(guardName: receiveGuard, file: watchFileName, detail: "file missing from Apps/Momo")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: watch.contents)
        if !stripped.contains("WatchReceivePlan.decide(") {
            findings.append(Finding(
                guardName: receiveGuard, file: watchFileName,
                detail: "receiveWatchEvent does not decide through WatchReceivePlan.decide("
            ))
        }
        for file in files {
            let fileStripped = MomoKitDisciplineScan.strippingComments(from: file.contents)
            if fileStripped.contains("WatchSyncGate") {
                findings.append(Finding(
                    guardName: receiveGuard, file: file.name,
                    detail: "raw WatchSyncGate named in app code (O5: the plan core is the only gate caller)"
                ))
            }
        }
        return findings
    }

    // MARK: - Guard 3: the erase writes the marker BEFORE deleting stores

    /// `eraseAllData()` must save the reset marker (`markerStore.save(` over
    /// a `WatchResetMarkerStore(directory:`) and must do so BEFORE the store
    /// tree deletion (`removeItem(at: storeDirectory)`) — signal-first: by
    /// the time pet data is gone the Watch's wipe instruction is durable.
    static func eraseMarkerViolations(files: [(name: String, contents: String)]) -> [Finding] {
        guard let settings = files.first(where: { $0.name == settingsFileName }) else {
            return [Finding(guardName: eraseGuard, file: settingsFileName, detail: "file missing from Apps/Momo")]
        }
        let stripped = MomoKitDisciplineScan.strippingComments(from: settings.contents)
        var findings: [Finding] = []
        if !stripped.contains("WatchResetMarkerStore(directory:") {
            findings.append(Finding(
                guardName: eraseGuard, file: settingsFileName,
                detail: "eraseAllData() never builds a WatchResetMarkerStore"
            ))
        }
        let saveIndex = stripped.range(of: "markerStore.save(")?.lowerBound
        if saveIndex == nil {
            findings.append(Finding(
                guardName: eraseGuard, file: settingsFileName,
                detail: "eraseAllData() never saves the reset marker"
            ))
        }
        let deleteIndex = stripped.range(of: "removeItem(at: storeDirectory)")?.lowerBound
        if deleteIndex == nil {
            findings.append(Finding(
                guardName: eraseGuard, file: settingsFileName,
                detail: "eraseAllData() never deletes the store tree"
            ))
        }
        if let saveIndex, let deleteIndex, saveIndex > deleteIndex {
            findings.append(Finding(
                guardName: eraseGuard, file: settingsFileName,
                detail: "marker save happens AFTER the store-tree deletion — signal-first ordering violated"
            ))
        }
        return findings
    }

    // MARK: - Guard 4: the marker's load and save cite the SAME directory rule

    /// The reset marker has exactly two production sites (the O1 census):
    /// the launch load (the init routing through the `+Watch` helper) and
    /// the erase read-modify-save (`+Settings`). BOTH must derive the
    /// marker's directory from the same rule —
    /// `StoreRules.watchResetMarkerDirectory()`, the Application Support
    /// root OUTSIDE the store tree — or the load can never observe the save
    /// and the marker cannot survive a relaunch (review F-1's exact
    /// divergence; the suite was structurally blind to it). Four legs, all
    /// on comment-stripped text:
    ///
    /// 1. the init routes its load through `loadResetMarkerEraseCount()`;
    /// 2. the main file constructs NO `WatchResetMarkerStore` directly (the
    ///    sanctioned constructions are the `+Watch` load helper and the
    ///    `+Settings` erase site — a store-tree load in the init is F-1);
    /// 3. the `+Watch` launch-load derivation cites the rule token;
    /// 4. the `+Settings` erase-save derivation cites the same token.
    static func markerDirectoryViolations(files: [(name: String, contents: String)]) -> [Finding] {
        var findings: [Finding] = []
        guard let main = files.first(where: { $0.name == mainFileName }) else {
            return [Finding(guardName: markerDirectoryGuard, file: mainFileName, detail: "file missing from Apps/Momo")]
        }
        let strippedMain = MomoKitDisciplineScan.strippingComments(from: main.contents)
        if !strippedMain.contains("loadResetMarkerEraseCount()") {
            findings.append(Finding(
                guardName: markerDirectoryGuard, file: mainFileName,
                detail: "the init's marker load does not route through loadResetMarkerEraseCount()"
            ))
        }
        if strippedMain.contains("WatchResetMarkerStore(") {
            findings.append(Finding(
                guardName: markerDirectoryGuard, file: mainFileName,
                detail: "the main file constructs a WatchResetMarkerStore directly — the launch load must derive its directory through the +Watch helper's shared rule"
            ))
        }
        let derivationSites = [
            (file: watchFileName, role: "launch-load derivation"),
            (file: settingsFileName, role: "erase-save derivation"),
        ]
        for site in derivationSites {
            guard let contents = files.first(where: { $0.name == site.file })?.contents else {
                findings.append(Finding(
                    guardName: markerDirectoryGuard, file: site.file, detail: "file missing from Apps/Momo"
                ))
                continue
            }
            let stripped = MomoKitDisciplineScan.strippingComments(from: contents)
            if !stripped.contains("watchResetMarkerDirectory()") {
                findings.append(Finding(
                    guardName: markerDirectoryGuard, file: site.file,
                    detail: "the \(site.role) does not cite StoreRules.watchResetMarkerDirectory() — the marker's load and save must share the one directory rule (review F-1)"
                ))
            }
        }
        return findings
    }
}
