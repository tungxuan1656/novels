# Work Documents

## Task record

Own one approved execution unit. Reuse a sufficient accessible tracker instead
of making a local copy. Link durable specs and decisions rather than repeating them.

```markdown
# <task-id> - <title>

- Status: <todo | active | blocked | done>
- Owner: <person or agent>
- Required to start: <task link or none>
- Required to integrate/release: <task link or none>

## Scope and non-goals

<Outcome, boundary, and explicit exclusions.>

## Acceptance

- [ ] <Observable condition.>

## Sources

- <Canonical spec or decision link.>

## Plan

<Short inline steps or a link to the separate canonical plan when needed.>

## Verification and handoff

- Evidence: <exact command/result or not run>
- Blockers: <blocker or none>
- Next: <one action or none when complete>
```

Keep only necessary sections. Status and owner have one location, not a second
index. Independent tasks can be active; coordinate overlapping files separately.
A roadmap index links to tasks but does not duplicate status or dependencies.
Do not create a root progress log. At a material handoff, update this task or
tracker with restart evidence. Follow existing history policy without erasing
required evidence. A separate handoff is useful only when the canonical record
cannot support restart. Across people, use an accessible shared source and
disclose uncommitted work. Preserve legacy logs during approved migration.
After closure, extract durable knowledge; check incoming links, dependency
consumers, and retention policy before removing a disposable task. Archive
only history worth retaining, not every task by default.

## Execution plan

Keep bounded plans inline. A separate plan owns execution sequencing when
phases, coordination, rollback, or recovery need durable detail. Link it from
the task; do not duplicate status or durable product behavior there.

Map approved acceptance to deliverables, affected paths, observed checks, and
risk controls. Do not prescribe a line-count quota, generic phases, or complete
future code. Name unresolved decisions instead of inventing them. Do not add
commit, branch, or review requirements without repository or user policy.
