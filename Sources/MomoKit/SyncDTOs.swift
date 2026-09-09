import Foundation
import MomoCore

// MARK: - Sync DTOs (05-technical-architecture §6.2; ADR-003; TASK-023)

/// The iPhone → Watch payload (05 §6.2's sketch, field-for-field). Carried by
/// `updateApplicationContext` — latest-wins, replaced, never queued (§6.1).
/// Stores never cross the link (TR4): this DTO wraps the §4.11 read-model and
/// the quest cascade inputs, never an `EngineState`.
///
/// **Versioning.** `schemaVersion` is the DTO's own (single-sourced as
/// `StoreRules.watchSnapshotSchemaVersion` at construction; the initializer
/// defaults it, tests pass explicit versions to pin the gate). Decode-side
/// semantics for any other version: IGNORED — `decoded(from:)` returns nil
/// and the Watch keeps rendering its last local snapshot (§6.3: no error
/// surface exists). That is the store's above-head rule under the shipped
/// `MigrationChain.empty`, applied to a wire payload: no DTO migration
/// machinery exists, so any version that is not the current one is not
/// understood. A future reader wanting below-current tolerance would peek
/// the version BEFORE full decode — the field exists on the wire precisely
/// so that branch is possible.
///
/// **Canonical bytes.** The serialization recipe is the store's:
/// `JSONEncoder` with `.sortedKeys` (REQUIRED — key order is otherwise
/// unspecified, which would make byte pins and cross-device expectations
/// unverifiable) and Foundation's DEFAULT Date strategy. There is no Date
/// field on this DTO today; the recipe statement governs the encoder, not a
/// field. `encoded()` single-sources the recipe for EPIC-008's transport
/// wrapper.
///
/// **Hand-written `Codable` — DISCLOSED (TASK-023 Requirement 1).** The
/// conformance cannot synthesize: `DisplayState` (and its
/// `QuestGeneration.QuestLine` member) are MomoCore read-models without
/// `Codable` conformances, and TASK-023 is forbidden from touching
/// MomoCore (`Sources/MomoCore/` diff must stay empty). The encoding is the
/// obvious keyed shape — `DisplayState` as a nested keyed container with its
/// eight §4.11 fields verbatim; `QuestLine` as the toolchain-canonical enum
/// shape (`{"wish":"Q6"}` / `{"allDone":{}}`, the same keyed-object shape the
/// SnapshotStore header documents for synthesized enum encodings). Migrating
/// `DisplayState` to `Codable` later would let this conformance synthesize
/// without changing the wire shape.
public struct WatchSnapshot: Equatable, Sendable, Codable {

    /// This snapshot's wire schema version
    /// (`StoreRules.watchSnapshotSchemaVersion` in production).
    public let schemaVersion: Int

    /// Monotonic, iPhone-assigned (05 §6.2) — assigned from the sync state's
    /// `nextSnapshotSeq` by `makeWatchSnapshot`. Ordering metadata for the
    /// Watch's latest-wins render; never a correctness gate (the prune gate
    /// consumes `lastAppliedIntentSeq`, not this).
    public let snapshotSeq: Int

    /// §4.11's surface read-model — everything the Watch renders.
    public let display: DisplayState

    /// Today's quest cascade inputs (05 §6.2's `QuestCascadeInputs` —
    /// "today's 3 quests: id/progress/target/completion") mapped onto
    /// MomoCore's existing `[QuestProgress]` per the TASK-023 contract; the
    /// §5.5 cascade consumes exactly this.
    public let questInputs: [QuestProgress]

    /// Haptics preference for the Watch's pat feedback (UX-13; haptics only —
    /// no sound exists, 04 §11). Sourced from `EngineState.settings`.
    public let hapticsEnabled: Bool

    /// The watermark: the highest Watch intent seq applied, scoped to
    /// `lastAppliedEpoch` (05 §6.2/§6.4). The Watch prunes journal entries
    /// ≤ this — only when the epoch matches its own.
    public let lastAppliedIntentSeq: Int

    /// The epoch `lastAppliedIntentSeq` belongs to; a Watch whose epoch
    /// differs ignores it (prunes nothing — §6.4 step 4).
    public let lastAppliedEpoch: UUID

