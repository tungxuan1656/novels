---
name: harness-slim
description: >-
  Create or simplify a compact repository harness for coding agents. Use when a
  repository needs concise AGENTS.md instructions, feature_index.json state,
  feature plans, session progress, and an evidence-based Bash init.sh for lint,
  format, build, test, or declared monorepo workspaces.
---

# Harness Slim

Create only the knowledge and verification artifacts that let an agent start, stay scoped, verify work, and resume safely.

Use `harness-task` when installed to assess incoming work before creating or
updating feature, plan, or progress artifacts. The assessment is an intake
policy, not orchestration of this or any other skill.

## Artifacts

| File | Owns |
|---|---|
| `AGENTS.md` | Navigation, repository-wide rules, verification, and lifecycle |
| `feature_index.json` | Feature ID, title, status, and dependencies |
| `features/feat-template.md` | Reusable feature document template |
| `features/feat-<id>.md` | Scope, acceptance, plan, evidence, and handoff |
| `progress.md` | Append-only session result and next action history |
| `init.sh` | Editable format, lint, build, and test workflow |

Do not add state-check scripts, generated helpers, empty documentation scaffolds, generic coding advice, or `.agents/README.md`. Do not reference `.agents/README.md` from `AGENTS.md`.

## Inspect before writing

1. Read existing instruction files, harness artifacts, README files, and relevant project documents.
2. Inspect manifests, lockfiles, workspace configuration, CI workflows, and test directories.
3. Find existing verification commands before inventing commands.
4. Identify the repository root and declared workspace modules.
5. Classify findings as `Observed`, `Intended`, `Proposed`, or `Uncertain` when they differ.
6. Ask only when scope, overwrite permission, or a verification decision cannot be inferred safely.

Use representative configuration, tests, and maintained documents as evidence. Do not treat repeated legacy code as intended design without a canonical source.

## Create or update artifacts

Use the files in `templates/` as starting points. Replace placeholders with repository facts. After writing `init.sh`, run `chmod +x init.sh`.

When a harness already exists:

- Preserve its canonical state and documentation ownership.
- Update the smallest source of truth that needs the new rule.
- Do not overwrite a managed file without explicit user approval.

### Version check (detect drift from installed repo)

When the repository already contains harness artifacts (`AGENTS.md`, `feature_index.json`, `init.sh`, or `progress.md`):

1. Read the provenance marker: `AGENTS.md` footer `<!-- harness-slim ... -->` or `feature_index.json` field `_harness.version`. If no marker, treat as `unknown` (legacy repo).
2. Read skill version from `metadata.json` (`version`).
3. If repo marker equals skill version: no drift — skip changelog.
4. If repo marker is older or `unknown`: read `CHANGELOG.md` entries strictly between repo version and skill version (lazy read).
5. For each entry, classify `Type` and act surgically with user approval:
   - `non-breaking-doc`: no repo change (e.g. `references/gotchas.md`).
   - `additive`: add missing marker/field/section.
   - `breaking-rules`: surgical section replace in `AGENTS.md` per entry's Update action.
   - `breaking-script`: surgical block edit in `init.sh` (never touch `FORMAT/LINT/BUILD/TEST` task arrays).
6. Show diff preview per file, ask for approval. If target region has user customizations that conflict, ask instead of overwriting.
7. After applying, update provenance markers to the new skill version (`{{HARNESS_VERSION}}` / `{{GENERATED_AT}}`). Do not write `progress.md` for harness maintenance; mention the update in the session summary only.

Legacy repos (no marker): show the full changelog and ask the user before updating.

Keep zero or one feature `active`. Do not activate `todo` work without user scope. Do not require a feature merely because the harness provides feature artifacts.

Decide feature tracking with this table. Default to inline. Use an external plan only when >=2 conditions in the third column apply.

| Mode | Use when | Signals for external plan |
|---|---|---|
| No feature | <20 lines, 1 file, no API/DB/complexity change | — |
| Inline plan (`features/feat-<id>.md`) | 1-3 files, 1 workspace, <200 lines, single concern, <1 day | — |
| External plan (`docs/plans/feat-<id>.md`) | Substantial work | >=4 files or >=2 workspaces, DB migration or breaking API, needs phases/rollback, or needs multi-agent file ownership |

Do not create `docs/plans/feat-<id>.md` for bounded work.

Create `features/feat-template.md` from `templates/feat-template.md`. Create or update a feature only when project scale, task complexity, and impact justify durable tracking. Keep the plan inline for bounded tracked work.

For substantial work that needs durable phases, coordination, recovery, or risk control:

1. Create `docs/plans/feat-<id>.md`.
2. Link it from the feature file.
3. Define phases, dependencies, agent ownership, file ownership, verification, and handoff.

Keep durable architecture and product facts in their canonical project documents. Do not duplicate them in feature or progress records.

Keep `progress.md` append-only: retain its template at the top and add a new block below the final template note only when repository-local feature work has a material result, blocker, handoff, or next action. Do not edit older blocks.

## Write init.sh from evidence

Write `init.sh` only in Bash. Do not invoke Node.js or generate child scripts at runtime.

For Node.js repositories:

1. Read root `package.json`, lockfiles, and workspace configuration.
2. Prefer root scripts when they orchestrate all declared workspaces.
3. When a root phase is absent, run the matching script in each declared workspace.
4. Ignore nested packages outside declared workspaces.
5. Add only commands that exist or that repository evidence supports.

Use this order:

```text
format:fix, format:write, or format
  ↓
lint:fix or lint -- --fix
  ↓
build + test in bounded parallelism
```

Run format and lint before build and test because they can modify files. Run independent build and test tasks in parallel. Print an explicit skip for an absent phase. Exit nonzero when any configured task fails.

Do not install dependencies, infer package scripts at runtime, or modify source files outside formatter and linter fixes. Update `init.sh` when commands, tools, or workspace modules change.

`init.sh` must configure at least one `BUILD_TASKS` or `TEST_TASKS` entry when repository evidence shows a build or test exists. If no suite exists, add an explicit commented-out entry with evidence (e.g. `# "pnpm run test" # SKIP explicit: no test dir, no test script in package.json`). Do not leave all four task arrays silently empty.

For non-Node repositories, write equivalent Bash commands only when their tools and configuration exist in the repository.

## Finish

1. Run the relevant commands from `init.sh`. Fail the harness if `init.sh` has no BUILD/TEST tasks while evidence shows a build or test exists, or if all four task arrays are silently empty.
2. For feature work, record evidence in the feature file and record progress only when execution state materially changed.
3. Keep unknowns and blockers explicit.
4. Explain which repository evidence determined the harness.

## References

Read only when the current task needs it:

- Session memory → [Memory persistence](references/memory-persistence-pattern.md)
- Context pressure → [Context engineering](references/context-engineering-pattern.md)
- Parallel agents → [Multi-agent coordination](references/multi-agent-pattern.md)
- Failure modes (slim core) → [Gotchas](references/gotchas.md)
- Full runtime gotchas → [Gotchas Full](references/gotchas-full.md) — only when hacking the harness engine itself
