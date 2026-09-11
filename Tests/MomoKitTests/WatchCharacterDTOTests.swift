import Foundation
import Testing
@testable import MomoCore
@testable import MomoKit

/// The ADR-014 character read-model suite (TASK-041 R1): the DTO's
/// hand-written codec (case-name maps for the MomoCore-bare bands, verbatim
/// ride-through for the Codable activity/satiety members), the snapshot's
/// ADDITIVE-OPTIONAL carrier (round-trip, key omission, pre-character
/// payload compatibility with NO schemaVersion bump, unknown-band strictness),
/// the builder's pass-through, the wire-direction derivation's four-field
/// shape, and the Watch-side assembly's purity — including the pinned nil
/// degraded path and the greeting → moment projection.
@Suite("WatchCharacterDTO — ADR-014 character read model on the wire (TASK-041)")
struct WatchCharacterDTOTests {

    private let fixture = SyncFixture()
    private let storeFixture = StoreFixture()

    /// A fully-populated DTO (the codec suites' roundtrip anchor) — bands,
    /// an activity, and a satiety hint all present.
    private func fullDTO() -> WatchCharacterDTO {
        WatchCharacterDTO(
            moodBand: .content,
            energyBand: .energetic,
            activity: .playing,
            satietyHint: .recentlyFed
        )
    }

    /// The DTO-augmented snapshot the carrier tests reuse.
    private func snapshotWithCharacter(_ character: WatchCharacterDTO?) -> WatchSnapshot {
        WatchSnapshot(
            snapshotSeq: fixture.snapshot().snapshotSeq,
            display: fixture.display(),
            questInputs: fixture.snapshot().questInputs,
            hapticsEnabled: fixture.snapshot().hapticsEnabled,
            lastAppliedIntentSeq: fixture.snapshot().lastAppliedIntentSeq,
            lastAppliedEpoch: fixture.epoch1,
            character: character
        )
    }

    // MARK: - The DTO's codec

    @Test("the DTO round-trips through the canonical recipe")
    func dtoRoundTrips() throws {
        let data = try #require(fullDTO().encoded())
        let decoded = try #require(WatchCharacterDTO.decoded(from: data))
        #expect(decoded == fullDTO())
    }

    @Test("a nil-optional DTO round-trips (nil members are real values, not absences)")
    func dtoNilOptionalsRoundTrip() throws {
        let bare = WatchCharacterDTO(
            moodBand: .wistful, energyBand: .drowsy, activity: nil, satietyHint: nil
        )
        let data = try #require(bare.encoded())
        let decoded = try #require(WatchCharacterDTO.decoded(from: data))
        #expect(decoded == bare)
    }