    /// - Parameters:
    ///   - schemaVersion: defaults to `StoreRules.watchSnapshotSchemaVersion`
    ///     (the production shape); tests pass explicit versions to pin the
    ///     unknown-version gate.
    public init(
        schemaVersion: Int = StoreRules.watchSnapshotSchemaVersion,
        snapshotSeq: Int,
        display: DisplayState,
        questInputs: [QuestProgress],
        hapticsEnabled: Bool,
        lastAppliedIntentSeq: Int,
        lastAppliedEpoch: UUID
    ) {
        self.schemaVersion = schemaVersion
        self.snapshotSeq = snapshotSeq
        self.display = display
        self.questInputs = questInputs
        self.hapticsEnabled = hapticsEnabled
        self.lastAppliedIntentSeq = lastAppliedIntentSeq
        self.lastAppliedEpoch = lastAppliedEpoch
    }

    // MARK: Codec (canonical recipe; see the type header)

    /// The canonical bytes (type header's recipe: `.sortedKeys`, Foundation
    /// default Date strategy). Nil on an encoding failure — an `Equatable`
    /// roundtrip anchor is still guaranteed by the tests, and a snapshot that
    /// cannot encode is a domain-model regression, not a runtime state.
    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    /// The version-gated decode: nil for malformed bytes AND for any
    /// `schemaVersion` other than the current one (the type header's
    /// ignore-semantics). Total — never throws.
    public static func decoded(from data: Data) -> WatchSnapshot? {
        guard let snapshot = try? JSONDecoder().decode(WatchSnapshot.self, from: data) else {
            return nil
        }
        guard snapshot.schemaVersion == StoreRules.watchSnapshotSchemaVersion else { return nil }
        return snapshot
    }

    // MARK: Codable (hand-written — see the type header's disclosure)

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, snapshotSeq, display, questInputs
        case hapticsEnabled, lastAppliedIntentSeq, lastAppliedEpoch
    }

    private enum DisplayKeys: String, CodingKey {
        case petName, moodWordKey, energyPhraseKey, bondStage, bondDescriptorKey
        case questLine, wakefulness, greeting
    }

    private enum QuestLineKeys: String, CodingKey {
        case wish, allDone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        snapshotSeq = try container.decode(Int.self, forKey: .snapshotSeq)
        let displayContainer = try container.nestedContainer(keyedBy: DisplayKeys.self, forKey: .display)
        let questLineContainer = try displayContainer.nestedContainer(keyedBy: QuestLineKeys.self, forKey: .questLine)
        let questLine: QuestGeneration.QuestLine
        if questLineContainer.contains(.wish) {
            let rawWish = try questLineContainer.decode(String.self, forKey: .wish)
            guard let wish = QuestID(rawValue: rawWish) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .wish, in: questLineContainer,
                    debugDescription: "unknown QuestID raw value '\(rawWish)'"
                )
            }
            questLine = .wish(wish)
        } else {
            // `.allDone`'s payload is the canonical empty object ({}); its
            // presence IS the case. Decoding it is validation, not extraction.
            _ = try questLineContainer.decode([String: String].self, forKey: .allDone)
            questLine = .allDone
        }
        display = DisplayState(
            petName: try displayContainer.decode(String.self, forKey: .petName),
            moodWordKey: try displayContainer.decode(String.self, forKey: .moodWordKey),
            energyPhraseKey: try displayContainer.decode(String.self, forKey: .energyPhraseKey),
            bondStage: try displayContainer.decode(BondStage.self, forKey: .bondStage),
            bondDescriptorKey: try displayContainer.decode(String.self, forKey: .bondDescriptorKey),
            questLine: questLine,
            wakefulness: try displayContainer.decode(Wakefulness.self, forKey: .wakefulness),
            greeting: try displayContainer.decodeIfPresent(GreetingKind.self, forKey: .greeting)
        )
        questInputs = try container.decode([QuestProgress].self, forKey: .questInputs)
        hapticsEnabled = try container.decode(Bool.self, forKey: .hapticsEnabled)
        lastAppliedIntentSeq = try container.decode(Int.self, forKey: .lastAppliedIntentSeq)
        lastAppliedEpoch = try container.decode(UUID.self, forKey: .lastAppliedEpoch)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(snapshotSeq, forKey: .snapshotSeq)
        var displayContainer = container.nestedContainer(keyedBy: DisplayKeys.self, forKey: .display)
        try displayContainer.encode(display.petName, forKey: .petName)
        try displayContainer.encode(display.moodWordKey, forKey: .moodWordKey)
        try displayContainer.encode(display.energyPhraseKey, forKey: .energyPhraseKey)
        try displayContainer.encode(display.bondStage, forKey: .bondStage)
        try displayContainer.encode(display.bondDescriptorKey, forKey: .bondDescriptorKey)
        var questLineContainer = displayContainer.nestedContainer(keyedBy: QuestLineKeys.self, forKey: .questLine)
        switch display.questLine {
        case .wish(let id):
            try questLineContainer.encode(id.rawValue, forKey: .wish)
        case .allDone:
            // The canonical empty object for the no-payload enum case ({}),
            // the keyed shape the SnapshotStore header documents for
            // synthesized enum encodings.
            try questLineContainer.encode([String: String](), forKey: .allDone)
        }
        try displayContainer.encode(display.wakefulness, forKey: .wakefulness)
        // Explicit encode (never encodeIfPresent): an absent greeting and a
        // null greeting are the same value, but the always-present key keeps
        // the canonical byte shape stable across greeting transitions.
        try displayContainer.encode(display.greeting, forKey: .greeting)
        try container.encode(questInputs, forKey: .questInputs)
        try container.encode(hapticsEnabled, forKey: .hapticsEnabled)
        try container.encode(lastAppliedIntentSeq, forKey: .lastAppliedIntentSeq)
        try container.encode(lastAppliedEpoch, forKey: .lastAppliedEpoch)
    }
}

