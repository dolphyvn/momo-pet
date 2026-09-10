import Testing
import Foundation
@testable import MomoKit

/// The launch-read probe's suite (TASK-031; 05 §5.2–§5.3): `AppModelLaunch`
/// decides fresh-vs-loaded by GENERATION PRESENCE (any file in
/// `StoreRules.generationFileNamesInReadOrder` existing), never by content —
/// so a corrupt store still reads as "loaded" and `SnapshotStore.load`'s
/// fallback recovers invisibly. The integration row drives a real
/// `SnapshotStore` save and then corrupts every generation.
@Suite
struct AppModelLaunchTests {

    /// A unique throwaway store directory per case.
    private func makeDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("task031-launch-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    /// An empty directory is a fresh store.
    @Test("empty directory → fresh")
    func emptyDirectoryIsFresh() throws {
        #expect(AppModelLaunch.hasGenerations(directory: try makeDirectory()) == false)
    }

    /// The current generation alone reads as loaded.
    @Test("state.json present → loaded")
    func currentGenerationMeansLoaded() throws {
        let directory = try makeDirectory()
        try Data("x".utf8).write(to: directory.appendingPathComponent(StoreRules.currentStateFileName))
        #expect(AppModelLaunch.hasGenerations(directory: directory))
    }

    /// ANY generation in read order counts — a crash mid-rotation that left
    /// only an older generation still launches as a loaded store.
    @Test("state.prev.json alone → loaded")
    func previousGenerationAloneMeansLoaded() throws {
        let directory = try makeDirectory()
        try Data("x".utf8).write(to: directory.appendingPathComponent(StoreRules.previousStateFileName))
        #expect(AppModelLaunch.hasGenerations(directory: directory))
    }

    /// The integration row: a real save flips the probe to loaded; then
    /// EVERY generation corrupted, the probe STILL says loaded and the
    /// store's load falls through to the injected fallback invisibly (§5.3)
    /// — the executor's `requiresOnboarding` lands on the fallback's own
    /// flag, indistinguishable from a fresh store, exactly as specified.
    @Test("saved store is loaded; total corruption falls through invisibly")
    func savedStoreIsLoadedAndCorruptionFallthroughIsInvisible() async throws {
        let directory = try makeDirectory()
        let fixture = StoreFixture()
        let store = SnapshotStore(
            directory: directory,
            clock: TickingClock(at: fixture.instant("2026-03-03T09:00:00Z"))
        )

        // Fresh before the save, loaded after it.
        #expect(AppModelLaunch.hasGenerations(directory: directory) == false)
        await store.save(fixture.populatedState())
        #expect(AppModelLaunch.hasGenerations(directory: directory))

        // Corrupt all three generations in place.
        for name in StoreRules.generationFileNamesInReadOrder {
            try Data("not json at all".utf8).write(to: directory.appendingPathComponent(name))
        }
        // Presence-based: still a "loaded" store — the probe never reads
        // content, so corruption cannot masquerade as freshness.
        #expect(AppModelLaunch.hasGenerations(directory: directory))
        // The load falls through to the injected fallback, verbatim.
        let fallback = fixture.state(bond: 10)
        #expect(store.load(fallback: fallback) == fallback)
    }
}
