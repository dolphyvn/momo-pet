Momo Agent Team Orchestration Contract

This file defines the mandatory operating rules for all Claude/AI agents working on the Momo project.

These rules are project-wide and override normal agent preferences unless the human owner explicitly changes them.

1. CORE OPERATING PRINCIPLE

The project must be executed as a multi-agent engineering team.

The main/orchestration agent coordinates the work.

Specialized agents execute individual tasks.

No substantial implementation task should be completed entirely by the main orchestration agent unless explicitly required.

The default workflow is:

Plan → Create Task → Spawn Fresh Agent → Execute → Review → Fix → Test → Commit → Push → Update Status → Continue

2. MANDATORY FRESH AGENT PER TASK

Always spawn a new agent for every task.

This applies to:

product tasks

design tasks

architecture tasks

implementation tasks

test tasks

bug fixes

refactoring

documentation changes

infrastructure changes

release work

code reviews

Do not reuse the same implementation agent across separate tasks.

Each task must have a clean agent context based on:

the task specification,

relevant project files,

current architecture and coding standards,

.claude/tasks/status.md,

the task-specific files under .claude/tasks.

The orchestration agent must assume that any future agent may have no prior conversational context.

Therefore all important state must exist in the repository.

3. MODEL REQUIREMENT

All agents must use the Jupiter model.

This applies to:

orchestration agents,

implementation agents,

review agents,

QA agents,

architecture agents,

documentation agents,

debugging agents,

release agents.

Do not silently downgrade to another model.

If Jupiter is unavailable, stop that task and record the blockage in:

.claude/tasks/status.md

Do not substitute another model without explicit approval from the human owner.

4. MAIN ORCHESTRATION AGENT RESPONSIBILITIES

The main agent in the primary session is the project orchestrator.

The main agent must:

understand the current project state before assigning new work,

maintain the task structure,

break Epics into executable tasks,

define dependencies,

create task files,

spawn a fresh agent for every task,

ensure review occurs before commit,

ensure tests pass,

ensure every completed task is committed and pushed,

regularly update project progress,

preserve architectural consistency,

prevent agents from silently expanding scope,

keep .claude/tasks/status.md accurate,

ensure another orchestration agent can resume work without needing chat history.

The main agent should coordinate rather than perform large implementation tasks itself.

5. REQUIRED TASK DIRECTORY

The main orchestration agent must create and maintain:

.claude/
└── tasks/
    ├── status.md
    ├── epics/
    ├── active/
    ├── completed/
    ├── reviews/
    └── decisions/

Create missing directories automatically.

The repository, not chat history, is the source of truth for execution state.

6. STATUS.MD IS MANDATORY

The following file must always exist:

.claude/tasks/status.md

It is the primary orchestration handoff file.

It must contain enough information for a new orchestration agent to continue immediately without asking the previous agent what happened.

At minimum it must contain:

# Project Status

## Current Phase

## Current Epic

## Overall Progress

## Completed Work

## Work In Progress

## Next Tasks

## Blocked Tasks

## Recent Commits

## Architecture / Product Decisions

## Known Issues

## Test Status

## Build Status

## Repository / Branch Status

## Important Context for Next Agent

## Last Updated

Update status.md:

after every completed task,

after every commit,

after every push,

when a task becomes blocked,

after significant debugging,

after architecture decisions,

after a meaningful coding period,

before ending an orchestration session.

Never leave status materially stale.

7. EPIC STRUCTURE

Every Epic must have its own file under:

.claude/tasks/epics/

Recommended naming:

EPIC-001-foundation.md
EPIC-002-pet-state-engine.md
EPIC-003-iphone-home.md
EPIC-004-watch-app.md

Each Epic should include:

# EPIC-XXX — Name

## Objective

## User / Product Value

## Scope

## Non-Goals

## Dependencies

## Tasks

## Acceptance Criteria

## Test Requirements

## Definition of Done

## Status

Every Epic must be decomposed into independently executable tasks.

8. TASK FILES

Every implementation unit must have a task file.

Active tasks belong in:

.claude/tasks/active/

Recommended naming:

TASK-001-project-bootstrap.md
TASK-002-pet-model.md
TASK-003-pet-state-engine.md

A task file must include:

# TASK-XXX — Name

## Parent Epic

## Objective

## Context

## Requirements

## Files / Areas Likely Affected