/// The Watch → iPhone payload (05 §6.2's sketch, field-for-field): one
/// journal entry, one `transferUserInfo` frame (§6.1). The intent is
/// WRAPPED, never re-invented — `InteractionIntent` already carries the
/// INV-10 idempotency key (`id`), the §6.4 day-attribution key
/// (`localDayKey`), the timestamp, the source, and the kind.
///
/// **Versioning.** `schemaVersion` is the DTO's own (single-sourced as
/// `StoreRules.intentEventSchemaVersion`). Decode-side semantics for any
/// other version: the journal SKIPS the line (its documented tolerance — a
/// future version can never wedge the queue). Same ignore-family as
/// `WatchSnapshot.decoded(from:)`.
///
/// **Canonical bytes.** The store's recipe again: `.sortedKeys` + Foundation
/// default Date strategy — the Date strategy is LOAD-BEARING here
/// (`intent.timestamp` is a JSON number of seconds since the reference date,
/// byte-stable within a toolchain). `encoded()` single-sources it; the
/// journal appends one newline-terminated `encoded()` per event.
///
/// **Hand-written `Codable` and `Equatable` — DISCLOSED (TASK-023
/// Requirement 1).** Both conformances would synthesize only if
/// `InteractionIntent` (and its `Source`/`Kind` members) were `Codable`/
/// `Equatable` — they are deliberately bare `Sendable` messages in MomoCore
/// (05 §3.1), and TASK-023 may not touch MomoCore. The encoding nests the
/// intent's five fields under `"intent"` verbatim; `Source`/`Kind`/
/// `PatGesture`/`TouchZone` map through exhaustive switches to their Swift
/// case-name strings, with `Kind` in the toolchain-canonical keyed-enum
/// shape (`{"pat":{"gesture":"tap","zone":"head"}}`, `{"feed":{}}`). An
/// unknown case-name string on decode throws — the journal's skip semantics
/// absorb it. `==` compares the intent FIELD-WISE (id, source, localDayKey,
/// timestamp, kind), making roundtrip pins exact.
public struct IntentEvent: Sendable, Codable {

    /// This event's wire schema version
    /// (`StoreRules.intentEventSchemaVersion` in production).
    public let schemaVersion: Int

    /// The wrapped intent — the INV-10 key travels inside it.
    public let intent: InteractionIntent

    /// Per-install Watch identity (05 §6.2: generated at first launch,
    /// persisted in the Watch store §5.6, regenerated on reinstall/re-pair/
    /// new Watch). The watermark and prune scopes are keyed on it.
    public let watchSessionEpoch: UUID

