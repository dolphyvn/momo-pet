import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-041 R2 Watch snapshot store suite (05 §6.6): the two-generation
/// rotation's crash-window table (every prefix of the write sequence is a
/// loadable state), the recovery fall-through (corrupt / empty / unknown-
/// version current → `.prev` → nil), the §6.6 wipe's idempotence and its
/// file-boundary discipline (generation files ONLY — the consumed marker
/// shares the directory and must survive), and the actor's serialization
/// under real concurrency (the `SnapshotStoreConcurrencyTests` membership
/// pattern — the save order over a concurrent set is not pinnable, the
/// chain's consistency is).
@Suite("WatchSnapshotStore — §6.6 Watch-side snapshot persistence (TASK-041)")
struct WatchSnapshotStoreTests {

    private let fixture = SyncFixture()

    /// A throwaway store directory per test (the injected-directory rule;
    /// no ambient paths in tests).
    private func makeStoreDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-watch-snapshot-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// A snapshot distinct only by `snapshotSeq` — the suite's
    /// distinguishable-payload axis (the concurrency suites' bond axis).
    private func snapshot(seq: Int) -> WatchSnapshot {
        let base = fixture.snapshot()
        return WatchSnapshot(
            snapshotSeq: seq,
            display: base.display,
            questInputs: base.questInputs,
            hapticsEnabled: base.hapticsEnabled,
            lastAppliedIntentSeq: base.lastAppliedIntentSeq,
            lastAppliedEpoch: base.lastAppliedEpoch
        )
    }

    private func url(_ fileName: String, in directory: URL) -> URL {
        directory.appendingPathComponent(fileName)
    }

    // MARK: - Load recovery

    @Test("a fresh (or missing) directory loads nil — the settling-in shape")
    func freshDirectoryLoadsNil() throws {
        let store = WatchSnapshotStore(directory: try makeStoreDirectory())
        #expect(store.load() == nil, "no data is a defined quiet state, never an error")
    }

