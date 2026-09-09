import Foundation

// MARK: - Day-stable seed derivation (05-technical-architecture §4.10; ADR-004)

/// Day-stable 64-bit seeds: `seed = SHA-256(petID ‖ localDayKey ‖ epoch ‖ salt)`
/// truncated to 64 bits (05 §4.10). Same day ⇒ same seed — on iPhone, on the
/// Watch, and in tests — because SHA-256 is standardized and stable across OS
/// versions and devices, and every input is derived from injected values.
///
/// Salts (05 §4.10, verbatim): `.choreography` for the idle sequencer
/// (epoch = `choreographyEpoch`, changes only when the idle-variant catalog
/// changes — 04 §5.1), `.copy` for line picks, `.quest` for daily set
/// generation. The salt separation guarantees a change in one domain's epoch
/// can never reshuffle another domain's draws.
///
/// The engine derives these; the character consumes the choreography seed and
/// never calls system randomness (04 §9.4).
public enum DaySeed {

    /// The three derivation domains (05 §4.10). Raw values are the spec's
    /// salt strings, byte-for-byte.
    public enum Salt: String, Sendable, CaseIterable {
        case choreography
        case copy
        case quest
    }

    /// Derives the 64-bit day seed. Pure: no clock, no calendar, no ambient
    /// state — the caller injects the pet identity, the calendar-derived day
    /// key (`DayKey.make`), the domain's epoch, and the salt.
    ///
    /// Truncation (documented contract): the digest's FIRST 8 bytes,
    /// interpreted big-endian as a `UInt64` ("leftmost 64 bits" of the
    /// digest, FIPS 180-4 big-endian word order).
    public static func make(petID: UUID, localDayKey: String, epoch: Int, salt: Salt) -> UInt64 {
        let digest = SHA256.digest(preimage(petID: petID, localDayKey: localDayKey, epoch: epoch, salt: salt))
        var seed: UInt64 = 0
        for byte in digest.prefix(8) {
            seed = (seed << 8) | UInt64(byte)
        }
        return seed
    }

    /// The exact bytes hashed by `make` — exposed (internal) so tests can pin
    /// the encoding byte-for-byte. See the header of `frame` for the encoding
    /// contract.
    static func preimage(petID: UUID, localDayKey: String, epoch: Int, salt: Salt) -> [UInt8] {
        var bytes: [UInt8] = []
        bytes.append(contentsOf: Self.frame(uuidBytes(petID)))
        bytes.append(contentsOf: Self.frame(Array(localDayKey.utf8)))
        bytes.append(contentsOf: Self.frame(epochBytes(epoch)))
        bytes.append(contentsOf: Self.frame(Array(salt.rawValue.utf8)))
        return bytes
    }

    /// The RFC 4122 16-byte form of `id` (`UUID.uuid` is an imported 16-byte
    /// tuple; this is its sequential byte order, stable across platforms).
    static func uuidBytes(_ id: UUID) -> [UInt8] {
        withUnsafeBytes(of: id.uuid, Array.init)
    }

    /// Byte encoding of the ‖-concatenation (05 §4.10) — a deliberate,
    /// documented choice, so the derivation is reproducible forever:
    ///
    /// Each field is **length-framed**: a 4-byte big-endian byte count
    /// followed by exactly that many payload bytes, fields in the fixed order
    /// petID, localDayKey, epoch, salt.
    ///
    /// Why framing over naive concatenation: naive `a ‖ b` is ambiguous
    /// (("ab", "c") and ("a", "bc") hash identically), which would let a
    /// future field re-partition silently change every derived seed. Framing
    /// makes the preimage self-delimiting — the encoding is injective for any
    /// field contents. Why framing over field tags: the salt already provides
    /// domain separation (the three salts are distinct literal domains), so
    /// tags would be redundant bytes without additional guarantees.
    ///
    /// Payload encodings inside the frames:
    /// - petID: `UUID.uuid` — the RFC 4122 canonical 16-byte big-endian
    ///   representation, stable across platforms (not the hyphenated string).
    /// - localDayKey: UTF-8 of the `"YYYY-MM-DD"` key from `DayKey.make`.
    /// - epoch: fixed 8-byte big-endian two's-complement bit pattern of the
    ///   `Int` (so any integer round-trips regardless of platform endianness).
    /// - salt: UTF-8 of the salt's raw value (`"choreography"`/`"copy"`/`"quest"`).
    private static func frame(_ payload: [UInt8]) -> [UInt8] {
        var bytes: [UInt8] = []
        let count = UInt32(payload.count)
        bytes.append(UInt8(truncatingIfNeeded: count >> 24))
        bytes.append(UInt8(truncatingIfNeeded: count >> 16))
        bytes.append(UInt8(truncatingIfNeeded: count >> 8))
        bytes.append(UInt8(truncatingIfNeeded: count))
        bytes.append(contentsOf: payload)
        return bytes
    }

    /// Fixed-width big-endian encoding of the epoch (see `frame`).
    private static func epochBytes(_ epoch: Int) -> [UInt8] {
        let bits = UInt64(bitPattern: Int64(epoch))
        return (0..<8).reversed().map { UInt8(truncatingIfNeeded: bits >> (UInt64($0) * 8)) }
    }
}