    /// The Watch's per-epoch monotonic seq (05 §6.2: "resets with the
    /// epoch"). The Watch assigns it (EPIC-008, §5.6); TASK-023's gate
    /// consumes it against the per-epoch watermark.
    public let watchSeq: Int

    /// - Parameters:
    ///   - schemaVersion: defaults to `StoreRules.intentEventSchemaVersion`
    ///     (the production shape); tests pass explicit versions to pin the
    ///     unknown-version gate.
    public init(
        schemaVersion: Int = StoreRules.intentEventSchemaVersion,
        intent: InteractionIntent,
        watchSessionEpoch: UUID,
        watchSeq: Int
    ) {
        self.schemaVersion = schemaVersion
        self.intent = intent
        self.watchSessionEpoch = watchSessionEpoch
        self.watchSeq = watchSeq
    }

    // MARK: Codec (canonical recipe; see the type header)

    /// The canonical bytes (type header's recipe). Nil on an encoding
    /// failure — a domain-model regression, not a runtime state (the journal
    /// treats it DEBUG-loud and appends nothing).
    public func encoded() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return try? encoder.encode(self)
    }

    /// The version-gated decode: nil for malformed bytes AND for any
    /// `schemaVersion` other than the current one (the journal skips the
    /// line). Total — never throws.
    public static func decoded(from data: Data) -> IntentEvent? {
        guard let event = try? JSONDecoder().decode(IntentEvent.self, from: data) else {
            return nil
        }
        guard event.schemaVersion == StoreRules.intentEventSchemaVersion else { return nil }
        return event
    }

    // MARK: Codable (hand-written — see the type header's disclosure)

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, intent, watchSessionEpoch, watchSeq
    }

    private enum IntentKeys: String, CodingKey {
        case id, source, kind, localDayKey, timestamp
    }

    private enum PatKeys: String, CodingKey {
        case gesture, zone
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        let intentContainer = try container.nestedContainer(keyedBy: IntentKeys.self, forKey: .intent)
        let id = try intentContainer.decode(UUID.self, forKey: .id)
        let sourceRaw = try intentContainer.decode(String.self, forKey: .source)
        guard let source = Self.source(fromRaw: sourceRaw) else {
            throw DecodingError.dataCorruptedError(
                forKey: .source, in: intentContainer,
                debugDescription: "unknown intent source '\(sourceRaw)'"
            )
        }
        let kindContainer = try intentContainer.nestedContainer(keyedBy: KindKeys.self, forKey: .kind)
        let kind = try Self.kind(from: kindContainer)
        intent = InteractionIntent(
            id: id,
            source: source,
            localDayKey: try intentContainer.decode(String.self, forKey: .localDayKey),
            timestamp: try intentContainer.decode(Instant.self, forKey: .timestamp),
            kind: kind
        )
        watchSessionEpoch = try container.decode(UUID.self, forKey: .watchSessionEpoch)
        watchSeq = try container.decode(Int.self, forKey: .watchSeq)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        var intentContainer = container.nestedContainer(keyedBy: IntentKeys.self, forKey: .intent)
        try intentContainer.encode(intent.id, forKey: .id)
        try intentContainer.encode(Self.raw(of: intent.source), forKey: .source)
        var kindContainer = intentContainer.nestedContainer(keyedBy: KindKeys.self, forKey: .kind)
        switch intent.kind {
        case .pat(let gesture, let zone):
            var patContainer = kindContainer.nestedContainer(keyedBy: PatKeys.self, forKey: .pat)
            try patContainer.encode(Self.raw(of: gesture), forKey: .gesture)
            try patContainer.encode(zone.map(Self.raw(of:)), forKey: .zone)
        case .feed:
            try kindContainer.encode([String: String](), forKey: .feed)
        case .play:
            try kindContainer.encode([String: String](), forKey: .play)
        case .tuckIn:
            try kindContainer.encode([String: String](), forKey: .tuckIn)
        case .nap:
            try kindContainer.encode([String: String](), forKey: .nap)
        }
        try intentContainer.encode(intent.localDayKey, forKey: .localDayKey)
        try intentContainer.encode(intent.timestamp, forKey: .timestamp)
        try container.encode(watchSessionEpoch, forKey: .watchSessionEpoch)
        try container.encode(watchSeq, forKey: .watchSeq)
    }

    // MARK: Case-name maps (exhaustive; an unknown string never decodes)

    private enum KindKeys: String, CodingKey {
        case pat, feed, play, tuckIn, nap
    }

    private static func raw(of source: InteractionIntent.Source) -> String {
        switch source {
        case .iPhone: "iPhone"
        case .watch: "watch"
        }
    }

    private static func source(fromRaw raw: String) -> InteractionIntent.Source? {
        switch raw {
        case "iPhone": .iPhone
        case "watch": .watch
        default: nil
        }
    }

    private static func raw(of gesture: PatGesture) -> String {
        switch gesture {
        case .tap: "tap"
        case .doubleTap: "doubleTap"
        case .longPress: "longPress"
        case .stroke: "stroke"
        }
    }

    private static func gesture(fromRaw raw: String) -> PatGesture? {
        switch raw {
        case "tap": .tap
        case "doubleTap": .doubleTap
        case "longPress": .longPress
        case "stroke": .stroke
        default: nil
        }
    }

    private static func raw(of zone: TouchZone) -> String {
        switch zone {
        case .head: "head"
        case .belly: "belly"
        }
    }

    private static func zone(fromRaw raw: String) -> TouchZone? {
        switch raw {
        case "head": .head
        case "belly": .belly
        default: nil
        }
    }

    private static func kind(from container: KeyedDecodingContainer<KindKeys>) throws -> InteractionIntent.Kind {
        if container.contains(.pat) {
            let patContainer = try container.nestedContainer(keyedBy: PatKeys.self, forKey: .pat)
            let gestureRaw = try patContainer.decode(String.self, forKey: .gesture)
            guard let gesture = gesture(fromRaw: gestureRaw) else {
                throw DecodingError.dataCorruptedError(
                    forKey: .gesture, in: patContainer,
                    debugDescription: "unknown pat gesture '\(gestureRaw)'"
                )
            }
            let decodedZone: TouchZone?
            if patContainer.contains(.zone), let zoneRaw = try patContainer.decodeIfPresent(String.self, forKey: .zone) {
                guard let zone = Self.zone(fromRaw: zoneRaw) else {
                    throw DecodingError.dataCorruptedError(
                        forKey: .zone, in: patContainer,
                        debugDescription: "unknown touch zone '\(zoneRaw)'"
                    )
                }
                decodedZone = zone
            } else {
                decodedZone = nil
            }
            return .pat(gesture: gesture, zone: decodedZone)
        }
        if container.contains(.feed) { return .feed }
        if container.contains(.play) { return .play }
        if container.contains(.tuckIn) { return .tuckIn }
        if container.contains(.nap) { return .nap }
        throw DecodingError.dataCorruptedError(
            forKey: .pat, in: container,
            debugDescription: "intent kind object carries no known case"
        )
    }
}