## Dependencies

## Constraints

## Acceptance Criteria

## Required Tests

## Review Requirements

## Git Requirements

## Status

## Implementation Notes

## Reviewer Findings

## Completion Evidence

The task must be sufficiently complete for a fresh agent to execute it without relying on conversational memory.

9. ONE TASK = ONE FRESH IMPLEMENTATION AGENT

For each task:

Main agent creates or updates the task file.

Main agent spawns a fresh Jupiter agent.

Agent reads:

CLAUDE.md

.claude/tasks/status.md

the task file

relevant project source files

Agent executes only the assigned scope.

Agent updates implementation notes in the task file.

Agent runs appropriate tests.

Agent does not commit yet.

A separate review agent is spawned.

Review findings are addressed.

Tests are rerun.

Only then may the task be committed and pushed.

Never combine unrelated tasks into a single agent assignment merely for convenience.

10. MANDATORY INDEPENDENT CODE REVIEW

Every code-producing task must be reviewed by a separate fresh agent before commit.

The implementation agent must not self-approve.

The review agent must also use Jupiter.

The review agent should inspect:

correctness,

task requirements,

architectural consistency,

regressions,

edge cases,

test quality,

error handling,

concurrency,

performance,

security/privacy,

accessibility where relevant,

Apple platform conventions where relevant,

unnecessary complexity,

dead code,

scope creep.

Review output must be recorded under:

.claude/tasks/reviews/

Recommended naming:

REVIEW-TASK-003.md

Review status should be one of:

APPROVED

APPROVED_WITH_MINOR_NOTES

CHANGES_REQUIRED

BLOCKED

A task may not be committed while its review status is CHANGES_REQUIRED or BLOCKED.

11. REVIEW/FIX LOOP

If review identifies problems:

record findings,

spawn a fresh Jupiter fix agent if the fixes form a distinct task or substantial revision,

apply fixes,

rerun tests,

have a fresh reviewer verify the corrected implementation when changes are material,

update the task and review documents.

Do not bypass review because a change appears small.

12. COMMIT RULE

Every completed task derived from an Epic must result in its own Git commit unless the task explicitly produces no repository change.

Use atomic commits.

One task should normally map to one final task commit.

Do not accumulate many completed tasks into one large commit.

Recommended format:

<type>(<scope>): <TASK-ID> <summary>

Examples:

feat(pet): TASK-003 implement pet state engine
test(pet): TASK-004 add pet state transition coverage
fix(watch): TASK-021 resolve stale Watch state sync
docs(architecture): TASK-010 record persistence ADR

Commit messages must include the task ID.

13. PUSH RULE

After a task:

passes implementation,

passes review,

passes required tests,

is committed,

the task must be pushed to the configured remote.

Do not intentionally leave completed task commits only in the local repository.

After pushing:

record the commit hash,

record the branch,

record push status,

update .claude/tasks/status.md.

If push fails, record the failure as a blocker.

14. BRANCHING

Follow the repository's existing branch strategy if one exists.

If none exists, default to:

main
feature/TASK-XXX-short-name
fix/TASK-XXX-short-name

Do not invent a complicated GitFlow model unless the project requires it.

The orchestration agent must avoid parallel agents editing the same files on conflicting branches without explicit coordination.

15. PROGRESS UPDATE RULE

After a meaningful period of coding, the active agent must update task progress.

Do not work for long stretches while leaving repository status undocumented.

Progress updates should include:

what was completed,

what remains,

files changed,

tests executed,

current failures,

blockers,

important decisions,

next expected action.

Update either:

the active task file,

status.md,

or both depending on significance.

Before an agent session ends, persistent state must be written to the repository.

Never rely on chat history as the only record of progress.

16. INTERRUPTION-SAFE DEVELOPMENT

The project must be designed so orchestration can be interrupted at any moment.

A replacement orchestration agent should be able to resume by reading:

CLAUDE.md

.claude/tasks/status.md

current Epic file

files in .claude/tasks/active/

recent Git history

No essential state may exist only in the previous agent's context.

Before stopping work, always make the repository interruption-safe.

17. TASK LIFECYCLE

Use these task states:

TODO
READY
IN_PROGRESS
IN_REVIEW
CHANGES_REQUIRED
TESTING
BLOCKED
DONE

Typical lifecycle:

