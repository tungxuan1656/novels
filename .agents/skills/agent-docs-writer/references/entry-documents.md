# Entry Documents

## AGENTS.md

Own repository navigation and repository-wide operating rules. Do not include detailed architecture, product behavior, feature notes, tutorials, or generic coding advice.

```markdown
# AGENTS.md

<Project purpose in one or two sentences.>

## Start here

- Architecture → `<path>`
- Subsystem rules → `<path>`
- Product behavior → `<path>`
- Work state → `<path>`

## Repository map

<Shallow interpreted map.>

## Rules

- <Repository-wide invariant.>
- <Repository-wide invariant.>

## Verification

- Quick: `<command>`
- Full: `<command>`

## End session

1. <Update canonical work state.>
2. <Record evidence and the next action.>
```

Keep only routes that exist. Keep only rules that apply to almost every coding task.

## Architecture

Own topology, boundaries, major flows, and the interpreted code map.

```markdown
# Architecture

## System

<Topology or primary flow.>

## Code map

<Shallow map with responsibility for each area.>

## Boundaries

Allowed:
- `<A> → <B>`

Forbidden:
- `<A> ✕ <C>`

## Flows

### <Flow name>

<Ordered interaction.>

## Related docs

- <Topic> → `<path>`
```

Move implementation doctrine to subsystem guides. Move behavior rules to product or domain specs.
