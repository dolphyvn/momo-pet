# REVIEW-TASK-012 — MomoCore Domain Model

- **Task:** TASK-012 — Define MomoCore domain model (EPIC-003)
- **Deliverables reviewed:** 11 new sources (`Sources/MomoCore/{Instant,Thresholds,Pet,PetState,Bands,DayKey,Quest,DayRecord,InteractionIntent,SettingsState,CharacterInterface}.swift`), 3 new test suites (`Tests/MomoCoreTests/{BandDerivationTests,DayKeyTests,DomainInvariantsTests}.swift`), deletion of the TASK-009 placeholder pair, task-file notes update.
- **Independence statement:** This reviewer did not author any part of TASK-012 and had no role in its implementation. All claims below were independently re-executed (tests re-run, greps re-run, dates machine-probed, specs re-read), not accepted from the Implementation Notes.
- **Date:** 2026-09-08
- **Repo state at review:** branch `feature/EPIC-003-domain-model`, HEAD `8ae4970` (verified before and after review — unchanged; reviewer made no commits). Working tree = the declared change set plus the orchestrator's pre-existing uncommitted `CLAUDE.md` §14 edit (out of TASK-012 scope, per orchestrator instruction).

## Review Method (re-runs with verbatim outcomes)

1. **`swift test`** → `✔ Test run with 64 tests in 11 suites passed after 0.011 seconds.` (reproduced the Implementation Notes' claim verbatim). Baseline arithmetic verified: 35 − 1 (placeholder) + 30 new = 64; 9 − 1 + 3 suites = 11. Counted the new suites by hand: 8 (BandDerivation) + 8 (DayKey) + 14 (DomainInvariants) = 30 new tests — matches.
2. **D-R1 scan (grep, independently of the in-suite scan):** all 11 sources import exactly `import Foundation`. The in-suite scan passed in the same run as `Test "MomoCore as it stands passes the D-R1 whitelist (non-empty source set)"` — non-vacuous.
3. **`print(` scan:** `grep -rn "print(" Sources/ Tests/` → none. No secrets, no new dependencies (`Package.swift` untouched per `git diff`; `dependencies:` absent per D-R4).
4. **Ambient-clock scan:** `grep -rn "Date()\|Calendar.current\|TimeZone.current" Sources/MomoCore/` → only doc-comment text in `DayKey.swift`. `dayKey` derivation takes injected instant + injected calendar only.
5. **Mutability scan:** `grep -rn "var " Sources/MomoCore/` → **zero hits** (stronger than the `let`-everywhere claim: not even local `var`s). All public types `Sendable`; module builds clean under Swift tools 6.2 strict concurrency: `swift build` → no warnings, no errors.
6. **Threshold single-source scan:** `grep -rnE '\b(20|45|75|149|150|399|400|749|750|1000|12|20|7|90|30|22|85|60|92|25|35)\b'` over `Sources/MomoCore/` excluding `Thresholds.swift` → no executable hits; the only occurrences are doc-comment references. Every threshold literal lives once in `Thresholds.swift`; derivations, `QuestWindow`, `PetState`, and `DayRecord` all read the constants.
7. **Spec diff (manual, byte-level):** type set vs 05 §3.1; five interface types vs 04 §9.2 field-by-field; derivations vs PRD §3.1–3.3 tables; quest catalog vs PRD §5.2 row-by-row (ids, families, targets 1/1/2/2/3/1/3, windows) — all exact.
8. **Placeholder provenance:** `git show HEAD:Sources/MomoCore/MomoCorePlaceholder.swift` → its own doc comment says "Replaced by real domain sources in EPIC-003." Removal condition self-declared and now met; no remaining references anywhere (`grep` clean). `Tests/MomoCoreTests/MomoCorePlaceholderTests.swift` referenced nothing outside the placeholder itself.
9. **DST test claim machine-probed** (independent Swift script, /tmp): `America/New_York`, Nov 1 2026 → weekday 1 (Sunday); `2026-11-01T05:30Z` → local 01:30, offset −4 (DST); `2026-11-01T06:30Z` → local 01:30, offset −5 (standard); next transition `2026-11-01T06:00:00Z`. The test's "repeated local hour" comment is factually exact, and the test genuinely exercises the repeated hour.
10. **Citation spot-checks:** FR-6 AC-3 ("Each feed increments the day's feedCount"), FR-18 AC-1 ("applies exactly once… replay/duplicate delivery does not double-apply"), FR-14/15/16, UX-6, PRD §5.3 no-duplicates — all quoted accurately in code comments/tests.
11. **Scope:** `git status --porcelain` before and after review — exactly the declared inventory + orchestrator's CLAUDE.md edit; no docs/status/decisions/pbxproj/Package.swift changes; no simulator use (none required; `swift test` is macOS-headless).

## Findings

### MINOR-1 — "Conformances exactly as the docs declare … nothing added" is slightly overstated (task-file claim, not a code defect)
`Sources/MomoCore/Bands.swift:6,14,22` and `PetState.swift:7,15,25` declare `Equatable` on `MoodBand/EnergyBand/BondStage/Wakefulness/Activity/SatietyPhase`, and `CharacterInterface.swift:79,122` on `GreetingKind/HandshakeKind`, where the 05 §3.1 / 04 §9.2 sketches declare `Sendable` only (e.g. `enum MoodBand: Sendable`, `enum HandshakeKind: Sendable`). The addition is benign and effectively required (test `#expect` equality needs `Equatable`; synthesis is trivial for case-less-payload enums), and the sketches' `InteractionIntent`/`CharacterReport` correctly keep `Sendable`-only — but the Implementation Notes' "nothing added" wording does not match the diff. **Suggested fix:** none to code. One-line correction in the task file's Deviations (or accept this review as the record of the deviation). Does not block commit.

### NITPICK-1 — `Thresholds.Band.lowUpperBound` naming
`Thresholds.swift:28` — the constant is the *first Wistful/Drowsy value* (20), i.e. the Low/Exhausted band's exclusive upper edge; "lowUpperBound" can be misread as Low's inclusive upper bound (19). The doc comment ("First Wistful (mood) / Drowsy (energy) value") disambiguates; cosmetic only.

### NITPICK-2 — ambient `.now` filler in tests
`DomainInvariantsTests.swift:72–75`, `230–241` use `createdAt: .now` / `timestamp: .now` where the instant is irrelevant to the assertion. The no-ambient-clock constraint targets model code, so no violation; a fixed fixture instant would be marginally cleaner.

### NITPICK-3 — `QuestCatalogEntry` has an internal memberwise init
`Quest.swift:62` — external modules can read but not construct entries. This looks intentional (the static catalog is the sole source) but is undocumented; a one-line doc note would help EPIC-004/006 consumers.

### Verified-benign adjudications (implementation's flagged judgment calls)
- **(a) No `Codable` yet — SOUND.** ADR-002/05 §5 do require a Codable payload store, but the store (and its schema/migration design) is EPIC-005. Deferring keeps TASK-012 free of speculative API; adding conformances later *in MomoCore* (same module) avoids Swift 6 retroactive-conformance warnings and is purely additive — no hidden breaking cost. ADR-002's "MomoCore stays persistence-free (value types only)" further supports not front-running the store.
- **(b) `QuestCatalog.entry(for:)` force-unwrap — SOUND.** The table is `static let`, complete, one entry per `QuestID`; completeness and lookup are pinned by `catalogTable` + `entryLookup`. A regression fails the suite before any ship; the crash path is reachable only by editing a compile-time-static table that CI pins.
- **(c) `SatietyHint` = `SatietyPhase` typealias — FAITHFUL.** 05 §3.1 names the PetState field `satietyPhase: SatietyPhase`; 04 §9.2 names the display field `satietyHint: SatietyHint?`; 05 §4.5 gives the character-facing hint values `.full/.recentlyFed/.hungry` — the same three cases. One type, two doc names, optionality at the usage site: exactly what the docs describe.
- **(d) `let`-everywhere vs the sketches' `var` — CORRECT CALL.** Requirement 3/AC-1 demand immutable types and 05 §3.0 itself says "immutable-by-convention … the engine produces new state." No behavioral loss: every consumer in 05 constructs new values per transition.
- **(e) Placeholder pair removal — VERIFIED.** See Method item 8.

## Clean Dimensions
- Type-set completeness vs 05 §3.1: complete and exact — no missing, renamed, or unjustified extra types. Supporting types (`QuestWindow`, `QuestCatalogEntry`, `PatGesture`, `TouchZone`) are each doc-anchored (PRD §5.2; 05 §3.1 "static table"; 04 §6.1; 04 §2.3). 05 §4.1's `Handshake` is engine-side (EPIC-004), correctly out of §3.1 scope.
- Derivation fidelity vs PRD §3.1–3.3: every boundary verified — 20→Wistful/Drowsy, 45→Content/Relaxed, 75→Joyful/Energetic, 19.5→Low/Exhausted, 149/150, 399/400, 749/750, 1000 plateau. The `150/400/750` first-value form faithfully encodes the PRD's inclusive-range table (0–149 / 150–399 / 400–749 / 750–1000); the "149/399/749" phrasing elsewhere is the same partition's inclusive *upper* bounds. Code, `Thresholds` comments, and tests all express one consistent semantics: value-at-cut-off belongs to the band/stage above.
- Purity: no engine dynamics (attractor/floor/ceiling/reduce/generation/RNG) anywhere in `Sources/MomoCore/` (grep — only a doc comment saying "no RNG").
- INV-1…11 disposition honesty: see AC-4 sweep below — all eleven dispositions match what the code and tests actually do; the engine/store splits (INV-3 monotonicity, INV-4 within-day monotonicity, INV-5 clamp arithmetic, INV-6 completion-never-reverses, INV-7 uniqueness/window/attribution, INV-8 transitions, INV-10 exactly-once, INV-11 engine-composes-no-prose) match 05 §10.3's own placement of those tests in the engine/kit categories.
- Sendable/immutability: compile-proven under tools 6.2 strict concurrency, zero warnings; zero `var` in the module; no global mutable state.
- Test discipline: focused only — no exhaustive 0…100/0…1000 sweeps, no TASK-013 scope creep; DayKey coverage includes known instants, determinism, day boundary (one second either side), timezone variation in both directions, a genuine DST repeated hour, and a non-Gregorian calendar (Buddhist era 2569).
- Fabrication check: every recorded number reproduced (64/11; boundary values; catalog targets/windows; the DST date probed by machine). Nothing found copied rather than produced.

## AC-1…AC-5 Sweep
- **AC-1 — MET.** All 05 §3.1 value types + all five 04 §9.2 interface types exist in MomoCore (placement per 05 §2.1/§4.11), `Sendable`, `let`-immutable, doc-specified names and fields.
- **AC-2 — MET.** `makeMoodBand`/`makeEnergyBand`/`makeBondStage` match PRD §3.1–3.3 including boundary semantics; thresholds defined exactly once in `Thresholds.swift` (verified by scan).
- **AC-3 — MET.** `DayKey.make(from:calendar:)` is injected-calendar/injected-instant only; no ambient clock in the module (grep-verified).
- **AC-4 — MET.** All eleven invariants dispositioned (task-file table) and each disposition verified against code + a named test: INV-1/2/4/5/6 type-enforced (failable inits, unrepresentability tests incl. NaN); INV-3 range type-enforced with monotonicity honestly deferred; INV-7/8/9/10/11 representation-enforced with the model-side half pinned (`helloAwarded` single Bool, exhaustive 4-case switch, Instant=Date + derived keys, non-optional UUID, string-free display inventory).
- **AC-5 — MET.** `swift test` → 64 tests / 11 suites passed (reproduced); baseline 35/9 preserved (−1 placeholder +30/+3); D-R1 and banned-vocabulary standing scans green in the same run.

## VERDICT

**APPROVED_WITH_MINOR_NOTES**

The implementation is faithful to 05 §3.1, 04 §9.2, and PRD §3/§5 to the letter, including boundary semantics; the purity and single-source constraints hold under independent scan; the INV disposition table is honest, with the engine/store splits matching 05's own test plan; and every recorded claim survived re-execution. The one MINOR finding is a wording imprecision in the task file's conformance claim (Equatable added to doc-`Sendable`-only enums — benign, test-necessitated), plus three cosmetic nitpicks; none affect code behavior or block commit.

**Recommendation:** Commit `feat(domain): TASK-012 define MomoCore domain model (05 §3.1)` and push, then dispatch TASK-013.

## Disposition (orchestrator, 2026-09-08)

| Finding | Disposition |
|---|---|
| MINOR-1 — "nothing added" conformance wording overstated | **FIXED (task file only).** Deviations bullet rewritten to state the test-necessitated `Equatable` additions on the band/stage/state enums + `GreetingKind`/`HandshakeKind`, with `InteractionIntent`/`CharacterReport` correctly `Sendable`-only. No code change (reviewer: "none to code"). |
| NITPICK-1 — `lowUpperBound` naming | **DECLINED.** Cosmetic; the constant's doc comment already disambiguates ("First Wistful (mood) / Drowsy (energy) value"). Renaming an approved constant after review adds churn with no behavior or clarity gain. |
| NITPICK-2 — ambient `.now` filler in two tests | **DECLINED.** Reviewer's own finding: "no violation" — the constraint targets model code, and the instant is irrelevant to those assertions. Fixture swap would be post-approval diff noise. |
| NITPICK-3 — `QuestCatalogEntry` internal init undocumented | **FIXED.** Doc note added to `Quest.swift` stating the read-only-by-design intent (`QuestCatalog` is the sole source; consumers use `entry(for:)`). Comment-only change. |

Post-disposition verification: `swift test` re-run after the two mechanical edits (doc comment + task file) — result recorded in the task file's Completion Evidence. No other code touched; the approved implementation is byte-identical except the added `Quest.swift` doc comment. Optionally fold the MINOR-1 one-line correction into the task file when recording Completion Evidence.
