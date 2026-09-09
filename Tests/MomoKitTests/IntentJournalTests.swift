import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-023 journal matrix (contract Requirement 4, AC-2): append →
/// parse roundtrips (FIFO order), torn-line tolerance (the §6.4 crash
/// tolerance — trailing tears lose only themselves, never earlier entries;
/// mid-file garbage and blank lines follow the same documented skip
/// semantics), the epoch-matched prune (the ≤ boundary pinned exactly; a
/// stale-epoch watermark leaves the file byte-identical; a two-epoch
/// journal prunes per entry; epoch identity survives the rewrite), and
/// totality over absent/empty/oversized journals. Every public API is
/// non-throwing BY SIGNATURE — the tests exercise the defined paths, and
/// the no-`try` shape is the no-error-surface claim (FR-18 AC-4's half).
@Suite("IntentJournal — NDJSON append/parse/prune, torn-line tolerance, epoch-matched prune (TASK-023; 05 §6.4)")
struct IntentJournalTests {

    private let fixture = SyncFixture()

    // MARK: - Harness

    /// A journal over a fresh throwaway directory.
    private func makeJournal() -> (journal: IntentJournal, directory: URL) {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-journal-\(UUID().uuidString)", isDirectory: true)
        return (IntentJournal(directory: directory), directory)
    }

    private var journalFileName: String { StoreRules.intentJournalFileName }

    private func fileURL(in directory: URL) -> URL {
        directory.appendingPathComponent(journalFileName)
    }

    private func readBytes(_ directory: URL) -> Data? {
        try? Data(contentsOf: fileURL(in: directory))
    }

    private func writeBytes(_ bytes: Data, to directory: URL) {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! bytes.write(to: fileURL(in: directory))
    }

    /// `count` distinct pats journaled at seqs 1…count in `epoch`.
    private func appendPats(_ journal: IntentJournal, count: Int, epoch: UUID) -> [IntentEvent] {
        let events = (1...count).map { seq in
            fixture.event(
                fixture.intent(
                    id: fixture.intentID(seq),
                    at: fixture.instant(String(format: "2026-09-09T20:%02d:00Z", seq))
                ),
                epoch: epoch,
                seq: seq
            )
        }
        for event in events {
            journal.append(event)
        }
        return events
    }

    /// The independently-built NDJSON bytes for `events` (one canonical line
    /// each, newline-terminated) — the prune byte pins' expected form.
    private func ndjson(_ events: [IntentEvent]) -> Data {
        var data = Data()
        for event in events {
            data.append(SyncFixture.canonicalData(event))
            data.append(0x0A)
        }
        return data
    }

    // MARK: - Append + parse roundtrip

    @Test("append → parse roundtrips N events in FIFO order, one line per event")
    func appendThenParseRoundtripsInOrder() {
        let (journal, directory) = makeJournal()
        let events = appendPats(journal, count: 3, epoch: fixture.epoch1)
        #expect(journal.events() == events, "FIFO order preserved; each event intact")
        // Format pins: newline-terminated, exactly one line per event.
        let bytes = readBytes(directory)!
        #expect(bytes.last == 0x0A)
        #expect(bytes.split(separator: 0x0A).count == 3)
    }

    @Test("append creates a missing (nested) directory and still roundtrips")
    func appendCreatesMissingDirectory() {
        let (journal, directory) = makeJournal()
        #expect(!FileManager.default.fileExists(atPath: directory.path(percentEncoded: false)))
        let events = appendPats(journal, count: 1, epoch: fixture.epoch1)
        #expect(journal.events() == events)
    }

    // MARK: - Torn-line tolerance (the §6.4 crash tolerance)