    @Test("the bands ride as case-name strings; an unknown band never decodes")
    func unknownBandNeverDecodes() throws {
        let json = """
        {"activity":{"playing":{}},"energyBand":"relaxed","moodBand":"blissful","satietyHint":{"full":{}}}
        """
        #expect(WatchCharacterDTO.decoded(from: Data(json.utf8)) == nil,
                "the case-name map must reject an unknown mood band (the IntentEvent discipline)")
    }

    @Test("the DTO's canonical bytes are the four keyed fields")
    func dtoBytesAreTheFourFields() throws {
        let data = try #require(fullDTO().encoded())
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""moodBand":"content""#), "got \(json)")
        #expect(json.contains(#""energyBand":"energetic""#), "got \(json)")
        // The MomoCore-Codable members ride the toolchain's keyed enum shape
        // (the SnapshotStore header's documented encoding).
        #expect(json.contains(#""activity":{"playing":{}}"#), "got \(json)")
        #expect(json.contains(#""satietyHint":{"recentlyFed":{}}"#), "got \(json)")
    }

    // MARK: - The snapshot's additive-optional carrier (the marker precedent)

    @Test("a character-bearing snapshot round-trips through encode → decode")
    func characterSurvivesTheWireRoundTrip() throws {
        let carried = snapshotWithCharacter(fullDTO())
        let data = try #require(carried.encoded())
        let decoded = try #require(WatchSnapshot.decoded(from: data))
        #expect(decoded == carried)
        #expect(decoded.character == fullDTO())
    }

    @Test("a no-character snapshot's bytes OMIT the key (byte-compatibility with the pre-character wire shape)")
    func noCharacterBytesOmitTheKey() throws {
        let data = try #require(snapshotWithCharacter(nil).encoded())
        let json = String(decoding: data, as: UTF8.self)
        #expect(!json.contains("character"),
                "encodeIfPresent must omit the key when nil — got \(json)")
        #expect(!json.contains("moodBand"))
    }

    @Test("a PRE-CHARACTER payload decodes cleanly with the character absent (the no-bump compatibility pin)")
    func preCharacterPayloadDecodesCleanly() throws {
        // Hand-written bytes the production encoder never emits — the
        // cross-check pattern (an independent byte source): the full
        // snapshot shape WITHOUT the character key. The codec's
        // decodeIfPresent is what makes this stream legal — no
        // schemaVersion bump, no dropped payload, degraded-nil render.
        let base = snapshotWithCharacter(nil)
        let json = """
        {"display":{"bondStage":{"gettingClose":{}},"bondDescriptorKey":"momo.line.vocab.bond.gettingClose","energyPhraseKey":"momo.line.vocab.energy.steady","greeting":{"missedYou":{}},"moodWordKey":"momo.line.vocab.mood.content","petName":"Momo","questLine":{"wish":"Q6"},"wakefulness":{"awake":{}}},"hapticsEnabled":true,"lastAppliedEpoch":"E0000000-0000-4000-8000-000000000001","lastAppliedIntentSeq":5,"questInputs":[],"schemaVersion":1,"snapshotSeq":12}
        """
        let decoded = try #require(WatchSnapshot.decoded(from: Data(json.utf8)))
        #expect(decoded.character == nil)
        #expect(decoded.display == base.display)
        #expect(decoded.schemaVersion == StoreRules.watchSnapshotSchemaVersion)
    }

    @Test("a character-bearing payload encodes the key (the carrier is real, not vacuous)")
    func characterKeyIsPresentWhenCarried() throws {
        let data = try #require(snapshotWithCharacter(fullDTO()).encoded())
        let json = String(decoding: data, as: UTF8.self)
        #expect(json.contains(#""character":{"#), "got \(json)")
        #expect(json.contains(#""moodBand":"content""#))
    }

    // MARK: - The builder's pass-through

    @Test("the builder threads the character through verbatim; the default is nil")
    func builderThreadsTheCharacter() {
        let state = storeFixture.state(bond: 10)
        let sync = SyncState()
        let character = makeWatchCharacter(makeCharacterDisplayState(state))
        let with = makeWatchSnapshot(
            state: state, display: fixture.display(), questInputs: [],
            watermarkEpoch: fixture.epoch1, sync: sync,
            character: character
        )
        let without = makeWatchSnapshot(
            state: state, display: fixture.display(), questInputs: [],
            watermarkEpoch: fixture.epoch1, sync: sync
        )
        #expect(with.snapshot.character == character, "the DTO is threaded verbatim")
        #expect(without.snapshot.character == nil, "no character is the default shape")
        #expect(with.nextSync == without.nextSync, "the character leg consumes no sync state")
    }

    // MARK: - The derivations (ADR-014's two directions)

    @Test("makeWatchCharacter carries EXACTLY the four fields the display lacks")
    func derivationCarriesExactlyTheFourFields() {
        let state = storeFixture.state(bond: 10)
        let characterDisplay = makeCharacterDisplayState(state)
        let dto = makeWatchCharacter(characterDisplay)
        #expect(dto.moodBand == characterDisplay.moodBand)
        #expect(dto.energyBand == characterDisplay.energyBand)
        #expect(dto.activity == characterDisplay.activity)
        #expect(dto.satietyHint == characterDisplay.satietyHint)
    }

    @Test("makeWatchCharacterDisplay assembles the faithful mirror, moment projected from the greeting")
    func assemblyMirrorsAndProjectsTheMoment() {
        let dto = fullDTO()
        let character = makeWatchCharacterDisplay(display: fixture.display(), character: dto)
        let expected = CharacterDisplayState(
            moodBand: .content,
            energyBand: .energetic,
            bondStage: .gettingClose,
            wakefulness: .awake,
            activity: .playing,
            satietyHint: .recentlyFed,
            momentRequest: .greeting(.missedYou)
        )
        #expect(character == expected)
    }

    @Test("a nil greeting projects a nil moment request (the no-greeting open)")
    func assemblyProjectsWithoutGreeting() {
        let character = makeWatchCharacterDisplay(
            display: fixture.display(greeting: nil),
            character: fullDTO()
        )
        #expect(character?.momentRequest == nil)
        #expect(character?.bondStage == .gettingClose)
        #expect(character?.wakefulness == .awake)
    }

    @Test("a nil character is the pinned degraded shape: the assembly yields nil")
    func assemblyNilCharacterIsDegraded() {
        #expect(makeWatchCharacterDisplay(display: fixture.display(), character: nil) == nil,
                "cross-version skew degrades to words-only — never a crash, never an error surface")
    }

    // MARK: - Round-trip through BOTH directions (the ADR's faithfulness pin)

    @Test("derive → encode → decode → assemble reproduces the character the iPhone rig received")
    func fullRoundTripIsFaithful() throws {
        let state = storeFixture.state(bond: 10)
        let original = makeCharacterDisplayState(state)
        let wire = makeWatchCharacter(original)
        var snapshot = fixture.snapshot()
        snapshot = WatchSnapshot(
            snapshotSeq: snapshot.snapshotSeq,
            display: snapshot.display,
            questInputs: snapshot.questInputs,
            hapticsEnabled: snapshot.hapticsEnabled,
            lastAppliedIntentSeq: snapshot.lastAppliedIntentSeq,
            lastAppliedEpoch: snapshot.lastAppliedEpoch,
            character: wire
        )
        let data = try #require(snapshot.encoded())
        let decoded = try #require(WatchSnapshot.decoded(from: data))
        let reassembled = makeWatchCharacterDisplay(display: decoded.display, character: decoded.character)
        // The mirror is faithful on the four carried fields; the projected
        // moment is the display's greeting (the rig's OTHER three fields —
        // bondStage/wakefulness — arrive through display, not the DTO).
        #expect(reassembled?.moodBand == original.moodBand)
        #expect(reassembled?.energyBand == original.energyBand)
        #expect(reassembled?.activity == original.activity)
        #expect(reassembled?.satietyHint == original.satietyHint)
        #expect(reassembled?.momentRequest == snapshot.display.greeting.map { .greeting($0) })
    }
}
