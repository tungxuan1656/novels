# Blueprint Format

Return a proposal in this shape. Remove sections that do not apply.

```markdown
# Repository knowledge architecture

## Assessment

- Delivery profile: <compact, growing, established, or federated>
- Project stage: <greenfield, growing, production, migration, or legacy>
- Pressure signals: <specific domain, topology, stack, integration, data, risk, delivery, and coordination evidence>
- Existing strengths to preserve: <artifacts or conventions>
- Main failures or risks to solve: <navigation, intent, contracts, freshness, recovery, security, reliability>

## Knowledge gaps and open decisions

| Status | Gap or question | Affected area | Decision owner | Risk if unresolved |
|---|---|---|---|---|
| Missing/Conflicting/Inaccessible | <fact or question> | <artifact, interface, or domain> | <role or source> | <consequence> |

## Proposed map

<A shallow tree containing only justified artifacts. Mark conditional items.>

## Artifact contracts

| Status | Artifact | Owns | Evidence or decision source | Read when | Lifecycle | Freshness or validation |
|---|---|---|---|---|---|---|
| Keep/Create/Revise/Move/Retire | `<path>` | <one class of truth> | <source or owner> | <task condition> | <durable/active/historical/generated/external> | <source, owner, generator, or check> |

## Reading routes

| Task | Start | Read next when |
|---|---|---|
| <task type> | `<entry point>` | <condition -> focused source> |

## Intentionally omitted

| Capability | Reason |
|---|---|
| <artifact or category> | <no pressure, accessible canonical source, or maintenance cost> |

## Writer handoff

| Artifact | Evidence to inspect | Required content | Required routes | Constraints |
|---|---|---|---|---|
| `<path>` | <code, tests, accepted decisions, commands> | <artifact responsibility> | <incoming and outgoing links> | <lifecycle, uncertainty, size, generated boundary> |

## Maintenance contract

- <event that requires an update>
- <mechanical check, generator, or owner>
- <gardening cadence only when justified>
```

## Status rules

- `Keep`: already satisfies the required capability.
- `Create`: no equivalent exists and a concrete failure, risk, or accepted
  greenfield constraint justifies it.
- `Revise`: preserve the artifact while fixing ownership, routing, lifecycle,
  or stale content.
- `Move`: relocate only when the current location breaks discovery or ownership.
- `Retire`: remove only after canonical truth and incoming routes are migrated.

Use `Missing`, `Conflicting`, or `Inaccessible` for gaps. Use `Observed`,
`Intended`, `Proposed`, or `Uncertain` when recording facts. Do not use `Create`
for an empty category directory. Do not use `Move` or `Retire` only to make
filenames uniform.
