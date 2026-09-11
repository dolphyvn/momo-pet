import Foundation
import Testing

/// The TASK-040 structural guards over `Apps/Momo` (the app target's Watch
/// wiring): the push arm really calls the transport, the receive path really
/// decides through the plan core (and never names the raw gate), the erase
/// really writes the reset marker BEFORE deleting the stores, and the
/// marker's launch load and erase save derive from the SAME directory rule
/// (review F-1 — a one-sided edit left the marker unable to survive a
/// relaunch). The
/// same layered non-vacuity as `MomoKitDisciplineScanTests`: fixture
/// self-tests prove every predicate turns red on its violation in BOTH stub
/// directions (the load-bearing token stripped, and the token present only
/// in a comment — the comment-stripper must let neither fake compliance nor
/// mute a citation), and the standing tests are the restore-green halves
/// over the real tree.
@Suite("Watch wiring scan — the app target's TASK-040 seams are load-bearing")
struct MomoWatchWiringScanTests {

    // MARK: - Fixture self-tests, guard 1 (push arm → transport call)

    @Test("stub direction: an arm whose body never calls push fails")
    func pushArmStubBodyFails() {
        let main = [
            "        switch step {",
            "            case .pushWatchSnapshot:",
            "                _ = 0",
            "            }",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.pushArmViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: main),
            (name: WatchWiringScan.watchFileName, contents: Self.pushWithSend),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchWiringScan.pushGuard)
        #expect(findings.first?.detail.contains("does not call pushWatchSnapshot()") == true)
    }

    @Test("stub direction: a comment-only call in the arm cannot green it")
    func pushArmCommentMentionFails() {
        let main = [
            "        switch step {",
            "            case .pushWatchSnapshot:",
            "                // pushWatchSnapshot() handles the delivery",
            "            }",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.pushArmViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: main),
            (name: WatchWiringScan.watchFileName, contents: Self.pushWithSend),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchWiringScan.pushGuard)
    }

    @Test("stub direction: a send-less push (send mentioned only in a comment) fails")
    func pushWithoutTransportSendFails() {
        let main = [
            "        switch step {",
            "            case .pushWatchSnapshot:",
            "                pushWatchSnapshot()",
            "            }",
        ].joined(separator: "\n")
        let watch = [
            "func pushWatchSnapshot() {",
            "    // watchTransport.send(contextData: data) would go here",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.pushArmViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: main),
            (name: WatchWiringScan.watchFileName, contents: watch),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchWiringScan.pushGuard)
        #expect(findings.first?.detail.contains("never calls watchTransport.send") == true)
    }

    @Test("green fixture: the properly wired arm + push produce no finding")
    func pushArmGreenFixturePasses() {
        let main = [
            "        switch step {",
            "            case .pushWatchSnapshot:",
            "                pushWatchSnapshot()",
            "            }",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.pushArmViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: main),
            (name: WatchWiringScan.watchFileName, contents: Self.pushWithSend),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 2 (receive path → plan-core gate)

    @Test("stub direction: a raw WatchSyncGate receive (no decide) fails on both legs")
    func receiveRawGateFails() {
        let watch = [
            "func receiveWatchEvent(_ data: Data) {",
            "    guard WatchSyncGate.shouldApply(event, sync: sync) else { return }",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.receiveGateViolations(files: [
            (name: WatchWiringScan.watchFileName, contents: watch),
        ])
        #expect(findings.count == 2, "\(findings)")
        #expect(findings.allSatisfy { $0.guardName == WatchWiringScan.receiveGuard })
    }

    @Test("stub direction: a receive that gates some other way fails the decide leg alone")
    func receiveWithoutDecideFails() {
        let watch = [
            "func receiveWatchEvent(_ data: Data) {",
            "    if seen.contains(event.id) { return }",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.receiveGateViolations(files: [
            (name: WatchWiringScan.watchFileName, contents: watch),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("WatchReceivePlan.decide(") == true)
    }

    @Test("the raw gate cited in COMMENTS stays legal (the doc citation must not mute the scan)")
    func receiveCommentOnlyGateMentionPasses() {
        let watch = [
            "func receiveWatchEvent(_ data: Data) {",
            "    // Never a raw WatchSyncGate with call-site watermarks here.",
            "    guard case .apply = WatchReceivePlan.decide(event: e, sync: s, seenIntentIDs: []) else { return }",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.receiveGateViolations(files: [
            (name: WatchWiringScan.watchFileName, contents: watch),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 3 (erase → reset marker first)

    @Test("stub direction: deleting stores BEFORE the marker save fails the ordering leg alone")
    func eraseReversedOrderFails() {
        let settings = [
            "func eraseAllData() {",
            "    let markerStore = WatchResetMarkerStore(directory: directory)",
            "    try? FileManager.default.removeItem(at: storeDirectory)",
            "    markerStore.save(WatchResetMarker(eraseCount: 1))",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.eraseMarkerViolations(files: [
            (name: WatchWiringScan.settingsFileName, contents: settings),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("AFTER the store-tree deletion") == true)
    }

    @Test("stub direction: an erase with no marker write at all fails the write legs")
    func eraseWithoutMarkerFails() {
        let settings = [
            "func eraseAllData() {",
            "    try? FileManager.default.removeItem(at: storeDirectory)",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.eraseMarkerViolations(files: [
            (name: WatchWiringScan.settingsFileName, contents: settings),
        ])
        #expect(findings.count == 2, "\(findings)")
    }

    @Test("stub direction: a comment-only marker save cannot green it")
    func eraseCommentOnlySaveFails() {
        let settings = [
            "func eraseAllData() {",
            "    let markerStore = WatchResetMarkerStore(directory: directory)",
            "    // markerStore.save(marker) before the delete",
            "    try? FileManager.default.removeItem(at: storeDirectory)",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.eraseMarkerViolations(files: [
            (name: WatchWiringScan.settingsFileName, contents: settings),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.detail.contains("never saves the reset marker") == true)
    }

    @Test("green fixture: signal-first erase produces no finding")
    func eraseGreenFixturePasses() {
        let settings = [
            "func eraseAllData() {",
            "    let markerStore = WatchResetMarkerStore(directory: directory)",
            "    markerStore.save(WatchResetMarker(eraseCount: 1))",
            "    try? FileManager.default.removeItem(at: storeDirectory)",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.eraseMarkerViolations(files: [
            (name: WatchWiringScan.settingsFileName, contents: settings),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - Fixture self-tests, guard 4 (marker load/save → one directory rule)

    @Test("stub direction: a launch-load derivation off the shared rule fails")
    func markerLoadOffRuleFails() {
        let main = "        self.watchResetMarkerEraseCount = Self.loadResetMarkerEraseCount()"
        let watch = [
            "static func loadResetMarkerEraseCount() -> Int {",
            "    let markerDirectory = try StoreRules.defaultDirectory()",
            "    return WatchResetMarkerStore(directory: markerDirectory).load()?.eraseCount ?? 0",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.markerDirectoryViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: main),
            (name: WatchWiringScan.watchFileName, contents: watch),
            (name: WatchWiringScan.settingsFileName, contents: Self.settingsCitingRule),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchWiringScan.markerDirectoryGuard)
        #expect(findings.first?.file == WatchWiringScan.watchFileName)
        #expect(findings.first?.detail.contains("launch-load derivation") == true)
    }

    @Test("stub direction: an erase-save derivation off the shared rule fails")
    func markerSaveOffRuleFails() {
        let settings = [
            "func eraseAllData() {",
            "    let markerDirectory = try StoreRules.defaultDirectory()",
            "    let markerStore = WatchResetMarkerStore(directory: markerDirectory)",
            "    markerStore.save(WatchResetMarker(eraseCount: 1))",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.markerDirectoryViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: Self.mainRoutingThroughHelper),
            (name: WatchWiringScan.watchFileName, contents: Self.watchCitingRule),
            (name: WatchWiringScan.settingsFileName, contents: settings),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.guardName == WatchWiringScan.markerDirectoryGuard)
        #expect(findings.first?.file == WatchWiringScan.settingsFileName)
        #expect(findings.first?.detail.contains("erase-save derivation") == true)
    }

    @Test("stub direction: an init reverted to a direct store-tree load fails both main legs")
    func markerInitDirectStoreLoadFails() {
        // The review F-1 reversion shape: the init builds the marker store
        // over the executor's store tree while the +Watch helper still sits
        // unused — the routing leg AND the no-direct-construction leg red.
        let main = [
            "        self.watchResetMarkerEraseCount = WatchResetMarkerStore(directory: directory)",
            "            .load()?.eraseCount ?? 0",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.markerDirectoryViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: main),
            (name: WatchWiringScan.watchFileName, contents: Self.watchCitingRule),
            (name: WatchWiringScan.settingsFileName, contents: Self.settingsCitingRule),
        ])
        #expect(findings.count == 2, "\(findings)")
        #expect(findings.allSatisfy { $0.guardName == WatchWiringScan.markerDirectoryGuard })
        #expect(findings.allSatisfy { $0.file == WatchWiringScan.mainFileName })
    }

    @Test("stub direction: a comment-only rule token cannot green the load derivation")
    func markerLoadCommentOnlyTokenFails() {
        let watch = [
            "static func loadResetMarkerEraseCount() -> Int {",
            "    // StoreRules.watchResetMarkerDirectory() is the right rule here",
            "    let markerDirectory = try StoreRules.defaultDirectory()",
            "    return WatchResetMarkerStore(directory: markerDirectory).load()?.eraseCount ?? 0",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.markerDirectoryViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: Self.mainRoutingThroughHelper),
            (name: WatchWiringScan.watchFileName, contents: watch),
            (name: WatchWiringScan.settingsFileName, contents: Self.settingsCitingRule),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.file == WatchWiringScan.watchFileName)
        #expect(findings.first?.detail.contains("launch-load derivation") == true)
    }

    @Test("stub direction: a comment-only rule token cannot green the save derivation")
    func markerSaveCommentOnlyTokenFails() {
        let settings = [
            "func eraseAllData() {",
            "    // StoreRules.watchResetMarkerDirectory() is the right rule here",
            "    let markerDirectory = try StoreRules.defaultDirectory()",
            "    let markerStore = WatchResetMarkerStore(directory: markerDirectory)",
            "    markerStore.save(WatchResetMarker(eraseCount: 1))",
            "}",
        ].joined(separator: "\n")
        let findings = WatchWiringScan.markerDirectoryViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: Self.mainRoutingThroughHelper),
            (name: WatchWiringScan.watchFileName, contents: Self.watchCitingRule),
            (name: WatchWiringScan.settingsFileName, contents: settings),
        ])
        #expect(findings.count == 1, "\(findings)")
        #expect(findings.first?.file == WatchWiringScan.settingsFileName)
        #expect(findings.first?.detail.contains("erase-save derivation") == true)
    }

    @Test("green fixture: load and save both citing the shared rule produce no finding")
    func markerDirectoryGreenFixturePasses() {
        let findings = WatchWiringScan.markerDirectoryViolations(files: [
            (name: WatchWiringScan.mainFileName, contents: Self.mainRoutingThroughHelper),
            (name: WatchWiringScan.watchFileName, contents: Self.watchCitingRule),
            (name: WatchWiringScan.settingsFileName, contents: Self.settingsCitingRule),
        ])
        #expect(findings.isEmpty, "\(findings)")
    }

    // MARK: - The standing scans over the real app target
    // (the restore-green halves; the mutation bites are recorded in the task file)

    @Test("Apps/Momo as it stands wires the push arm through the transport")
    func realTreePushArmIsWired() throws {
        let sources = try KitRepo.momoAppSources()
        #expect(!sources.isEmpty, "Apps/Momo must exist and contain Swift sources")
        let findings = WatchWiringScan.pushArmViolations(files: sources)
        #expect(findings.isEmpty, "push-arm wiring violation: \(findings)")
    }

    @Test("Apps/Momo as it stands decides receives through the plan core only")
    func realTreeReceiveGateIsPlanCore() throws {
        let sources = try KitRepo.momoAppSources()
        let findings = WatchWiringScan.receiveGateViolations(files: sources)
        #expect(findings.isEmpty, "receive-gate violation: \(findings)")
    }

    @Test("Apps/Momo as it stands writes the reset marker before the store deletion")
    func realTreeEraseWritesMarkerFirst() throws {
        let sources = try KitRepo.momoAppSources()
        let findings = WatchWiringScan.eraseMarkerViolations(files: sources)
        #expect(findings.isEmpty, "erase-marker violation: \(findings)")
    }

    @Test("Apps/Momo as it stands loads the reset marker from the same directory rule the erase saves with")
    func realTreeMarkerLoadMatchesSaveRule() throws {
        let sources = try KitRepo.momoAppSources()
        let findings = WatchWiringScan.markerDirectoryViolations(files: sources)
        #expect(findings.isEmpty, "marker-directory violation: \(findings)")
    }

    // MARK: - Fixtures

    /// The transport-reaching push body the guard-1 fixtures reuse.
    private static let pushWithSend = [
        "func pushWatchSnapshot() {",
        "    watchTransport.send(contextData: data)",
        "}",
    ].joined(separator: "\n")

    /// The guard-4 fixtures' init leg: the marker load routes through the
    /// +Watch helper (no direct marker-store construction in the main file).
    private static let mainRoutingThroughHelper = [
        "        self.watchResetMarkerEraseCount = Self.loadResetMarkerEraseCount()",
    ].joined(separator: "\n")

    /// The guard-4 fixtures' load leg: the +Watch derivation cites the rule.
    private static let watchCitingRule = [
        "static func loadResetMarkerEraseCount() -> Int {",
        "    let markerDirectory = try StoreRules.watchResetMarkerDirectory()",
        "    return WatchResetMarkerStore(directory: markerDirectory).load()?.eraseCount ?? 0",
        "}",
    ].joined(separator: "\n")

    /// The guard-4 fixtures' save leg: the erase derivation cites the rule.
    private static let settingsCitingRule = [
        "func eraseAllData() {",
        "    let markerDirectory = try StoreRules.watchResetMarkerDirectory()",
        "    let markerStore = WatchResetMarkerStore(directory: markerDirectory)",
        "    markerStore.save(WatchResetMarker(eraseCount: 1))",
        "}",
    ].joined(separator: "\n")
}
