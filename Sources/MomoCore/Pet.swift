import Foundation

/// Pet identity (05-technical-architecture §3.1).
///
/// All properties are `let`: value semantics, immutable by construction —
/// the engine produces new values rather than mutating shared state (05 §3).
public struct Pet: Equatable, Sendable, Codable {

    /// Stable identity, generated once at the onboarding Enter tap.
    public let id: UUID

    /// The pet's name. INV-1: stored trimmed and guaranteed non-empty — the
    /// failable initializer rejects whitespace-only input, so an invalid name
    /// is unrepresentable (FR-1, UX S2).
    public let name: String

    /// When the pet was created (UTC instant, D20 / INV-9).
    public let createdAt: Instant

    /// Fails (returns nil) when the name is empty after trimming — INV-1's
    /// type-level enforcement. The stored name is the trimmed value.
    public init?(id: UUID, name: String, createdAt: Instant) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        self.id = id
        self.name = trimmed
        self.createdAt = createdAt
    }
}
