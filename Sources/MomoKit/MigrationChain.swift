import MomoCore

// MARK: - Migration chain (05-technical-architecture §5.5; TASK-022)

/// One link of the schema-migration chain (05 §5.5): a pure, total transform
/// that maps an `EngineState` persisted under schema version `from` to the
/// same state under version `from + 1`.
///
/// **Shape: `from` only — `to` is `from + 1` by construction.** 05 §5.5
/// registers a `migrate(v→v+1)` function per breaking change, so a step's
/// target is not independent data: deriving it removes the possibility of an
/// internally inconsistent step (`from: 1` "to" `3`) and leaves exactly one
/// way for a walk to fail — a MISSING step at some hop — which the walk, not
/// the step, reports. An explicit `to` would add a validation obligation
/// (what may `to ≠ from + 1` mean?) with no use case.
///
/// **Purity and totality (§5.5: "no failure path — worst case maps to a
/// valid default").** `apply` does not throw and reads nothing ambient: the
/// same input state always yields the same output. A migration that cannot
/// express its transform purely maps degenerate fields to a valid default
/// inside `apply` itself — never by failing.
public struct MigrationStep: Sendable {

    /// The schema version `apply` reads (its output is version `from + 1`).
    public let from: Int

    /// The pure `from → from + 1` transform.
    public let apply: @Sendable (EngineState) -> EngineState

    /// - Parameters:
    ///   - from: the version this step upgrades.
    ///   - apply: the pure, total transform to version `from + 1`.
    public init(from: Int, apply: @escaping @Sendable (EngineState) -> EngineState) {
        self.from = from
        self.apply = apply
    }
}

/// The injected chain of migration steps the read path walks for a generation
/// persisted below the current schema version (05 §5.5). VALUE DATA, not a
/// global registry: each `SnapshotStore` receives its own chain at
/// initialization and stores are independent (pinned in the migration suite).
///
/// **The production chain is `MigrationChain.empty`.** 05 §5.5: "additive
/// evolution is the norm" — new optional/defaulted fields decode forward with
/// no migration, and schema `1` is correct as shipped. Registering a non-empty
/// chain is a §5.5-policy event (a `schemaVersion` bump owns its steps); the
/// store ships no steps and bumps nothing.
///
/// **Walk semantics.** For a generation at version `v` and a target version
/// `t` (the store passes `StoreRules.currentSchemaVersion`): `v > t` is not a
/// walk (nil — the above-head shape); `v == t` needs no steps; `v < t` walks
/// `v → v+1 → … → t`, applying the step registered at each hop, and ANY
/// missing hop makes the whole generation unreadable (nil) — a half-migrated
/// state is never served. Steps at or above the target are inert (the walk
/// never consults them). The walk itself is pure: the input state is never
/// mutated, and no failure path exists other than the nil "unreadable" result,
/// which the store resolves by falling through to the next generation — the
/// public API never surfaces it.
public struct MigrationChain: Sendable {

    /// The shipped chain (05 §5.5: no migration for a change that has not
    /// happened). Every production `SnapshotStore` uses this.
    public static let empty = MigrationChain(steps: [])

    /// Steps indexed by their `from` version — the walk's hop table. If the
    /// injected array declares two steps with the same `from`, the FIRST
    /// declaration wins (deterministic; a duplicate `from` is an authoring
    /// defect the chain does not paper over with a silent last-wins).
    private let stepsByFrom: [Int: MigrationStep]

    /// - Parameter steps: the chain's steps, in any order (the walk looks hops
    ///   up by version, not position).
    public init(steps: [MigrationStep]) {
        var index: [Int: MigrationStep] = [:]
        for step in steps where index[step.from] == nil {
            index[step.from] = step
        }
        self.stepsByFrom = index
    }

    /// Walks `state` from `fromVersion` up to `toVersion` through the
    /// registered steps, returning the migrated state — or nil when the walk
    /// cannot be completed (`fromVersion > toVersion`, or a hop's step is
    /// missing). Never throws, never mutates its input.
    public func migrated(
        _ state: EngineState,
        from fromVersion: Int,
        to toVersion: Int
    ) -> EngineState? {
        guard fromVersion <= toVersion else { return nil }
        var current = state
        for version in fromVersion..<toVersion {
            guard let step = stepsByFrom[version] else { return nil }
            current = step.apply(current)
        }
        return current
    }

    /// The step registered to upgrade `version`, if any. Exposed for pins on
    /// the chain itself (the store consumes `migrated(_:from:to:)` only).
    public func step(from version: Int) -> MigrationStep? {
        stepsByFrom[version]
    }

    /// Whether no steps are registered (the production shape).
    public var isEmpty: Bool {
        stepsByFrom.isEmpty
    }
}
