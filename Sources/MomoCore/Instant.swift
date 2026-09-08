import Foundation

/// The spec's `Instant` (05-technical-architecture §3.1) realized as
/// Foundation's `Date`: an absolute point in time with no timezone of its own,
/// which is exactly INV-9's representation rule ("all persisted timestamps are
/// UTC instants"). Aliased so the domain vocabulary matches the architecture
/// documents and so the concrete choice has exactly one place to change.
public typealias Instant = Date
