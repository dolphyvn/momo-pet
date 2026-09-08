# Momo — Technical Architecture (Step 5)

| | |
|---|---|
| Task | TASK-006 — Step 5: Technical Architecture (project.md §40 Step 5, §30 items 17–21) |
| Date | 2026-09-08 |
| Inputs | `project.md`, `docs/product/01-product-review.md` (D1–D20), `docs/product/02-mvp-prd.md` (normative), `docs/design/03-ux-architecture.md` (UX-1–UX-14), `docs/design/04-character-system.md` (§9 engine contract normative), `ADR-001` (Direction C — Round Rabbit, closed) |
| Status | DRAFT — pending independent review (CLAUDE.md §10) |
| Scope | Phase 1 implementation architecture + Phase 2 **reservations only** (strategy level; no Phase 2 code, targets, or entitlements are designed or built in Phase 1) |
| Authority | The PRD is the normative product source; 04 §9 is the normative engine↔character contract; the TASK-006 task-file "Intake Obligations" are binding. Where this document adds engineering specifics (store format, transport mechanisms, engine constants), they are the binding implementation contract and are recorded as ADRs. |

**Normative language.** MUST/SHOULD/MAY as in the PRD. Engine quantities labeled *(starting value)* implement PRD directions verbatim and are engine-owned tunables; PRD **normative** numbers may only change via PRD revision. Items labeled **VERIFY-AT-BUILD** are Apple-API or hardware claims that MUST be re-verified against current official documentation at EPIC-002 bootstrap (project.md §21; 2026 fall OS churn is a known hazard — nothing is asserted from memory alone).

---

## 0. Decision Index

| # | Decision | ADR | Section |
|---|----------|-----|---------|
| 1 | Local-first persistence = plain Codable atomic file store with generational recovery; not SwiftData | ADR-002 | §5 |
| 2 | Sync = WatchConnectivity: `updateApplicationContext` (iPhone→Watch snapshot) + `transferUserInfo` (Watch→iPhone intent queue); iPhone authoritative; idempotent intent events; no cloud | ADR-003 | §6 |
| 3 | Pet State Engine = pure deterministic core; event-driven catch-up evaluation (no background timers); injected clock + seeded RNG; handshake protocol per 04 §9 | ADR-004 | §4 |
| 4 | Module packaging = local Swift Package (`MomoCore`, `MomoCharacter`, `MomoKit`) + two app targets; enforced purity boundary; zero external dependencies | ADR-005 | §2 |
| 5 | Deployment targets pinned at EPIC-002 bootstrap to the current shipping OS generation; N-1 evaluated at release only | ADR-006 | §2.4, §12 |
| 6 | Animation runtime = SwiftUI-native parametric vector rig (ratifies 04 §8.2; no new decision) | ADR-007 | §2.2 |
| 7 | Satiety window = 90 min (window value PRD-delegated), three satiety phases (0–30 min "full" refusal; 30–90 min "recently fed" nibble — proposed response class, I-2/OPEN-5, pending owner confirmation) | — (engine-owned tunable; value PRD-delegated, response classes PRD-owned) | §4.5 |
| 8 | Play-round effects applied at the single instant the round ceases (confirm 04 §9.6 item 4) | ADR-004 | §4.7 |
| 9 | Interactions during settling **decline warm, never queue** (confirm 04 §9.6 item 8) | ADR-004 | §4.7 |

---

## 1. System Context

Phase 1 is a two-device, fully offline system with exactly one outbound channel: the paired-device link. Everything else is on-device. The diagram is the complete trust and data boundary.

```
                       ┌────────────────────────┐
                       │          User          │
                       └───────┬───────┬────────┘
                    touch/taps │       │ raise wrist / pat
                               ▼       ▼
        ┌──────────────────────────┐   ┌──────────────────────────┐
        │  iPhone app  (Momo)      │   │  Watch app  (MomoWatch)  │
        │  ─────────────────────   │   │  ──────────────────────  │
        │  • Pet State Engine      │   │  • Snapshot display      │
        │    (ONLY engine host)    │   │    + quest cascade       │
        │  • Authoritative store   │──►│    (pure derivation)     │
        │  • Home / Room / Settings│   │  • Pat intent journal    │
        │  • Character (full rig)  │◄──│  • Character (LOD rig)   │
        └───────────┬──────────────┘   └───────────┬──────────────┘
                    │ write-through snapshots      │ local snapshot +
                    ▼                              │ journal files
        ┌──────────────────────────┐               ▼
        │  Local file store        │   ┌──────────────────────────┐
        │  (Codable, atomic,       │   │  Watch local store       │
        │  generational recovery)  │   │  (snapshot + journal)    │
        └──────────────────────────┘   └──────────────────────────┘
                 iPhone ◄───── WatchConnectivity ─────► Watch
                 (paired-device link ONLY; latest-wins snapshot →,
                  queued idempotent intent events ←; no cloud)

  Phase 2 EXTENSION POINTS (reservations — §7, §8, §9; nothing ships in Phase 1):
   [WidgetKit extension]  → reads snapshot/DisplayState via app-group container
   [HealthKit reads]      → ActivitySource port → DailyProgress.steps (read-only)
   [UserNotifications]    → local scheduling only, governor + quiet rules

  HARD BOUNDARIES (all phases unless the owner explicitly approves):
   ✗ no cloud backend, no network traffic beyond the paired link (FR-20 AC-1)
   ✗ no analytics/telemetry SDKs, no third-party SDKs of any kind (D7, FR-20)
   ✗ no location permission ever without owner approval (D19/E3)
   ✗ no HealthKit, no notifications, zero system permissions in Phase 1 (UX §8.1)
   ✗ no monetization code paths (D8)
```

Key context facts the rest of this document relies on:

1. **Single engine host.** The Pet State Engine runs on the iPhone only. The Watch never evaluates pet dynamics; it renders a received snapshot through pure derivations (band words, cascade) and queues pat intents. This is D5 ("iPhone authoritative") made structural — the conflict-handling problem is dissolved by construction (§6.5).
2. **Zero permissions, zero entitlements in Phase 1** (UX §8.1). No app groups, no push, no HealthKit, no background modes. The only background activity is the system-delivered WatchConnectivity transport (§6).
3. **Phase 2 reservations** (§7–§9) name the extension points and the Phase 1 decisions that keep them cheap (DisplayState read-model, DTO-based sync, additive store schema). They introduce no Phase 1 code.

## 2. Module Architecture

### 2.1 Targets

| Target | Kind | Owns | Depends on |
|---|---|---|---|
| `Momo` | iOS app (SwiftUI) | Presentation (S1–S6, M1–M3), engine host + evaluation scheduling, WatchConnectivity iPhone-side session, haptics, settings UI | MomoCore, MomoCharacter, MomoKit |
| `MomoWatch` | watchOS app (SwiftUI, single-surface W1) | Snapshot display, cascade rendering, pat capture + intent journaling, WC Watch-side session, LOD character, AOD static glyph, haptics | MomoCore, MomoCharacter, MomoKit |
| `MomoCore` | SPM target | Domain types, Pet State Engine (pure), quest generator + cascade, DisplayState + CharacterDisplayState derivations, seed derivation, day-ledger logic. **Foundation-only imports.** | (none) |
| `MomoCharacter` | SPM target | Rig (04 §2.2), CharacterClock (04 §9.5), idle sequencer (04 §5, pure files), LOD tiers (full / LOD-glance / glyph), Reduce Motion pose mapping | MomoCore, SwiftUI |
| `MomoKit` | SPM target | SnapshotStore (§5), intent journal + watermarks (§6), WatchSnapshot DTO encode/decode, settings persistence, day-ledger pruning | MomoCore |

```
┌──────────────┐   ┌──────────────┐
│ Momo (iOS)   │   │ MomoWatch    │      app targets — SwiftUI, platform glue
└──────┬───────┘   └──────┬───────┘
       │ import           │ import
       └────────┬─────────┘
                ▼
   ┌─────────────────────────┐
   │ MomoKit                 │   persistence + sync DTOs
   └───────────┬─────────────┘
                ▼
   ┌─────────────────────────┐      ┌─────────────────────────┐
   │ MomoCore (pure)         │◄─────│ MomoCharacter           │
   │ domain · engine · quest │      │ rig · clock · sequencer │
   │ generator · DisplayState│      │ (SwiftUI transforms)    │
   └─────────────────────────┘      └─────────────────────────┘
```

Phase 2 reservation: a future `MomoWidgets` extension target would import MomoCore (DisplayState + cascade) and MomoKit (app-group snapshot read path) — no new derivation would be written (§8).

### 2.2 Character runtime (ratified, not re-decided)

The animation runtime is the **SwiftUI-native parametric vector rig** decided by TASK-005 (04 §8.1–8.2): transform-only motion on pre-built layers, repo-local generated `Path` constants, zero runtime dependencies. This document adds only its placement: the rig, CharacterClock, and LOD tiers live in `MomoCharacter` so the full rig (iPhone), LOD-glance (Watch foreground), and glyph (AOD/future complications) compile once and are consumed by both app targets. The idle sequencer (04 §5) lives here as pure Foundation-only files (parameter tables + schedule function) so its determinism is testable headlessly; the engine only derives and injects the day-stable seed (04 §9.4) and never owns choreography. Recorded as ADR-007 (ratification).

### 2.3 Dependency rules (enforceable)

