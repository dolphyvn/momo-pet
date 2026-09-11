import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-040 R3 reset-marker suite (05 §6.6; the TASK-038 routed AC-2
/// leg): the marker RECORD's shape, the marker STORE's commit-point
/// discipline (double-save safe — the `moveItem`-onto-existing lesson), the
/// `WatchSnapshot` ADDITIVE-OPTIONAL carrier (round-trip, key-omission for
/// the no-marker shape, pre-marker payload compatibility with NO
/// schemaVersion bump), and the builder's pass-through. The erase→survival
/// sequence is simulated at the kit level exactly as `eraseAllData()` runs
/// it: load the persisted count → +1 → save → (the caller deletes its OWN
/// tree — never the marker's directory) → a fresh store over a fresh
/// process-equivalent directory instance reads the marker back.
@Suite("WatchResetMarker — §6.6 erase signal record, store, additive context carrier (TASK-040)")
struct WatchResetMarkerTests {

    private let fixture = SyncFixture()
    private let storeFixture = StoreFixture()

    /// A throwaway marker directory per test (the injected-directory rule;
    /// no ambient paths in tests).
    private func makeMarkerDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-marker-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - The record

    @Test("the marker record round-trips through the canonical recipe")
    func recordRoundTrips() throws {
        let marker = WatchResetMarker(eraseCount: 3)
        let data = try #require(marker.encoded())
        let decoded = try #require(WatchResetMarker.decoded(from: data))
        #expect(decoded == marker)
    }

    @Test("the marker's canonical bytes are the sorted single field (no envelope)")
    func recordBytesAreTheBareField() throws {
        let marker = WatchResetMarker(eraseCount: 1)
        let data = try #require(marker.encoded())
        let json = String(decoding: data, as: UTF8.self)
        #expect(json == #"{"eraseCount":1}"#, "got \(json) — the sync-state precedent: plain, no envelope")
    }

    // MARK: - The store (the commit-point discipline)

    @Test("save → load round-trips over an injected directory (the move path)")
    func storeRoundTripsFirstSave() throws {
        let directory = try makeMarkerDirectory()
        let store = WatchResetMarkerStore(directory: directory)
        #expect(store.load() == nil, "a fresh directory has no marker")
        store.save(WatchResetMarker(eraseCount: 1))
        #expect(store.load()?.eraseCount == 1)
    }

    @Test("double-save is safe: the second save REPLACES (the moveItem-onto-existing pin)")
    func storeDoubleSaveReplaces() throws {
        let directory = try makeMarkerDirectory()
        let store = WatchResetMarkerStore(directory: directory)
        store.save(WatchResetMarker(eraseCount: 1))
        store.save(WatchResetMarker(eraseCount: 2))
        #expect(store.load()?.eraseCount == 2,
                "the replace-when-present commit must land the newest count")
    }

    @Test("a second store INSTANCE over the same directory reads the persisted marker (relaunch equivalence)")
    func storeSurvivesInstanceRecreation() throws {
        let directory = try makeMarkerDirectory()
        WatchResetMarkerStore(directory: directory).save(WatchResetMarker(eraseCount: 4))
        // A fresh process equivalent: a brand-new store over the same path.
        let reloaded = WatchResetMarkerStore(directory: directory)
        #expect(reloaded.load()?.eraseCount == 4)
    }

    @Test("the erase sequence outlives the erase: marker saved OUTSIDE the deleted tree survives it")
    func markerOutlivesTheErasedStoreTree() throws {
        let markerDirectory = try makeMarkerDirectory()
        let storeTree = try makeMarkerDirectory() // the erase's deletion target

        // First erase (marker store writes OUTSIDE the tree), then the
        // executor's tree deletion — the exact `eraseAllData()` order.
        let markerStore = WatchResetMarkerStore(directory: markerDirectory)
        let firstCount = (markerStore.load()?.eraseCount ?? 0) + 1
        markerStore.save(WatchResetMarker(eraseCount: firstCount))
        try FileManager.default.removeItem(at: storeTree)

        // A relaunch later (fresh instances): the signal is intact…
        #expect(WatchResetMarkerStore(directory: markerDirectory).load()?.eraseCount == 1)
        // …and the store tree is really gone (the fresh-install shape).
        #expect(!FileManager.default.fileExists(atPath: storeTree.path(percentEncoded: false)))

        // A SECOND erase increments over the survivor: one-shot consumption
        // needs distinct counts per erase.
        let secondCount = (markerStore.load()?.eraseCount ?? 0) + 1
        markerStore.save(WatchResetMarker(eraseCount: secondCount))
        #expect(WatchResetMarkerStore(directory: markerDirectory).load()?.eraseCount == 2)
    }

    @Test("a garbled marker file recovers to nil (the defined, silent recovery)")
    func garbledMarkerRecoversToNil() throws {
        let directory = try makeMarkerDirectory()
        let url = directory.appendingPathComponent(StoreRules.watchResetMarkerFileName)
        try Data("not json".utf8).write(to: url)
        #expect(WatchResetMarkerStore(directory: directory).load() == nil)
    }

    @Test("no temp file survives a save (the commit point consumed it)")
    func noTempFileRemains() throws {
        let directory = try makeMarkerDirectory()
        WatchResetMarkerStore(directory: directory).save(WatchResetMarker(eraseCount: 1))
        let leftovers = try FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false))
        #expect(leftovers == [StoreRules.watchResetMarkerFileName], "got \(leftovers)")
    }

    // MARK: - The additive-optional context carrier

    @Test("the builder passes the marker count through verbatim; the default is nil")
    func builderPassesTheCountThrough() {
        let state = storeFixture.state(bond: 10)
        let sync = SyncState()
        let without = makeWatchSnapshot(
            state: state, display: fixture.display(), questInputs: [],
            watermarkEpoch: fixture.epoch1, sync: sync
        )
        let with = makeWatchSnapshot(
            state: state, display: fixture.display(), questInputs: [],
            watermarkEpoch: fixture.epoch1, sync: sync, resetMarkerEraseCount: 7
        )
        #expect(without.snapshot.resetMarkerEraseCount == nil, "no erase pending is the default shape")
        #expect(with.snapshot.resetMarkerEraseCount == 7, "the count is threaded verbatim")
        #expect(with.nextSync == without.nextSync, "the marker leg consumes no sync state")
    }

    @Test("a marker-bearing snapshot round-trips through encode → decode")
    func markerSurvivesTheWireRoundTrip() throws {
        let snapshot = fixture.snapshot()
        let carried = WatchSnapshot(
            snapshotSeq: snapshot.snapshotSeq,
            display: snapshot.display,
            questInputs: snapshot.questInputs,
            hapticsEnabled: snapshot.hapticsEnabled,
            lastAppliedIntentSeq: snapshot.lastAppliedIntentSeq,
            lastAppliedEpoch: snapshot.lastAppliedEpoch,
            resetMarkerEraseCount: 2
        )
        let data = try #require(carried.encoded())
        let decoded = try #require(WatchSnapshot.decoded(from: data))
        #expect(decoded == carried)
        #expect(decoded.resetMarkerEraseCount == 2)
    }

    @Test("a no-marker snapshot's bytes OMIT the key (byte-compatibility with the pre-marker wire shape)")
    func noMarkerBytesOmitTheKey() throws {
        let data = try #require(fixture.snapshot().encoded())
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("resetMarkerEraseCount"),
                "encodeIfPresent must omit the key when nil — got \(json)")
    }

    @Test("a PRE-MARKER payload decodes cleanly with the marker absent (the no-bump compatibility pin)")
    func preMarkerPayloadDecodesCleanly() throws {
        // Build the pre-marker shape: the full snapshot minus the new key.
        // The codec's decodeIfPresent is what makes this byte stream legal
        // — no schemaVersion bump, no dropped payload.
        let snapshot = fixture.snapshot()
        let noMarker = WatchSnapshot(
            snapshotSeq: snapshot.snapshotSeq,
            display: snapshot.display,
            questInputs: snapshot.questInputs,
            hapticsEnabled: snapshot.hapticsEnabled,
            lastAppliedIntentSeq: snapshot.lastAppliedIntentSeq,
            lastAppliedEpoch: snapshot.lastAppliedEpoch
        )
        let data = try #require(noMarker.encoded())
        #expect(!String(decoding: data, as: UTF8.self).contains("resetMarkerEraseCount"))
        let decoded = try #require(WatchSnapshot.decoded(from: data))
        #expect(decoded == noMarker)
        #expect(decoded.resetMarkerEraseCount == nil)
    }

    @Test("a marker-bearing payload encodes the key (the carrier is real, not vacuous)")
    func markerKeyIsPresentWhenCarried() throws {
        let carried = WatchSnapshot(
            snapshotSeq: 1,
            display: fixture.display(),
            questInputs: [],
            hapticsEnabled: false,
            lastAppliedIntentSeq: 0,
            lastAppliedEpoch: fixture.epoch1,
            resetMarkerEraseCount: 5
        )
        let json = String(decoding: try #require(carried.encoded()), as: UTF8.self)
        #expect(json.contains(#""resetMarkerEraseCount":5"#), "got \(json)")
    }
}
