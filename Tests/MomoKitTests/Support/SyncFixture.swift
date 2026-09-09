import Foundation
@testable import MomoCore
@testable import MomoKit

/// Shared fixtures for the TASK-023 sync suites: fixed epoch/intent
/// identities, builders for `InteractionIntent`/`IntentEvent`/`DisplayState`/
/// `WatchSnapshot`, and the complete `InteractionIntent.Kind` case matrix.
///
/// All time is literal (`instant(_:)` over fixed ISO strings — the
/// `StoreFixture` discipline); nothing here touches an ambient clock or
/// path. The canonical-JSON helper is deliberately INDEPENDENT of the
/// production `encoded()` implementations (its own encoder) — the same
/// test-side cross-check pattern as `SnapshotStoreTests.recomputedChecksum`,
/// so a production encoder drift fails the pins instead of agreeing with
/// itself.
struct SyncFixture {

    /// Fixed Watch session epochs — stable bytes for the table/prune pins.
    let epoch1 = UUID(uuidString: "E0000000-0000-4000-8000-000000000001")!
    let epoch2 = UUID(uuidString: "E0000000-0000-4000-8000-000000000002")!

    /// Fixed snapshot watermark epoch (a third identity so builder pins can
    /// prove no OTHER epoch's watermark leaks into the snapshot).
    let watermarkEpoch = UUID(uuidString: "E0000000-0000-4000-8000-000000000003")!

    func instant(_ iso: String) -> Instant {
        ISO8601DateFormatter().date(from: iso)!
    }

    /// Deterministic distinct intent id `n` — stable bytes for the gate pins.
    func intentID(_ n: Int) -> UUID {
        UUID(uuidString: String(format: "D0000000-0000-4000-8000-%012X", n))!
    }

    /// A Watch-sourced pat intent (the Phase 1 surface, FR-17) with
    /// overridable everything — the journal/gate suites' builder.
    func intent(
        id: UUID,
        kind: InteractionIntent.Kind = .pat(gesture: .tap, zone: .head),
        source: InteractionIntent.Source = .watch,
        dayKey: String = "2026-09-09",
        at: Instant? = nil
    ) -> InteractionIntent {
        InteractionIntent(
            id: id,
            source: source,
            localDayKey: dayKey,
            timestamp: at ?? instant("2026-09-09T21:30:00Z"),
            kind: kind
        )
    }

    /// An `IntentEvent` at the current wire schema version.
    func event(
        _ intent: InteractionIntent,
        epoch: UUID,
        seq: Int,
        schemaVersion: Int = StoreRules.intentEventSchemaVersion
    ) -> IntentEvent {
        IntentEvent(
            schemaVersion: schemaVersion,
            intent: intent,
            watchSessionEpoch: epoch,
            watchSeq: seq
        )
    }

    /// A DisplayState with every field populated (§4.11 read-model); the
    /// overridables are the fields the DTO/builder pins vary.
    func display(
        petName: String = "Momo",
        questLine: QuestGeneration.QuestLine = .wish(.q6),
        wakefulness: Wakefulness = .awake,
        greeting: GreetingKind? = .missedYou,
        bondStage: BondStage = .gettingClose
    ) -> DisplayState {
        DisplayState(
            petName: petName,
            moodWordKey: "momo.line.vocab.mood.content",
            energyPhraseKey: "momo.line.vocab.energy.steady",
            bondStage: bondStage,
            bondDescriptorKey: "momo.line.vocab.bond.gettingClose",
            questLine: questLine,
            wakefulness: wakefulness,
            greeting: greeting
        )
    }

    /// A minimal quest input row (INV-6-valid per the catalog target).
    func quest(_ id: QuestID, progress: Int, completed: Bool) -> QuestProgress {
        QuestProgress(questID: id, progress: progress, completed: completed)!
    }

    /// A fully-populated snapshot at the current schema version — the codec
    /// suites' roundtrip anchor.
    func snapshot(
        questLine: QuestGeneration.QuestLine = .wish(.q6),
        greeting: GreetingKind? = .missedYou,
        schemaVersion: Int = StoreRules.watchSnapshotSchemaVersion
    ) -> WatchSnapshot {
        WatchSnapshot(
            schemaVersion: schemaVersion,
            snapshotSeq: 12,
            display: display(questLine: questLine, greeting: greeting),
            questInputs: [
                quest(.q1, progress: 1, completed: true),
                quest(.q2, progress: 0, completed: false),
                quest(.q6, progress: 0, completed: false),
            ],
            hapticsEnabled: true,
            lastAppliedIntentSeq: 5,
            lastAppliedEpoch: epoch1
        )
    }

    /// The complete `InteractionIntent.Kind` case matrix: every gesture ×
    /// every zone shape (nil is part of the persisted domain — the Watch's
    /// `.pat(.tap, nil)` surface, FR-17) plus the four no-payload kinds. A
    /// NEW case fails these argument lists' consumers by omission — the
    /// codec matrix would silently miss it, which is why the no-numeric-
    /// leakage discipline pins case sets at compile time in MomoCore's own
    /// suites; here the exhaustive switches in the hand-written codec ARE
    /// the compile-time pin (a new case breaks the build in `SyncDTOs.swift`).
    static let allKinds: [InteractionIntent.Kind] = {
        let gestures: [PatGesture] = [.tap, .doubleTap, .longPress, .stroke]
        let zones: [TouchZone?] = [nil, .head, .belly]
        var kinds = gestures.flatMap { gesture in
            zones.map { zone in InteractionIntent.Kind.pat(gesture: gesture, zone: zone) }
        }
        kinds.append(contentsOf: [.feed, .play, .tuckIn, .nap])
        return kinds
    }()

    /// The independent canonical encoder — the production recipe RESTATED
    /// test-side (`.sortedKeys`, default strategies) so `encoded()`'s bytes
    /// are cross-checked against an encoder the production code does not
    /// own.
    static func canonicalData<T: Encodable>(_ value: T) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try! encoder.encode(value)
    }

    static func canonicalString<T: Encodable>(_ value: T) -> String {
        String(data: canonicalData(value), encoding: .utf8)!
    }
}