| # | Rule | Enforcement |
|---|---|---|
| D-R1 | `MomoCore` imports only Foundation (no SwiftUI/UIKit/WatchConnectivity, no third-party packages) | Package target definition; compiles and unit-tests on macOS via `swift test` — a macOS build catches platform-unavailable imports (UIKit, WatchKit, WatchConnectivity, HealthKit) but NOT SwiftUI, which compiles on macOS; that residual is closed at build time by an import-whitelist scan in the test target (§10.2), with SwiftUI-residue on the standing review checklist (project.md §31). This is the project's purity guarantee for FR-13 AC-3 determinism. |
| D-R2 | `MomoKit` and `MomoCharacter` depend only on `MomoCore` (never on each other, never on app targets) | Package graph; review check |
| D-R3 | App targets never import each other; all shared state flows through MomoKit DTOs over the WC transport | No target dependency between `Momo` and `MomoWatch`; review check |
| D-R4 | No third-party package dependencies anywhere (FR-20 AC-3 "no third-party SDKs") | Empty `dependencies:` in Package.swift; CI/review check |
| D-R5 | Views contain no engine logic; the engine is invoked only through the app model's evaluate/apply facade | Review gate (project.md §31); the pure core makes violations visible in review |
| D-R6 | The engine never imports persistence or sync; it consumes and produces value types only. Persistence and sync adapt around it | Type-level: engine signatures take/return `Sendable` value types only (ADR-004) |

Rationale for packages over folders-in-one-target: D-R1 must be *machine-enforced*, not conventional — it is what makes "deterministic where tests require" (§23) auditable. Two SPM targets (Core vs everything else) is the minimum boundary that buys that; a single mega-module would make the purity rule review-enforced only. **Alternatives considered:** single app target with folder groups (rejected — no enforcement, no headless engine tests); multiple Xcode framework targets (rejected — heavier build config for the same result; SPM is the current-native mechanism, VERIFY-AT-BUILD for project-template details at bootstrap). ADR-005.

### 2.4 Deployment targets (D15 — explicit choice)

**Policy implementation:** at EPIC-002 bootstrap, pin the minimum deployment targets to the **current stable shipping OS generation** ("support current; consider N-1"). As of this document (2026-09) the shipping generation is iOS 26 / watchOS 26; Apple's fall 2026 releases are imminent or fresh at build time, so the pinned numbers are set at bootstrap and expected to be **iOS 26 / watchOS 26 or their then-current successors** — **VERIFY-AT-BUILD**, asserted from memory of no specific OS. Consequences and justification:

- The app's framework floor is low by design: no SwiftData (ADR-002 removes that floor), no widgets/HealthKit/notifications (Phase 2), a Codable store, and SwiftUI + Observation as the only modern requirements. This makes a current-generation pin nearly free of availability shims — the simplest configuration (§22).
- **N-1 is a deliberate non-commitment**, re-evaluated once at release planning (TASK-007): widening is a build-setting change plus a device-matrix expansion, cheap to do later if release review wants the reach. The watchOS pairing matrix (iOS ↔ watchOS version compatibility) also stays simplest under current-only — **VERIFY-AT-BUILD** for the current pairing rules.
- All API availability claims in this document inherit this policy: nothing is claimed available below the pinned floor; every version-sensitive claim is VERIFY-AT-BUILD.

## 3. Domain Model

Normalized from project.md §24 per the review's warning (C5: model Phase 1 fields only; future fields are extension points, not present-but-empty columns). All types are **value types (`struct`/`enum`), `Sendable`, immutable-by-convention** — the engine produces new state, nothing mutates shared state across targets (§31 "avoid global mutable state"; intake rule on immutability). Swift-shaped sketches below are **interface definitions, not implementation** (same standing as 04 §9.2).

### 3.1 Types

```swift
// — Pet identity —
struct Pet: Equatable, Sendable {
    let id: UUID              // stable; generated at onboarding Enter
    var name: String          // invariant INV-1: trimmed, non-empty
    let createdAt: Instant    // UTC (D20)
}

// — The three dimensions (PRD §3; bands are DERIVED, never stored) —
struct PetState: Equatable, Sendable {
    var mood: Double          // 0...100   (INV-2)
    var energy: Double        // 0...100   (INV-2)
    var bond: Int             // 0...1000  (INV-3 monotonic)
    var wakefulness: Wakefulness   // .awake .settling .asleep .waking
    var activity: Activity?        // .eating .playing .napping
    var lastFedAt: Instant?        // satiety clock (§4.5)
    var satietyPhase: SatietyPhase  // derived at evaluation; stored for render
}

enum MoodBand: Sendable { case joyful, content, wistful, low }       // PRD §3.1
enum EnergyBand: Sendable { case energetic, relaxed, drowsy, exhausted } // PRD §3.2
enum BondStage: Sendable { case newFriends, gettingClose, bestFriends, soulCompanions } // PRD §3.3
// makeMoodBand(_:), makeEnergyBand(_:), makeBondStage(_:) — pure functions,
// PRD §3 tables are the single source of truth (property-tested over the range).

// — Per-local-day record (7-day retention, §5.4).
// Named DayRecord here; ≡ project.md §24's DailyProgress (§7's DailyProgress.steps extends it in Phase 2).
struct DayRecord: Equatable, Sendable {
    let dayKey: String             // "YYYY-MM-DD" in the user's local calendar (D20)
    var feedCount: Int             // didSet-free; ≥ 0 (INV-4: counters monotonic within a day)
    var playCount: Int
    var careCount: Int
    var patCount: Int
    var questSet: [QuestProgress]  // exactly 3 (FR-14/15); generated once, persisted
    var helloAwarded: Bool         // once per day, either device (UX-6)
    var familiesUsed: Set<QuestFamily>   // feed/play/care — variety bonus input
    var bondAwarded: Int           // 0...20 (INV-5 daily cap)
    var questGenEpoch: Int         // generator version that produced questSet
}

struct QuestProgress: Equatable, Sendable {
    let questID: QuestID           // Q1...Q7 (PRD §5.2 catalog, static data)
    var progress: Int              // ≤ target (INV-6)
    var completed: Bool            // automatic on target (FR-16); never un-completes
}
// QuestCatalog: static table — id, family, target, window (Q1 <12:00; Q6 20:00–07:00; rest all-day)

// — Interactions (intents; from iPhone UI or Watch sync) —
struct InteractionIntent: Sendable {
    let id: UUID                   // idempotency key (FR-18 AC-1)
    let source: Source             // .iPhone / .watch
    let localDayKey: String        // attributed day = calendar day of its timestamp (D20, Q6 rule)
    let timestamp: Instant         // UTC
    let kind: Kind
    enum Kind: Sendable {
        case pat(gesture: PatGesture, zone: TouchZone?)   // Watch sends .pat(.tap, nil)
        case feed
        case play                                         // requests a round
        case tuckIn
        case nap
    }
}

// — Settings (Phase 1 per FR-19 + 04 §11: NO sound toggle, NO audio) —
struct SettingsState: Equatable, Sendable {
    var onboardingComplete: Bool   // written atomically at Enter tap (UX S3)
    var hapticsEnabled: Bool       // syncs to Watch in the snapshot (UX-13)
}
```

**Room** is deliberately **not a domain entity** in Phase 1 (D13/K4: static scene). It exists as an asset + view only; no persisted model, no state. Recorded here so the §22 domain list and §24's example are accounted for honestly rather than silently dropped. Extension point: Phase 3 room customization would introduce a `RoomState` value type persisted in the same store — no Phase 1 preparation beyond this sentence (§22/K2/K4).

### 3.2 Invariants (testable; each maps to the test targets in §10)

| # | Invariant | Source |
|---|---|---|
| INV-1 | Pet name is non-empty after trimming (whitespace-only rejected at input) | FR-1, UX S2 |
| INV-2 | mood, energy ∈ 0...100 at every persisted transition | PRD §3.1–3.2 |
| INV-3 | bond is monotonic non-decreasing across ALL mutations, including sync application and intent replay; ∈ 0...1000 | FR-10 AC-2, D3 |
| INV-4 | day counters ≥ 0 and monotonic within a dayKey | FR-6 AC-3, §4 |
| INV-5 | sum of bond events per dayKey ≤ +20, by clamp-at-award (§4.6) | PRD §3.3 cap, FR-10 AC-1 |
| INV-6 | quest progress ≤ target; completed ⇒ target met; completion never reverses | FR-16, TR5 (retroactive tolerance note, §7) |
| INV-7 | hello awarded at most once per dayKey, device-agnostic, never window-gated | UX-6, intake |
| INV-8 | Wakefulness machine makes only legal transitions (§4.7 diagram) | 04 §4.1 rule 4 |
| INV-9 | All persisted timestamps are UTC instants; `dayKey` is derived, never stored as a timezone-dependent date type | D20, FR-11 AC-4 |
| INV-10 | An intent's effects are applied exactly once — replay/duplicate delivery is a no-op (intent UUID set + per-epoch watermark, §6.4) | FR-18 AC-1 |
| INV-11 | Engine outputs carry no composed user-facing strings — only catalog keys from the approved namespaces (§4.9) | FR-12 tone guardrails |

## 4. Pet State Engine

ADR-004 records the decision set summarized here. Division of authority follows 04 §9.3 exactly: **the engine owns *what* and *when* (state, gating, numeric effects, windows, resets); the character owns *how it looks*; the presentation layer owns *whether it runs* (pause).** The engine never animates, never pauses (§4.1/§4.2), never composes prose (§4.9).

