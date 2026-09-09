import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-023 snapshot builder matrix (contract Requirement 6, AC-5): the
/// pure, ambient-free assembly pin — every field of the produced snapshot is
/// threaded from an EXPLICIT input (`display` verbatim, `questInputs`
/// verbatim, `hapticsEnabled` from the engine state's settings — no ambient
/// read anywhere, `lastAppliedEpoch` the parameter, `lastAppliedIntentSeq`
/// the watermark of THAT epoch only), the snapshot sequence is consumed from
/// (and returned through) the sync state so monotonicity is structural, and
/// the empty-state totality is defined. The function is a single call with
/// no hidden inputs — these tests fail if a clock, calendar, or store ever
/// sneaks in.
@Suite("WatchSnapshotBuilder — pure field threading, seq consumption (TASK-023; 05 §6.4)")
struct WatchSnapshotBuilderTests {

    private let fixture = SyncFixture()
    private let storeFixture = StoreFixture()

    // MARK: - Field-for-field threading

    @Test("every snapshot field is threaded from the explicit inputs (the no-ambient-read pin)")
    func fieldsThreadFromExplicitInputs() {
        let display = fixture.display()
        let questInputs = [
            fixture.quest(.q1, progress: 1, completed: true),
            fixture.quest(.q2, progress: 0, completed: false),
        ]
        let sync = SyncState(watermarks: [
            fixture.epoch1: 5,
            fixture.watermarkEpoch: 9,
        ], nextSnapshotSeq: 12)

        let result = makeWatchSnapshot(
            state: storeFixture.populatedState(), // hapticsEnabled: false
            display: display,
            questInputs: questInputs,
            watermarkEpoch: fixture.watermarkEpoch,
            sync: sync
        )

        let snapshot = result.snapshot
        #expect(snapshot.display == display, "the read model is threaded verbatim")
        #expect(snapshot.questInputs == questInputs, "the quest rows are threaded verbatim")
        #expect(snapshot.hapticsEnabled == false, "sourced from the state's settings, not an ambient read")
        #expect(snapshot.lastAppliedEpoch == fixture.watermarkEpoch, "the parameter is the snapshot's epoch")
        #expect(snapshot.lastAppliedIntentSeq == 9, "the watermark of THAT epoch — epoch1's 5 must not leak")
        #expect(snapshot.snapshotSeq == 12, "the seq is consumed from the sync state")
        #expect(snapshot.schemaVersion == StoreRules.watchSnapshotSchemaVersion)
    }

    @Test("hapticsEnabled follows the engine state's setting (both values)",
          arguments: [(state: "populated", expected: false), (state: "bond", expected: true)])
    func hapticsFollowsTheSettings(_ spec: (state: String, expected: Bool)) {
        let state = spec.state == "populated"
            ? storeFixture.populatedState()
            : storeFixture.state(bond: 10)
        #expect(state.settings.hapticsEnabled == spec.expected, "fixture preconditions hold")
        let result = makeWatchSnapshot(
            state: state,
            display: fixture.display(),
            questInputs: [],
            watermarkEpoch: fixture.epoch1,
            sync: SyncState()
        )
        #expect(result.snapshot.hapticsEnabled == spec.expected)
    }

    // MARK: - The sequence's structural monotonicity

    @Test("the returned sync state is the advanced one: repeated builds consume 1, 2, 3")
    func repeatedBuildsConsumeMonotoneSeqs() {
        var sync = SyncState()
        var seqs: [Int] = []
        for _ in 1...3 {
            let result = makeWatchSnapshot(
                state: storeFixture.state(bond: 10),
                display: fixture.display(),
                questInputs: [],
                watermarkEpoch: fixture.epoch1,
                sync: sync
            )
            seqs.append(result.snapshot.snapshotSeq)
            sync = result.nextSync
        }
        #expect(seqs == [1, 2, 3], "the caller must thread nextSync back; the builder never resets")
        #expect(sync.nextSnapshotSeq == 4)
    }

    @Test("an empty sync state yields lastAppliedIntentSeq 0 and seq 1 (totality at the origin)")
    func emptySyncStateYieldsDefinedOrigin() {
        let result = makeWatchSnapshot(
            state: storeFixture.state(bond: 10),
            display: fixture.display(),
            questInputs: [],
            watermarkEpoch: fixture.epoch1,
            sync: SyncState()
        )
        #expect(result.snapshot.lastAppliedIntentSeq == 0)
        #expect(result.snapshot.snapshotSeq == 1)
        #expect(result.nextSync.nextSnapshotSeq == 2)
    }

    // MARK: - Purity shape (the same inputs → the same snapshot, seq aside)

    @Test("two builds from identical inputs are identical apart from the consumed seq")
    func buildsAreDeterministic() {
        let state = storeFixture.populatedState()
        let display = fixture.display()
        let questInputs = [fixture.quest(.q3, progress: 2, completed: false)]
        let sync = SyncState(watermarks: [fixture.epoch1: 3])
        let first = makeWatchSnapshot(state: state, display: display, questInputs: questInputs,
                                      watermarkEpoch: fixture.epoch1, sync: sync)
        let second = makeWatchSnapshot(state: state, display: display, questInputs: questInputs,
                                       watermarkEpoch: fixture.epoch1, sync: sync)
        // Each build consumes from the SAME seed state, so the seqs agree —
        // and the full snapshots are equal. (The "no ambient read" claim's
        // observable consequence: nothing but the inputs can move the value.)
        #expect(first.snapshot == second.snapshot)
        #expect(first.nextSync == second.nextSync)
    }
}