// MARK: - Equatable (hand-written — see the IntentEvent header's disclosure)

extension IntentEvent: Equatable {

    /// Field-wise equality, including the wrapped intent compared
    /// FIELD-wise (id, source, localDayKey, timestamp, kind) — exact
    /// roundtrip-pin semantics, since `InteractionIntent` itself carries no
    /// `Equatable` conformance to delegate to.
    public static func == (lhs: IntentEvent, rhs: IntentEvent) -> Bool {
        guard lhs.schemaVersion == rhs.schemaVersion,
              lhs.watchSessionEpoch == rhs.watchSessionEpoch,
              lhs.watchSeq == rhs.watchSeq,
              lhs.intent.id == rhs.intent.id,
              lhs.intent.localDayKey == rhs.intent.localDayKey,
              lhs.intent.timestamp == rhs.intent.timestamp
        else { return false }
        guard lhs.intent.source == rhs.intent.source else { return false }
        switch (lhs.intent.kind, rhs.intent.kind) {
        case (.feed, .feed), (.play, .play), (.tuckIn, .tuckIn), (.nap, .nap):
            return true
        case (.pat(let lhsGesture, let lhsZone), .pat(let rhsGesture, let rhsZone)):
            return lhsGesture == rhsGesture && lhsZone == rhsZone
        default:
            return false
        }
    }
}
