import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The OBS-1 golden-bytes pin (TASK-022; routed from the TASK-021 review).
/// The shipped TASK-021 suite never loaded bytes recorded OUTSIDE the running
/// process, so the exact failure mode the TASK-021 Disclosure-1 note guards
/// against (the checksum recipe's coupling to the toolchain's canonical
/// Codable byte shape) was real but unpinned. This suite closes that: it
/// writes RECORDED literal bytes — captured 2026-09-09 by running the
/// production save path for `StoreFixture.populatedState()` (pinned manual
/// clock at 2026-03-03T12:00:00Z) in a SEPARATE process, then pasting the
/// resulting `state.json` verbatim below — into a store directory and loads
/// them through the PUBLIC API. The pin fails if the bytes drift OR the
/// recipe drifts:
///
/// - byte drift (any payload digit/field): the decode-vs-re-encode recipe no
///   longer reproduces the recorded checksum → checksum gate refuses → the
///   served state is the fallback, not the fixture.
/// - recipe drift (encoder shape, `.sortedKeys`, hash, hex case): the
///   recomputed digest over the recorded payload no longer equals the
///   recorded hex — asserted directly in `recordedChecksum…`.
/// - fixture drift (StoreFixture changes): the decoded payload no longer
///   equals the in-process `populatedState()` — asserted in both tests.
///
/// MAINTENANCE OBLIGATION (the flip side of OBS-3's documented limit): any
/// DELIBERATE payload-shape change (a §5.5 additive field) or toolchain
/// change to canonical Codable bytes BREAKS this pin by design — re-record
/// the literal then, with a fresh out-of-process capture, rather than
/// loosening the assertions.
@Suite("SnapshotStore golden bytes — recorded out-of-process generation loads through the public API (TASK-022; OBS-1)")
struct SnapshotStoreGoldenBytesTests {

    /// The recorded `state.json`, byte-exact (1827 bytes): one
    /// `{checksum, payload, savedAt, schemaVersion}` envelope with
    /// `.sortedKeys` ordering and this toolchain's canonical enum shape
    /// (simple cases as keyed objects, e.g. `{"settle":{}}` — the OBS-3
    /// limit's concrete example, preserved here as evidence).
    private static let recordedGeneration = #"{"checksum":"6025fd1e4779250d60877af51d3e405dc89dcaa22da995db4da949dc74346ea2","payload":{"days":[{"bondAwarded":12,"careCount":0,"dayKey":"2026-03-01","familiesUsed":[{"greet":{}},{"feed":{}}],"feedCount":1,"helloAwarded":true,"patCount":2,"playCount":0,"questGenEpoch":1,"questSet":[{"completed":true,"progress":1,"questID":"Q1"},{"completed":true,"progress":1,"questID":"Q2"},{"completed":false,"progress":0,"questID":"Q3"}]},{"bondAwarded":20,"careCount":1,"dayKey":"2026-03-02","familiesUsed":[{"feed":{}},{"play":{}},{"care":{}}],"feedCount":2,"helloAwarded":true,"patCount":3,"playCount":2,"questGenEpoch":1,"questSet":[{"completed":true,"progress":2,"questID":"Q4"},{"completed":false,"progress":1,"questID":"Q5"},{"completed":true,"progress":1,"questID":"Q6"}]},{"bondAwarded":8,"careCount":1,"dayKey":"2026-03-03","familiesUsed":[{"greet":{}},{"feed":{}},{"play":{}},{"care":{}},{"pet":{}}],"feedCount":0,"helloAwarded":false,"patCount":1,"playCount":1,"questGenEpoch":1,"questSet":[{"completed":true,"progress":3,"questID":"Q7"},{"completed":false,"progress":0,"questID":"Q1"},{"completed":false,"progress":0,"questID":"Q2"}]}],"highestCelebratedStage":{"gettingClose":{}},"lastEvaluatedAt":794221201,"lastGreeting":{"at":794221200,"kind":{"missedYou":{}}},"lastOpenedAt":794221200,"pendingHandshake":{"kind":{"settle":{}},"token":"A1B2C3D4-E5F6-4A7B-8C9D-0E1F2A3B4C5D"},"pet":{"createdAt":788918400,"id":"7C47A9C4-2E5F-4B8A-9C1D-3E6F8A2B4C0D","name":"Momo"},"processedIntents":["11111111-2222-4333-8444-555555555555","AAAAAAAA-BBBB-4CCC-8DDD-EEEEEEEEEEEE"],"settings":{"hapticsEnabled":false,"onboardingComplete":true},"state":{"activity":{"eating":{}},"bond":456,"energy":41.25,"lastFedAt":794219400,"mood":72.5,"satietyPhase":{"recentlyFed":{}},"wakefulness":{"waking":{}}}},"savedAt":794232000,"schemaVersion":1}"#

