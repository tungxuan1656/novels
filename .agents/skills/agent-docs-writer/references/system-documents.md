# System Documents

## Subsystem guide

Own the implementation rules for one subsystem.

```markdown
# <Subsystem>

## Flow

<Primary flow.>

## Responsibilities

- `<component>`: <responsibility>

## Rules

- <Required pattern.>

## Avoid

- <Forbidden pattern.>

## Examples

- Canonical: `<path or symbol>`
- Legacy, do not copy: `<path or symbol>`

## Verification

- `<command>`
```

Include examples only when the repository contains competing patterns.

## Product or domain spec

Own durable behavior. Do not prescribe implementation unless the technology is a durable accepted constraint.

```markdown
# <Behavior>

## Flow

<User or domain flow.>

## Rules

- <Required behavior.>

## States

<State transition, if applicable.>

## Cases

| Case | Result |
|---|---|
| <case> | <expected result> |

## Acceptance

- [ ] <Observable outcome.>
```

Put edge cases next to the rule or state that they modify.
