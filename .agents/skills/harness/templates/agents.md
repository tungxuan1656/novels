# AGENTS.md

{{PROJECT_PURPOSE}}

Detected stack: `{{PROJECT_STACK}}`

## Read when needed

{{CANONICAL_DOC_ROUTES}}

Read the relevant spec or decision before changing behavior. Do not infer an
accepted product or architecture decision from implementation alone.

## Work scope

- Follow user-approved scope and acceptance; ask about unresolved behavior or ownership.
- Use no task record for small, clear work or read-only requests.
- Reuse the canonical tracker; otherwise keep durable work in `tasks/task-<slug>.md`.
- Keep bounded plans inline. Link a separate plan only for sequencing, coordination, or recovery needs.
- Keep durable rules in canonical docs, not in task notes.

## Concurrent work

- Each task owns its status, dependencies, evidence, and handoff; no root progress log.
- `tasks/index.md`, when used, owns roadmap/navigation only; never mirror status there.
- Use `todo`, `active`, `blocked`, or `done`. Independent tasks can be active concurrently.
- Name the task owner; coordinate overlapping files before parallel edits. Task records are not locks.
- Record start dependencies separately from integrate/release gates. Do not start unapproved backlog work.

## Verification and handoff

- Read the selected task and its linked sources; do not load all task history.
- Run proportional checks after meaningful changes. Full configured checks: `./init.sh`.
- Never automatically fix source files or install dependencies in verification scripts.
- Record baseline failures and coverage gaps; repair them only within approved scope.
- Mark done only when acceptance and relevant checks pass, with exact evidence in the task.
- At a material handoff, update this task's blockers and next action, not a root log.
- Across people, share an accessible tracker, PR, branch, or commit; disclose uncommitted work.
- Before retiring a task, extract durable knowledge and check links/dependents and retention policy.
- Update verification commands and affected canonical docs when their source changes.

<!-- harness {{HARNESS_VERSION}} · generated {{GENERATED_AT}} -->
