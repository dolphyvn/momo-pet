import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-042 R2c journal-wipe suite: `IntentJournal.wipe()` — the §6.6
/// consumption's journal half AND the epoch (re)generation's F-3
/// self-defense. Pins the two states that matter for the executor's
/// replay-idempotence argument: a PRESENT journal is removed, an ABSENT one
/// stays absent (so a crash between the wipe legs replays as a no-op), and
/// nothing else in the directory is touched (the consumed marker and the
/// snapshot pair are the other legs' files — a wipe that reached them would
/// break the F-3 ordering's recoverability).
@Suite("IntentJournal.wipe — §6.6 journal half + F-3 epoch self-defense (TASK-042)")
struct IntentJournalWipeTests {

    private let fixture = SyncFixture()

    private func makeJournalDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("momo-journal-wipe-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func populate(_ journal: IntentEvent...) throws -> URL {
        let directory = try makeJournalDirectory()
        let target = IntentJournal(directory: directory)
        for event in journal {
            target.append(event)
        }
        return directory
    }

    private func journalExists(in directory: URL) -> Bool {
        FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(StoreRules.intentJournalFileName).path(percentEncoded: false)
        )
    }

    @Test("a present journal is removed by wipe")
    func presentJournalIsRemoved() throws {
        let directory = try populate(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        )
        #expect(journalExists(in: directory), "precondition: the journal is on disk")
        IntentJournal(directory: directory).wipe()
        #expect(!journalExists(in: directory))
        #expect(IntentJournal(directory: directory).events().isEmpty, "an absent journal parses to the empty queue")
    }

    @Test("wiping an absent journal is a SUCCESS no-op (the replay-idempotence pin)")
    func absentJournalWipeIsANoOp() throws {
        let directory = try makeJournalDirectory()
        IntentJournal(directory: directory).wipe()
        #expect(!journalExists(in: directory))
        // And it stays a no-op after a prior wipe (the double-wipe replay).
        IntentJournal(directory: directory).wipe()
        #expect(!journalExists(in: directory))
    }

    @Test("wipe touches ONLY the journal file — siblings (marker shape, snapshot bytes) survive")
    func wipeTouchesOnlyTheJournal() throws {
        let directory = try populate(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        )
        // A sibling file a real store directory always carries.
        let sibling = directory.appendingPathComponent(StoreRules.watchConsumedMarkerFileName)
        try Data(#"{"eraseCount":2}"#.utf8).write(to: sibling)

        IntentJournal(directory: directory).wipe()

        #expect(!journalExists(in: directory))
        #expect(FileManager.default.fileExists(atPath: sibling.path(percentEncoded: false)),
                "the wipe must never reach the directory's other stores")
    }

    @Test("wipe is total over a torn journal (the crash-recovery input wipes clean too)")
    func tornJournalWipesClean() throws {
        let directory = try populate(
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        )
        // Tear the trailing line (the mid-append crash shape).
        let url = directory.appendingPathComponent(StoreRules.intentJournalFileName)
        let torn = try Data(contentsOf: url).prefix(40)
        try Data(torn).write(to: url)

        IntentJournal(directory: directory).wipe()

        #expect(!journalExists(in: directory))
    }
}
