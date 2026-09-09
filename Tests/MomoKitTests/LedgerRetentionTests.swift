import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The §5.4 retention matrix (TASK-022 Requirement 1): the pure prune's
/// totality (empty / under-cap / at-cap / oversized), determinism
/// (idempotence, survivor order), the dayKey lexicographic==chronological
/// format pin, the duplicate-dayKey defect pin, and the store-level
/// placement — prune on the WRITE path only, the read path never prunes.
/// Every count assertion references the normative constants
/// (`StoreRules.retainedDayCount`, `EngineState.processedIntentsCapacity`);
/// the raw literals live only in `StoreRulesPinnedTests`.
@Suite("LedgerRetention — §5.4 caps, deterministic prune, store-path placement (TASK-022)")
struct LedgerRetentionTests {

    private let fixture = StoreFixture()

    // MARK: - Harness (suite-local copies of the SnapshotStoreTests helpers,
    // per the per-suite self-containment convention)

    private func makeStore() -> (store: SnapshotStore, directory: URL) {
        let clock = ManualEngineClock(at: fixture.instant("2026-03-03T12:00:00Z"))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
        return (SnapshotStore(directory: directory, clock: clock), directory)
    }

    private func writeBytes(_ bytes: Data, to fileName: String, in directory: URL) {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! bytes.write(to: directory.appendingPathComponent(fileName))
    }

    private func readEnvelope(_ fileName: String, in directory: URL) -> SnapshotStore.SnapshotEnvelope? {
        guard let bytes = try? Data(contentsOf: directory.appendingPathComponent(fileName)) else {
            return nil
        }
        return try? JSONDecoder().decode(SnapshotStore.SnapshotEnvelope.self, from: bytes)
    }