TODO
→ READY
→ IN_PROGRESS
→ IN_REVIEW
→ TESTING
→ DONE

If review fails:

IN_REVIEW
→ CHANGES_REQUIRED
→ IN_PROGRESS
→ IN_REVIEW

When done, move the task file from:

.claude/tasks/active/

to:

.claude/tasks/completed/

Do not mark a task DONE until commit and push are complete.

18. DEFINITION OF TASK DONE

A task is DONE only when all applicable conditions are satisfied:

requirements implemented,

acceptance criteria satisfied,

appropriate tests added,

tests pass,

independent review completed,

review approved,

review findings addressed,

no known critical regression introduced,

task documentation updated,

commit created,

commit pushed,

commit hash recorded,

status.md updated.

Code compiling alone is not sufficient.

19. TEST BEFORE COMMIT

Never commit code known to fail required tests.

For each task, run the most relevant available checks.

Examples:

build,

compiler,

unit tests,

integration tests,

UI tests,

lint,

static analysis,

SwiftFormat/SwiftLint if configured,

app launch verification,

Watch build,

widget build,

accessibility checks,

snapshot tests if available.

The exact test command and result should be recorded in the task completion evidence.

20. NO BLIND FIXING

Do not repeatedly patch code without understanding the failure.

For defects:

reproduce,

identify root cause,

define expected behaviour,

create or update a regression test where practical,

fix,

test,

review,

commit,

push.

Avoid patch chains where each fix creates another unexplained fix.

21. ARCHITECTURE DECISIONS

Meaningful architectural decisions must be persisted under:

.claude/tasks/decisions/

Recommended format:

ADR-001-local-first-persistence.md
ADR-002-watch-sync-strategy.md
ADR-003-pet-state-engine.md

An ADR should contain:

# ADR-XXX — Title

## Status

## Context

## Decision

## Alternatives Considered

## Consequences

## Date

Do not allow major architectural decisions to exist only in agent conversation history.

22. SCOPE CONTROL

Agents must execute the assigned task only.

If an agent discovers unrelated work:

do not silently implement it,

record it as a follow-up task,

notify the orchestration state,

let the main agent prioritize it.

Small directly necessary changes are allowed when required to complete the assigned task safely.

Avoid feature creep.

23. PRODUCT SOURCE OF TRUTH

For the Momo product, preserve the agreed product philosophy:

Momo is a tiny companion that quietly shares the user's everyday life.

The application should remain:

Cute × Calm × Minimal × Alive × Premium

It should not drift toward:

Childish × Noisy × Addictive × Complicated × Game-heavy

Product decisions should support emotional companionship, not screen-time maximization.

24. MVP SCOPE PROTECTION

Do not silently expand MVP scope.

Phase 1 should remain focused on the approved core experience.

Future features should be recorded as later work rather than implemented opportunistically.

Examples of non-MVP ideas that require explicit approval:

social network,

public profiles,

multiplayer,

large backend platform,

AI chatbot pet,

loot boxes,

complex economy,

advertisements,

dozens of pets,

aggressive streak mechanics.

25. NO FAKE COMPLETION

Agents must never claim:

tests passed when they were not run,

code was reviewed when no review agent reviewed it,

code was pushed when Git push did not succeed,

a feature works on device when only static inspection occurred,

an API is supported without verification,

a task is complete while required acceptance criteria remain open.

Report the actual state.

26. NO UNDOCUMENTED TODO DEBT

Avoid leaving unexplained:

TODO
FIXME
HACK
TEMP

If temporary debt is unavoidable:

attach it to a task,

document why,

record impact,

create a follow-up task if necessary.

27. SECURITY AND PRIVACY REVIEW

Tasks touching any of the following require explicit review attention:

HealthKit,

personal data,

notifications,

location,

CloudKit/iCloud,

authentication,

analytics,

network communication,

file storage,

secrets,

entitlements.

Never put credentials, secrets, tokens, certificates, or private keys into the repository.

28. AGENT HANDOFF FORMAT

Before finishing a task, the executing agent should leave:

## Handoff

### Completed

### Files Changed

### Tests Run

### Test Results

### Known Issues

### Decisions Made

### Reviewer Status

### Commit

### Push

### Recommended Next Step

This information must live in the task file or another repository artifact, not only in chat.

29. ORCHESTRATION SESSION START

Whenever a new main/orchestration agent starts:

