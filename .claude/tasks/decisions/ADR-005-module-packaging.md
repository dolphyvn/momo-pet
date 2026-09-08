# ADR-005 — Module Packaging: Local Swift Package (MomoCore / MomoCharacter / MomoKit) + Two App Targets

## Status
PROPOSED — under review (TASK-006). Becomes ACCEPTED upon REVIEW-TASK-006 approval.

## Context
Phase 1 ships an iPhone app and a watchOS app that must share the domain, the engine, the quest cascade, and the character rig, while keeping business logic out of views (project.md §22, §31) and avoiding enterprise structure (§22). The critical engineering rule is that the engine's purity be *machine-enforced*, not conventional: FR-13 AC-3 determinism and the headless test strategy (§10 of 05-technical-architecture) only hold if the pure core cannot import UI or platform frameworks by accident.

## Decision
**One repo-local Swift Package (zero external dependencies) with three targets, consumed by two app targets:**
- `MomoCore` — domain types, engine, quest generator/cascade, DisplayState + CharacterDisplayState derivations, seeds. **Foundation-only imports**; compiles and unit-tests on macOS — the build catches platform-unavailable imports (UIKit, WatchKit, WatchConnectivity, HealthKit) but **not** SwiftUI, which compiles on macOS; an import-whitelist scan step in the test target closes that residual at build time, with SwiftUI-residue on the standing review checklist (05 §2.3, §10.2).
- `MomoCharacter` — rig, CharacterClock, idle sequencer (pure files), LOD tiers. Depends on MomoCore + SwiftUI only.
- `MomoKit` — persistence (ADR-002), sync DTOs/journal/watermarks. Depends on MomoCore only; stays macOS-clean (WatchConnectivity wrappers live in the app targets, where their roles differ anyway).
- App targets `Momo` (iOS) and `MomoWatch` (watchOS) import all three; they never import each other; all cross-device state flows through MomoKit DTOs (ADR-003).

Dependency rules D-R1–D-R6 with their enforcement mechanisms: 05-technical-architecture §2.3. Phase 2 reservation: a widget extension target would import MomoCore + MomoKit without new derivations.

## Alternatives Considered
- **Single app target with folder groups:** rejected — every layering rule becomes review-enforced only, and no headless engine tests; the cheapest option is the one that silently erodes.
- **One package target (MomoKit imports everything):** rejected — collapses the purity boundary that motivates packaging at all.
- **Multiple Xcode framework targets:** equivalent enforcement but heavier project configuration; SPM is the current-native mechanism (VERIFY-AT-BUILD for template specifics at bootstrap).
- **Remote/extracted package or third-party scaffolding:** rejected — zero-dependency posture (FR-20 AC-3) and one-product scale (§22).

## Consequences
- Purity, dependency direction, and the no-third-party rule are enforced by the package graph, with review as the second line.
- Engine/kit/character logic is testable headlessly (`swift test` on macOS), keeping the fast feedback loop the determinism strategy relies on (VERIFY-AT-BUILD that all three targets' non-UI slices host on macOS).
- WatchConnectivity wrapper code is deliberately duplicated per app target (~100 lines each) — plain over DRY; its testable logic (journal, watermark arithmetic) lives in MomoKit.
- Package layout changes are cheap now (nothing ships yet) and expensive after EPIC-002 — this ADR is sequenced before any build work.

## Date
2026-09-08
