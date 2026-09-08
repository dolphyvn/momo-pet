# ADR-006 — Deployment Targets: Current Shipping OS Generation at Build Start

## Status
PROPOSED — under review (TASK-006). Becomes ACCEPTED upon REVIEW-TASK-006 approval. Implements TASK-002 D15 ("latest stable shipping OS at build start; support current, consider N-1"; exact versions delegated to TASK-006).

## Context
project.md §21 requires verifying APIs and deployment requirements against current official Apple documentation; the review flagged 2026 fall OS churn as a live hazard (TR6) and refused to pin version numbers in a document task. Phase 1's framework floor is deliberately low: no SwiftData (ADR-002), no widgets/HealthKit/notifications (Phases 2), a Codable store, SwiftUI + Observation as the only modern requirements. The app pairs an iPhone app with a watchOS app, so the iOS↔watchOS version-pairing matrix is part of the decision.

## Decision
**Pin minimum deployment targets at EPIC-002 bootstrap to the current stable shipping OS generation — expected iOS 26 / watchOS 26 or their then-current successors (exact numbers recorded at bootstrap; VERIFY-AT-BUILD, asserted from no specific OS).** N-1 support is a deliberate non-commitment, re-evaluated once at release planning (TASK-007): widening later is a build-setting change plus device-matrix expansion, cheap if release review wants the reach. The device/performance matrix (05-technical-architecture §12) is pinned at the same bootstrap moment. All API availability claims in the architecture inherit this policy and carry VERIFY-AT-BUILD where version-sensitive.

## Alternatives Considered
- **Pin N-1 now for reach:** rejected — no evidence any Phase 1 capability requires it, it expands the watchOS pairing matrix, and it commits to availability shims the product does not need (§22: keep architecture proportional).
- **Pin to the newest beta generation:** rejected — Phase 1 is a production-quality release (§39); targeting unreleased OSes contradicts §21's stable-stack direction.
- **Defer the decision to EPIC-002 entirely:** the policy *is* deferred-by-reference, but recording the policy and its justification now (rather than an empty "decide later") is what makes the bootstrap decision mechanical and reviewable.

## Consequences
- No availability shims or `#if` back-deployment branches are expected anywhere in Phase 1 — the simplest build configuration.
- Reach is bounded to current-generation devices at launch; widening N-1 at release is explicitly preserved as a low-cost option, with the pairing-matrix check as its VERIFY-AT-BUILD gate.
- Every version-sensitive claim in the architecture (Clock idioms, WC transport behaviors, test frameworks, privacy-manifest requirements, watchOS memory norms) remains VERIFY-AT-BUILD; none is asserted from memory (§25).

## Date
2026-09-08