    @Test("save → load round-trips the snapshot (first save, the move path)")
    func saveThenLoadRoundTrips() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        #expect(store.load() == snapshot(seq: 12))
    }

    @Test("a second save rotates: load serves the newest, the prev file serves the predecessor")
    func secondSaveRotatesAndPrevServes() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        #expect(store.load() == snapshot(seq: 13))
        // The direct prev probe: remove the current file (the same thing a
        // crash after step 1 of the NEXT save would leave) — the recovery
        // fall-through must serve the predecessor.
        try FileManager.default.removeItem(at: url(StoreRules.watchSnapshotFileName, in: directory))
        #expect(store.load() == snapshot(seq: 12), "the one retained predecessor is the recovery generation")
    }

    @Test("a corrupted current falls through to the prev generation")
    func corruptedCurrentFallsThroughToPrev() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        try Data("not json".utf8).write(to: url(StoreRules.watchSnapshotFileName, in: directory))
        #expect(store.load() == snapshot(seq: 12))
    }

    @Test("corrupted BOTH generations load nil (and empty bytes fall through like garbage)")
    func corruptedBothLoadsNil() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        try Data("garbage".utf8).write(to: url(StoreRules.watchSnapshotFileName, in: directory))
        try Data().write(to: url(StoreRules.previousWatchSnapshotFileName, in: directory))
        #expect(store.load() == nil)
    }

    @Test("a snapshot at an UNKNOWN schema version in the current file falls through to prev (the decode gate)")
    func unknownVersionFallsThrough() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        // Hand-write a future-version snapshot's canonical bytes INTO the
        // current slot (simulating a rollback after a future install wrote
        // it) — the store's load must refuse it via `WatchSnapshot.decoded`'s
        // version gate and serve the predecessor.
        let future = WatchSnapshot(
            schemaVersion: StoreRules.watchSnapshotSchemaVersion + 1,
            snapshotSeq: 14,
            display: fixture.snapshot().display,
            questInputs: [],
            hapticsEnabled: true,
            lastAppliedIntentSeq: 5,
            lastAppliedEpoch: fixture.epoch1
        )
        let bytes = try #require(future.encoded())
        try bytes.write(to: url(StoreRules.watchSnapshotFileName, in: directory))
        #expect(store.load() == snapshot(seq: 12),
                "a version this build cannot understand must not surface as data")
    }

    // MARK: - On-disk layout (the StoreRules names)

    @Test("two saves leave EXACTLY the two StoreRules-named files and no temp")
    func onDiskLayoutIsTheTwoGenerationFiles() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        let names = try #require(try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)))
        #expect(Set(names) == [StoreRules.watchSnapshotFileName, StoreRules.previousWatchSnapshotFileName],
                "got \(names) — the commit point must consume its temp and nothing else may appear")
    }

    // MARK: - The §6.6 wipe

    @Test("wipe clears BOTH generations: load returns nil and neither file remains")
    func wipeClearsBothGenerations() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        await store.wipe()
        #expect(store.load() == nil, "post-wipe the Watch renders the settling-in line")
        let names = try #require(try? FileManager.default.contentsOfDirectory(atPath: directory.path(percentEncoded: false)))
        #expect(!names.contains(StoreRules.watchSnapshotFileName))
        #expect(!names.contains(StoreRules.previousWatchSnapshotFileName))
    }

    @Test("wipe is idempotent — over a fresh directory and repeated after a real wipe")
    func wipeIsIdempotent() async throws {
        let store = WatchSnapshotStore(directory: try makeStoreDirectory())
        await store.wipe() // nothing there yet
        await store.save(snapshot(seq: 12))
        await store.wipe()
        await store.wipe() // already gone — the F-3 replay tolerance
        #expect(store.load() == nil)
    }

    @Test("save after wipe rebirths the store through the move path")
    func saveAfterWipeRebirths() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        await store.save(snapshot(seq: 12))
        await store.wipe()
        await store.save(snapshot(seq: 20))
        #expect(store.load() == snapshot(seq: 20))
    }

    @Test("the wipe NEVER touches the consumed marker sharing the directory (the re-consumption pin)")
    func wipeLeavesTheConsumedMarkerAlone() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        let consumed = WatchConsumedMarkerStore(directory: directory)
        consumed.save(WatchResetMarker(eraseCount: 2))
        await store.save(snapshot(seq: 12))
        await store.save(snapshot(seq: 13))
        await store.wipe()
        #expect(consumed.load()?.eraseCount == 2,
                "wiping the snapshot store resets consumption to 0 and the same count re-consumes forever")
        #expect(store.load() == nil)
    }

    // MARK: - Serialization under real concurrency (the membership pattern)

    @Test("concurrent saves converge to a consistent two-generation pair")
    func concurrentSavesConverge() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        let total = 24
        let written = Set((1...total))

        await withTaskGroup(of: Void.self) { group in
            for seq in written {
                group.addTask { await store.save(snapshot(seq: seq)) }
            }
        }

        // Which seq landed where is scheduler-dependent (the
        // SnapshotStoreConcurrencyTests lesson — no issue-order pins). What
        // holds for EVERY total order: both slots hold DISTINCT members of
        // the saved set, the read path serves exactly the current slot, and
        // the chain never lost, duplicated, or fabricated a generation.
        let currentData = try #require(try? Data(contentsOf: url(StoreRules.watchSnapshotFileName, in: directory)))
        let previousData = try #require(try? Data(contentsOf: url(StoreRules.previousWatchSnapshotFileName, in: directory)))
        let current = try #require(WatchSnapshot.decoded(from: currentData))
        let previous = try #require(WatchSnapshot.decoded(from: previousData))
        #expect(written.contains(current.snapshotSeq), "current holds seq \(current.snapshotSeq) — outside the saved set")
        #expect(written.contains(previous.snapshotSeq), "prev holds seq \(previous.snapshotSeq) — outside the saved set")
        #expect(current.snapshotSeq != previous.snapshotSeq, "both slots hold the same generation")
        #expect(store.load() == current)
    }

    @Test("loads racing saves never fail and always observe nil or one complete generation")
    func loadsRacingSavesObserveOnlyCompleteGenerations() async throws {
        let directory = try makeStoreDirectory()
        let store = WatchSnapshotStore(directory: directory)
        let total = 16
        let saved = Set(1...total)
        let savers = 8
        let loadsPerLoader = 40

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<savers {
                group.addTask {
                    for seq in 1...total {
                        await store.save(snapshot(seq: seq))
                    }
                }
            }
            for _ in 0..<4 {
                group.addTask {
                    for _ in 0..<loadsPerLoader {
                        // A torn or mixed read cannot decode — it surfaces as
                        // the defined nil, never a crash; the pin is that
                        // whatever comes back IS nil or a real saved seq.
                        let loaded = store.load()
                        #expect(loaded == nil || saved.contains(loaded!.snapshotSeq),
                                "load observed seq \(loaded?.snapshotSeq as Any) — not nil nor any saved state")
                    }
                }
            }
        }

        #expect(store.load() != nil, "post-completion at least one generation survives")
    }
}
