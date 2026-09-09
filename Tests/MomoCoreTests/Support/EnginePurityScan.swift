import Foundation

/// Engine-purity scan (TASK-014 Requirement 8; 05 §4.1/§4.10/ADR-004).
///
/// The engine performs no I/O, reads no ambient time (`Date()`, `Date.now`),
/// no ambient calendar/time zone (`Calendar.current`, `TimeZone.current`),
/// and no system randomness (`random()`, `arc4random`, `UUID()`,
/// `randomElement()`, the C `srand`/`drand48` family). Ambient world enters
/// only through injected `EngineClock`/`Calendar`/`SeededGenerator` values.
/// This scanner keeps that mechanically true over the real MomoCore sources
/// — the same pure-text pattern as the import whitelist and banned-vocabulary
/// scans (TASK-010): no filesystem access here, the real-tree test feeds
/// file contents read via `TestRepo`.
///
/// Scope: ALL of `Sources/MomoCore` (domain + engine), not only the new
/// engine files — stricter than TASK-014's requirement, and it enforces a
/// rule the module already carries in prose: "Model code never touches
/// `Date()` or `Calendar.current` (D20 / TASK-012 requirement)",
/// `DayKey.swift` header. One documented exemption: `EngineClock.swift`'s
/// `SystemEngineClock` is §4.10's sanctioned production system-clock read —
/// the exemption is per-pattern (randomness stays banned there too) and the
/// scan test asserts the exempted file actually exists and actually contains
/// the exempted pattern, so the carve-out can never go stale or dead.
enum EnginePurityScan {

    /// One banned construction: the literal substring matched against
    /// comment-stripped source, plus per-file exemptions by last path
    /// component.
    struct BannedPattern: Equatable {
        let literal: String
        let rationale: String
        let exemptedFiles: Set<String>
    }

    /// The banned vocabulary (TASK-014 Requirement 8 + the sibling stdlib/
    /// C spellings of the same clauses). Every entry names its clause.
    static let patterns: [BannedPattern] = [
        BannedPattern(
            literal: "Date(",
            rationale: "ambient wall-clock construction — time enters only via EngineClock (§4.10)",
            exemptedFiles: ["EngineClock.swift"]
        ),
        BannedPattern(
            literal: "Date.now",
            rationale: "ambient wall-clock read — time enters only via EngineClock (§4.10)",
            exemptedFiles: ["EngineClock.swift"]
        ),
        BannedPattern(
            literal: "Calendar.current",
            rationale: "ambient calendar — D20: the calendar is always injected (TASK-012 pattern)",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "TimeZone.current",
            rationale: "ambient time zone — locality comes from the injected calendar (D20)",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "random(",
            rationale: "system randomness — includes random(), arc4random(, Int.random(in:) (§4.10)",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "randomElement(",
            rationale: "system randomness via the stdlib default generator (§4.10)",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "arc4random",
            rationale: "system randomness (covers arc4random_uniform and call-less references)",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "UUID(",
            rationale: "system randomness — UUID() draws from the system source; ids are injected",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "srand(",
            rationale: "C-family system randomness seeding",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "srand48(",
            rationale: "C-family system randomness seeding",
            exemptedFiles: []
        ),
        BannedPattern(
            literal: "drand48(",
            rationale: "C-family system randomness",
            exemptedFiles: []
        ),
    ]

    /// One violation: the file and the banned literal, for actionable output.
    struct Violation: Equatable {
        let file: String
        let literal: String
    }

    /// Scans the given files (comment-stripped) and returns every violation,
    /// sorted by (file, literal) for stable, deterministic reporting.
    static func violations(
        files: [(name: String, contents: String)],
        patterns: [BannedPattern] = EnginePurityScan.patterns
    ) -> [Violation] {
        files
            .flatMap { file in
                let stripped = ImportWhitelistScan.strippingComments(from: file.contents)
                let fileName = (file.name as NSString).lastPathComponent
                return patterns
                    .filter { !$0.exemptedFiles.contains(fileName) }
                    .filter { stripped.contains($0.literal) }
                    .map { Violation(file: file.name, literal: $0.literal) }
            }
            .sorted { ($0.file, $0.literal) < ($1.file, $1.literal) }
    }
}
