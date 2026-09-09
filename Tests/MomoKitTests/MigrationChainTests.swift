import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The §5.5 migration matrix (TASK-022 Requirement 2–4): the injected chain's
/// walk (single-hop through the store's read path, multi-hop at the chain
/// unit level), the unreadable shapes (missing hop, above head — the
/// principled form of the TASK-021 unknown-version rule), the gate ORDER
/// (checksum before migration), re-persistence at the current version, and
/// the NFR-7 fresh-install/upgrade parity property.
///
/// MECHANISM FIXTURES, NOT HISTORY: no schema version below 1 ever existed
/// (05 §5.5 — additive evolution is the norm, and the payload SHAPE never
/// changed). The synthetic version-0 generations and steps below exist only
/// to exercise the walk machinery; at the shipped `currentSchemaVersion == 1`
/// the store-level walk has exactly one hop available (v0 → 1), which is why
/// the multi-hop pins live at the `MigrationChain` unit level. Every step
/// transform is a pure, total value-to-value rebuild.
@Suite("MigrationChain — §5.5 injected walk, gate order, re-persistence, parity (TASK-022)")
struct MigrationChainTests {

    private let fixture = StoreFixture()

    // MARK: - Harness (suite-local helpers, per the per-suite convention)

    private func makeStore(chain: MigrationChain = .empty) -> (store: SnapshotStore, directory: URL, clock: ManualEngineClock) {
        let clock = ManualEngineClock(at: fixture.instant("2026-03-03T12:00:00Z"))
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
        return (SnapshotStore(directory: directory, clock: clock, chain: chain), directory, clock)
    }

    private func writeBytes(_ bytes: Data, to fileName: String, in directory: URL) {
        try! FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try! bytes.write(to: directory.appendingPathComponent(fileName))
    }

