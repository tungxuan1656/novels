---
name: harness-review
description: >-
  Audit a coding-agent harness without modifying it. Use when reviewing
  AGENTS.md, task-local records, init.sh, documentation routes, or a legacy
  feature/progress harness for safe migration to Harness v2.
---

# Harness Review

Report evidence-backed failures and the smallest useful repairs. This is the
v2 successor to `harness-slim-review`; migration is explicit, not automatic.

## Inspect

1. Identify the repository root, instruction precedence, and requested coverage.
2. Read the router, selected task or tracker, relevant canonical docs, manifests,
   CI, and verification commands. Sample unrelated tasks only when needed;
   disclose the boundary instead of claiming exhaustive coverage.
3. Inspect `init.sh` before running it. Do not run source fixes, installs,
   destructive tests, or other unsafe side effects without authorization.
4. For v1 repositories, inspect legacy state as evidence, not as permission to migrate.
5. Read the [rubric](references/review-rubric.md) and apply only relevant criteria.

## Evaluate

- Router: shallow paths to canonical truth, scoped work, escalation, verification.
- Tasks: one state owner per task, acceptance, evidence, handoff, independent concurrency.
- Plans: inline by default; separate only for actual sequencing, coordination, or recovery.
- Verification: evidence-backed check-only commands, failure propagation, explicit coverage gaps.
- Docs: durable knowledge separate from work state; no generic scaffold or duplicated rules.

Use `agent-docs-checker` for a docs-focused audit rather than expanding this
review into unrelated product or architecture design. Missing optional artifacts
are not defects. Do not require branches, commits, review gates, or tools without
repository policy or user instruction.

## Report

Findings first, ordered by severity: HIGH for unsafe work or false completion,
MEDIUM for stale or ambiguous ownership/commands, LOW for navigation friction.
For each, give a file and line, evidence labelled Observed/Inferred/Uncertain,
concrete impact, and smallest repair. Then give Ready/Needs targeted fixes/Not
ready, coverage, strengths if useful, and assumptions/checks not run.

Separate existing project failures from harness defects. If no supported
findings exist, say so. Do not edit or regenerate the target unless requested.
