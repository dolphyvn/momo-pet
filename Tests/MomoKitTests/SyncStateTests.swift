import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-023 sync-state matrix (contract Requirement 3/5, AC-4): the
/// per-epoch watermark accessor's 0-init (§6.6), the strictly-monotone
/// snapshot sequence (iPhone-owned, per sync-state-file lifetime — reset is
/// a Watch display no-op, never a gate input, so its monotonicity scope is
/// deliberately per-file and pinned as such), persistence roundtrips through
/// `SyncStateStore` over an injected directory, and the store's totality
/// (absent / empty / garbled → fresh, never throwing).
@Suite("SyncState + SyncStateStore — watermark table, snapshot seq, durable sync state (TASK-023; 05 §6.4)")
struct SyncStateTests {

    private let fixture = SyncFixture()

    // MARK: - Harness

    private func makeStore() -> (store: SyncStateStore, directory: URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-sync-state-\(UUID().uuidString)", isDirectory: true)
        return (SyncStateStore(directory: directory), directory)
    }

    private func syncStateFileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(StoreRules.syncStateFileName)
    }

    // MARK: - The watermark accessor (the one 0-init site)

    @Test("an unseen epoch reads watermark 0 (the §6.6 initialization)")
    func unseenEpochReadsZero() {
        #expect(SyncState().watermark(for: fixture.epoch1) == 0)
        #expect(SyncState().watermarks.isEmpty, "reading must not mutate the table")
    }

    @Test("a known epoch reads its recorded watermark back")
    func knownEpochReadsRecordedWatermark() {
        let sync = SyncState(watermarks: [fixture.epoch1: 7, fixture.epoch2: 2])
        #expect(sync.watermark(for: fixture.epoch1) == 7)
        #expect(sync.watermark(for: fixture.epoch2) == 2)
    }

    // MARK: - The snapshot sequence (strictly monotone per file lifetime)

    @Test("consumingSnapshotSeq assigns 1, 2, 3 — strictly monotone from a fresh state")
    func consumingSnapshotSeqIsStrictlyMonotone() {
        let sync = SyncState()
        let first = sync.consumingSnapshotSeq()
        let second = first.sync.consumingSnapshotSeq()
        let third = second.sync.consumingSnapshotSeq()
        #expect(first.assignedSeq == 1)
        #expect(second.assignedSeq == 2)
        #expect(third.assignedSeq == 3)
        #expect(third.sync.nextSnapshotSeq == 4)
    }

    @Test("an explicitly-seeded next seq continues monotonically from the seed")
    func seededNextSeqContinuesMonotonically() {
        let sync = SyncState(nextSnapshotSeq: 41)
        let consumed = sync.consumingSnapshotSeq()
        #expect(consumed.assignedSeq == 41)
        #expect(consumed.sync.nextSnapshotSeq == 42)
    }

    // MARK: - Persistence through SyncStateStore (injected directory)

    @Test("a multi-epoch sync state roundtrips through save → load exactly")
    func multiEpochStateRoundtripsThroughStore() {
        let (store, _) = makeStore()
        var sync = SyncState()
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 5)
        )
        sync = sync.recordingApplied(
            fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch2, seq: 9)
        )
        sync = sync.consumingSnapshotSeq().sync
        sync = sync.consumingSnapshotSeq().sync

        store.save(sync)
        #expect(store.load() == sync, "the whole table, both epochs, and the seq survive persistence")
    }

    @Test("the persisted sync state is a plain JSON document (sorted keys, no envelope)")
    func persistedBytesArePlainJSON() {
        let (store, directory) = makeStore()
        let sync = SyncState(watermarks: [fixture.epoch1: 3])
        store.save(sync)
        let json = String(data: try! Data(contentsOf: syncStateFileURL(in: directory)), encoding: .utf8)!
        #expect(json.hasPrefix("{"))
        #expect(json.contains("\"watermarks\""))
        #expect(json.contains("\"nextSnapshotSeq\""))
        #expect(!json.contains("checksum"), "sync state is deliberately envelope-free (no §7 checksum recipe)")
    }

    @Test("an absent file loads as a fresh state (never throws, never creates)")
    func absentFileLoadsFresh() {
        let (store, directory) = makeStore()
        let loaded = store.load()
        #expect(loaded == SyncState())
        #expect(!FileManager.default.fileExists(
            atPath: syncStateFileURL(in: directory).path(percentEncoded: false)
        ))
    }

    @Test("garbled and empty bytes load as a fresh state (totality of load)")
    func garbledFileLoadsFresh() {
        let (store, directory) = makeStore()
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! Data("not json".utf8).write(to: syncStateFileURL(in: directory))
        #expect(store.load() == SyncState())

        try! Data().write(to: syncStateFileURL(in: directory))
        #expect(store.load() == SyncState(), "an empty file is also the fresh state")
    }

    @Test("the gate advances are durable: load → record → save → load yields the identical state")
    func recordedWatermarkSurvivesRePersistence() {
        let (store, _) = makeStore()
        let event = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 4)
        let first = store.load()
        let advanced = first.recordingApplied(event).consumingSnapshotSeq().sync
        store.save(advanced)
        #expect(store.load() == advanced)
        #expect(store.load().watermark(for: fixture.epoch1) == 4)
        #expect(store.load().nextSnapshotSeq == 2)
    }

    @Test("saving leaves no temp file behind (the atomic commit point)")
    func saveLeavesNoTempBehind() {
        let (store, directory) = makeStore()
        store.save(SyncState(watermarks: [fixture.epoch1: 1]))
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(StoreRules.temporarySyncStateFileName).path(percentEncoded: false)
        ))
    }

    // MARK: - Regression pins (REVIEW-TASK-023's confirmed MAJOR: the
    // second save must LAND — replace-when-present — not fail onto the
    // existing file)

    @Test("a second save over the existing file LANDS (the replace-when-present commit point)")
    func secondSaveOverExistingFileLands() {
        let (store, _) = makeStore()
        let first = SyncState(watermarks: [fixture.epoch1: 1])
        store.save(first)
        #expect(store.load() == first, "precondition: the first save is in place")
        // The exact shape the defect hid behind: a save over the NOW-
        // EXISTING file — the app's second sync-state write. Before the
        // fix this failed (Code 516) into the DEBUG-loud path.
        let second = SyncState(
            watermarks: [fixture.epoch1: 5, fixture.epoch2: 2],
            nextSnapshotSeq: 7
        )
        store.save(second)
        #expect(store.load() == second,
                "the watermark table update must persist — the second save must land, not fail")
    }

    @Test("no temp is left behind after the SECOND save (cleanup on the replace path)")
    func secondSaveLeavesNoTempBehind() {
        let (store, directory) = makeStore()
        store.save(SyncState(watermarks: [fixture.epoch1: 1]))
        store.save(SyncState(watermarks: [fixture.epoch1: 2]))
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(StoreRules.temporarySyncStateFileName).path(percentEncoded: false)
        ))
    }
}
