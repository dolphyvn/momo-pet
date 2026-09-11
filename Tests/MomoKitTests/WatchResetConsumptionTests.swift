import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-041 R5 consumption suite (05 §6.6): the pure decision's FULL
/// boundary matrix (nil / equal / regression / greater, against fresh and
/// consumed baselines), the consumed-marker store's commit-point discipline
/// (the `WatchResetMarkerStore` recipe mirrored), the marker's survival of
/// snapshot wipes, and the §6.6 sequence end-to-end at kit level — including
/// the F-3 crash-window replay (wipe-before-record re-decides consume, and
/// the replay is a no-op second time).
@Suite("WatchResetConsumption — §6.6 erase consumption decision + record (TASK-041)")
struct WatchResetConsumptionTests {

    /// A throwaway store directory per test (the injected-directory rule).
    private func makeStoreDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-consumption-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - The decision matrix

    @Test("a nil incoming count always renders — the no-marker steady shape")
    func nilIncomingRenders() {
        #expect(WatchResetConsumption.decide(incomingEraseCount: nil, consumedEraseCount: 0) == .render)
        #expect(WatchResetConsumption.decide(incomingEraseCount: nil, consumedEraseCount: 3) == .render)
    }

    @Test("an EQUAL count is the steady post-consumption redelivery, not a new erase")
    func equalCountRenders() {
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 1) == .render)
        #expect(WatchResetConsumption.decide(incomingEraseCount: 5, consumedEraseCount: 5) == .render,
                "the count rides EVERY context until the next erase — equality is the normal state")
    }

    @Test("a REGRESSED count renders — a stale frame from an older erase is refused by the monotonic rule")
    func regressedCountRenders() {
        #expect(WatchResetConsumption.decide(incomingEraseCount: 2, consumedEraseCount: 3) == .render)
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 5) == .render)
    }

    @Test("a GREATER count consumes — the one new-erase signal")
    func greaterCountConsumes() {
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 0) == .consume,
                "the first erase ever: consumed defaults to 0")
        #expect(WatchResetConsumption.decide(incomingEraseCount: 4, consumedEraseCount: 3) == .consume)
    }

    @Test("the lifetime sequence: consume → redelivery renders → the second erase consumes again")
    func lifetimeSequence() {
        // Erase #1 arrives (consumed starts at 0 — nothing recorded yet).
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 0) == .consume)
        // The count keeps riding every subsequent context (TASK-040 R3) —
        // each redelivery is inert.
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 1) == .render)
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 1) == .render)
        // Erase #2 mints count 2 — a NEW consumption event.
        #expect(WatchResetConsumption.decide(incomingEraseCount: 2, consumedEraseCount: 1) == .consume)
        // …and its redeliveries are inert in turn.
        #expect(WatchResetConsumption.decide(incomingEraseCount: 2, consumedEraseCount: 2) == .render)
    }

    // MARK: - The consumed-marker store

    @Test("the store round-trips (first save, the move path) over an injected directory")
    func storeRoundTripsFirstSave() throws {
        let directory = try makeStoreDirectory()
        let store = WatchConsumedMarkerStore(directory: directory)
        #expect(store.load() == nil, "a fresh directory has consumed nothing")
        store.save(WatchResetMarker(eraseCount: 1))
        #expect(store.load()?.eraseCount == 1)
    }

    @Test("double-save is safe: the second save REPLACES (the commit-point pin)")
    func storeDoubleSaveReplaces() throws {
        let directory = try makeStoreDirectory()
        let store = WatchConsumedMarkerStore(directory: directory)
        store.save(WatchResetMarker(eraseCount: 1))
        store.save(WatchResetMarker(eraseCount: 2))
        #expect(store.load()?.eraseCount == 2, "the replace-when-present commit must land the newest count")
    }

    @Test("a second store INSTANCE over the same directory reads the record (relaunch equivalence)")
    func storeSurvivesInstanceRecreation() throws {
        let directory = try makeStoreDirectory()
        WatchConsumedMarkerStore(directory: directory).save(WatchResetMarker(eraseCount: 4))
        let reloaded = WatchConsumedMarkerStore(directory: directory)
        #expect(reloaded.load()?.eraseCount == 4)
    }

    @Test("a garbled record loads nil — nothing consumed yet, silently (the family's load stance)")
    func garbledRecordLoadsNil() throws {
        let directory = try makeStoreDirectory()
        try Data("corrupted".utf8).write(
            to: directory.appendingPathComponent(StoreRules.watchConsumedMarkerFileName)
        )
        #expect(WatchConsumedMarkerStore(directory: directory).load() == nil)
    }

    // MARK: - The §6.6 sequence at kit level

    @Test("consume wipes the snapshot store, then records — and the redelivery then renders")
    func consumptionSequenceEndToEnd() async throws {
        let directory = try makeStoreDirectory()
        let snapshots = WatchSnapshotStore(directory: directory)
        let consumed = WatchConsumedMarkerStore(directory: directory)
        await snapshots.save(fixtureSnapshot())

        // The context arrives announcing erase #1 against nothing consumed.
        let incoming = 1
        let prior = consumed.load()?.eraseCount ?? 0
        #expect(WatchResetConsumption.decide(incomingEraseCount: incoming, consumedEraseCount: prior) == .consume)
        // The executor's order: wipe FIRST, record SECOND (the F-3 stance).
        await snapshots.wipe()
        consumed.save(WatchResetMarker(eraseCount: incoming))
        #expect(snapshots.load() == nil, "the wipe precedes any re-render")
        #expect(consumed.load()?.eraseCount == 1)
        // The SAME count rides the next context — now inert.
        #expect(WatchResetConsumption.decide(incomingEraseCount: incoming, consumedEraseCount: 1) == .render)
    }

    @Test("the F-3 crash window replays safely: wipe-without-record re-decides consume and the replay is a no-op")
    func crashBeforeRecordReplaysIdempotently() async throws {
        let directory = try makeStoreDirectory()
        let snapshots = WatchSnapshotStore(directory: directory)
        let consumed = WatchConsumedMarkerStore(directory: directory)
        await snapshots.save(fixtureSnapshot())

        // Consume leg one — but the process dies AFTER the wipe, BEFORE the
        // record: the store is empty and nothing is consumed.
        await snapshots.wipe()
        #expect(consumed.load() == nil)
        // The redelivered context re-decides CONSUME (1 > 0 — the record is
        // the only thing that would have made it render).
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 0) == .consume)
        // The replayed wipe is a no-op (idempotent), and this time the
        // record lands — the system converges.
        await snapshots.wipe()
        consumed.save(WatchResetMarker(eraseCount: 1))
        #expect(snapshots.load() == nil)
        #expect(consumed.load()?.eraseCount == 1)
        #expect(WatchResetConsumption.decide(incomingEraseCount: 1, consumedEraseCount: 1) == .render)
    }

    @Test("a snapshot saved AFTER a consumption survives with the consumption recorded (the fresh-sync rebirth)")
    func postConsumptionSnapshotCoexistsWithTheRecord() async throws {
        let directory = try makeStoreDirectory()
        let snapshots = WatchSnapshotStore(directory: directory)
        let consumed = WatchConsumedMarkerStore(directory: directory)
        await snapshots.wipe()
        consumed.save(WatchResetMarker(eraseCount: 3))
        // The post-erase steady state: a NEW context (count now absent) is
        // rendered and persisted alongside the consumed record.
        #expect(WatchResetConsumption.decide(incomingEraseCount: nil, consumedEraseCount: 3) == .render)
        await snapshots.save(fixtureSnapshot())
        #expect(snapshots.load() != nil)
        #expect(consumed.load()?.eraseCount == 3)
    }

    /// Any persisted snapshot — the sequence tests only care that it IS one.
    private func fixtureSnapshot() -> WatchSnapshot {
        WatchSnapshot(
            snapshotSeq: 12,
            display: SyncFixture().display(),
            questInputs: [],
            hapticsEnabled: true,
            lastAppliedIntentSeq: 5,
            lastAppliedEpoch: SyncFixture().epoch1
        )
    }
}