### 4.1 Shape: pure core, one evaluation entry point

```swift
// Interface sketch (MomoCore). All types Sendable value types.
struct EngineState: Sendable {          // the full persisted domain state (§3)
    var pet: Pet
    var state: PetState
    var days: [DayRecord]               // 7-day ledger, newest last
    var settings: SettingsState
    var pendingHandshake: Handshake?    // issued settle/wake/play tokens
    var processedIntents: [UUID]        // recent intent ids (≤ 64) — belt for §6.4
    var highestCelebratedStage: BondStage
    var lastOpenedAt: Instant
    var lastEvaluatedAt: Instant
}

enum EngineEvent: Sendable {
    case interaction(InteractionIntent)
    case characterReport(CharacterReport)      // 04 §9.2 vocabulary, incl. handshakeCancelled
    case evaluate(now: Instant)                // catch-up/scheduled evaluation
}

struct EngineOutcome: Sendable {
    var newState: EngineState
    var response: ResponsePlan?                // 04 §9.2 — one per interaction event
    var moments: [CharacterMoment]             // greeting / questCompleted / bondStageReached
    var changed: Bool                          // false ⇒ no persistence write, no sync push
}

// The single entry point. Pure: (state, event, clock, rng) → outcome.
func reduce(_ state: EngineState, _ event: EngineEvent,
            clock: EngineClock, rng: inout SeededGenerator) -> EngineOutcome
```

- **Purity:** `reduce` performs no I/O, no timers, no singletons, no `Date()`, no `Random()`. Clock and RNG are injected (§4.10). Identical (state, event, clock, seed) ⇒ identical outcome (FR-13 AC-3) — testable by property.
- The app model wraps `reduce` with the side effects in fixed order: apply `newState` → persist if `changed` (§5, write-through) → deliver `response`/`moments` to the character layer → push snapshot to Watch if `changed` (§6).

### 4.2 Tick model: event-driven catch-up, never a background timer

There is **no engine timer, no background task, no polling** (NFR-2: no background work beyond sync delivery; §33 battery). Time passes only when `reduce` is invoked with `.evaluate(now:)`. Triggers (all app-layer, all cheap):

| Trigger | When | What it catches up |
|---|---|---|
| Foreground / scenePhase → active | every open (iPhone only — the Watch has no engine) | full time fold (§4.3), day rollover, missed night/wake, absence greeting |
| Any interaction event | user acts | fold-to-now first, then the interaction |
| CharacterReport | handshake completes/cancels | fold-to-now, then report handling |
| Scheduled boundary evaluation | in-session only: 22:00 onset, 07:00 wake, local midnight, nap-end instant | night onset while user is watching; midnight reset; nap completion |
| Significant time change | OS timezone/clock-change notifications | re-derive dayKey, single reset guarantee (§4.4) |

Catch-up is **segment folding**: elapsed wall time since `lastEvaluatedAt` is decomposed into segments (waking hours / night windows / local-midnight boundaries / nap intervals) using the user's calendar, and each segment applies its rule once, in order. Nothing is recomputed per-minute; a 7-day absence folds in microseconds.

In-session scheduling: the app layer computes the *next* boundary instant from the folded state and schedules exactly one evaluation at that instant (a single `Task`-scheduled call or equivalent — VERIFY-AT-BUILD for the current idiomatic mechanism). If the app is backgrounded first, the scheduled call simply does not matter — the next foreground evaluation catches up. Schedulers re-schedule, never replay (matches 04 §5.3 pause discipline).

### 4.3 Time-fold rules (deterministic; PRD §3 numbers)

| Rule | Starting value / formula | PRD anchor |
|---|---|---|
| Passive energy decline, waking hours | −1.5 pts/hour *(starting value; PRD 1–2)*; none during night or nap | §3.2 |
| Night restore | From sleep onset, energy ramps linearly to **85** at 07:00; wake value clamped ≥ **75** | §3.2 (start of day 85; ≥ 75 by 07:00) |
| Mood attractor | `mood += (target − mood) × (1 − e^(−Δt/τ))`, τ = 3 h *(starting value)*; target = **60** normally | §3.1 attractor 60 |
| Energy-coupling mood pull | While energy ∈ Drowsy/Exhausted **during waking hours**, attractor target = **35**, floor 25 enforced | §3.1 |
| Day rollover | At local calendar midnight: new DayRecord generated (§4.8), counters reset, quests reset — keyed by `dayKey`, so exactly once | FR-11, D20 |
| Absence | No penalty accrues anywhere: drift targets are calm attractors; bond untouched; absent days simply get no DayRecord (silently empty, FR-12 AC-1) | D3, D4, FR-12 |

Night/morning transitions: folding past 22:00 with the app closed lands `wakefulness = .asleep` directly (no handshake — nothing is listening). Folding past 07:00 lands `.waking`, and the next in-session evaluation emits the waking stretch via handshake (§4.7) — opening the app in the morning shows the unhurried wake beat (04 §4.2).

**Clock edge cases (§32 matrix, D20):** all instants are UTC; `dayKey` is derived through the user's calendar at evaluation time. Timezone change mid-day ⇒ the derived day may change ⇒ one rollover to the new day's key; the `dayKey`-keyed ledger makes duplicate resets structurally impossible (a day is reset once, ever). DST transitions change segment arithmetic only. Manual clock changes fold like any elapsed time; backward changes re-derive an already-awarded `dayKey` and find its ledger entry present ⇒ no double hello, no duplicate reset. Each case is a named engine test (§10.3).

### 4.4 Interaction semantics (implements PRD §4 matrix + D18)

The engine evaluates every interaction against the **state** (bands + wakefulness + satiety), never against limits. There are no cooldowns, no counters that gate, no refusals with penalty (D18). Output is a `ResponsePlan` (04 §9.2) with a `ReactionID` from 04 §8.4's namespace, a `lineKey` from the copy classes (§4.9), and an optional `HapticID`.

**Counting rules (PRD letter, asymmetry deliberate — flagged as interpretation I-1 for the reviewer):**

- **Feed counts always** (FR-6 AC-3 "each feed increments feedCount"): even the politely-full refusal and the asleep gentle-decline increment `feedCount` and quest progress. The state shapes the *response and numeric effects only* — a declined meal still happened. This is the only reading under which Q3 (feed ×2) is completable in ≤ ~2 minutes (PRD §5.1 rule 2) while the satiety window stays meaningful (§4.5).
- **Play counts on round completion only** (FR-7 AC-2 "round completion increments playCount"): in Exhausted/sleeping states a play intent yields the gentle-stir response, no round starts, nothing counts. A round that never started did not happen.
- **Pat counts always**, any state, any device (stir while asleep still counts toward `patCount`/Q7; touch is never refused, FR-5 AC-2).
- **Care counts when performed**: tuck-in (in its window; blanket-adjust while asleep still counts, PRD §4) and nap increment `careCount`.

**Numeric effects — engine-owned starting values** (PRD directions; all clamped by band rules):

| Effect | Value | Multiplied by |
|---|---|---|
| Play round | energy −10, mood +6 *(starting)* | repetition curve (§4.5) |
| Feed (hungry meal) | energy +6, mood +4 *(starting)* | repetition curve × satiety phase |
| Feed (recently-fed nibble) — *I-2: proposed class, pending owner confirmation* | effects × 0.25 *(starting)* | — |
| Feed (full refusal) | zero state effect | — |
| Pet/touch | mood +2 *(starting; zero bond ever — G2)* | repetition curve |
| Tuck-in | mood +3, energy +2 *(starting)* | — |
| Nap | energy +20 over the nap *(starting)* | — |
| Mood ceiling | normal play clamps ≤ **92**; complete-quest-set and stage moments may reach top of Joyful | §3.1 |

