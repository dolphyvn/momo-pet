import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The TASK-023 DTO matrix (contract Requirement 1, AC-1): roundtrips (both
/// DTOs, every case of every wrapped enum), byte-stability under the
/// canonical encoder (cross-checked against an independent encoder), the
/// golden canonical-bytes pin (Date-free, so hand-statable), the
/// unknown-version ignore gates, verbatim §6.4 attribution survival, and
/// the hand-written `IntentEvent.==` semantics. The hand-written conformances
/// are the disclosed TASK-023 shape (see `SyncDTOs.swift`'s headers).
@Suite("Sync DTOs — codec, versioning, canonical bytes (TASK-023; 05 §6.2)")
struct SyncDTOTests {

    private let fixture = SyncFixture()

    // MARK: - Roundtrips

    @Test("a fully-populated WatchSnapshot roundtrips exactly")
    func watchSnapshotRoundtripsExactly() {
        let snapshot = fixture.snapshot()
        let decoded = WatchSnapshot.decoded(from: snapshot.encoded()!)
        #expect(decoded == snapshot, "every field must survive the codec unchanged")
    }

    @Test("every QuestLine case roundtrips through the WatchSnapshot codec",
          arguments: [QuestGeneration.QuestLine.wish(.q1), .wish(.q2), .wish(.q3),
                      .wish(.q4), .wish(.q5), .wish(.q6), .wish(.q7), .allDone])
    func questLineCaseRoundtrips(_ questLine: QuestGeneration.QuestLine) {
        let snapshot = fixture.snapshot(questLine: questLine)
        #expect(WatchSnapshot.decoded(from: snapshot.encoded()!) == snapshot)
    }

    @Test("every greeting shape (the four kinds + nil) roundtrips",
          arguments: [GreetingKind?.none, .freshMorning, .welcomeBack, .missedYou, .nightGlance])
    func greetingShapeRoundtrips(_ greeting: GreetingKind?) {
        let snapshot = fixture.snapshot(greeting: greeting)
        #expect(WatchSnapshot.decoded(from: snapshot.encoded()!) == snapshot)
    }

    @Test("a fully-populated IntentEvent roundtrips exactly")
    func intentEventRoundtripsExactly() {
        let event = fixture.event(
            fixture.intent(id: fixture.intentID(1), kind: .pat(gesture: .longPress, zone: .belly)),
            epoch: fixture.epoch1,
            seq: 3
        )
        #expect(IntentEvent.decoded(from: event.encoded()!) == event)
    }

    @Test("every IntentEvent kind (all pat variants + the four no-payload kinds) roundtrips",
          arguments: SyncFixture.allKinds)
    func everyKindRoundtrips(_ kind: InteractionIntent.Kind) {
        let event = fixture.event(
            fixture.intent(id: fixture.intentID(7), kind: kind),
            epoch: fixture.epoch1,
            seq: 1
        )
        let decoded = IntentEvent.decoded(from: event.encoded()!)
        #expect(decoded == event)
        // The wrapped intent's KIND specifically — the `==` pin above could
        // theoretically pass on a degenerate codec; assert the kind directly.
        guard let decodedKind = decoded?.intent.kind else {
            Issue.record("decode failed")
            return
        }
        switch (decodedKind, kind) {
        case (.pat(let lhsGesture, let lhsZone), .pat(let rhsGesture, let rhsZone)):
            #expect(lhsGesture == rhsGesture && lhsZone == rhsZone)
        case (.feed, .feed), (.play, .play), (.tuckIn, .tuckIn), (.nap, .nap):
            break
        default:
            Issue.record("decoded kind does not match the encoded kind")
        }
    }

    @Test("the §6.4 attribution data (intent.localDayKey + timestamp) survives the codec verbatim")
    func attributionSurvivesVerbatim() {
        let dayKey = "2026-08-31"
        let timestamp = fixture.instant("2026-08-31T23:30:00Z") // the §6.4 23:30 pat
        let event = fixture.event(
            fixture.intent(id: fixture.intentID(9), dayKey: dayKey, at: timestamp),
            epoch: fixture.epoch1,
            seq: 1
        )
        let decoded = IntentEvent.decoded(from: event.encoded()!)
        #expect(decoded?.intent.localDayKey == dayKey)
        #expect(decoded?.intent.timestamp.timeIntervalSinceReferenceDate
            == timestamp.timeIntervalSinceReferenceDate)
    }

    @Test("an iPhone-sourced intent roundtrips (the source map covers both cases)")
    func iPhoneSourceRoundtrips() {
        let event = fixture.event(
            fixture.intent(id: fixture.intentID(2), source: .iPhone),
            epoch: fixture.epoch1,
            seq: 1
        )
        #expect(IntentEvent.decoded(from: event.encoded()!)!.intent.source == .iPhone)
    }

    // MARK: - Canonical bytes

    @Test("encoding is byte-stable across calls (both DTOs)")
    func encodingIsByteStable() {
        let snapshot = fixture.snapshot()
        let event = fixture.event(fixture.intent(id: fixture.intentID(3)), epoch: fixture.epoch1, seq: 2)
        #expect(snapshot.encoded() == snapshot.encoded())
        #expect(event.encoded() == event.encoded())
    }

    @Test("the production encoded() matches an independent canonical encoder (both DTOs)")
    func productionEncoderMatchesIndependentEncoder() {
        let snapshot = fixture.snapshot()
        let event = fixture.event(fixture.intent(id: fixture.intentID(4)), epoch: fixture.epoch2, seq: 9)
        #expect(snapshot.encoded() == SyncFixture.canonicalData(snapshot))
        #expect(event.encoded() == SyncFixture.canonicalData(event))
    }

    @Test("the WatchSnapshot canonical bytes are pinned (sorted keys, nested display shape)")
    func snapshotCanonicalBytesPinned() {
        // Deliberately minimal and Date-FREE (the snapshot has no Date field,
        // so the canonical string is hand-statable): every top-level key, the
        // nested display container, the keyed QuestLine shape, and a null
        // greeting.
        let snapshot = WatchSnapshot(
            snapshotSeq: 1,
            display: SyncFixture().display(
                petName: "Momo",
                questLine: .wish(.q6),
                wakefulness: .awake,
                greeting: nil,
                bondStage: .newFriends
            ),
            questInputs: [],
            hapticsEnabled: false,
            lastAppliedIntentSeq: 0,
            lastAppliedEpoch: SyncFixture().watermarkEpoch
        )
        let expected = "{\"display\":{"
            + "\"bondDescriptorKey\":\"momo.line.vocab.bond.gettingClose\","
            + "\"bondStage\":{\"newFriends\":{}},"
            + "\"energyPhraseKey\":\"momo.line.vocab.energy.steady\","
            + "\"greeting\":null,"
            + "\"moodWordKey\":\"momo.line.vocab.mood.content\","
            + "\"petName\":\"Momo\","
            + "\"questLine\":{\"wish\":\"Q6\"},"
            + "\"wakefulness\":{\"awake\":{}}},"
            + "\"hapticsEnabled\":false,"
            + "\"lastAppliedEpoch\":\"\(SyncFixture().watermarkEpoch.uuidString)\","
            + "\"lastAppliedIntentSeq\":0,"
            + "\"questInputs\":[],"
            + "\"schemaVersion\":1,"
            + "\"snapshotSeq\":1}"
        #expect(String(data: snapshot.encoded()!, encoding: .utf8) == expected)
    }

    @Test("the IntentEvent canonical bytes pin the keyed kind shape and nested intent container")
    func eventCanonicalShapePinned() {
        let event = fixture.event(
            fixture.intent(id: fixture.intentID(5), kind: .pat(gesture: .tap, zone: nil)),
            epoch: fixture.epoch1,
            seq: 1
        )
        let json = String(data: event.encoded()!, encoding: .utf8)!
        // Structural pins (the full string embeds a Date number — byte-stable
        // per toolchain but not hand-statable): the keyed-enum kind shape,
        // the null zone, and the nested intent container under "intent".
        #expect(json.contains("\"kind\":{\"pat\":{\"gesture\":\"tap\",\"zone\":null}}"))
        #expect(json.contains("\"intent\":{"))
        #expect(json.hasPrefix("{\"intent\":{")) // sorted keys: intent < schemaVersion < watch*
        #expect(json.contains("\"schemaVersion\":1,"))
        #expect(json.contains("\"watchSeq\":1,\"watchSessionEpoch\":"))
        #expect(json.hasSuffix("\"watchSessionEpoch\":\"\(fixture.epoch1.uuidString)\"}"))
        // The no-payload kinds encode as the canonical empty object.
        let feed = fixture.event(fixture.intent(id: fixture.intentID(5), kind: .feed), epoch: fixture.epoch1, seq: 1)
        #expect(String(data: feed.encoded()!, encoding: .utf8)!.contains("\"kind\":{\"feed\":{}}"))
    }

    // MARK: - The version gates (AC-1: unknown version behavior defined and pinned)

    @Test("a WatchSnapshot at any non-current version is ignored (above AND below current)",
          arguments: [StoreRules.watchSnapshotSchemaVersion + 1, StoreRules.watchSnapshotSchemaVersion + 99, 0])
    func unknownSnapshotVersionIsIgnored(_ version: Int) {
        let snapshot = fixture.snapshot(schemaVersion: version)
        #expect(WatchSnapshot.decoded(from: snapshot.encoded()!) == nil)
    }

    @Test("an IntentEvent at any non-current version is skipped by the decode gate",
          arguments: [StoreRules.intentEventSchemaVersion + 1, StoreRules.intentEventSchemaVersion + 99, 0])
    func unknownEventVersionIsIgnored(_ version: Int) {
        let event = fixture.event(fixture.intent(id: fixture.intentID(6)), epoch: fixture.epoch1, seq: 1, schemaVersion: version)
        #expect(IntentEvent.decoded(from: event.encoded()!) == nil)
    }

    @Test("the current version decodes on both gates (the gates are equality, not range)")
    func currentVersionDecodes() {
        #expect(WatchSnapshot.decoded(from: fixture.snapshot().encoded()!) != nil)
        let event = fixture.event(fixture.intent(id: fixture.intentID(6)), epoch: fixture.epoch1, seq: 1)
        #expect(IntentEvent.decoded(from: event.encoded()!) != nil)
    }

    @Test("malformed bytes decode to nil on both gates (never throw)")
    func garbageBytesDecodeToNil() {
        #expect(WatchSnapshot.decoded(from: Data("not json".utf8)) == nil)
        #expect(IntentEvent.decoded(from: Data("not json".utf8)) == nil)
        #expect(WatchSnapshot.decoded(from: Data()) == nil)
        #expect(IntentEvent.decoded(from: Data()) == nil)
    }

    // MARK: - The hand-written Equatable (exact roundtrip-pin semantics)

    @Test("IntentEvent equality is field-wise: differing in any single field breaks equality")
    func intentEventEqualityIsFieldWise() {
        func base() -> IntentEvent {
            fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 2)
        }
        #expect(base() == base(), "identical values are equal")
        // id (the INV-10 key)
        #expect(base() != fixture.event(fixture.intent(id: fixture.intentID(2)), epoch: fixture.epoch1, seq: 2))
        // seq
        #expect(base() != fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 3))
        // epoch
        #expect(base() != fixture.event(fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch2, seq: 2))
        // kind payload (zone only)
        #expect(base() != fixture.event(
            fixture.intent(id: fixture.intentID(1), kind: .pat(gesture: .tap, zone: .belly)),
            epoch: fixture.epoch1, seq: 2
        ))
        // kind case
        #expect(base() != fixture.event(
            fixture.intent(id: fixture.intentID(1), kind: .feed),
            epoch: fixture.epoch1, seq: 2
        ))
        // source
        #expect(base() != fixture.event(
            fixture.intent(id: fixture.intentID(1), source: .iPhone),
            epoch: fixture.epoch1, seq: 2
        ))
        // dayKey
        #expect(base() != fixture.event(
            fixture.intent(id: fixture.intentID(1), dayKey: "2026-09-08"),
            epoch: fixture.epoch1, seq: 2
        ))
        // timestamp
        #expect(base() != fixture.event(
            fixture.intent(id: fixture.intentID(1), at: fixture.instant("2026-09-09T21:30:01Z")),
            epoch: fixture.epoch1, seq: 2
        ))
        // schemaVersion
        #expect(base() != fixture.event(
            fixture.intent(id: fixture.intentID(1)), epoch: fixture.epoch1, seq: 2,
            schemaVersion: StoreRules.intentEventSchemaVersion + 1
        ))
    }
}
