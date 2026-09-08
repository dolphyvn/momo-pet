# EPIC-008 — Watch App & Sync

## Objective
Deliver the watchOS experience and device-to-device sync per FR-17/FR-18, ADR-003, and 03 §6 / 05 §6: the iPhone-side WatchConnectivity session (snapshot push + intent receive with epoch-scoped exactly-once application), the MomoWatch W1 glance with persisted snapshots and AOD glyph, the offline-first pat with intent journaling and local delight, the shared cascade rendering and settings/haptics propagation — proven by the full §10.4 synchronization matrix including paired-device delivery obligations.

## User / Product Value
The first vertical slice completes: Momo's state reaches the wrist, and a pat from the watch — even offline, even mid-run — lands exactly once on the iPhone. The Watch must feel independently worthwhile within ≤ 5 s (FR-17), never a laggy phone mirror (PR6/§44).

## Scope
- iPhone session (05 §6.1–6.4): `updateApplicationContext` push of `WatchSnapshot` on every state change (latest-wins; DisplayState + quest inputs + haptics flag + epoch-scoped watermark); receive path = fold-to-now → apply iff UUID unseen ∧ seq > watermark → next snapshot carries watermark; `sendMessage` optimization only.
- MomoWatch (FR-17, UX §6.1/§6.5, NFR-9): W1 renders last-synced snapshot instantly from local store (persisted per receive + background transition); mood in words + stage word + quest line + pat targets; LOD-glance rig foreground, static glyph AOD; no numbers/bars/freshness indicators (UX-9); settling-in line pre-first-sync.
- Watch pat (FR-17 AC-1/2, UX §6.2–6.4, 04 §6.4): capture via pet canvas or Pat pill (UX-11); immediate local micro-reaction (awake bounce / asleep stir + heart) + subtle haptic honoring synced toggle — fully offline; journal with `watchSessionEpoch` + monotonic seq; `transferUserInfo` drain; epoch-matched prune.
- Cascade + propagation (05 §4.8 consumer, UX-13): quest line = shared `makeDisplayState` derivation (no Watch-side logic); haptics toggle via snapshot; no Watch settings surface.
- Sync test coverage (05 §10.4): matrix as named tests + paired-device WC delivery evidence.

## Non-Goals
Complications/widgets (Phase 2, 05 §8), Watch settings (UX-13), numeric history on the wrist, freshness indicators (UX-9), any network beyond the paired link, HealthKit (D17/D19 — Phase 2).

## Dependencies
- EPIC-007 (TASK-031 facade), EPIC-005 (TASK-023 journal/DTOs), EPIC-006 (LOD tiers), EPIC-004 (cascade derivation TASK-018/019).

## Tasks
Branch: `feature/EPIC-008-watch-sync` (from `main`).

| TASK | Title | Size | Depends on |
|---|---|---|---|
| TASK-040 | Implement iPhone-side WatchConnectivity session (05 §6.1–6.4, ADR-003) | L | TASK-031, TASK-023 |
| TASK-041 | Implement MomoWatch W1 glance + snapshot persistence + AOD (FR-17, NFR-9) | L | TASK-040, TASK-026, TASK-019 |
| TASK-042 | Implement the Watch pat (FR-17 AC-1/2, UX §6.2–6.4, 04 §6.4) | M | TASK-041 |
| TASK-043 | Implement Watch cascade + settings/haptics propagation (05 §4.8 consumer, UX-13) | S | TASK-041 |
| TASK-044 | Add sync test coverage — §10.4 matrix + device obligations (05 §10.4; CLAUDE.md §25) | L | TASK-040…043 |

## Acceptance Criteria
1. Every FR-18 acceptance criterion passes: offline pat applied exactly once (AC-1); Watch pats increment the same counters/quests as iPhone pats (AC-2); foreground-reconnect shows current state (AC-3); replay/duplicate never regresses bond or double-counts (AC-4/INV-3).
2. W1 restores from local snapshot within the ~2 s budget even after Watch termination (NFR-9, FR-17 AC-4); AOD renders the static glyph only.
3. Pat works fully offline with immediate local delight; journal survives termination; drain resumes on reachability.
4. Erase-all-data reset marker propagates to the Watch (completes TASK-038's cross-epic AC).
5. Paired-device WC delivery obligations verified and recorded (05 §10.4; CLAUDE.md §25 — never claimed from simulators alone).

## Test Requirements
- project.md §32 **Synchronization matrix (complete)** per 05 §10.4: iPhone→Watch context re-render; Watch→iPhone intent application; disconnection; stale data; conflict (latest-wins + watermark); termination/relaunch; epoch-reset flows.
- `MomoWatchUITests`: pat flow, journal persistence, restore-timing assertion, AOD rendering.
- Core/Kit exactly-once properties over duplicate/reordered delivery streams (reused from EPIC-005).
- Paired-device session evidence recorded (R9 mitigation).

## Definition of Done
All five tasks DONE per CLAUDE.md §18; sync matrix green with device evidence; reviews APPROVED; atomic TASK-ID commits on `feature/EPIC-008-watch-sync`, pushed; epic merged to `main`; orchestrator status update. **The first vertical slice (project.md §40 Step 7) is complete at this epic's end.**

## Status
TODO
