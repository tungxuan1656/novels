---
name: harness-task
description: >-
  Assess incoming work in repositories that use Harness Slim and choose the
  lightest safe feature and plan artifacts before acting. Use for questions,
  reviews, investigations, code, configuration, documentation, bugs, features,
  refactors, migrations, and other requests when Harness Slim artifacts such as
  AGENTS.md, feature_index.json, features/, or progress.md govern the repository.
  Do not use outside a Harness Slim repository or to orchestrate other skills.
---

# Harness Task

Choose whether the request needs no feature, a feature with an inline plan, or
a feature with a separate linked plan. Base the choice on project scale, task
complexity, and impact rather than on task labels or file count alone.

## Assess the request

1. Read the applicable instruction files and the user's requested outcome.
2. Inspect `feature_index.json`, the active feature, and any accessible
   canonical tracker only when the request may need tracked state or may affect
   existing tracked work.
3. Inspect only the repository slice needed to estimate affected subsystems,
   execution horizon, coordination, risk, and reversibility.
4. Read [Task routing matrix](references/task-routing-matrix.md) and select one
   artifact level.
5. Reuse an in-scope feature or sufficient external tracker before creating a
   local feature.
6. State the choice in one short sentence with its strongest reason, then
   continue the requested work.

Ask only when an unresolved requirement materially changes the artifact level
or makes the work unsafe. Do not run broad verification merely to classify the
request.

## Apply the choice

- For **no feature**, create no feature, plan, or progress record. This is the
  default for questions, reviews, lookups, read-only investigations, and small
  clear work that can finish safely in one session.
- For **feature with inline plan**, keep scope, acceptance, concise steps, and
  evidence in the feature record. Use this when durable tracking is useful but
  the work remains one bounded execution unit.
- For **feature with separate plan**, create or reuse the canonical plan,
  link it from the feature, and keep the feature record concise. Use this when
  the plan itself is needed for staged execution, coordination, recovery, or
  risk control.

When an accessible external tracker substitutes for the feature record, keep
the same inline-versus-separate judgment in that canonical system and create no
duplicate local feature or progress state.

Update `progress.md` only for repository-local feature work and only when a
result, blocker, handoff, or next action materially changes. Do not log a task
merely because a session occurred. Apply the same rules to code and non-code
work.

## Preserve boundaries

- Treat repository size as a modifier, never as sufficient evidence by itself.
- Treat a short but high-impact change as potentially substantial.
- Do not create an artifact solely to record this assessment.
- Do not mirror a sufficient external tracker into Harness state.
- Do not move unrelated work into the active feature.
- Honor an explicit user request for an artifact and existing repository-native
  ownership conventions.
- Do not select, invoke, or replace design, planning, implementation, review,
  or verification skills.