read CLAUDE.md,

read .claude/tasks/status.md,

inspect active tasks,

inspect current Epic,

inspect recent Git commits,

check repository status,

reconcile any mismatch between task state and Git state,

choose the next READY task,

spawn a fresh Jupiter agent.

Do not begin new work before understanding current state.

30. ORCHESTRATION SESSION END

Before a main agent ends its session:

update status.md,

ensure task states are correct,

record current branch,

record latest commits,

record uncommitted changes,

record blockers,

record test/build status,

specify exact next task,

ensure active task files contain sufficient context.

The next agent must be able to continue immediately.

31. STATUS.MD RECOMMENDED FORMAT

Use this template:

# Momo Project Status

Last Updated: YYYY-MM-DD HH:MM UTC
Updated By: <agent/session>

## Current Phase
<phase>

## Current Epic
<EPIC-ID and name>

## Overall Progress
<summary>

## Completed Work
- ...

## Work In Progress
- TASK-XXX — ...
  - Status:
  - Branch:
  - Agent:
  - Notes:

## Next Tasks
1. TASK-XXX — ...
2. TASK-XXX — ...

## Blocked Tasks
- None

## Recent Commits
- <hash> — TASK-XXX — message

## Recent Pushes
- <branch> → <remote> — success/failure

## Architecture / Product Decisions
- ADR-XXX — ...

## Known Issues
- ...

## Test Status
- Unit:
- Integration:
- UI:
- iPhone Build:
- watchOS Build:
- Widget Build:

## Repository Status
- Branch:
- Clean/Dirty:
- Uncommitted files:
- Remote sync:

## Important Context for Next Agent
- ...

## Exact Next Action
<single concrete action>

32. TASK SIZE

Prefer tasks that can be independently:

understood,

implemented,

tested,

reviewed,

committed.

If a task is too large, split it before implementation.

Avoid tasks such as:

Build the entire app.

Prefer:

TASK-012 Define PetState domain model
TASK-013 Implement deterministic PetStateEngine
TASK-014 Add PetStateEngine tests
TASK-015 Connect PetStateEngine to HomeView
TASK-016 Persist pet state

Every task still requires its own fresh agent.

33. REVIEW AGENT INDEPENDENCE

The review agent should receive:

task requirements,

diff,

relevant architecture,

tests,

project rules.

Do not prime the reviewer with:

The implementation is correct.

Ask the reviewer to independently try to disprove correctness.

A reviewer must identify concrete evidence for approval.

34. COMMIT/PUSH CHECKLIST

Before commit:

[ ] Task requirements complete
[ ] Acceptance criteria satisfied
[ ] Tests added where appropriate
[ ] Required tests pass
[ ] Independent review completed
[ ] Review approved
[ ] Findings addressed
[ ] Task notes updated
[ ] No accidental files/secrets
[ ] Git diff inspected

After commit:

[ ] Commit contains TASK-ID
[ ] Commit hash recorded
[ ] Push succeeded
[ ] Remote branch verified where possible
[ ] status.md updated
[ ] Task moved to completed if DONE

35. PERIODIC PROJECT HEALTH CHECK

After a substantial coding period or several completed tasks, the orchestration agent must perform a project health checkpoint.

Review:

Epic progress,

build health,

test health,

architecture drift,

duplicated code,

unresolved TODOs,

active blockers,

task documentation quality,

Git cleanliness,

product scope,

technical debt.

Record the checkpoint in status.md.

If needed, create dedicated remediation tasks.

36. HUMAN ESCALATION

Do not interrupt the human owner for low-risk reversible implementation choices.

Escalate only when a decision is materially:

product-defining,

architecture-defining,

destructive,

expensive to reverse,

privacy-sensitive,

security-sensitive,

monetization-related,

scope-changing.

When escalating, provide:

issue,

options,

recommendation,

consequences,

whether work can continue elsewhere.

37. FINAL RULE

The project must remain resumable, reviewable, testable, and auditable at all times.

The orchestration system succeeds only when:

every task has clear ownership,

every task gets a fresh Jupiter agent,

every code task gets an independent review agent,

every completed Epic task is committed,

every completed task is pushed,

progress is persistently documented,

.claude/tasks/status.md always tells the truth,

a brand-new orchestration agent can continue the project without requiring prior chat history.

When in doubt:

write the state to the repository before moving on.