    private func envelopeBytes(for state: EngineState, savedAt: Instant) -> Data {
        let payloadJSON = SnapshotStore.payloadJSONData(for: state)!
        let envelope = SnapshotStore.SnapshotEnvelope(
            schemaVersion: StoreRules.currentSchemaVersion,
            savedAt: savedAt,
            checksum: SnapshotStore.checksumHex(of: payloadJSON),
            payload: state
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try! encoder.encode(envelope)
    }

    /// A belt of `count` distinct deterministic intent ids.
    private func intents(_ count: Int) -> [UUID] {
        (0..<count).map { fixture.intentID($0) }
    }

    // MARK: - Totality

    @Test("an under-cap state passes through unchanged")
    func underCapStateIsUnchanged() {
        let state = fixture.populatedState() // 3 days, 2 intents — under both caps
        #expect(LedgerRetention.pruned(state) == state)
    }

    @Test("an empty ledger and belt are total (identity)")
    func emptyLedgerAndBeltAreTotal() {
        let state = fixture.state(days: [], processedIntents: [])
        #expect(LedgerRetention.pruned(state) == state)
    }

    // MARK: - The day-ledger cap

    @Test("an oversized ledger keeps exactly the retainedDayCount newest dayKeys")
    func oversizedLedgerKeepsExactlyTheRetainedDayCountNewest() {
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 30)
        let pruned = LedgerRetention.pruned(fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: []))
        #expect(pruned.days.count == StoreRules.retainedDayCount)
        #expect(
            Set(pruned.days.map(\.dayKey)) == Set(keys.suffix(StoreRules.retainedDayCount)),
            "survivors must be the lexicographically-greatest \(StoreRules.retainedDayCount) keys"
        )
    }

    @Test("survivor relative order is the input ledger's order (ascending and adversarially reversed inputs)")
    func oversizedLedgerPreservesSurvivorRelativeOrder() {
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 30)
        let survivors = Set(keys.suffix(StoreRules.retainedDayCount))
        // Ascending input: survivors in ascending order.
        let ascending = LedgerRetention.pruned(fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: []))
        #expect(ascending.days.map(\.dayKey) == keys.filter { survivors.contains($0) })
        // Reversed input: the SAME survivor set, now in descending order —
        // input order, not key order, decides the output order.
        let reversed = LedgerRetention.pruned(fixture.state(days: keys.reversed().map { fixture.minimalDay($0) }, processedIntents: []))
        #expect(Set(reversed.days.map(\.dayKey)) == survivors)
        #expect(reversed.days.map(\.dayKey) == keys.reversed().filter { survivors.contains($0) })
    }

    @Test("an at-cap ledger passes through unchanged")
    func atCapLedgerIsUnchanged() {
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: StoreRules.retainedDayCount)
        let state = fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: [])
        #expect(LedgerRetention.pruned(state) == state)
    }

    @Test("the current day is never dropped (the newest dayKey survives an oversized prune)")
    func currentDayIsNeverDropped() {
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 30)
        let pruned = LedgerRetention.pruned(fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: []))
        #expect(pruned.days.map(\.dayKey).contains(keys.max()!), "the current (greatest-dayKey) day must survive")
    }

    // MARK: - The intent-belt cap

    @Test("an oversized belt keeps exactly the processedIntentsCapacity last ids, in order")
    func oversizedIntentBeltKeepsExactlyTheCapacityNewest() {
        let belt = intents(200)
        let pruned = LedgerRetention.pruned(fixture.state(days: [], processedIntents: belt))
        #expect(pruned.processedIntents.count == EngineState.processedIntentsCapacity)
        #expect(
            pruned.processedIntents == Array(belt.suffix(EngineState.processedIntentsCapacity)),
            "the LAST ids in append order are the survivors"
        )
    }

    @Test("an at-cap belt passes through unchanged")
    func atCapBeltIsUnchanged() {
        let belt = intents(EngineState.processedIntentsCapacity)
        let state = fixture.state(days: [], processedIntents: belt)
        #expect(LedgerRetention.pruned(state) == state)
    }

    @Test("both caps bind together, and every non-ledger field passes through untouched")
    func oversizedLedgerAndBeltTogether() {
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 30)
        let belt = intents(200)
        let oversized = fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: belt)
        let pruned = LedgerRetention.pruned(oversized)
        // Whole-state equality against the hand-built expected value.
        let expected = fixture.state(
            days: keys.suffix(StoreRules.retainedDayCount).map { fixture.minimalDay($0) },
            processedIntents: Array(belt.suffix(EngineState.processedIntentsCapacity))
        )
        #expect(pruned == expected)
        #expect(pruned.pet == oversized.pet)
        #expect(pruned.state == oversized.state)
        #expect(pruned.settings == oversized.settings)
        #expect(pruned.pendingHandshake == oversized.pendingHandshake)
        #expect(pruned.highestCelebratedStage == oversized.highestCelebratedStage)
        #expect(pruned.lastOpenedAt == oversized.lastOpenedAt)
        #expect(pruned.lastEvaluatedAt == oversized.lastEvaluatedAt)
        #expect(pruned.lastGreeting == oversized.lastGreeting)
    }

    // MARK: - Determinism

    @Test("the prune is idempotent: prune∘prune == prune (oversized and under-cap)")
    func pruneIsIdempotent() {
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 30)
        let oversized = fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: intents(200))
        let once = LedgerRetention.pruned(oversized)
        #expect(LedgerRetention.pruned(once) == once)
        let underCap = fixture.populatedState()
        #expect(LedgerRetention.pruned(LedgerRetention.pruned(underCap)) == LedgerRetention.pruned(underCap))
        // Determinism on the input: the same input prunes to the same output.
        #expect(LedgerRetention.pruned(oversized) == once)
    }

    // MARK: - The dayKey format pin (lexicographic == chronological)

    @Test("DayKey.make is zero-padded, and unpadded keys would mis-order — the load-bearing format assumption")
    func dayKeysOrderLexicographicallyBecauseTheyAreZeroPadded() {
        // The production derivation is zero-padded: single-digit months and
        // days sort lexicographically == chronologically.
        #expect(DayKey.make(from: fixture.instant("2026-03-03T12:00:00Z"), calendar: Self.utcCalendar) == "2026-03-03")
        #expect(DayKey.make(from: fixture.instant("2026-01-05T12:00:00Z"), calendar: Self.utcCalendar) == "2026-01-05")
        #expect(DayKey.make(from: fixture.instant("2026-12-31T12:00:00Z"), calendar: Self.utcCalendar) == "2026-12-31")
        // The failure mode the format rules out, made concrete: UNPADDED keys
        // ("2026-3-1" for March 1) do NOT sort chronologically ("3" > "1"
        // character-wise). Over an oversized ledger the lexicographic cap then
        // DROPS THE CHRONOLOGICALLY-NEWEST DAY — selection is by string, and
        // only `DayKey.make`'s zero-padded output (pinned above) makes that
        // the same as chronological. If the format ever changed, this pin
        // fails and the retention rule must be revisited with it.
        let misOrdered = [
            "2026-12-31", // chronologically NEWEST — lexicographically smallest here
            "2026-9-4", "2026-9-5", "2026-9-6", "2026-9-7", "2026-9-8", "2026-9-9",
            "2026-3-1",   // chronologically Mar 1 — lexicographically the GREATEST
        ]
        #expect("2026-3-1" > "2026-12-31", "unpadded keys mis-order: Mar 1 sorts above Dec 31")
        let pruned = LedgerRetention.pruned(fixture.state(days: misOrdered.map { fixture.minimalDay($0) }, processedIntents: []))
        #expect(
            Set(pruned.days.map(\.dayKey)) == Set(misOrdered.dropFirst()),
            "the lexicographic cap kept the mis-ordered set and DROPPED the chronologically-newest day — string order, not date order, decides"
        )
        #expect(
            pruned.days.map(\.dayKey) == Array(misOrdered.dropFirst()),
            "survivors keep the input's relative order (retention selects, it never re-sorts)"
        )
    }

    @Test("duplicate dayKeys keep the first occurrence (defect pin: exactly one record per key)")
    func duplicateDayKeysKeepTheFirstOccurrence() {
        let kept = "2026-03-05"
        let older = "2026-03-04"
        let firstMarked = fixture.day(
            dayKey: kept,
            feed: 1, play: 0, care: 0, pat: 0, // content marker: the FIRST record
            questSet: [fixture.quest(.q1, progress: 0, completed: false),
                       fixture.quest(.q2, progress: 0, completed: false),
                       fixture.quest(.q6, progress: 0, completed: false)],
            helloAwarded: false,
            familiesUsed: [],
            bondAwarded: 0
        )
        let duplicate = fixture.minimalDay(kept) // same dayKey, different content
        let pruned = LedgerRetention.pruned(fixture.state(
            days: [firstMarked, fixture.minimalDay(older), duplicate],
            processedIntents: []
        ))
        #expect(pruned.days.map(\.dayKey) == [kept, older], "the duplicate must not survive beside its first occurrence")
        #expect(pruned.days.first { $0.dayKey == kept } == firstMarked, "the FIRST occurrence is the survivor")

        // The same defect's NO-CROWDING clause: duplicates collapse BEFORE
        // the window opens, so a duplicated key at the window boundary never
        // costs a distinct day its slot — 8 distinct days plus a duplicate
        // of the newest still retain the full 7-day window (a
        // multiset-window implementation would keep only 6).
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 8)
        let crowded = fixture.state(
            days: keys.map { fixture.minimalDay($0) } + [fixture.minimalDay(keys[7])],
            processedIntents: []
        )
        let prunedCrowded = LedgerRetention.pruned(crowded)
        #expect(
            prunedCrowded.days.map(\.dayKey) == Array(keys.dropFirst()),
            "a duplicate at the window boundary must not crowd out a distinct day — the full 7-day window is retained"
        )
    }

    // MARK: - Store-path placement (write prunes, read does not)

    @Test("save prunes before encode: the on-disk payload satisfies both caps")
    func savePrunesBeforeEncode() async {
        let (store, directory) = makeStore()
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-02-01T12:00:00Z", count: 30)
        let oversized = fixture.state(days: keys.map { fixture.minimalDay($0) }, processedIntents: intents(200))
        await store.save(oversized)
        let envelope = readEnvelope(StoreRules.currentStateFileName, in: directory)
        #expect(envelope?.payload.days.count == StoreRules.retainedDayCount)
        #expect(envelope?.payload.processedIntents.count == EngineState.processedIntentsCapacity)
        #expect(envelope?.payload == LedgerRetention.pruned(oversized), "the persisted payload is exactly the pruned state")
        // And the loaded state is the pruned one too (it is what was written).
        #expect(store.load(fallback: fixture.state(bond: 999)) == LedgerRetention.pruned(oversized))
    }

    @Test("the read path does NOT prune: a valid oversized generation is served whole")
    func loadDoesNotPrune() {
        let (store, directory) = makeStore()
        // A generation whose payload exceeds both caps, with a valid
        // self-consistent checksum at the current version — e.g. written by
        // an older build before the caps were enforced.
        let keys = fixture.consecutiveDayKeys(startingISO: "2026-01-01T12:00:00Z", count: StoreRules.retainedDayCount + 3)
        let oversized = fixture.state(
            days: keys.map { fixture.minimalDay($0) },
            processedIntents: intents(EngineState.processedIntentsCapacity + 1)
        )
        writeBytes(envelopeBytes(for: oversized, savedAt: fixture.instant("2026-03-03T12:00:00Z")), to: StoreRules.currentStateFileName, in: directory)
        let loaded = store.load(fallback: fixture.state(bond: 999))
        #expect(loaded == oversized, "loads never write or mutate — the read path serves the verified payload un-pruned")
        #expect(loaded.days.count == StoreRules.retainedDayCount + 3)
        #expect(loaded.processedIntents.count == EngineState.processedIntentsCapacity + 1)
    }
}

private extension LedgerRetentionTests {

    static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()
}
