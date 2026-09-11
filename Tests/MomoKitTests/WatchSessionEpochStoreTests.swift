import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-042 R1 epoch suite (05 §6.2; the `WatchResetMarkerTests`
/// pattern applied to the Watch's own sync identity): the record's canonical
/// bytes, the store's commit-point discipline, the epoch's STABILITY across
/// relaunch-equivalent store recreation, and the defined recoveries. The
/// generation decision is CALLER-side by design — the store never mints
/// (pinned here by the store's surface having no generate path) — so the
/// app model's read-miss → mint → save → journal-wipe leg is the executor's
/// (structurally guarded there; this suite proves the store half).
@Suite("WatchSessionEpoch — §6.2 per-install identity record + store (TASK-042)")
struct WatchSessionEpochStoreTests {

    private let fixture = SyncFixture()

    /// A throwaway store directory per test (the injected-directory rule).
    private func makeEpochDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-epoch-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - The record

    @Test("the epoch record round-trips through the canonical recipe")
    func recordRoundTrips() throws {
        let epoch = WatchSessionEpoch(epoch: fixture.epoch1)
        let data = try #require(epoch.encoded())
        let decoded = try #require(WatchSessionEpoch.decoded(from: data))
        #expect(decoded == epoch)
    }

    @Test("the epoch's canonical bytes are the sorted single field (no envelope)")
    func recordBytesAreTheBareField() throws {
        let data = try #require(WatchSessionEpoch(epoch: fixture.epoch1).encoded())
        let json = String(decoding: data, as: UTF8.self)
        #expect(json == #"{"epoch":"E0000000-0000-4000-8000-000000000001"}"#, "got \(json)")
    }

    // MARK: - The store (the commit-point discipline)

    @Test("save → load round-trips over an injected directory; a fresh directory has no epoch")
    func storeRoundTrips() throws {
        let directory = try makeEpochDirectory()
        let store = WatchSessionEpochStore(directory: directory)
        #expect(store.load() == nil, "a fresh directory has no epoch — the caller generates")
        store.save(WatchSessionEpoch(epoch: fixture.epoch1))
        #expect(store.load()?.epoch == fixture.epoch1)
    }

    @Test("double-save is safe: the second save REPLACES (the moveItem-onto-existing pin)")
    func storeDoubleSaveReplaces() throws {
        let directory = try makeEpochDirectory()
        let store = WatchSessionEpochStore(directory: directory)
        store.save(WatchSessionEpoch(epoch: fixture.epoch1))
        store.save(WatchSessionEpoch(epoch: fixture.epoch2))
        #expect(store.load()?.epoch == fixture.epoch2,
                "the replace-when-present commit must land the newest epoch")
    }

    @Test("the epoch is STABLE across relaunch-equivalent store recreation (§6.2's persistence pin)")
    func epochStableAcrossRelaunch() throws {
        let directory = try makeEpochDirectory()
        WatchSessionEpochStore(directory: directory).save(WatchSessionEpoch(epoch: fixture.epoch1))

        // A "relaunch": fresh store instances over the same directory read
        // the SAME epoch — the identity a journal's events are keyed by.
        let relaunched = WatchSessionEpochStore(directory: directory)
        #expect(relaunched.load()?.epoch == fixture.epoch1)
        #expect(WatchSessionEpochStore(directory: directory).load()?.epoch == fixture.epoch1)
    }

    @Test("a garbled epoch file recovers to nil — the caller's regeneration leg (the defined, silent recovery)")
    func garbledEpochRecoversToNil() throws {
        let directory = try makeEpochDirectory()
        let url = directory.appendingPathComponent(StoreRules.watchSessionEpochFileName)
        try Data("not json".utf8).write(to: url)
        #expect(WatchSessionEpochStore(directory: directory).load() == nil)
    }

    @Test("no temp file survives a save (the commit point consumed it)")
    func noTempFileRemains() throws {
        let directory = try makeEpochDirectory()
        WatchSessionEpochStore(directory: directory).save(WatchSessionEpoch(epoch: fixture.epoch1))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
        #expect(leftovers == [StoreRules.watchSessionEpochFileName], "got \(leftovers)")
    }
}