    @Test("a torn trailing line is skipped; the earlier entries survive intact")
    func tornTrailingLineIsSkipped() {
        let (journal, directory) = makeJournal()
        let events = appendPats(journal, count: 3, epoch: fixture.epoch1)
        // Simulate a mid-append crash: cut INSIDE the last line (5 bytes off
        // the end — the last line is a full JSON object, far longer).
        var torn = readBytes(directory)!
        torn = torn.prefix(torn.count - 5)
        writeBytes(torn, to: directory)
        #expect(journal.events() == Array(events.prefix(2)),
                "the torn trailing line loses only itself")
    }

    @Test("an append after a tear seals it: the new event parses; the torn line stays skipped")
    func appendAfterTearPreservesTheNewEvent() {
        let (journal, directory) = makeJournal()
        let events = appendPats(journal, count: 3, epoch: fixture.epoch1)
        var torn = readBytes(directory)!
        torn = torn.prefix(torn.count - 5) // event 3 torn
        writeBytes(torn, to: directory)
        let fresh = fixture.event(fixture.intent(id: fixture.intentID(4)), epoch: fixture.epoch1, seq: 4)
        journal.append(fresh)
        // The torn third line is skipped; events 1, 2, and the NEW 4 survive.
        #expect(journal.events() == [events[0], events[1], fresh])
    }

    @Test("mid-file corruption (not just a trailing tear) follows the same skip semantics")
    func midFileGarbageLineIsSkipped() {
        let (journal, directory) = makeJournal()
        let events = appendPats(journal, count: 2, epoch: fixture.epoch1)
        var corrupted = ndjson([events[0]])
        corrupted.append(Data("this is not json\n".utf8))
        corrupted.append(ndjson([events[1]]))
        writeBytes(corrupted, to: directory)
        #expect(journal.events() == events, "the garbage line is skipped; both valid events survive")
    }

    @Test("blank lines are ignored (not events, not defects)")
    func blankLinesAreIgnored() {
        let (journal, directory) = makeJournal()
        let events = appendPats(journal, count: 2, epoch: fixture.epoch1)
        var padded = ndjson([events[0]])
        padded.append(Data("\n\n".utf8))
        padded.append(ndjson([events[1]]))
        writeBytes(padded, to: directory)
        #expect(journal.events() == events)
    }

    @Test("an unknown-version line is skipped by the journal (a future version cannot wedge the queue)")
    func unknownVersionLineIsSkipped() {
        let (journal, directory) = makeJournal()
        let current = fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 1)
        let future = fixture.event(
            fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2,
            schemaVersion: StoreRules.intentEventSchemaVersion + 1
        )
        writeBytes(ndjson([current, future]), to: directory)
        #expect(journal.events() == [current])
    }

    // MARK: - The prune (epoch-matched ONLY; the ≤ boundary pinned exactly)

    @Test("prune drops watchSeq ≤ watermark and keeps watchSeq > watermark (the boundary is ≤)")
    func pruneBoundaryIsInclusive() {
        let (journal, _) = makeJournal()
        let events = appendPats(journal, count: 5, epoch: fixture.epoch1)
        journal.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 3)
        #expect(journal.events() == Array(events.suffix(2)),
                "seqs 1, 2, 3 dropped (≤ 3); 4, 5 kept (> 3)")
        // The exact boundary: watermark == 3 drops seq 3 itself; watermark
        // == 2 keeps it.
        let (boundary, _) = makeJournal()
        let boundaryEvents = appendPats(boundary, count: 5, epoch: fixture.epoch1)
        boundary.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 2)
        #expect(boundaryEvents[2].watchSeq == 3)
        #expect(boundary.events().first == boundaryEvents[2], "seq 3 survives a watermark of 2")
    }

    @Test("a stale-epoch watermark prunes NOTHING: the journal file is byte-identical")
    func staleEpochWatermarkPrunesNothing() {
        let (journal, directory) = makeJournal()
        _ = appendPats(journal, count: 4, epoch: fixture.epoch1)
        let before = readBytes(directory)!
        journal.prune(watermarkEpoch: fixture.epoch2, watermarkSeq: 99)
        let after = readBytes(directory)!
        #expect(after == before, "a stale-epoch watermark never prunes a newer journal")
        #expect(journal.events().count == 4)
    }

    @Test("a two-epoch journal prunes per entry: only the matching epoch's entries drop")
    func twoEpochJournalPrunesOnlyMatchingEpoch() {
        let (journal, _) = makeJournal()
        let epoch1Events = appendPats(journal, count: 3, epoch: fixture.epoch1)
        let epoch2Events = (1...2).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(100 + seq)), epoch: fixture.epoch2, seq: seq)
        }
        for event in epoch2Events {
            journal.append(event)
        }
        // Watermark for epoch1 at seq 2: epoch1's seqs 1–2 drop, epoch1's
        // seq 3 survives, BOTH epoch2 entries survive untouched.
        journal.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 2)
        #expect(journal.events() == [epoch1Events[2], epoch2Events[0], epoch2Events[1]])
    }

    @Test("journal epoch identity is held across the prune (survivors carry their epochs verbatim)")
    func epochIdentityHeldAcrossPrune() {
        let (journal, _) = makeJournal()
        let epoch1Events = appendPats(journal, count: 3, epoch: fixture.epoch1)
        let epoch2Event = fixture.event(fixture.intent(id: fixture.intentID(50)), epoch: fixture.epoch2, seq: 1)
        journal.append(epoch2Event)
        journal.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 2)
        let survivors = journal.events()
        #expect(survivors.map(\.watchSessionEpoch) == [fixture.epoch1, fixture.epoch2])
        #expect(survivors[0].watchSessionEpoch == epoch1Events[2].watchSessionEpoch)
        #expect(survivors[0].watchSeq == 3)
    }

    @Test("a matched prune rewrites the file to exactly the survivors' canonical lines")
    func matchedPruneByteShape() {
        let (journal, directory) = makeJournal()
        let events = appendPats(journal, count: 3, epoch: fixture.epoch1)
        journal.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 1)
        #expect(readBytes(directory) == ndjson([events[1], events[2]]))
    }

    @Test("prune leaves no temp file behind (the atomic-replace commit point)")
    func pruneLeavesNoTemp() {
        let (journal, directory) = makeJournal()
        _ = appendPats(journal, count: 3, epoch: fixture.epoch1)
        journal.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 1)
        #expect(!FileManager.default.fileExists(
            atPath: directory.appendingPathComponent(StoreRules.temporaryIntentJournalFileName).path(percentEncoded: false)
        ))
    }

    // MARK: - Totality (empty, boundary, oversized)

    @Test("an absent journal parses to an empty queue, and prune leaves it absent (no file created)")
    func absentJournalIsEmptyAndStaysAbsent() {
        let (journal, directory) = makeJournal()
        #expect(journal.events().isEmpty)
        journal.prune(watermarkEpoch: fixture.epoch1, watermarkSeq: 5)
        #expect(!FileManager.default.fileExists(atPath: fileURL(in: directory).path(percentEncoded: false)))
    }

    @Test("the pure prune core is total: empty input, all-dropped, and oversized inputs are defined")
    func purePruneCoreIsTotal() {
        let events = (1...5).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        // Empty input.
        #expect(IntentJournal.pruned([], watermarkEpoch: fixture.epoch1, watermarkSeq: 0).isEmpty)
        // All entries at/below the watermark.
        #expect(IntentJournal.pruned(events, watermarkEpoch: fixture.epoch1, watermarkSeq: 5).isEmpty)
        // Nothing at/below (watermark 0 — the fresh-epoch shape).
        #expect(IntentJournal.pruned(events, watermarkEpoch: fixture.epoch1, watermarkSeq: 0) == events)
        // Oversized input: the cap-free prune scales by the same rule.
        let oversized = (1...500).map { seq in
            fixture.event(fixture.intent(id: fixture.intentID(seq)), epoch: fixture.epoch1, seq: seq)
        }
        #expect(IntentJournal.pruned(oversized, watermarkEpoch: fixture.epoch1, watermarkSeq: 497).count == 3)
        #expect(IntentJournal.pruned(oversized, watermarkEpoch: fixture.epoch1, watermarkSeq: 497).first?.watchSeq == 498)
    }
}
