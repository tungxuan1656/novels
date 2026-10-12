# Harness v2 Review Rubric

Apply only what the repository actually needs.

| Area | Pass condition |
|---|---|
| Router | Exact routes, repository-specific invariants, proportional verification, explicit escalation |
| Task sizing | No record for lightweight work; inline by default; separate plans justified by risk or coordination |
| Canonical state | Task or tracker owns status, owner, evidence, and handoff; no duplicated status index |
| Concurrent work | Independent tasks can be active; overlapping file edits have an agreed owner/integration order |
| Scope | Approved goal, non-goals, acceptance, and required dependencies are explicit |
| Restart | Selected task gives latest useful evidence, blockers, and next action without loading root history |
| Done | Acceptance and relevant checks pass; evidence names commands and actual results |
| Knowledge | Specs, decisions, design, and architecture own durable facts; tasks link instead of copying |
| init.sh | Bash, strict failure handling, script-directory resolution, simple sequential commands |
| Checks | Existing read-only root entrypoint owns coverage/concurrency; explicit commands when none exists |
| Safety | No source fixes, installs, runtime command discovery, generated scripts, or swallowed failures |
| Coverage | Syntax/whitespace checks are not presented as full application verification; gaps are visible |
| Migration | Legacy history preserved, owners/links reconciled, approved edits only |

No global one-active-task invariant, numeric plan threshold, mandatory root log,
custom scheduler, or universal commit/review policy. A task record is not a lock.
Task-local state reduces metadata conflicts; it does not prevent source conflicts.
