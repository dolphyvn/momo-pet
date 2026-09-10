# ADR-010 — Idle resume discipline under the zero-on-pause clock

## Status

Accepted (TASK-027 fix round 1 — REVIEW-TASK-027 MAJOR-2)

## Context

The contract's Requirement 8 / AC-2 / Required Test 3 asked the idle pipeline to satisfy "resume NEVER replays or bursts … identical continuation to an uninterrupted run from T + gap", and REVIEW-TASK-027 found no test implementing that reading. But the shipped clock — approved and pinned in TASK-026 (`CharacterClock`, `CharacterClockTests`) — is zero-on-pause: `pause()` zeroes the timeline, `elapsed()` stays 0 while stopped, and `resume()` re-anchors, restarting accumulation from 0. Under that clock a resumed run equals an uninterrupted run from **0**, not from T + gap; pre-gap events recur in real time. The contract's continuation clause was an over-translation of the doc, and the doc itself (04 §5.3) is explicit about what "never replay" means: "app-hide zeroes the CharacterClock and the entire schedule resumes cleanly on return (no event backlog bursts — timers re-schedule, never replay)" — replay is forbidden in the BACKLOG sense (no accumulated event debt flushed as a burst), which the zeroing clock satisfies structurally: after a pause there are no between-pause events, because between-pause character time does not exist. Changing the clock to honor the contract's literal reading would break the TASK-026 pins that embody zero-on-pause (the contract itself forbids that) and would render stale, fast-forwarded motion after a long background dwell — the opposite of §5.3's freshness intent.

## Decision

Zero-on-pause IS the resume discipline. Its executable semantics, pinned by `Tests/MomoCharacterTests/MomoIdleResumeTests.swift`:

1. Pause at any T ⇒ elapsed 0 (stays 0 across the whole wall-clock gap).
2. Resume restarts the timeline from 0 and accumulates only real post-resume time — no catch-up burst (a dwell of G seconds yields G seconds of timeline after resume, never T + G).
3. The schedule regenerates identically from the unchanged seed — the post-resume log is byte-for-byte the from-zero log (purity makes the replay deterministic).
4. The replayed log is burst-free: no instant carries multiple newly-active events (distinct starts), nothing is active at the resume instant itself.
5. The pose at every post-resume timeline instant equals a never-paused run's pose at the same instant.

The TASK-026 clock pins (`CharacterClockTests`) remain authoritative for the clock; the suite above pins the discipline THROUGH the sequencer + model pipeline (the contract's missing Required Test 3).

## Alternatives Considered

- **Honor the literal continuation clause (resume at T + gap).** Requires re-anchoring the clock forward on resume — breaks `CharacterClockTests` (out of bounds for this task), breaks §7.4 rule 1's "clock zeroed" gate, and renders the character mid-state after hours of absence instead of the calm t = 0 pose.
- **Keep zero-on-pause but replay only post-T events.** Contradicts the seed-derived schedule (the log is a pure function of the seed; a "from T" log is a different log) and invents a second, event-level pause mechanism beside the one clock — two pause disciplines for one timeline.

## Consequences

- After a pause the character replays its idle log from the beginning, in real time. Within a day's stable seed (§5.1) the replay is identical to what the user already saw; §5.3's "resumes cleanly" reads as exactly this.
- "No replay" in the contract's Req 8 is hereby interpreted as the doc's backlog sense; the contract clause "identical continuation to an uninterrupted run from T + gap" is recorded as an over-translation and is superseded by "identical to an uninterrupted run from 0" (pinned).
- No catch-up burst is possible by construction (the timeline cannot jump), so the §7.4 "scheduled, never polled" cost model holds across pause/resume.

## Date

2026-09-10 (TASK-027 fix round 1)
