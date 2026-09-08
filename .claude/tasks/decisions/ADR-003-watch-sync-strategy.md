# ADR-003 — Watch Sync Strategy: WatchConnectivity, iPhone-Authoritative, Idempotent Intents

## Status
PROPOSED — under review (TASK-006). Becomes ACCEPTED upon REVIEW-TASK-006 approval. Implements TASK-002 D5 (conflict principle; mechanism delegated to this ADR) and D6 (Phase 1 transport; VERIFY-AT-BUILD carried).

## Context
Phase 1 requires "reliable synchronization" (§27) with the Watch valuable independently (§2, §12, §44), while the iPhone is the authoritative pet state (§21). The §32 sync matrix demands disconnection, staleness, conflict, and termination/relaunch coverage; FR-18 demands an offline Watch pat apply exactly once (AC-1), tick the same counters as iPhone pats (AC-2), and never surface a sync error (AC-4); FR-20 AC-5 forbids any cloud. Background delivery is not immediate and `updateApplicationContext` delivers only the latest snapshot (TR1). The review resolved the principle (D5: queued, idempotent intent events) and delegated the mechanism here.

## Decision
**WatchConnectivity is the sole Phase 1 transport (VERIFY-AT-BUILD as the current-generation-blessed mechanism), with one mechanism per direction:**
- **iPhone → Watch:** `updateApplicationContext` carrying the latest `WatchSnapshot` (DisplayState + quest-cascade inputs + haptics flag + `lastAppliedEpoch` + `lastAppliedIntentSeq` watermark). Latest-wins; delivered even when the counterpart app is suspended.
- **Watch → iPhone:** pats journal locally (append-only NDJSON) and drain via `transferUserInfo` (reliable queued delivery); `sendMessage` is a best-effort immediacy optimization only — the journal path is the correctness path.
- The Watch runs **no engine**. It renders the snapshot through pure derivations (band words, §5.5 cascade) and queues pat intents. All bond/counters/quests are computed on the iPhone exactly once.
- **Idempotency, two independent guards:** intent UUID set retained on the iPhone (plus monotonic per-Watch `watchSeq` vs the snapshot's `lastAppliedIntentSeq` watermark, scoped per `watchSessionEpoch` — a reset/re-pair epoch re-initializes its watermark at 0; normative semantics in 05 §6.4), which also prunes the journal, epoch-matched only. Duplicates, replays, and redeliveries are no-ops.
- **No cloud, no merge:** the only Watch-originated writes are commutative, additive, idempotent pat events, so the D5 conflict problem is dissolved by construction — there is no concurrent-edit conflict to resolve and bond cannot regress on either device.

Full spec including the no-iPhone / paired-but-away / erase-propagation cases: 05-technical-architecture §6.

## Alternatives Considered
- **iCloud/CloudKit (SwiftData+CloudKit or CKSyncEngine):** rejected for Phase 1 per D6/K7 — no requirement exists that a paired link fails to satisfy, and it would add a network dependency, account semantics, and privacy surface to a "Data Not Collected" product. Phase 2 decision with a written justification gate (D6).
- **Shared storage (app group) as the sync medium:** rejected — Watch and iPhone app-group containers are not shared across devices (TR4's misconception); only DTOs can travel.
- **`transferUserInfo` in both directions:** viable but abandons the purpose-built latest-wins context mechanism; two mechanisms each doing one job is plainer and coalesces better.
- **Custom BLE/NetworkFramework link:** reimplementing WatchConnectivity badly — rejected without serious consideration.

## Consequences
- FR-18 AC-1/2/4 hold by construction (exactly-once application; same counters; no error surface exists to show). AC-3 ("next sync opportunity") is honored by design: background delivery is never assumed immediate, and no freshness indicator exists anywhere (UX-9).
- The Watch works fully offline forever (FR-17 AC-2/3): last snapshot renders instantly from local storage (persisted on every background transition, NFR-9); pats always work and queue.
- Honest limits, documented: background delivery latency is system-scheduled (tested within a foreground reconnect, not asserted immediate); a Watch offline at erase time keeps its local snapshot until the next sync (§11.3).
- VERIFY-AT-BUILD obligations at EPIC-002: current delivery behaviors (background latency, context coalescing/launch delivery, any required background capability declaration) and on-device WC frame-delivery tests — unit tests cannot certify the transport (§25).

## Date
2026-09-08
