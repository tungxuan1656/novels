---
name: harness-slim-review
description: >-
  Audit a repository's coding-agent harness against Harness Slim criteria. Use
  when reviewing AGENTS.md, feature_index.json, feature documents, progress.md,
  init.sh, or their consistency; before adopting or refactoring a harness; or
  when deciding whether agent instructions and verification are concise, safe,
  evidence-based, and restartable.
---

# Harness Slim Review

Review the current harness without modifying it. Report evidence, findings, and the smallest useful improvements.

## Inspect

1. Identify the repository root and instruction-file precedence.
2. Inventory `AGENTS.md`, `feature_index.json`, `features/`, `progress.md`, `init.sh`, and `docs/plans/`.
3. Read the root instructions, all harness artifacts, relevant project documents, manifests, workspace configuration, CI, and test directories.
4. Compare verification commands with repository evidence. Inspect `init.sh` before running it.
5. Treat the current working tree and current feature state as evidence, not as defects by default.

Do not run `./init.sh` when it can format or lint with fixes unless the user authorizes those working-tree changes. You can run read-only inspection and syntax checks when available. Do not add, regenerate, or repair harness files unless requested.

Label claims `Observed`, `Inferred`, or `Uncertain`. Do not infer intended architecture, commands, policies, or ownership from legacy code alone.

## Evaluate

Read the full [review rubric](references/review-rubric.md). Assess only requirements applicable to the target repository.

Check in this order:

1. `AGENTS.md`: task assessment, conditional startup, scope boundaries, lifecycle, verification, and escalation.
2. State: index schema, feature status, dependencies, and matching feature documents.
3. Work records: feature scope, acceptance, plan location, evidence, handoff, and append-only progress.
4. `init.sh`: Bash-only implementation, evidence-backed commands, safe order, failure behavior, and workspace coverage.
5. Cross-file consistency and unnecessary process.

Missing a needed artifact is a finding. A repository that does not need a feature, plan, progress entry, phase, or document is not defective when the omission is explicit and evidence supports it.

## Rate findings

- `HIGH`: agents can work out of scope, claim done without evidence, lose/recover state incorrectly, or verification is unsafe or unusable.
- `MEDIUM`: a feature, dependency, command, workspace, plan, or handoff is stale, ambiguous, or inconsistent.
- `LOW`: wording, discoverability, or maintainability creates friction without changing safe execution.

Report only findings supported by repository evidence. Do not use an arbitrary total score.

## Report

Use this structure:

```md
# Harness review

## Verdict
<Ready | Needs targeted fixes | Not ready>

## Evidence
- <Observed files, commands, and configuration.>

## Coverage
| Area | Status | Evidence |
|---|---|---|
| AGENTS.md | pass / gap / n/a | <path or fact> |

## Findings
### [HIGH] <short title>
- File: `<path>:<line>`
- Evidence: <observed fact>
- Impact: <concrete agent failure>
- Fix: <smallest change>

## Strengths
- <criterion satisfied with evidence>

## Priority changes
1. <highest-leverage fix>
```

Use `n/a` only with evidence. If no material findings exist, state that explicitly and still list any unverified assumptions.

## Finish

Separate baseline project failures from harness defects. State whether checks ran, were inspected only, or were not run, and why. Do not edit the target unless the user asks for remediation.
