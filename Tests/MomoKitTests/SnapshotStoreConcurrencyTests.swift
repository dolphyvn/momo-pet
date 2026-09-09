import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The serialization claim under real concurrency (TASK-021 Requirement 4):
/// saves are total-ordered by the actor, so concurrent saves converge to a
/// consistent chain whose newest completed save is current; loads racing
/// saves are `nonisolated` on purpose (see the SnapshotStore header) so this
/// suite exercises the atomic-rename guarantee for real instead of masking
/// it behind the actor's queue. Bounded workloads only — the suite stays
/// inside the millisecond-scale store budget.
@Suite("SnapshotStore — serialized saves, racing loads (TASK-021 Requirement 4)")
struct SnapshotStoreConcurrencyTests {

    private let fixture = StoreFixture()

    private func makeDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
    }

    @Test("concurrent saves converge to a consistent chain: the last three completed saves, newest first")
    func concurrentSavesConvergeToAConsistentChain() async throws {
        let directory = makeDirectory()
        let base = fixture.instant("2026-03-03T12:00:00Z")
        let store = SnapshotStore(
            directory: directory,
            clock: TickingClock(at: base)
        )
        let total = 24
        let states = (1...total).map { fixture.state(bond: $0) }

        await withTaskGroup(of: Void.self) { group in
            for state in states {
                group.addTask { await store.save(state) }
            }
        }

        // Every save has completed, and the actor processed them in SOME
        // total order over exactly these states — but WHICH order is not
        // pinnable: neither the order in which task-group children reach the
        // save suspension point nor Swift's actor job execution order is
        // FIFO-guaranteed, so the total order may be ANY permutation of the
        // saved set. (A pin like "current == bond 24" assumed issue order,
        // which is why it flaked.) What holds for every such permutation —
        // the actual Requirement-4 invariant — is pinned below.
        let current = try #require(readEnvelope(StoreRules.currentStateFileName, in: directory))
        let previous = try #require(readEnvelope(StoreRules.previousStateFileName, in: directory))
        let oldest = try #require(readEnvelope(StoreRules.oldestStateFileName, in: directory))
        // The read path serves the newest completed generation, and it is
        // exactly the chain's current slot.
        #expect(store.load(fallback: fixture.state(bond: 999)) == current.payload)
        // The chain holds three DISTINCT members of the saved set — no lost,
        // duplicated, or fabricated generation.
        let bonds = [current.payload.state.bond, previous.payload.state.bond, oldest.payload.state.bond]
        #expect(bonds.allSatisfy { (1...total).contains($0) }, "chain holds a bond outside the saved set: \(bonds)")
        #expect(Set(bonds).count == bonds.count, "chain slots do not hold three distinct generations: \(bonds)")
        // savedAt is EXACTLY adjacent (base+21…+23) — the convergence proof,
        // subsuming strict descent. Load-bearing assumption: each save reads
        // the clock exactly ONCE (`SnapshotStore.save`'s single
        // `clock.now()`, actor-serialized) and nothing else reads it (loads
        // consume no ticks), so k completed saves leave the clock at exactly
        // tick base+(k−1): the 24 saves must land the chain — the last three
        // COMPLETED saves — on the final three ticks, whichever permutation
        // σ the scheduler chose. A store that silently skipped a save
        // (Requirement 4's convergence clause) or double-read the clock
        // shifts the arithmetic and fails here.
        #expect(current.savedAt == base.addingTimeInterval(TimeInterval(total - 1)))
        #expect(previous.savedAt == base.addingTimeInterval(TimeInterval(total - 2)))
        #expect(oldest.savedAt == base.addingTimeInterval(TimeInterval(total - 3)))
    }

    @Test("loads racing saves never fail and always observe one complete generation")
    func loadsRacingSavesObserveOnlyCompleteGenerations() async throws {
        let directory = makeDirectory()
        let base = fixture.instant("2026-03-03T12:00:00Z")
        let store = SnapshotStore(
            directory: directory,
            clock: TickingClock(at: base)
        )
        let total = 16
        let states = (1...total).map { fixture.state(bond: $0) }
        let loadableBonds = Set([999] + (1...total)) // 999 = the fallback's bond
        let savers = 8
        let loadsPerLoader = 40

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<savers {
                group.addTask {
                    for state in states {
                        await store.save(state)
                    }
                }
            }
            for _ in 0..<4 {
                group.addTask {
                    for _ in 0..<loadsPerLoader {
                        // `load` never throws and never returns a torn or
                        // unknown state: whatever it observes is the fallback
                        // or one of the savable states, distinguishable by
                        // bond. A torn read would surface as a decode failure
                        // falling through — still a valid state, but the
                        // membership pin below would catch a MIXED payload
                        // (which cannot decode at all) or a fabricated one.
                        let loaded = store.load(fallback: fixture.state(bond: 999))
                        #expect(loadableBonds.contains(loaded.state.bond), "load observed bond \(loaded.state.bond) — not the fallback nor any savable state")
                    }
                }
            }
        }

        // Post-completion all 8 × 16 = 128 saves have completed (the task
        // group joins every saver), but WHICH save lands globally last is
        // scheduler-dependent across the savers' interleavings — so the
        // served state's BOND is not pinnable; the sound pin is membership,
        // a real saved state, never the fallback. Its snapshot time IS
        // pinned exactly, on the current envelope (`EngineState` carries no
        // savedAt): each save consumes exactly one clock tick (loads read
        // no ticks), so 128 completed saves leave the last tick at
        // base+127, and the read path must serve that globally-last save.
        // A silently skipped save shifts the arithmetic and fails here.
        let final = store.load(fallback: fixture.state(bond: 999))
        #expect((1...total).contains(final.state.bond), "post-completion load observed bond \(final.state.bond) — not any saved state")
        let finalCurrent = try #require(readEnvelope(StoreRules.currentStateFileName, in: directory))
        #expect(final == finalCurrent.payload)
        #expect(finalCurrent.savedAt == base.addingTimeInterval(TimeInterval(savers * total - 1)))
    }

    /// Test-side envelope reader (the concurrency assertions decode the chain
    /// directly rather than going through `load`).
    private func readEnvelope(_ fileName: String, in directory: URL) -> SnapshotStore.SnapshotEnvelope? {
        guard let bytes = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else {
            return nil
        }
        return try? JSONDecoder().decode(SnapshotStore.SnapshotEnvelope.self, from: bytes)
    }
}
