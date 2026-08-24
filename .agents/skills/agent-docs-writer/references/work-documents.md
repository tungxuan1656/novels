# Work Documents

## Feature document

Own one bounded execution unit. Link to durable truth instead of repeating it.

```markdown
# <id> — <title>

## Goal

<One observable outcome.>

## Scope

- <Included work.>

## Non-goals

- <Explicitly excluded work.>

## Acceptance

- [ ] <Concrete condition.>

## Relevant docs

- `<path>`

## Verify

- `<command>`

## Exceptions

- <Accepted exception, only when needed.>

## Handoff

- State: <state>
- Evidence: <result or link>
- Next: <one action>
```

Remove `Exceptions` and `Handoff` when they are not needed. Add a plan only when the work has several dependent steps.

Do not add commit, branch, or review requirements unless the repository or user requires them.

## Progress record

Use an append-only block. Do not repeat the feature's scope or durable decisions.

```markdown
## <date> — <feature or task>

**State**: <state>
**Done**: <completed work>
**Evidence**: <command and result>
**Blockers**: <blocker or none>
**Next**: <one action>
```

Use a separate handoff document only when the canonical feature and progress records cannot support a safe restart.