    private func readBytes(_ fileName: String, in directory: URL) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(fileName))
    }

    private func readEnvelope(_ fileName: String, in directory: URL) -> SnapshotStore.SnapshotEnvelope? {
        guard let bytes = readBytes(fileName, in: directory) else { return nil }
        return try? JSONDecoder().decode(SnapshotStore.SnapshotEnvelope.self, from: bytes)
    }

    /// A self-consistent generation file for `state` stamped at `version` —
    /// the checksum is the REAL recipe over the payload (version-independent),
    /// so the version gate is the only thing under test.
    private func writeGeneration(
        _ state: EngineState,
        version: Int,
        checksumOverride: String? = nil,
        to fileName: String,
        in directory: URL
    ) {
        let payloadJSON = SnapshotStore.payloadJSONData(for: state)!
        let envelope = SnapshotStore.SnapshotEnvelope(
            schemaVersion: version,
            savedAt: fixture.instant("2026-03-03T12:00:00Z"),
            checksum: checksumOverride ?? SnapshotStore.checksumHex(of: payloadJSON),
            payload: state
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        writeBytes(try! encoder.encode(envelope), to: fileName, in: directory)
    }

    // MARK: - Pure transform steps (statics: nothing captured, provably pure)

    /// Rebuilds `state` with the pet's bond set to `target` — a visible,
    /// deterministic marker a migration step "carried out".
    private static func replacing(bond target: Int, in state: EngineState) -> EngineState {
        let varied = PetState(
            mood: state.state.mood,
            energy: state.state.energy,
            bond: target,
            wakefulness: state.state.wakefulness,
            activity: state.state.activity,
            lastFedAt: state.state.lastFedAt,
            satietyPhase: state.state.satietyPhase
        )!
        return EngineState(
            pet: state.pet,
            state: varied,
            days: state.days,
            settings: state.settings,
            pendingHandshake: state.pendingHandshake,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: state.lastOpenedAt,
            lastEvaluatedAt: state.lastEvaluatedAt,
            lastGreeting: state.lastGreeting
        )
    }

    /// Appends `suffix` to the pet's name — an ORDER-SENSITIVE marker for the
    /// multi-hop walk pin (string concatenation does not commute).
    private static func appending(nameSuffix: String, in state: EngineState) -> EngineState {
        EngineState(
            pet: Pet(id: state.pet.id, name: state.pet.name + nameSuffix, createdAt: state.pet.createdAt)!,
            state: state.state,
            days: state.days,
            settings: state.settings,
            pendingHandshake: state.pendingHandshake,
            processedIntents: state.processedIntents,
            highestCelebratedStage: state.highestCelebratedStage,
            lastOpenedAt: state.lastOpenedAt,
            lastEvaluatedAt: state.lastEvaluatedAt,
            lastGreeting: state.lastGreeting
        )
    }

    /// The v0 → v1 step used by the store-level pins: bond becomes 42. The
    /// parity target is `fixture.state(bond: 42)` — see `migratedStateEquals`.
    private static func stepZeroToCurrent() -> MigrationStep {
        MigrationStep(from: 0) { replacing(bond: 42, in: $0) }
    }

    // MARK: - Serving the current version (steps at/above current are inert)

    @Test("a current-version generation is served directly — a step at the current version is never consulted")
    func currentVersionServesWithoutTouchingTheChain() async {
        // The from-1 step would visibly bump the bond if the walk touched the
        // current-version payload; the served state must be byte-equal to it.
        let inertStep = MigrationStep(from: StoreRules.currentSchemaVersion) { Self.replacing(bond: 42, in: $0) }
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [inertStep]))
        let current = fixture.state(bond: 5)
        writeGeneration(current, version: StoreRules.currentSchemaVersion, to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == current)
    }

    // MARK: - The walk

    @Test("a below-current generation walks the injected step (v0 → current)")
    func singleHopWalkMigratesBelowCurrentGeneration() async {
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [Self.stepZeroToCurrent()]))
        writeGeneration(fixture.state(bond: 5), version: 0, to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 42))
    }

    @Test("a missing hop makes a below-current generation unreadable — the next generation serves")
    func missingStepMakesBelowCurrentGenerationUnreadable() async {
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [
            MigrationStep(from: 1) { Self.replacing(bond: 42, in: $0) }, // a hop the walk never needs
        ]))
        writeGeneration(fixture.state(bond: 5), version: 0, to: StoreRules.currentStateFileName, in: directory)
        writeGeneration(fixture.state(bond: 1), version: StoreRules.currentSchemaVersion, to: StoreRules.previousStateFileName, in: directory)
        // The v0 generation has no from-0 step ⇒ unreadable ⇒ fall through to
        // prev, exactly like a corrupt generation (no error surface).
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 1))
    }

    @Test("an empty chain cannot read a below-current generation")
    func emptyChainCannotReadBelowCurrent() {
        #expect(MigrationChain.empty.isEmpty, "the production chain ships no steps (05 §5.5: additive evolution is the norm)")
        let (store, directory, _) = makeStore()
        writeGeneration(fixture.state(bond: 5), version: 0, to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 999))
    }

    @Test("a version above the chain head is unreadable even when steps are registered at it")
    func aboveHeadVersionIsUnreadableEvenWithStepsRegistered() async {
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [
            Self.stepZeroToCurrent(),
            // A step at the ABOVE-HEAD version: the range check refuses the
            // generation before any step could run — registered steps above
            // the current version are inert (the store does not know the
            // future schema).
            MigrationStep(from: 2) { Self.replacing(bond: 42, in: $0) },
        ]))
        writeGeneration(fixture.state(bond: 5), version: 2, checksumOverride: nil, to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 999))
    }

    // MARK: - The walk at the chain unit level (multi-hop: at the shipped
    // currentSchemaVersion == 1 the store-level walk has only one hop)

    @Test("a multi-hop walk applies the steps in version order (order-sensitive transforms)")
    func multiHopWalkAppliesStepsInOrder() throws {
        let chain = MigrationChain(steps: [
            MigrationStep(from: 2) { Self.appending(nameSuffix: "3", in: $0) },
            MigrationStep(from: 0) { Self.appending(nameSuffix: "1", in: $0) },
            MigrationStep(from: 1) { Self.appending(nameSuffix: "2", in: $0) },
        ])
        let result = try #require(chain.migrated(fixture.state(bond: 5), from: 0, to: 3))
        #expect(result.pet.name == "Momo123", "hops must apply v0→1→2→3 in order regardless of declaration order")
    }

    @Test("a missing hop mid-walk makes the whole walk unreadable (never a half-migrated state)")
    func missingStepHalfwayThroughMultiHopWalkIsUnreadable() {
        let chain = MigrationChain(steps: [
            MigrationStep(from: 0) { Self.appending(nameSuffix: "1", in: $0) },
            MigrationStep(from: 2) { Self.appending(nameSuffix: "3", in: $0) }, // the v1→2 hop is missing
        ])
        #expect(chain.migrated(fixture.state(bond: 5), from: 0, to: 3) == nil)
    }

    @Test("a walk whose source is above its target is not a migration (the unit-level above-head shape)")
    func walkAboveHeadIsNilAtTheUnitLevel() {
        #expect(MigrationChain.empty.migrated(fixture.state(bond: 5), from: 3, to: 1) == nil)
    }

    @Test("a walk already at its target is the state itself")
    func identityRangeIsTheStateItself() {
        let state = fixture.state(bond: 5)
        #expect(MigrationChain.empty.migrated(state, from: 1, to: 1) == state)
    }

    @Test("the walk never mutates its input (purity)")
    func walkIsPureOnItsInput() throws {
        let chain = MigrationChain(steps: [Self.stepZeroToCurrent()])
        let input = fixture.state(bond: 5)
        _ = try #require(chain.migrated(input, from: 0, to: 1))
        #expect(input == fixture.state(bond: 5), "the migrated value is a new value; the input is untouched")
    }

    // MARK: - The chain is value data

    @Test("the chain is per-store value data: two stores over one directory behave independently, loads never write")
    func theChainIsValueDataStoresAreIndependent() async {
        let directory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("momo-store-\(UUID().uuidString)", isDirectory: true)
        let clockA = ManualEngineClock(at: fixture.instant("2026-03-03T12:00:00Z"))
        let storeA = SnapshotStore(directory: directory, clock: clockA, chain: MigrationChain(steps: [Self.stepZeroToCurrent()]))
        let storeB = SnapshotStore(directory: directory, clock: ManualEngineClock(at: fixture.instant("2026-03-03T12:00:00Z")))
        writeGeneration(fixture.state(bond: 5), version: 0, to: StoreRules.currentStateFileName, in: directory)
        let bytesBefore = StoreRules.generationFileNamesInReadOrder.map { readBytes($0, in: directory) }

        #expect(storeA.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 42), "store A walks its chain")
        #expect(storeB.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 999), "store B's empty chain refuses the same bytes")
        // Neither load wrote anything: the directory is byte-identical.
        let bytesAfter = StoreRules.generationFileNamesInReadOrder.map { readBytes($0, in: directory) }
        #expect(bytesAfter == bytesBefore)
    }

    // MARK: - Gate order: the checksum verifies what is on disk, BEFORE the walk

    @Test("a below-current generation that FAILS its checksum falls through — it never migrates")
    func corruptChecksumBelowCurrentNeverMigrates() async {
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [Self.stepZeroToCurrent()]))
        // Valid v0 payload, WRONG digest — a corrupted on-disk generation.
        writeGeneration(
            fixture.state(bond: 5),
            version: 0,
            checksumOverride: SnapshotStore.checksumHex(of: SnapshotStore.payloadJSONData(for: fixture.state(bond: 1))!),
            to: StoreRules.currentStateFileName,
            in: directory
        )
        #expect(
            store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 999),
            "the checksum gate precedes the walk: this must fall through, never serve apply(payload)"
        )
    }

    @Test("negative control: the same generation with a valid checksum DOES migrate")
    func validChecksumBelowCurrentDoesMigrate() async {
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [Self.stepZeroToCurrent()]))
        writeGeneration(fixture.state(bond: 5), version: 0, to: StoreRules.currentStateFileName, in: directory)
        #expect(store.load(fallback: fixture.state(bond: 999)) == fixture.state(bond: 42))
    }

    // MARK: - Re-persistence (Requirement 4)

    @Test("a state loaded through migration re-persists at the current version and loads chain-independently")
    func migratedStateRepersistsAtCurrentVersion() async {
        let (store, directory, _) = makeStore(chain: MigrationChain(steps: [Self.stepZeroToCurrent()]))
        writeGeneration(fixture.state(bond: 5), version: 0, to: StoreRules.currentStateFileName, in: directory)
        let migrated = store.load(fallback: fixture.state(bond: 999))
        #expect(migrated == fixture.state(bond: 42))

        // The migrated state is simply the state in memory: the next save
        // stamps the CURRENT version with a fresh checksum.
        await store.save(migrated)
        let envelope = readEnvelope(StoreRules.currentStateFileName, in: directory)
        #expect(envelope?.schemaVersion == StoreRules.currentSchemaVersion)
        #expect(envelope?.payload == migrated)

        // The re-persisted generation needs no chain: a plain store reads it.
        let plainStore = SnapshotStore(
            directory: directory,
            clock: ManualEngineClock(at: fixture.instant("2026-03-03T12:00:00Z"))
        )
        #expect(plainStore.load(fallback: fixture.state(bond: 999)) == migrated)
    }

    // MARK: - NFR-7 parity (fresh-install ≡ upgrade)

    @Test("a state loaded through migration equals the equivalent freshly-built state (NFR-7 parity)")
    func migratedStateEqualsTheFreshlyBuiltState() throws {
        // Mechanism parity: the v0 → current step's output must be
        // INDISTINGUISHABLE (as an Equatable value) from the state a fresh
        // build would have produced — the property every real migration must
        // preserve (NFR-7 / AC-3's upgrade-vs-fresh-install identity).
        let chain = MigrationChain(steps: [Self.stepZeroToCurrent()])
        let upgraded = try #require(chain.migrated(fixture.state(bond: 5), from: 0, to: StoreRules.currentSchemaVersion))
        let freshlyBuilt = fixture.state(bond: 42)
        #expect(upgraded == freshlyBuilt)
    }

    // MARK: - Chain mechanics

    @Test("a duplicate from-version keeps the FIRST declared step (deterministic authoring-defect posture)")
    func duplicateFromKeepsTheFirstDeclaredStep() {
        let first = MigrationStep(from: 0) { Self.replacing(bond: 42, in: $0) }
        let second = MigrationStep(from: 0) { Self.replacing(bond: 77, in: $0) }
        let chain = MigrationChain(steps: [first, second])
        #expect(chain.step(from: 0)?.from == 0)
        #expect(chain.migrated(fixture.state(bond: 5), from: 0, to: 1) == fixture.state(bond: 42),
                "the first declaration wins — no silent last-wins")
    }
}