    /// The checksum hex embedded in the recorded envelope, pinned separately
    /// so a format accident in the literal's checksum field fails here too.
    private static let recordedChecksum = "6025fd1e4779250d60877af51d3e405dc89dcaa22da995db4da949dc74346ea2"

    private let fixture = StoreFixture()

    private func makeStore() -> (store: SnapshotStore, directory: URL) {
        let clock = ManualEngineClock(at: fixture.instant("2026-03-03T12:00:00Z"))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
        return (SnapshotStore(directory: directory, clock: clock), directory)
    }

    private func writeRecorded(_ bytes: Data, to fileName: String, in directory: URL) {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! bytes.write(to: directory.appendingPathComponent(fileName))
    }

    @Test("the recorded out-of-process generation loads through the public API with checksum verification")
    func recordedOutOfProcessGenerationLoadsThroughThePublicAPI() {
        let (store, directory) = makeStore()
        writeRecorded(Data(Self.recordedGeneration.utf8), to: StoreRules.currentStateFileName, in: directory)
        #expect(
            store.load(fallback: fixture.state(bond: 999)) == fixture.populatedState(),
            "the recorded bytes must serve the exact fixture state — any byte or recipe drift falls through to the fallback"
        )
    }

    @Test("the recorded checksum is the recipe over the recorded payload (bytes ↔ recipe coupling)")
    func recordedChecksumIsTheRecipeOverTheRecordedPayload() throws {
        let envelope = try JSONDecoder().decode(
            SnapshotStore.SnapshotEnvelope.self,
            from: Data(Self.recordedGeneration.utf8)
        )
        #expect(envelope.schemaVersion == StoreRules.currentSchemaVersion, "the recording is at the shipped schema")
        #expect(envelope.checksum == Self.recordedChecksum)
        let payloadJSON = try #require(SnapshotStore.payloadJSONData(for: envelope.payload))
        #expect(
            SnapshotStore.checksumHex(of: payloadJSON) == envelope.checksum,
            "re-deriving the recipe over the recorded payload must reproduce the recorded hex — encoder/.sortedKeys/hash/hex drift fails here"
        )
        #expect(envelope.payload == fixture.populatedState(), "the recorded payload IS the deterministic fixture (out-of-process agreement)")
    }

    @Test("a single tampered payload byte falls through to the fallback (the pin has teeth)")
    func aTamperedPayloadByteFallsThroughToTheFallback() {
        let tampered = Self.recordedGeneration.replacingOccurrences(of: "\"bond\":456", with: "\"bond\":457")
        #expect(tampered != Self.recordedGeneration, "the tamper must actually change the literal")
        #expect(tampered.count == Self.recordedGeneration.count, "the tamper is length-preserving: the checksum gate, not the decoder, must refuse it")
        let (store, directory) = makeStore()
        writeRecorded(Data(tampered.utf8), to: StoreRules.currentStateFileName, in: directory)
        #expect(
            store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 999),
            "a drifted payload byte must be refused by the checksum and fall through — never served"
        )
    }
}
