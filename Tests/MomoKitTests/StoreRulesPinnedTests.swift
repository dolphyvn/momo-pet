import Foundation
import Testing
@testable import MomoKit

/// The store constants pinned to their spec literals — 05-technical-architecture
/// §5.2 + ADR-002. TASK-013's anti-echo discipline: this file is the ONLY
/// place the raw literals may appear in tests; every behavior test references
/// `StoreRules` itself, so a spec change surfaces as exactly one pin failure
/// plus one constants edit.
@Suite("StoreRules — §5.2 literals pinned (TASK-021 Requirement 5)")
struct StoreRulesPinnedTests {

    @Test("the three generation file names are the §5.2 names, byte-for-byte")
    func generationFileNames() {
        #expect(StoreRules.currentStateFileName == "state.json")
        #expect(StoreRules.previousStateFileName == "state.prev.json")
        #expect(StoreRules.oldestStateFileName == "state.prev2.json")
    }

    @Test("the current schema version is 1 (initial schema)")
    func currentSchemaVersion() {
        #expect(StoreRules.currentSchemaVersion == 1)
    }

    @Test("the retained day count is 7 (05 §5.4's 7-day DayRecord window)")
    func retainedDayCount() {
        #expect(StoreRules.retainedDayCount == 7)
    }

    @Test("the generation count is 3 (current + two predecessors)")
    func generationCount() {
        #expect(StoreRules.generationCount == 3)
    }

    @Test("the read order is newest → oldest over exactly the three names, and matches the count")
    func readOrder() {
        #expect(StoreRules.generationFileNamesInReadOrder == [
            StoreRules.currentStateFileName,
            StoreRules.previousStateFileName,
            StoreRules.oldestStateFileName,
        ])
        #expect(StoreRules.generationFileNamesInReadOrder.count == StoreRules.generationCount)
    }

    @Test("the temp file lives in the store directory's namespace (same-volume rename)")
    func temporaryFileName() {
        #expect(StoreRules.temporaryStateFileName == "state.json.tmp")
    }

    @Test("the default directory is Application Support/Momo, created if missing (the one sanctioned ambient-path site)")
    func defaultDirectory() throws {
        let directory = try StoreRules.defaultDirectory()
        let path = directory.path(percentEncoded: false)
        #expect(path.hasSuffix("Application Support/Momo/"), "got \(path)")
        var isDirectory: ObjCBool = false
        #expect(FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory))
        #expect(isDirectory.boolValue, "the factory must create the directory when missing")
    }

    // MARK: - The TASK-023 sync constants (05 §6.2 + §6.4 + ADR-003)

    @Test("both sync payload schema versions are 1 (initial wire schemas)")
    func syncSchemaVersions() {
        #expect(StoreRules.watchSnapshotSchemaVersion == 1)
        #expect(StoreRules.intentEventSchemaVersion == 1)
    }

    @Test("the sync file names are the §6.4 names, byte-for-byte")
    func syncFileNames() {
        #expect(StoreRules.intentJournalFileName == "intent-journal.ndjson")
        #expect(StoreRules.syncStateFileName == "sync-state.json")
    }

    @Test("the sync temp names live in their documents' namespaces (same-volume renames)")
    func syncTemporaryFileNames() {
        #expect(StoreRules.temporaryIntentJournalFileName == "intent-journal.ndjson.tmp")
        #expect(StoreRules.temporarySyncStateFileName == "sync-state.json.tmp")
    }
}
