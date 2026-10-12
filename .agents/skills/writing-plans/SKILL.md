---
name: writing-plans
description: >-
  Write a proportional implementation plan from approved requirements when
  execution needs durable steps, coordination, or recovery. Reuse the
  repository's canonical task and plan location; keep bounded plans inline.
---

# Writing Plans

Write the smallest plan another engineer can execute and verify without
inventing behavior. A plan is not a second implementation or a mandatory
artifact for every multi-step change.

## Before drafting

1. Read the approved spec, applicable instructions, relevant code and tests,
   accepted decisions, and the selected task or tracker.
2. Identify affected callers, fixtures, exports, configuration, and docs.
3. Ask about unresolved behavior or risk before pretending the plan is executable.
4. Reuse the canonical task or tracker. Keep bounded steps inline; use a
   separate plan only for durable sequencing, coordination, or recovery.

With Harness v2, a needed separate plan defaults to
`docs/plans/task-<slug>.md` linked from `tasks/task-<slug>.md`. Reuse an
adequate native path, including legacy plans. If ownership is unclear, use
`agent-docs-architect` when available or return the path decision. Do not
create `docs/superpowers/` or a parallel spec tree.

## Simplicity pass

- Start from existing repository patterns and standard platform features.
- Choose the smallest complete solution; name non-goals explicitly.
- Do not add abstractions, dependencies, options, phases, or files without a concrete need.
- Do not restructure unrelated modules to make the plan look cleaner.
- Preserve validation, security, data integrity, error handling, and required accessibility.

## Plan content

Include only what execution requires:

- goal, acceptance source, non-goals, and exact project constraints;
- affected paths and each change's responsibility;
- ordered deliverables, dependencies, and owners only when needed;
- concrete behavior, interface changes, and edge cases;
- observed verification commands and expected outcomes;
- rollout or recovery steps only when risk requires them.

Use checkboxes for independent deliverables, not mandatory 2-5 minute rituals.
A step can combine code, tests, fixtures, and docs when they form one coherent
change. Name actual interfaces when another task consumes them. Show a code
snippet only when it removes genuine ambiguity; do not duplicate whole future
implementations or require a commit after every test cycle.

When a written plan will be consumed by `subagent-driven-development`'s
`task-brief` script, use `### Task N: <deliverable>` headings so extraction
works. Keep affected files and interface details in each relevant section;
this does not require a separate plan or tiny steps for ordinary execution.

Unknown critical facts are open questions, not fabricated code or vague
`handle edge cases` instructions. Ordinary predictable details can remain
implementation work when behavior and verification are unambiguous.

## Self-check and handoff

Check approved acceptance coverage, contradictory paths/interfaces, risk
controls, and unnecessary work. Confirm commands exist and verification does
not fix source or install dependencies. A spec/plan disagreement needs a
decision, not silent scope expansion.

State the canonical plan path, outstanding blockers, and next action. Follow
user-authorized execution; do not force another approval round for an already
approved plan. Offer inline or delegated execution only when a choice is useful.
