# ADR-014 — Watch Character Read-Model on the Wire

## Status

Accepted (2026-09-11, TASK-041 contract; owner-authorized orchestration decision per §36 — wire-schema shape, reversible, follows the established TASK-040 D-1 adjudication).

## Context

W1 must render the pet: the LOD-glance rig in the foreground and the static glyph in AOD (FR-17 AC-5; 04 §2.1). The rig consumes `CharacterDisplayState` (04 §9.2: moodBand, energyBand, bondStage, wakefulness, activity, satietyHint, momentRequest). The Watch never sees `EngineState` — it renders iPhone-issued snapshots, and the snapshot's surface read-model `DisplayState` (05 §4.11/§6.2) carries only moodWordKey / energyPhraseKey / bondStage / wakefulness / greeting. Four character-family fields (moodBand, energyBand, activity, satietyHint) ride nowhere. Inverting word keys back into bands would be lossy AND would put derivation logic on the Watch — both forbidden (04 §9.2's "no consumer derives its own view of engine state"; EPIC-008 AC-5's "the Watch runs no engine").

## Decision

`WatchSnapshot` gains one additive-OPTIONAL field, `character: WatchCharacterDTO?` — a small MomoKit DTO mirroring exactly the four fields `DisplayState` lacks (moodBand, energyBand, activity, satietyHint). The iPhone executor derives it from the SHARED `makeCharacterDisplayState(state)` derivation (never re-implemented anywhere), and `makeWatchSnapshot` threads it into the push. A pure MomoKit assembly function (`DisplayState` + `WatchCharacterDTO` → `CharacterDisplayState`, momentRequest projected from `display.greeting`) is what W1 consumes, so the assembled character is a faithful mirror of what the iPhone's own rig received at push time.

Codec discipline follows the TASK-040 reset-marker adjudication exactly: hand-written Codable with `decodeIfPresent`/`encodeIfPresent`, **no `schemaVersion` bump**, OBS-3 parity-fixture obligation NOT fired. A snapshot decoding without `character` (cross-version skew — cannot ship in Phase 1, both targets update together) degrades honestly: words + quest line render, the pet canvas slot is skipped, DEBUG-loud log; never a crash, never an error surface (UX §9).

## Alternatives Considered

- **Full `CharacterDisplayState` mirror DTO** (all seven fields): self-contained but duplicates bondStage/wakefulness/greeting that already ride in `display` — the wire carries redundant copies that can drift within one snapshot.
- **Derive bands on the Watch from the word keys**: lossy inversion plus Watch-side logic — violates 04 §9.2 and AC-5 outright.
- **`schemaVersion` bump to 2 with a required character field**: drops whole payloads at every pre-bump decoder and fires the OBS-3 parity-fixture obligation for zero pre-launch benefit (no old decoders exist outside tests).

## Consequences

The context payload grows by four small enums — negligible against the KB-scale snapshot budget (05 §6.2). The kit-level assembly function is headlessly testable (the app-target test gap lesson, REVIEW-TASK-040 F-6/D-7). The degraded nil-character path is a pinned, documented behavior, not silent dead code. The reset-marker field (TASK-040) and this field together establish the snapshot's additive-evolution pattern: later wire additions follow the same adjudication or justify a bump explicitly.
