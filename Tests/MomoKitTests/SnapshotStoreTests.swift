import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-021 store matrix (contract Requirement 8): roundtrip (populated
/// anchor + every persisted enum case), envelope pins, generational chain,
/// crash-window intermediates, corruption recovery, above-chain-head
/// fall-through (rewritten against the §5.5 migration chain in TASK-022 —
/// OBS-5), and byte-stability of the `.sortedKeys` payload/checksum
/// portion. Corruption and crash windows are constructed DIRECTLY on disk
/// through `@testable` helpers so each mode is pinned in isolation; every
/// assertion goes through the public `save`/`load` API, whose non-throwing
/// signatures ARE the no-error-surface claim (Requirement 3) — there is no
/// `try` to remove because none exists.
@Suite("SnapshotStore — envelope, atomic writes, generational recovery (TASK-021; 05 §5.1–§5.3, ADR-002)")
struct SnapshotStoreTests {

    private let fixture = StoreFixture()

    // MARK: - Harness

    /// A store over a fresh throwaway directory with a pinned manual clock.
    private func makeStore(at instant: String = "2026-03-03T12:00:00Z") -> (store: SnapshotStore, directory: URL, clock: ManualEngineClock) {
        let clock = ManualEngineClock(at: fixture.instant(instant))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
        return (SnapshotStore(directory: directory, clock: clock), directory, clock)
    }

    private func fileURL(_ directory: URL, _ fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    private func writeBytes(_ bytes: Data, to fileName: String, in directory: URL) {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! bytes.write(to: fileURL(directory, fileName))
    }

    private func readBytes(_ fileName: String, in directory: URL) -> Data? {
        try? Data(contentsOf: fileURL(directory, fileName))
    }

    /// Writes a VALID envelope for `state` under `fileName` — the crash-window
    /// tests' building block (a crash window is valid content under a partial
    /// chain, never corrupt content).
    private func writeValidGeneration(
        _ state: EngineState,
        schemaVersion: Int = StoreRules.currentSchemaVersion,
        checksumOverride: String? = nil,
        to fileName: String,
        in directory: URL,
        savedAt: Instant? = nil
    ) {
        let bytes = envelopeBytes(
            for: state,
            schemaVersion: schemaVersion,
            checksumOverride: checksumOverride,
            savedAt: savedAt ?? fixture.instant("2026-03-03T12:00:00Z")
        )
        writeBytes(bytes, to: fileName, in: directory)
    }

    private func envelopeBytes(
        for state: EngineState,
        schemaVersion: Int,
        checksumOverride: String?,
        savedAt: Instant
    ) -> Data {
        let payloadJSON = SnapshotStore.payloadJSONData(for: state)!
        let checksum = checksumOverride ?? SnapshotStore.checksumHex(of: payloadJSON)
        let envelope = SnapshotStore.SnapshotEnvelope(
            schemaVersion: schemaVersion,
            savedAt: savedAt,
            checksum: checksum,
            payload: state
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try! encoder.encode(envelope)
    }

    private func readEnvelope(_ fileName: String, in directory: URL) -> SnapshotStore.SnapshotEnvelope? {
        guard let bytes = readBytes(fileName, in: directory) else { return nil }
        return try? JSONDecoder().decode(SnapshotStore.SnapshotEnvelope.self, from: bytes)
    }

    /// The test-side recipe recomputation — deliberately NOT a call into the
    /// store's helpers: its own encoder, MomoCore's SHA-256, its own hex step.
    /// This is what makes the envelope pins teeth (Requirement: the reviewer's
    /// mutations — `.sortedKeys` removal, recipe swap — must fail HERE first).
    private func recomputedChecksum(for state: EngineState) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let payloadJSON = try! encoder.encode(state)
        return MomoCore.SHA256.digest([UInt8](payloadJSON))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    // MARK: - Roundtrip (Requirement 8, bullet 1)

    @Test("a fully-populated state roundtrips exactly through save → load")
    func populatedStateRoundtripsExactly() async {
        let (store, _, _) = makeStore()
        let state = fixture.populatedState()
        await store.save(state)
        let loaded = store.load(fallback: fixture.state(bond: 999))
        #expect(loaded == state, "every field must survive the envelope roundtrip unchanged")
    }

    @Test("every Wakefulness case roundtrips", arguments: StoreFixture.allWakefulness)
    func wakefulnessCaseRoundtrips(_ wakefulness: Wakefulness) async {
        let (store, _, _) = makeStore()
        let state = fixture.state(wakefulness: wakefulness)
        await store.save(state)
        #expect(store.load(fallback: fixture.state(bond: 999)) == state)
    }

    @Test("every Activity case (incl. nil) roundtrips", arguments: StoreFixture.allActivity)
    func activityCaseRoundtrips(_ activity: Activity?) async {
        let (store, _, _) = makeStore()
        let state = fixture.state(activity: activity)
        await store.save(state)
        #expect(store.load(fallback: fixture.state(bond: 999)) == state)
    }

    @Test("every SatietyPhase case roundtrips", arguments: StoreFixture.allSatietyPhase)
    func satietyPhaseCaseRoundtrips(_ satietyPhase: SatietyPhase) async {
        let (store, _, _) = makeStore()
        let state = fixture.state(satietyPhase: satietyPhase)
        await store.save(state)
        #expect(store.load(fallback: fixture.state(bond: 999)) == state)
    }

    @Test("every HandshakeKind case roundtrips", arguments: StoreFixture.allHandshakeKind)
    func handshakeKindCaseRoundtrips(_ handshakeKind: HandshakeKind) async {
        let (store, _, _) = makeStore()
        let state = fixture.state(handshakeKind: handshakeKind)
        await store.save(state)
        #expect(store.load(fallback: fixture.state(bond: 999)) == state)
    }

    @Test("every GreetingKind case roundtrips", arguments: StoreFixture.allGreetingKind)
    func greetingKindCaseRoundtrips(_ greetingKind: GreetingKind) async {
        let (store, _, _) = makeStore()
        let state = fixture.state(greetingKind: greetingKind)
        await store.save(state)
        #expect(store.load(fallback: fixture.state(bond: 999)) == state)
    }

    @Test("every BondStage case roundtrips", arguments: StoreFixture.allBondStage)
    func bondStageCaseRoundtrips(_ celebratedStage: BondStage) async {
        let (store, _, _) = makeStore()
        let state = fixture.state(celebratedStage: celebratedStage)
        await store.save(state)
        #expect(store.load(fallback: fixture.state(bond: 999)) == state)
    }

    @Test("the case pins are exhaustive, duplicate-free and count-pinned")
    func persistedEnumCasePinsAreComplete() {
        // The `pin(_:)` switches are default-free and exhaustive — a new case
        // anywhere fails the BUILD. These assertions additionally pin the
        // array/pin agreement so a copy-paste slip cannot desynchronize them.
        #expect(StoreFixture.allWakefulness.map(StoreFixture.pin).count == Set(StoreFixture.allWakefulness.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allActivity.map(StoreFixture.pin).count == Set(StoreFixture.allActivity.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allSatietyPhase.map(StoreFixture.pin).count == Set(StoreFixture.allSatietyPhase.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allHandshakeKind.map(StoreFixture.pin).count == Set(StoreFixture.allHandshakeKind.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allGreetingKind.map(StoreFixture.pin).count == Set(StoreFixture.allGreetingKind.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allBondStage.map(StoreFixture.pin).count == Set(StoreFixture.allBondStage.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allQuestID.map(StoreFixture.pin).count == Set(StoreFixture.allQuestID.map(StoreFixture.pin)).count)
        #expect(StoreFixture.allQuestFamily.map(StoreFixture.pin).count == Set(StoreFixture.allQuestFamily.map(StoreFixture.pin)).count)
    }

    @Test("the populated fixture really reaches every QuestID and QuestFamily case")
    func populatedFixtureReachesEveryQuestCase() {
        let state = fixture.populatedState()
        let questIDs = Set(state.days.flatMap { $0.questSet.map(\.questID) })
        #expect(questIDs == Set(StoreFixture.allQuestID), "the ledger's quest sets must cover all seven Q1–Q7")
        let families = Set(state.days.flatMap { $0.familiesUsed })
        #expect(families == Set(StoreFixture.allQuestFamily), "familiesUsed across the ledger must cover all five families")
    }

    // MARK: - Envelope pins (Requirement 8, bullet 2; Requirement 1)

    @Test("the on-disk envelope carries schemaVersion == 1 (raw pin with mutation teeth)")
    func envelopeCarriesSchemaVersionOne() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.populatedState())
        let envelope = readEnvelope(StoreRules.currentStateFileName, in: directory)
        #expect(envelope?.schemaVersion == 1, "raw literal: a currentSchemaVersion bump must fail HERE (the sanctioned mutation's expected bite)")
    }

    @Test("the on-disk checksum equals the independently recomputed recipe")
    func envelopeChecksumEqualsRecomputedRecipe() async {
        let (store, directory, _) = makeStore()
        let state = fixture.populatedState()
        await store.save(state)
        let envelope = readEnvelope(StoreRules.currentStateFileName, in: directory)
        #expect(envelope?.checksum == recomputedChecksum(for: state),
                "checksum must be SHA-256 over the .sortedKeys payload JSON bytes — recipe drift (unsorted payload, other digest, non-lowercase hex) fails here")
    }

    @Test("the on-disk savedAt equals the injected clock's value")
    func envelopeSavedAtEqualsInjectedClock() async {
        let (store, directory, clock) = makeStore(at: "2026-06-01T07:30:00Z")
        await store.save(fixture.populatedState())
        let envelope = readEnvelope(StoreRules.currentStateFileName, in: directory)
        #expect(envelope?.savedAt == clock.current,
                "savedAt comes ONLY from the injected EngineClock (Requirement 6)")
    }

    @Test("the on-disk envelope's key set is exactly the spec shape")
    func envelopeKeySetIsExactlyTheSpecShape() async throws {
        let (store, directory, _) = makeStore()
        await store.save(fixture.populatedState())
        let bytes = try #require(readBytes(StoreRules.currentStateFileName, in: directory))
        let object = try #require(try JSONSerialization.jsonObject(with: bytes) as? [String: Any])
        #expect(Set(object.keys) == ["schemaVersion", "savedAt", "checksum", "payload"],
                "envelope exactness (05 §5.2): exactly these four keys, nothing added")
    }

    // MARK: - Generational chain (Requirement 8, bullet 3; Requirement 2)

    @Test("after one save only state.json exists")
    func firstSaveLeavesASingleGeneration() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        #expect(readBytes(StoreRules.currentStateFileName, in: directory) != nil)
        #expect(readBytes(StoreRules.previousStateFileName, in: directory) == nil)
        #expect(readBytes(StoreRules.oldestStateFileName, in: directory) == nil)
    }

    @Test("after two saves prev2 is still absent and the chain carries N, N−1")
    func secondSaveLeavesATwoGenerationChain() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        #expect(readBytes(StoreRules.oldestStateFileName, in: directory) == nil)
        #expect(readEnvelope(StoreRules.currentStateFileName, in: directory)?.payload == fixture.state(bond: 2))
        #expect(readEnvelope(StoreRules.previousStateFileName, in: directory)?.payload == fixture.state(bond: 1))
    }

    @Test("after three saves the files carry N, N−1, N−2 per the documented demotion order")
    func threeSavesLeaveTheFullDemotedChain() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        await store.save(fixture.state(bond: 3))
        #expect(readEnvelope(StoreRules.currentStateFileName, in: directory)?.payload == fixture.state(bond: 3), "current = N")
        #expect(readEnvelope(StoreRules.previousStateFileName, in: directory)?.payload == fixture.state(bond: 2), "prev = N−1 (demoted once)")
        #expect(readEnvelope(StoreRules.oldestStateFileName, in: directory)?.payload == fixture.state(bond: 1), "prev2 = N−2 (demoted twice)")
    }

    // MARK: - Crash-window matrix (Requirement 8, bullet 4)

    @Test("crash window: current present + prev missing + prev2 stale serves current")
    func crashWindowCurrentPlusStalePrev2() async {
        let (store, directory, _) = makeStore()
        writeValidGeneration(fixture.state(bond: 2), to: StoreRules.currentStateFileName, in: directory)
        writeValidGeneration(fixture.state(bond: 0), to: StoreRules.oldestStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 2))
    }

    @Test("crash window: post-step-1 shape {current N, prev —, prev2 N−1} serves N")
    func crashWindowAfterPrevDemotion() async {
        let (store, directory, _) = makeStore()
        writeValidGeneration(fixture.state(bond: 2), to: StoreRules.currentStateFileName, in: directory)
        writeValidGeneration(fixture.state(bond: 1), to: StoreRules.oldestStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 2))
    }

    @Test("crash window: post-step-2 shape {current —, prev N, prev2 N−1} serves N via prev")
    func crashWindowAfterCurrentDemotion() async {
        let (store, directory, _) = makeStore()
        writeValidGeneration(fixture.state(bond: 2), to: StoreRules.previousStateFileName, in: directory)
        writeValidGeneration(fixture.state(bond: 1), to: StoreRules.oldestStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 2), "the interrupted save's own generation must not be lost")
    }

    @Test("crash window: an orphaned temp file is ignored by the read path")
    func crashWindowOrphanedTempIsIgnored() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 2))
        await store.save(fixture.state(bond: 3))
        writeBytes(Data("torn temp bytes".utf8), to: StoreRules.temporaryStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 3))
    }

    @Test("crash window: only prev2 surviving serves N−2")
    func crashWindowOnlyOldestSurvivorServes() async {
        let (store, directory, _) = makeStore()
        writeValidGeneration(fixture.state(bond: 1), to: StoreRules.oldestStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
    }

    // MARK: - Corruption recovery (Requirement 8, bullet 5; Requirement 3)

    @Test("a truncated current generation falls back to prev's state")
    func truncatedCurrentFallsBackToPrev() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        let bytes = readBytes(StoreRules.currentStateFileName, in: directory)!
        writeBytes(bytes.prefix(bytes.count * 2 / 3), to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
    }

    @Test("a checksum mismatch in current (decodable bytes, wrong digest) falls back to prev")
    func checksumMismatchFallsBackToPrev() async {
        let (store, directory, clock) = makeStore()
        // A two-generation chain first, so the fall-through target exists.
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        // Decodable envelope for one payload carrying the digest of a
        // DIFFERENT payload — isolates the checksum gate from the decode gate.
        let bytes = envelopeBytes(
            for: fixture.state(bond: 3),
            schemaVersion: StoreRules.currentSchemaVersion,
            checksumOverride: recomputedChecksum(for: fixture.state(bond: 1)),
            savedAt: clock.current
        )
        writeBytes(bytes, to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
    }

    @Test("garbage bytes in current fall back to prev")
    func garbageCurrentFallsBackToPrev() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        writeBytes(Data("this is not json at all {{{".utf8), to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
    }

    @Test("an empty current file falls back to prev")
    func emptyCurrentFallsBackToPrev() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        writeBytes(Data(), to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
    }

    @Test("all three generations corrupted returns the injected fresh default")
    func allGenerationsCorruptedReturnsFallback() async {
        let (store, directory, _) = makeStore()
        writeBytes(Data("garbage 1".utf8), to: StoreRules.currentStateFileName, in: directory)
        writeBytes(Data("garbage 2".utf8), to: StoreRules.previousStateFileName, in: directory)
        writeBytes(Data("garbage 3".utf8), to: StoreRules.oldestStateFileName, in: directory)
        let fallback = fixture.state(bond: 777)
        #expect(store.load(fallback: fallback) == fallback)
    }

    @Test("a missing store directory entirely returns the injected fresh default")
    func missingDirectoryReturnsFallback() {
        let (store, _, _) = makeStore()
        let fallback = fixture.state(bond: 777)
        #expect(store.load(fallback: fallback) == fallback)
    }

    @Test("corrupting one generation never damages the survivors (and loads never write)")
    func corruptingOneGenerationLeavesSurvivorsIntact() async {
        let (store, directory, _) = makeStore()
        await store.save(fixture.state(bond: 1))
        await store.save(fixture.state(bond: 2))
        await store.save(fixture.state(bond: 3))
        let prevBytesBefore = readBytes(StoreRules.previousStateFileName, in: directory)!
        let prev2BytesBefore = readBytes(StoreRules.oldestStateFileName, in: directory)!
        // Corrupt current → prev serves; the survivors' BYTES are untouched
        // (the read path is read-only by construction).
        writeBytes(Data("corrupted current".utf8), to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 2))
        #expect(readBytes(StoreRules.previousStateFileName, in: directory) == prevBytesBefore)
        #expect(readBytes(StoreRules.oldestStateFileName, in: directory) == prev2BytesBefore)
        // Corrupt prev too → prev2 serves, still byte-identical.
        writeBytes(Data("corrupted prev".utf8), to: StoreRules.previousStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
        #expect(readBytes(StoreRules.oldestStateFileName, in: directory) == prev2BytesBefore)
    }

    // MARK: - Versions above the chain head (Requirement 8, bullet 6;
    // TASK-022's OBS-5 rewrite: the skip is the §5.5 migration chain's
    // above-head rule — a version above `currentSchemaVersion` is unreadable
    // regardless of its bytes — not a store special case. The store under
    // test carries the production EMPTY chain; below-current walk behavior
    // lives in MigrationChainTests.)

    @Test("a generation above the chain head is skipped — prev serves even with a valid checksum")
    func generationAboveTheChainHeadIsSkippedToPrev() async {
        let (store, directory, clock) = makeStore()
        let previousState = fixture.state(bond: 1)
        let futureState = fixture.state(bond: 2)
        // Self-consistent envelope one version ABOVE the chain head (valid
        // recipe checksum): it must STILL be refused — the version range
        // check precedes the checksum, and no registered walk can reach a
        // version the store does not know.
        writeBytes(
            envelopeBytes(
                for: futureState,
                schemaVersion: StoreRules.currentSchemaVersion + 1,
                checksumOverride: nil,
                savedAt: clock.current
            ),
            to: StoreRules.currentStateFileName,
            in: directory
        )
        writeValidGeneration(previousState, to: StoreRules.previousStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == previousState)
    }

    @Test("versions above the chain head in every generation return the injected fallback")
    func versionsAboveTheChainHeadEverywhereReturnFallback() async {
        let (store, directory, clock) = makeStore()
        writeBytes(
            envelopeBytes(
                for: fixture.state(bond: 3),
                schemaVersion: StoreRules.currentSchemaVersion + 1,
                checksumOverride: nil,
                savedAt: clock.current
            ),
            to: StoreRules.currentStateFileName,
            in: directory
        )
        writeBytes(
            envelopeBytes(
                for: fixture.state(bond: 2),
                schemaVersion: StoreRules.currentSchemaVersion + 1,
                checksumOverride: nil,
                savedAt: clock.current
            ),
            to: StoreRules.previousStateFileName,
            in: directory
        )
        writeBytes(
            envelopeBytes(
                for: fixture.state(bond: 1),
                schemaVersion: StoreRules.currentSchemaVersion + 8,
                checksumOverride: nil,
                savedAt: clock.current
            ),
            to: StoreRules.oldestStateFileName,
            in: directory
        )
        let fallback = fixture.state(bond: 777)
        #expect(store.load(fallback: fallback) == fallback)
    }

    // MARK: - Determinism / byte stability (Requirement 8, bullet 7; the
    // `.sortedKeys` discipline made-to-pay)

    @Test("two saves of the same state are byte-identical except the savedAt digits")
    func sameStateSavesAreByteStableExceptSavedAt() async {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
        let ticking = TickingClock(at: fixture.instant("2026-03-03T12:00:00Z"), step: 1)
        let store = SnapshotStore(directory: directory, clock: ticking)
        let state = fixture.populatedState()

        await store.save(state)
        let first = Array(readBytes(StoreRules.currentStateFileName, in: directory)!)

        await store.save(state)
        let second = Array(readBytes(StoreRules.currentStateFileName, in: directory)!)

        // The savedAt values legitimately differ (the ticking clock advanced);
        // everything else — checksum, payload, schemaVersion — is byte-stable.
        let marker = Array("\"savedAt\":".utf8)
        let firstSplit = splitAroundFirst(first, marker)
        let secondSplit = splitAroundFirst(second, marker)
        #expect(firstSplit.before == secondSplit.before,
                "checksum + payload region must be byte-identical across saves of the same state")
        #expect(firstSplit.after != secondSplit.after,
                "the clock advanced, so the savedAt digits must differ")
        // The stable region really is the whole file except the savedAt number:
        // after the digits both files carry the same schemaVersion tail.
        #expect(tail(afterDigits: firstSplit.after) == tail(afterDigits: secondSplit.after))
        #expect(first != second, "sanity: the files as wholes do differ")
    }

    private func splitAroundFirst(_ bytes: [UInt8], _ marker: [UInt8]) -> (before: [UInt8], after: [UInt8]) {
        guard let index = bytes.firstRange(of: marker)?.lowerBound else {
            return (bytes, [])
        }
        return (Array(bytes[..<index]), Array(bytes[(index + marker.count)...]))
    }

    private func tail(afterDigits savedAtRegion: [UInt8]) -> [UInt8] {
        let schemaMarker = Array(",\"schemaVersion\"".utf8)
        if let index = savedAtRegion.firstRange(of: schemaMarker)?.lowerBound {
            return Array(savedAtRegion[index...])
        }
        return savedAtRegion
    }
}