*I-2 — proposed response class (pending owner confirmation; Appendix B OPEN-5):* FR-6's letter assigns the politely-full refusal, zero state effect, to the entire 0–90-minute "recently fed" span; the nibble row above is this document's proposal beyond that letter — surfaced, not silent (§0 #7, §4.5, ADR-004). Tuck-in and nap carry no repetition-curve multiplier because care is window/band-gated (counting rules above) — the curve's grind-protection purpose does not apply to it.

### 4.5 Satiety window — DECISION

**The window is 90 minutes, three satiety phases** *(engine-owned starting value; PRD §4 delegates the window VALUE — the response classes themselves are PRD-owned, and the 30–90-min class below is this document's proposal, flagged I-2 / OPEN-5)*:

| Phase | Since last feed | `SatietyHint` to character | Feed response class | Effects |
|---|---|---|---|---|
| Full | 0–30 min | `.full` | Politely full — the cute-refusal beat (04 §6.2 "sated sigh") | zero (counts per §4.4) |
| Recently fed | 30–90 min | `.recentlyFed` | Small contented nibble (shortened eating animation) — **I-2: proposed class, pending owner confirmation** | × 0.25 *(starting)* |
| Hungry | > 90 min | `.hungry` | Full meal | full, × repetition curve |

Justification: 90 minutes keeps the refusal beat honest (a meal is not forgotten in five minutes) yet clearable inside one ordinary return visit, so both response classes are reachable in normal use; it never gates availability (D18 — the button never changes); and since refused feeds count (§4.4, I-1), no quest window is hostage to the value. Alternatives considered: 30 min (refusal beat nearly unreachable; "full" reads as evaporated); 3 h ("recently fed" dominates daytime sessions, thinning the eating state's presence). The value is a single constant in MomoCore with this table as its spec — the window value is tunable without PRD change; changing the response-class split is PRD-owned and requires the owner's I-2 confirmation or a PRD revision.

**Same-family repetition curve** (PRD §4 starting curve, per family per local day): multipliers **1.0 / 0.6 / 0.25 / ~0** for the 1st–4th+ instance *(starting values)*. Independent of satiety: the 2nd meal of the day is softer even 2 hours later. The character's visual coalescing (04 §4.1 rule 3) is the *visual* half of FR-5 AC-3; this curve is the engine's *effect* half. Petting banks no bond at any volume (G2).

### 4.6 Bond ledger (FR-10; cap by construction)

Bond is a single cumulative integer; the *events* that may add to it are enumerated and ledgered per `dayKey`:

| Event | Bond | Engine guard |
|---|---|---|
| Daily hello | +8 | First `pat`/touch intent of the local day — **either device, idempotent, never window-gated** (UX-6): the `helloAwarded` flag on the intent's `dayKey`. A first touch at 14:00 (Q1 expired) still earns +8 exactly once. |
| Quest completed | +4 each | Max 3 quests/day by catalog construction (§4.8) |
| Variety bonus | +6 | Fired at the moment all three families are used in one day; awarded only up to remaining cap headroom |
| **Daily cap** | **+20** | Clamp-at-award: each award applies `min(event, 20 − bondAwarded)`. A 3-quest day reaches 20 via hello+quests (8+12); a 2-quest varied day reaches 20 as 8+8+4 (the +6 truncated) — PRD's own arithmetic, made explicit |

Events apply in chronological order; the clamp makes FR-10 AC-1 ("no sequence exceeds +20/day") true *by construction*, and the property test proves it over random interaction sequences. Stage derivation is a pure function of the cumulative value; crossing a threshold while the app is closed is detected at the next evaluation, which emits `momentRequest(.bondStageReached)` exactly once (`highestCelebratedStage` guard) — UX-10's deferral falls out naturally. Bond never decreases anywhere in the engine, in sync application, or in erase (erase deletes, it does not decrease) — FR-10 AC-2.

### 4.7 Wakefulness machine & handshakes (04 §9.2 contract implemented)

```
legal transitions (INV-8):
  awake ──tuckIn (20:00+) / 22:00 onset──► settling
  settling ──settleFinished──► asleep
  settling ──handshakeCancelled(.settle)──► awake          (preemption path)
  asleep ──07:00 / nap-end fold──► waking
  waking ──wakeFinished──► awake                            (never cancelled —
  awake + nap intent (Drowsy/Exhausted) ──► activity .napping  completes on return)
  napping ──elapsed / next evaluation──► waking
  any ──app hide──► (no engine involvement; presentation pauses — §4.1/§4.2)
```

**Handshakes** are event-driven on the engine side (04 §9.2): the engine sets the intermediate `wakefulness` + a `Handshake` token (kind + UUID); the character runs its choreography and reports; the engine applies the transition only on the report. Every report path is **idempotent**: reports are matched by token; a late, duplicate, or stale report (arriving after a newer state change) is accepted and applied or discarded without stranding — the engine is never left waiting on a report that will never come, because **`handshakeCancelled(HandshakeKind)`** is the cancellation path for every preemption (character preempted mid-settle, app-hide before a round completes, newer L2 replacing settling). The `.wake` kind exists for contract totality though waking is expected never to cancel (04 §9.2).

**Play rounds.** Authorization sets `activity = .playing` + a round token; the character paces the round within the ≤ 30 s bound (04 §6.3). **Play effects (energy −10, mood +6 × curve, `playCount` +1, quest tick) are applied at the single instant the round ceases — completion (`playRoundFinished`) or preemption (`handshakeCancelled(.play)`) — keyed by the round token so the unified application point is idempotent.** This **confirms** 04 §9.6 item 4's single-instant proposal: backgrounding mid-round and interaction-preemption become one deterministic case, and a force-quit mid-round loses at most the un-applied round (≤ 1 s state rule, FR-13 AC-1, is about *applied* state; an in-flight round applies on the next report — and if the app is force-quit before any report, the round simply never happened, which is a warm, harmless outcome).

**Interactions during settling — CONFIRMED as decline-warm (04 §9.6 item 8).** Feed → gentle sleepy decline; play → declined warm (no round); touch → soft stir. **Nothing queues until wake.** Rationale: queueing user-visible actions across a 2.5–3.5 s animation creates hidden deferred execution ("I tapped feed and it ate after waking") — surprising, and it adds a pending-intent machine for zero product value. A warm decline keeps causality legible and calm. The engine emits the declined `ResponsePlan` immediately; `handshakeCancelled(.settle)` still exists for the UI-preemption path and is tolerated idempotently. Naps are not offered during settling (care chips follow the §4 matrix offerings).

**Interactions during waking — declined warm (symmetric with settling; confirms the waking half of 04 §9.6 item 8).** A feed/play/touch arriving during the ≤ 2.5 s waking stretch is declined warm — the declined response references the **post-wake state** (the engine evaluates it against the state `wakeFinished` produces), never a queue. Waking is too short to make deferral legible, and no pending-intent machine is added for it; the engine contract is total over `.waking` — every interaction has a defined `ResponsePlan` in every wakefulness.

### 4.8 Quests: generation by construction + Watch cascade

**Daily set generation** (FR-15, PRD §5.3): a pure function `generate(dayKey, seed, priorTwoSets, questGenEpoch) -> [QuestProgress]`.

- Candidates: the 15 pairs drawn from {Q2…Q7} (+ mandatory Q1 anchor).
- Constraints applied **before** drawing, i.e., by construction: remove the pair equal to yesterday's pair (consecutive-repeat ban); if the rolling 3-day window lacks Q6 (checking the two prior sets — unknown priors count as "no Q6 credit", so day 1 of a fresh install always includes Q6, the evening anchor), restrict to the 5 pairs containing Q6. The post-filter candidate space is never empty (≥ 4 pairs in the tightest case) — provable, and unit-tested.
- The set is drawn with the seeded RNG (deterministic given inputs), stored on the DayRecord with `questGenEpoch` at first access of that day, and never regenerated for a past day. The 30-day simulation (FR-15 AC-2) is a sanity test; the by-construction argument above is the proof.
- Window checks at completion time: Q1 ticks only if local time < 12:00; Q6 only inside 20:00–07:00; attribution always to the intent's `dayKey` (Q6's 00:00–07:00 tail belongs to the new day — D20 day-ownership, PRD §5.1 rule 6). **Window checks evaluate the interaction's own local timestamp — consistent with `dayKey` attribution — never the application instant** (an 11:30 offline pat applied at 12:30 ticks Q1).

**Watch quest cascade** (PRD §5.5 — one shared pure function in MomoCore; the Watch renders its output; Phase 2 widgets reuse it, §8):

1. Q6, if in today's set ∧ incomplete ∧ **local time ≥ 20:00**;
2. else Q1, if local time < 12:00 ∧ incomplete;
3. else first incomplete feed-family quest (catalog order Q2 → Q3);
4. else first incomplete play-family quest (Q4 → Q5);
5. else Q7, if in today's set ∧ incomplete;
6. else the all-complete state ("All done — see you soon").

> **PRD FIX CANDIDATE — §5.5 rule 1 gap (flagged to the owner, per intake; NOT silently re-interpreted).** Rule 1 triggers on `local time ≥ 20:00`, but Q6's window is 20:00–07:00. In the 00:00–07:00 tail — e.g., a 02:00 tuck-in with Q1 already complete — rule 1 is false, and the cascade can select a daytime wish (e.g., "playtime") while Momo is asleep and Q6 is open, incomplete, and in-set. **Suggested one-line fix:** rule 1 becomes "Q6, if in today's set ∧ incomplete ∧ local time ∈ Q6's window (≥ 20:00 ∨ < 07:00)". **Phase 1 implements the PRD's letter as written above**; the cascade carries a named unit test documenting the letter's behavior, marked to flip when the PRD is revised. Escalated as a documentation fix — no product behavior is changed unilaterally.

### 4.9 Copy selection & tone constraints (FR-12 bound at the type level)

- The engine **composes no sentences**. It selects keys from exactly three catalog namespaces (04 §10.4): `momo.line.<slot>.<nn>` (visual body copy: morning/day/evening/night/greeting/care-moment), `momo.line.react.<family>.<nn>` (VoiceOver-only reaction lines, UX-8), `momo.line.moment.<nn>` (M2 stage banner, M3 all-done). Slot selection is by local-time window; within a slot, day-stable seeded pick (§4.10) — day-stable within a day, seeded across days (§8).
- Line selection is a pure function of (dayKey-seeded RNG, slot, context). App targets resolve keys via String Catalogs (D12; FR-20 AC-4 — no string literals in views; MomoCore stays locale-free by holding keys only).
- **OBS-2 resolution:** the 12-word max of the tone guide's rule 2 (04 §10.1) is scoped to the **visual body-copy classes** (`momo.line.<slot>`); the M2 stage banner (`momo.line.moment`) is exempt because it structurally carries the PRD-normative stage name + descriptor line.
- **OBS-1 resolution:** the VoiceOver formula is 04 §3.5's — "{Name} feels {mood word} and {energy phrase}" + stage sentence — with its vocabulary map (Wistful announced as "quiet"; energy verb phrases). `DisplayState` carries the resolved word/phrase **keys**; the a11y formatter renders the formula from the catalog. 03:428's literal template is superseded by 04 §3.5 per the intake.
- **Guilt is structurally impossible:** the engine's only string outputs are keys into curated pools; a static test scans the String Catalogs against 04 §10.2's banned-vocabulary list (forgot, lonely, sad, hurry, don't forget, streak, …) and fails the build on a hit (§10.2).

### 4.10 Clock & randomness (injectable; §23, FR-4 AC-1, FR-13 AC-3)

- **Clock:** a minimal `EngineClock` protocol (`now() -> Instant`) in MomoCore; production uses the system clock (Swift `Clock` where idiomatic — VERIFY-AT-BUILD for current-concurrency shapes), tests use a manually-advanced test clock. Every engine time read goes through it.
- **RNG:** a repo-owned seeded generator (SplitMix64-class, ~20 lines, no dependency) conforming to `RandomNumberGenerator`, injected as `inout`. Never system randomness inside the engine or the sequencer.
- **Day-stable seeds:** `seed = SHA-256(petID ‖ localDayKey ‖ epoch ‖ salt)` truncated to 64 bits. Salts: `choreography` for the idle sequencer (epoch = `choreographyEpoch`, changes only when the idle-variant catalog changes — 04 §5.1: day-stable personality, day-to-day variation, FR-4 AC-1), `copy` for line picks, `quest` for set generation. SHA-256 is standardized and stable across OS versions and devices — same day ⇒ same seed on iPhone and in tests. The engine derives these; the character consumes the choreography seed and never calls system randomness (04 §9.4).

### 4.11 Read-models — DisplayState + CharacterDisplayState (one read-model per consumer family)

Per UX §7's reservation, pure derivations in MomoCore — one read-model per consumer family: `DisplayState` for surfaces, `CharacterDisplayState` for the character (04 §9.2):

```swift
struct DisplayState: Equatable, Sendable {
    let petName: String
    let moodWordKey: String          // catalog keys (04 §3.5 vocabulary: joyful/content/quiet/low)
    let energyPhraseKey: String      // "has plenty of energy" / "is relaxed" / "is getting sleepy" / "is very sleepy"
    let bondStage: BondStage
    let bondDescriptorKey: String
    let questLine: QuestLine         // cascade output (§4.8): wish key or .allDone
    let wakefulness: Wakefulness     // pose context for the character
    let greeting: CharacterMoment.GreetingKind?  // freshMorning / welcomeBack / missedYou / nightGlance
}
func makeDisplayState(_ s: EngineState, at now: Instant, calendar: Calendar) -> DisplayState

// Character-facing read-model for 04 §9.2's engine→character interface:
// moodBand, energyBand, activity, satietyHint, wakefulness, momentRequest.
// Same purity discipline; CharacterDisplayState's shape is owned by 04 §9.2.
func makeCharacterDisplayState(_ s: EngineState) -> CharacterDisplayState
```

Consumed by: Home status row + VoiceOver formula (iPhone), W1 glance (Watch), and — Phase 2 reservation — widget timeline entries (§8). Words-not-numbers is portable, tone-checked once, and the Watch snapshot (§6) carries exactly this shape plus the quest-progress inputs the cascade needs. `makeCharacterDisplayState` is the character family's counterpart — the fields the full rig consumes per 04 §9.2 — so no consumer derives its own view of engine state.

## 5. Persistence (ADR-002)

**Decision: a plain Codable file store with atomic writes and generational recovery. Not SwiftData.** (Implements D14; the review itself flagged SwiftData as possibly more machinery than a one-pet data volume needs — TR4.)

### 5.1 Rationale

The entire Phase 1 dataset is one pet: a few KB of value types (§3). What the requirements actually demand is *behavioral*: atomic saves (NFR-7), force-quit loss ≤ 1 s (FR-13 AC-1), corruption recovery to the last valid snapshot (FR-13 AC-2), migration on upgrade (NFR-7), and testability. A file store delivers all five **by construction**: write-temp-then-atomic-rename is atomic; write-through per engine event bounds loss to the in-flight event; generational retention makes recovery explicit and testable; `schemaVersion` + explicit migration functions make upgrades auditable; and encode/decode tests run headlessly on macOS in milliseconds. SwiftData buys a query layer, relationship management, and (Phase 2) CloudKit plumbing — none of which Phase 1 uses at this volume, while its store semantics (atomicity exposure, corruption behavior, background writes) would sit *inside* the exact guarantees FR-13 makes, forcing us to build our own snapshot layer around it anyway. Sync transfers DTOs regardless (TR4), so SwiftData's model layer adds nothing to §6. If Phase 2 approves iCloud, the store sits behind one narrow protocol and the SwiftData-vs-Custom question is re-opened then with real requirements — recorded in ADR-002 as the revisit gate, not silently deferred.

**Alternatives considered:** SwiftData (rejected above); UserDefaults (rejected — property-list size semantics, no generational control, and a required-reason API under privacy manifests — VERIFY-AT-BUILD — for zero benefit); Core Data (rejected — strictly more machinery than SwiftData for less type safety); SQLite direct (rejected — no query needs). 

### 5.2 Store design

```
Application Support/Momo/
├── state.json            ← current generation (envelope + payload)
├── state.prev.json       ← generation N−1
├── state.prev2.json      ← generation N−2
```

Envelope: `{ schemaVersion, savedAt (UTC), checksum (SHA-256 of payload JSON), payload }`. Write path per engine event that changed state: encode payload → compute checksum → write temp file → atomic rename onto `state.json`, demoting the previous generation down the chain. The dataset is KB-scale, so a synchronous-enough write per event is far inside budgets; writes are serialized on a dedicated queue/actor so ordering is total; the main thread never blocks on I/O beyond launch's initial read (a KB-scale JSON decode, milliseconds — inside the 2 s launch budget, §12). iOS default file protection applies (NSFileProtectionComplete — VERIFY-AT-BUILD that it stays compatible with Phase 2's app-group widget read path, which would need `CompleteUntilFirstUnlock` for timeline builds; a Phase 2 enumerated change, §8).

### 5.3 Corruption & recovery stance (invisible, per UX §9)

Read path at launch: try `state.json` → verify checksum + decode → on failure try `.prev` → `.prev2` → regenerate a fresh default state. **No dialog, no copy, no error surface ever** (UX §9: "indistinguishable from a normal open"); the worst case is a pet showing a slightly older state — bounded by the write-through cadence (one event), satisfying FR-13 AC-2's "worst case ≤ last snapshot interval" with interval = 1 event. Total loss of all three generations (catastrophic disk failure, out of scope for "a bad write") regenerates a fresh pet — honest limit, documented here; bond regeneration is then necessarily zero, and no surface announces anything. The intent ledger (§4.1 `processedIntents`) travels inside the payload, so intent idempotency survives recovery.

### 5.4 Retention & pruning

Day-ledger retention is **7 days** of `DayRecord`s (pruned at each rollover). That window simultaneously serves: the rolling 3-day quest-generation window (§4.8), late Watch-intent attribution to their own day (§6.4), and clock-change safety (dayKey-keyed once-only resets, §4.3). `processedIntents` is capped (≤ 64 recent). All pruning is deterministic and unit-tested.

### 5.5 Migration policy (NFR-7, §32 "upgrade" edge)

- **Additive evolution is the norm:** new optional/defaulted fields decode with defaults — no migration function, old files load forward. This is the expected path for Phase 2's `DailyProgress.steps` (C5: extension point, not a present-but-empty column).
- **Breaking changes** bump `schemaVersion` and register an explicit `migrate(v→v+1)` function; the read path walks the chain. Migrations are pure, total (no failure path — worst case maps to a valid default), and unit-tested **in both directions of the §32 requirement: fresh-install path and upgrade path** produce identical behavior afterwards.
- Migration is invisible to the user (UX §9 row: "Migration invisible; state preserved").

### 5.6 Watch-side stores

The Watch persists: `watch-snapshot.json` (+ one `.prev`) — the last received WatchSnapshot, written on every receive and on every background transition (NFR-9/TR9: raise-to-wake renders from the local file, never a cold engine call; restore well under the ~2 s intake bound, §12); and `intent-journal.ndjson` — the append-only pending-intent queue (§6.4), pruned by the epoch-matched watermark. The Watch store also persists `watchSessionEpoch` (generated at Watch app first launch; regenerated on reinstall / re-pair / new Watch — §6.2, §6.4). Watch-side recovery is simpler than iPhone-side: the snapshot is reproducible from the iPhone at next sync, so an unrecoverable Watch store degrades to the "settling in" line (UX §9) — invisible, warm, self-healing.

## 6. iPhone ↔ Watch Synchronization (ADR-003)

**Decision: WatchConnectivity is the sole transport** (D6 default direction — VERIFY-AT-BUILD as the current-generation-blessed mechanism at bootstrap), with one mechanism per direction and no cloud of any kind (K7, FR-18 AC-5). The iPhone is authoritative (D5/§21); the Watch holds a display snapshot and a queue of pat intents; there is nothing else to synchronize.

### 6.1 Transport mapping

| Mechanism | Direction | Carries | Semantics |
|---|---|---|---|
| `updateApplicationContext` | iPhone → Watch | Latest `WatchSnapshot` (§6.2) | Latest-wins; delivered even when the counterpart app is suspended; replaced, never queued |
| `transferUserInfo` | Watch → iPhone | Pending intent events (pats) from the journal | Reliable queued FIFO delivery; drains in background; duplicates possible ⇒ idempotent by design (§6.4) |
| `sendMessage` (reachable only) | Watch → iPhone | Best-effort immediacy for a pat when the phone is foreground-reachable | Pure optimization; the journal path remains the correctness path. If unreachable, the pat is journaled and delivered by `transferUserInfo` |
| `sendMessage` (reachable only) | iPhone → Watch | Optional "fresh state now" nudge | Also an optimization; the context path remains the correctness path |

The WC session wrappers are small, per-target files (the iPhone and Watch roles differ; ~100 lines each) — a deliberate choice of *plain over DRY*; their pure logic (journaling, watermark arithmetic) lives in MomoKit where it is headlessly testable. **VERIFY-AT-BUILD:** current-generation delivery behaviors (background delivery latency, context coalescing, launch-time context delivery on watchOS).

### 6.2 Payloads

```swift
// Interface sketch (MomoKit DTOs — Codable, versioned; stores never cross the link, TR4)
struct WatchSnapshot: Codable, Sendable {
    let schemaVersion: Int
    let snapshotSeq: Int                  // monotonic, iPhone-assigned
    let display: DisplayState             // §4.11 — the surface read-model
    let questInputs: QuestCascadeInputs   // today's 3 quests: id/progress/target/completion
    let hapticsEnabled: Bool              // UX-13 (haptics only — no sound exists, 04 §11)
    let lastAppliedIntentSeq: Int         // watermark: highest Watch intent applied, per watchSessionEpoch (belongs to lastAppliedEpoch)
    let lastAppliedEpoch: UUID            // epoch the watermark belongs to; a Watch whose epoch differs ignores it (prunes nothing — §6.4)
}

struct IntentEvent: Codable, Sendable {
    let intent: InteractionIntent         // .pat only in Phase 1; id UUID (FR-18 AC-1 key)
    let watchSessionEpoch: UUID           // per-install id: generated at Watch app first launch, persisted in the Watch store (§5.6), regenerated on reinstall / re-pair / new Watch
    let watchSeq: Int                     // monotonic within its epoch (resets with the epoch)
}
```

The snapshot is small (KB), so context updates are cheap and coalesced by the system by design. The iPhone pushes a new snapshot whenever engine state changes while reachable; the context holds the latest otherwise.

### 6.3 Freshness & staleness rules

- **The Watch always displays its last snapshot — instantly** (FR-17 AC-3, UX-9: no freshness indicator, no "syncing", no staleness UI exists anywhere in the product; pet state is presented as timeless). Background delivery is never assumed immediate (FR-18 AC-3): the correctness contract is "at the next sync opportunity", tested within a foreground reconnect.
- On Watch foreground: render the local snapshot immediately (≤ ~2 s restore bound, intake; realistically first-frame in well under it — VERIFY-AT-BUILD on the watchOS launch path), then let WC deliver any pending context update and re-render if changed.
- On iPhone state change: push context. Band crossings and stage changes are rare, day-phase-driven events (§8's cadence argument) — a handful of context updates/day is the expected steady state.

### 6.4 Intent path (the only Watch→iPhone write)

1. Pat on Watch (any state, offline included): local micro-reaction + haptic immediately (FR-17 AC-2), intent appended to the journal, `transferUserInfo` send attempted.
2. iPhone receives intents in order; for each: fold-to-now, then apply **if** the intent UUID is unseen (INV-10) **and** `watchSeq > lastAppliedIntentSeq` **for that intent's `watchSessionEpoch`** — the iPhone stores the watermark per epoch, and an **unseen epoch initializes its watermark at 0**, so pats after a counter reset (seq 1, 2, …) apply normally (§6.6). Effects are computed by the engine exactly like an iPhone pat — including the day-agnostic hello (§4.6) against the intent's own `dayKey` (a 23:30 pat queues with `dayKey = D`; it awards D's hello, never D+1's).
3. **Expired-dayKey intents:** if the intent's `dayKey` has no ledger entry — pruned by the 7-day retention (§5.4) or pre-dating the pet — its **current-state** effects apply (a pat's mood, per §4.4) and all day-ledger attribution is dropped (hello flag, day counters, that day's quest ticks): days are never resurrected, and no retroactive `DayRecord` is created.
4. The next outgoing snapshot carries the new `lastAppliedIntentSeq` together with `lastAppliedEpoch`; the Watch prunes journal entries ≤ watermark **only when the snapshot's epoch matches its own** (a stale-epoch watermark never prunes a newer journal). Two independent idempotency guards (UUID set on iPhone + per-epoch watermark on Watch) make duplicate `transferUserInfo` delivery, replay, and restore-after-restore all no-ops — FR-18 AC-1 "exactly once" holds.
5. Bond/counters/quests move **only** on the iPhone; the Watch's own counters are display inputs, never authoritative — there is no merge step anywhere.

### 6.5 Conflict handling — dissolved by construction

Because the only Watch-originated writes are **commutative, additive, idempotent pat events**, and all derived state (bond, stages, bands, quests) is computed on exactly one device, there is no concurrent-edit conflict to resolve (D5's queued-intent principle, realized). Bond cannot regress on either device: the Watch only ever displays iPhone-issued snapshots; the iPhone's bond is monotonic (INV-3). FR-18 AC-4's "user never sees a sync error" is achieved by having no error surface at all (§6.3).

### 6.6 No-iPhone and paired-but-away cases

| Case | Behavior |
|---|---|
| Fresh install / unpaired Watch | Calm "settling in" line; pat available locally (no-op beyond local reaction); no error (UX §9) |
| iPhone off / out of range (paired-but-away) | Watch renders last snapshot; pats work and journal; snapshot ages silently (no staleness UI); at reconnect the journal drains and a fresh context arrives — all invisible |
| iPhone mid-erase (FR-19 AC-2) | Erase sets a **reset marker** in the next context; Watch wipes snapshot + journal at its next sync and returns to the settling-in line. Honest limit: a Watch left offline indefinitely keeps its local snapshot until the next sync — documented in §11's deletion story |
| Watch re-paired / watch app reinstalled / new Watch | The system wipe erases the Watch store — `watchSessionEpoch` and the seq counter with it; first launch of the fresh install generates a **new epoch**. The iPhone has no watermark for it (initializes at 0, §6.4), so pats (seq 1, 2, …) apply immediately — guards reset, pats flow, no starvation. Pats still queued in the old journal at wipe time are gone with the store (same system-level limit as §11.3's unpairing note) |
| iPhone reinstalled with paired Watch | Fresh iPhone store: empty UUID set, no epochs known — watermarks initialize at 0. Stale journal pats queued before the deletion drain and **apply warm onto the fresh pet** (intended behavior — the user did pat; the expired-dayKey rule keeps pruned/pre-pet days from resurrecting). The stale old-name snapshot renders until the first push — bounded by the first sync. System retention of undelivered WC transfers across reinstall: **VERIFY-AT-BUILD** |
| Watch offline across local midnight | Snapshot still shows yesterday's set until next sync (display-only staleness, no UI); pats journal with their own `dayKey`, so a 23:30 pat attributes correctly |
| Watch app terminated (TR9) | Snapshot + journal are persisted on every background transition; relaunch restores instantly (§5.6) |
| iPhone terminated mid-sync | WC redelivers; idempotency guards make it a no-op (INV-10) |

The §32 sync matrix (iPhone→Watch, Watch→iPhone, disconnection, stale data, conflict, termination/relaunch) maps row-by-row onto the test plan in §10.4.

## 7. HealthKit Strategy — Phase 2 RESERVATION ONLY

**Nothing in this section is Phase 1 scope.** No HealthKit framework reference, entitlement, permission string, or code exists in Phase 1 (FR-20 AC-3; D1: quests are interaction-only). Recorded as architecture so the Phase 2 decision starts from a shaped seam, not a rework (§27, §8.3).

- **Seam:** MomoCore already treats activity as an input port — `DailyProgress.steps` is the Phase 2 additive store field (§5.5), and quests would extend the catalog with activity families behind the same engine rules (D17 inclusivity preserved: the pool always keeps non-activity quests; step targets adaptive/lenient per D17). A small `ActivitySource` protocol (fetch daily step counts) is the only integration surface; its Phase 2 implementation is a HealthKit-reading adapter in the iPhone app target only.
- **Permission UX contract** (UX §8.2, binding when Phase 2 begins): contextual in-Momo-voice ask ("Momo would love to know when you go for a walk") → system dialog → **decline is a first-class outcome** (full usability, D17 anchor quest, no re-nag); read-only scopes only; because read-permission denial is indistinguishable from no-data (TR5), the UI never shows a "denied" state — empty data simply means nothing to show.
- **Data minimization:** read daily step aggregates only; store only the derived daily count on-device; **HealthKit-derived data never leaves the device for any purpose** (D7 — permanent policy), and never enters analytics.
- **Realities designed for (TR5):** late/retroactive same-day data (quest completion tolerates retroactive fulfillment — completion is monotonic, INV-6; revisions refine, never un-complete); background delivery requires a background mode (**VERIFY-AT-BUILD** at Phase 2 start); all step values stay within the two devices.

## 8. Widget Architecture — Phase 2 RESERVATION ONLY

Phase 1 ships no widgets or complications (§27; K6: no App Intents). What Phase 1 deliberately reserves:

- **One read-model, three surfaces:** widgets would render `DisplayState` (§4.11) through the same derivation the Watch uses — including the §5.5 cascade evaluated **at timeline-entry build time** (TR2: precomputed entries are the mechanism for time-of-day changes; no reactive-update promise is made anywhere, so Phase 2 inherits no broken expectation).
- **Timeline budget:** WidgetKit reloads are system-budgeted (order of dozens/day for well-used apps — TR2, **VERIFY-AT-BUILD** for current budgets). Entries precomputed at day-phase boundaries (morning / midday / evening / night, D11 windows) match both the product's calm cadence and the budget. Interactive widgets would imply App Intents (K6) — a Phase 2 scope decision on its own.
- **Shared state read path:** the widget extension reads the snapshot through an **app-group container** — the one new entitlement Phase 2 introduces, enumerated here because entitlements are scope-visible (Phase 1 ships zero, §11.4). The store's file protection would move to `CompleteUntilFirstUnlock` for that container (§5.2 note, **VERIFY-AT-BUILD**). The snapshot DTO already exists; no new persistence design is needed.

## 9. Notification Architecture — Phase 2 RESERVATION ONLY

Phase 1 ships no notifications and no permission (K10; FR-19 has no notification rows). Reservation per project.md §15 philosophy:

- **Channels:** local scheduling via UserNotifications only. No push, no server, ever — a backend does not exist (§1 hard boundaries).
- **Categories (future):** companion-value only — morning hello, evening sleepy note, celebration echoes. Each category is user-controllable (§15) via a Settings surface that does not exist yet (Phase 2 adds it with the permission).
- **Frequency governor (normative shape for Phase 2):** a hard daily cap *(starting value ≤ 2/day, PRD-owned when the phase is scoped)* enforced in one place — the notification planner may not emit more than the cap regardless of state changes; a minimum-spacing interval between emissions; no notification may be scheduled whose content depends on absence or incompletion (nothing of the form "you forgot…" can exist — the banned-vocabulary scan of §4.9 extends to notification strings).
- **Quiet rules:** no notification inside the night window (22:00–07:00 local, D11) — a sleeping pet never pings; plus a local-time quiet buffer around the window edges. Emissions align to day-phase boundaries the engine already computes.
- **Tone checklist:** §15's good/bad copy lists become the standing Phase 2 review gate (PR1/K10), same as §4.9's catalog discipline.

## 10. Testing Architecture

Strategy: **test the pure core headlessly and exhaustively; test the thin platform shells narrowly and honestly.** MomoCore and MomoKit unit tests run via `swift test` on macOS (fast, deterministic, no simulator — VERIFY-AT-BUILD at bootstrap that the package's platform conditions hold); SwiftUI app behavior runs under XCUITest in simulators; WatchConnectivity frame delivery and battery/energy claims are **device-verified obligations in EPIC-002** — never claimed from unit tests (§25 no fake completion). Framework: Swift Testing (current-native — VERIFY-AT-BUILD), no third-party test dependencies.

### 10.1 Test targets

| Target | Tests | Host |
|---|---|---|
| `MomoCoreTests` | engine, quests, cascade, time folds, seeds, DisplayState + CharacterDisplayState, import-whitelist scan | macOS (`swift test`) |
| `MomoKitTests` | store roundtrip/atomicity/recovery/migration, journal watermarks, DTO codec versioning | macOS (`swift test`) |
| `MomoCharacterTests` | idle sequencer determinism, Reduce Motion pose mapping (pure files) | macOS (`swift test`) |
| `MomoUITests` | onboarding, core loop, settings, accessibility audit | iOS simulator |
| `MomoWatchUITests` | pat flow, snapshot restore, AOD static rendering | watchOS simulator (+ device obligations) |

### 10.2 Coverage policy & standing static tests

- Coverage floors: MomoCore ≥ 90 % line coverage (it is pure and cheap to exercise), MomoKit ≥ 80 %, character sequencer logic fully covered by determinism properties, UI smoke over the FR-1/2/5–8/19 critical paths. Coverage numbers are recorded per task in EPIC-002, not asserted here.
- **Static tone test (build-time):** scan all String Catalogs against 04 §10.2's banned-vocabulary list; a hit fails the build (§4.9 — the structural FR-12 guard).
- **Import-whitelist scan (build-time, in MomoCoreTests):** fails on any `import` in MomoCore outside the Foundation family — closing D-R1's SwiftUI residual, which the macOS build alone cannot catch (SwiftUI exists on macOS; §2.3).
- **Determinism property tests:** identical (state, event sequence, clock, seed) ⇒ byte-identical outcome; run as properties over randomized interaction sequences (bounded, seeded — meta-determinism).

### 10.3 §32 Domain matrix → concrete tests

| §32 item | Test (target) |
|---|---|
| Mood/energy transitions | band-mapping property over 0...100 (FR-9 AC-1); attractor/floor/coupling folds (FR-9 AC-2/3) — Core |
| Bond progression | cap-by-construction property over random sequences (FR-10 AC-1); monotonicity incl. replay (AC-2); 1000-pats-zero-bond (AC-3); stage crossing once (AC-4/5) — Core |
| Daily reset | midnight rollover exactly once across folded spans; absent-day ledger emptiness (FR-11 AC-2, FR-12 AC-1) — Core |
| Quest progression | generator 30-day simulation + by-construction candidates; window checks (Q1/Q6); completion auto-tick; cascade rules incl. the letter-of-PRD gap test (§4.8) — Core |
| State-engine rules | response-matrix table test (PRD §4 rows × bands × wakefulness), satiety rows carrying the I-2 flip-marker — conformance = delete the nibble row, 30–90 min → politely-full (OPEN-5); satiety phases; settling + waking decline-warm cells; repetition curve; handshakes incl. late/duplicate/cancelled reports; play single-instant application — Core |
| Deterministic randomness | seed stability (same day ⇒ same seed); sequencer schedule purity (FR-4 AC-1) — Core/Character |

### 10.4 §32 Sync matrix → concrete tests

| §32 item | Test |
|---|---|
| iPhone → Watch | snapshot codec versioning; latest-wins context application re-render — Kit tests + Watch UI test |
| Watch → iPhone interaction | offline pat applies exactly once after reconnect (FR-18 AC-1); pat ticks same counters/quests as iPhone pats (AC-2); hello device-agnostic idempotency (UX-6) — Core + Kit |
| Temporary disconnection | journal drain on reconnect; display of last snapshot with zero UI acknowledgment (AC-3/UX-9) — Kit + Watch UI |
| Stale data | cascade over stale quest inputs renders sanely; no error surfaces (AC-3) — Core |
| Conflict handling | structural argument (§6.5) verified by replay/duplicate-intent no-op properties (INV-10); bond non-regression under replay (AC-4) — Core |
| Guard reset | Counter reset (new `watchSessionEpoch` — re-pair / watch app reinstall / new Watch): the next pat applies exactly once against the 0-initialized watermark; a stale-epoch snapshot watermark never prunes the new journal — Core + Kit |
| Termination/relaunch | Watch snapshot restore ≤ ~2 s measured in Watch UI test; iPhone relaunch ≤ 1 s state loss (FR-13 AC-1) — UI tests; WC frame delivery under suspension = **device obligation, EPIC-002** (VERIFY-AT-BUILD) |

### 10.5 §32 Edge-case matrix → concrete tests

| Edge | Where |
|---|---|
| Timezone change mid-day | Core fold test: one rollover to the new dayKey, no duplicates (FR-11 AC-3) |
| Daylight-saving change | Core fold test across a DST boundary night |
| Date rollover | Core fold test at local midnight (in-session + catch-up paths) |
| No Health permission | n/a Phase 1 (no HealthKit); Phase 2 test inherits §7's empty-data stance |
| Notification permission denied | n/a Phase 1; Phase 2 inherits §9's silent-decline stance |
| Watch unavailable | iPhone full functionality with zero Watch-dependent code paths (sync is fire-and-forget) — Core + UI |
| Offline device | everything (both devices) — UI smoke offline |
| Fresh installation | onboarding → Enter atomic write; day-1 Q6-forced generation — UI + Core |
| Upgrade | store migration v(n)→v(n+1) chain; fresh vs upgrade parity (NFR-7) — Kit |
| Long inactivity | 7-day absence fold: calm attractors, bond unchanged, warm return greeting (FR-12) — Core |

### 10.6 UI & accessibility tests

XCUITest suites per FR-1 (three-step onboarding, restart semantics), FR-2 (Home composition, no numeric state anywhere — a view audit test), FR-5–8 (interaction families incl. refusal-warm and stir paths), FR-16 (inline completion, window expiry), FR-19 (settings, erase-all roundtrip), and the FR-20/NFR-6 accessibility audit (VoiceOver labels per the 04 §3.5 formula, Dynamic Type sizing per the §12 device matrix, Reduce Motion pose substitution, ≥ 44 pt targets, contrast). Accessibility is launch-blocking (NFR-6) — audit executes in every UI task, not once at the end.

## 11. Privacy Architecture

### 11.1 Data inventory (complete — there is nothing else)

| Data | Lives on | Leaves the device? |
|---|---|---|
| Pet name | iPhone store; display string inside the Watch snapshot's DisplayState | Only to the paired Watch (WC) |
| Pet UUID, createdAt | iPhone store only — NOT mirrored to the Watch (data minimization: the Watch needs neither identity nor timestamps) | No egress |
| Mood/energy scalars, wakefulness, activity | iPhone store; band *words* in Watch snapshot | Only to the paired Watch |
| Bond points + day ledger (counters, quests, awarded flags) | iPhone store; cascade outputs in Watch snapshot | Only to the paired Watch |
| Settings (onboarding flag, haptics toggle) | iPhone store; haptics flag in snapshot | Only to the paired Watch |
| Intent journal (queued pats: UUID, dayKey, timestamp, `watchSessionEpoch` — a random per-install sync-guard id, regenerated on reinstall; not a device identifier) | Watch store | Only to the paired iPhone |
| No accounts, no contacts, no location, no health data, no advertising IDs, no device fingerprints | — | — |

### 11.2 Stance

All processing and storage is on-device; the **only** outbound channel is the paired-device link (FR-20 AC-1 — verified by a network-traffic audit test in EPIC-002). No analytics, no telemetry, no third-party SDKs (D7/K9, FR-20 AC-3). App Store privacy-label target: **"Data Not Collected"** (FR-20). Privacy manifest (`PrivacyInfo.xcprivacy`): no tracking, no data collection declared; required-reason-API usage kept to none/minimum (the store avoids UserDefaults and file-timestamp APIs — **VERIFY-AT-BUILD** for the current required-reason list at bootstrap). File protection: iOS/watchOS defaults (complete) per §5.2.

### 11.3 Deletion story (FR-19 AC-2)

Erase all data (explicit confirmation, S6.2): iPhone deletes the store directory (all generations) + regenerates fresh settings → app returns to onboarding, fresh. The next snapshot push carries the **reset marker**; the Watch wipes snapshot + journal at that sync and returns to the settling-in line. **Honest propagation limit, documented:** a Watch offline at erase time retains its local snapshot until its next sync with the erased iPhone (or unpairing, which wipes Watch-local data at the system level — the fresh Watch store then generates a new `watchSessionEpoch`, resetting the sync guards per §6.6). Deletion of the WC-paired link data is system-managed. No tombstones, no cloud copies — nothing to delete anywhere else, because nothing exists anywhere else.

### 11.4 Entitlements & permissions (Phase 1 = zero)

No entitlements file entries in Phase 1: no app groups, no HealthKit, no push, no background modes beyond what WatchConnectivity's system-delivered transport requires (**VERIFY-AT-BUILD** — if the current WC transport requires any declared background capability, it is enumerated and justified at bootstrap; nothing else is added). No Info.plist permission strings exist, so no permission dialog can appear (UX §8.1's zero-permission strategy made structural). Phase 2 additions are enumerated in §7–§9 before any of them ships.

## 12. Performance Budget (§33 — measure, never guess)

| Budget | Value | Verification |
|---|---|---|
| Cold launch → interactive Home | ≤ **2.0 s** (NFR-1) on the smallest supported device | On-device measure in EPIC-002 (XCTest launch metrics); synchronous KB-scale store read is the only launch I/O |
| Animation smoothness | Sustained **60 fps** on reference hardware; ≤ **8 ms/frame** CPU+GPU work on 60 Hz devices; no sustained stutter (NFR-1). ProMotion not assumed | Instruments animation trace; transform-only rig (04 §7.4) is the structural guarantee |
| Memory, iPhone | ≤ **150 MB** steady-state Home idle *(provisional, NFR-3)* | Instruments soak (04 §7.4 rule 6) |
| Memory, Watch | ≤ **80 MB** foreground *(provisional starting budget; VERIFY-AT-BUILD against current watchOS norms)* | Instruments on device |
| Download size | ≤ **60 MB** (NFR-4); art contribution ≤ **1.5 MB** target (04 §8.3) — app is binary-dominated | Archive report |
| Energy, iPhone | Xcode energy gauge **Low** over a 10-min idle session (NFR-2); no background work beyond WC delivery | Energy gauge + battery trace |
| Energy, Watch | No standing timers/work; AOD = static glyph; schedulers are next-event timers only (04 §5.2); WC transfers coalesced by the system (context latest-wins) | Energy gauge on device; pat-roundtrip trace |
| Watch snapshot restore | ≤ **~2 s** raise-to-glance (intake; protects FR-17's ≤ 5 s raise-to-pat) | Watch UI test timing assertion |
| Play round | ≤ 30 s bounded by engine + character pacing (FR-7, 04 §6.3) | Core test on engine side; character bound per 04 |
| Sync cadence | Context pushes: on-change only (a handful/day steady state); intent sends: on pat | Log-verified in EPIC-002 device runs |

**Device matrix (intake obligation — defines "smallest supported" everywhere):** pinned at EPIC-002 bootstrap with the deployment targets (ADR-006) — expected composition, VERIFY-AT-BUILD: **iPhone** — the smallest device run by the pinned iOS generation (expected 4.7" SE-class) + one current mid-tier + one current flagship; **Watch** — one current SE-class (smallest case) + one current flagship. FR-2 AC-1a's no-scroll budget is verified against the smallest iPhone at default Dynamic Type; the §12 launch/energy budgets are measured on the smallest devices.

Standing rule inherited from 04 §7.4: every animation ships with a battery note; any new motion passes the same review gate. All budgets are re-measured, never assumed, at EPIC-002; a budget miss is a task-level blocker, not a note (§33 "measure rather than guess").

---

## Appendix A — Intake Obligation Traceability

| Intake obligation | Where satisfied |
|---|---|
| DisplayState read-model (UX §7); CharacterDisplayState derivation (04 §9.2) | §4.11 (both read-models), §6.2 (snapshot shape), §8 |
| FR-2 AC-1a device matrix | §12 |
| Hello idempotency + hello/Q1 window split | §4.6, §4.8, §6.4, §10.4 |
| Haptics sync to Watch (no sound) | §6.2, §3.1 SettingsState, §11.1 |
| Watch snapshot restore ≤ ~2 s | §5.6, §6.3, §10.4, §12 |
| Invisible corruption-recovery cadence | §5.3, §10.2 |
| ResponsePlan per PRD §4 matrix (engine decides what/when) | §4.4 |
| Satiety window value | §4.5 (DECISION: 90 min, three phases; nibble class proposed via I-2/OPEN-5) |
| Settle/wake/play handshakes + `handshakeCancelled` | §4.7 |
| Play effects at the single instant the round ceases | §4.7 (confirmed 04 §9.6 item 4) |
| Single CharacterClock pause authority | §4.1/§4.2 (engine never pauses; presentation owns pause per 04 §9.3/9.5) |
| Day-stable idle seed `hash(petID, localDay, choreographyEpoch)` | §4.10 |
| Copy-class namespaces + M2/M3 surfaces | §4.9 |
| OBS-1 (04 §3.5 VoiceOver formula governs) | §4.9, §4.11 |
| OBS-2 (M2 banner exempt from 12-word max) | §4.9 |
| PRD §5.5 rule-1 gap flagged, letter implemented | §4.8 box |

## Appendix B — Open Items & VERIFY-AT-BUILD Register

**OPEN-1 (owner, doc fix):** PRD §5.5 cascade rule 1 gap — the 00:00–07:00 Q6 tail (§4.8). One-line fix drafted; Phase 1 implements the PRD letter with a flip-ready test.
**OPEN-2 (reviewer confirmation):** interpretation I-1 — refused/declined feeds increment `feedCount` and quest progress (PRD FR-6 AC-3 letter; required for Q3's ≤ 2-min completability). §4.4.
**OPEN-3 (bootstrap):** exact deployment-target versions, device-matrix device names, test-framework idioms pinned with ADR-006. §2.4, §12.
**OPEN-4 (noted placement decision):** idle sequencer lives in MomoCharacter (04 owns choreography) as pure Foundation-only files, not in MomoCore; alternative was Core placement for one-stop determinism tests — rejected to respect the 04 §9.4 ownership split. §2.2.
**OPEN-5 (owner confirmation):** interpretation I-2 — the 30–90-min "recently fed" nibble (§4.4, §4.5) is a proposed third response class, not PRD letter. **PRD FIX CANDIDATE:** FR-6's wording ("recently fed → politely full, zero penalty") and the §4 matrix assign the politely-full refusal, zero effects, to all of 0–90 min; only the window VALUE is delegated (TASK-006 intake). **Flip-ready test:** the §10.3 response-matrix table test carries the satiety rows marked to flip — conformance = delete the nibble row; 30–90 min maps to politely-full (zero effects). **Disposition:** proposed, pending owner confirmation; Phase 1 implements §4.5 as specified until ruled.

**VERIFY-AT-BUILD consolidated:** deployment-target versions and iOS↔watchOS pairing rules (§2.4); WatchConnectivity transport behaviors (background delivery latency, context coalescing/launch delivery, any required background capability, system retention of undelivered transfers across iPhone reinstall) (§6.1, §6.6, §11.4); Swift `Clock`/concurrency idioms (§4.10); `swift test` hostability of the package targets (§10); privacy-manifest required-reason API list (§11.2); WidgetKit budgets and app-group/file-protection interaction (§8 — Phase 2); HealthKit background mode (§7 — Phase 2); watchOS memory norms (§12); device-matrix composition (§12).

## Appendix C — Requirements Traceability (§30 items 17–21)

| §30 item | Where |
|---|---|
| 17 Technical architecture | This document, all sections |
| 18 Data model | §3 (+ ADR-002 for the store) |
| 19 Sync strategy | §6 (+ ADR-003) |
| 20 Permission/privacy strategy | §11, §7–§9 reservations (+ UX §8) |
| 21 Analytics/event taxonomy | n/a Phase 1 by D7 — paper taxonomy lives in PRD §9; this document enforces the "no instrumentation" boundary (§1, §11.2) |

*End of document.*

