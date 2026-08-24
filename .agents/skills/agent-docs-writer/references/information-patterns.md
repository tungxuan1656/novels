# Information Patterns

Use a structured form only when it communicates more than a short list.

## Map

Show location and responsibility. Keep the tree shallow.

```text
apps/
├─ web/     → browser application
├─ api/     → HTTP API
└─ worker/  → background jobs
```

Do not copy a complete directory tree.

## Flow

Show ordered interaction or data movement.

```text
Request
  → Route
  → Service
  → Repository
  → Database
```

Label an edge when its mechanism matters:

```text
Web ──HTTP──> API
API ──event──> Worker
```

## Dependency boundary

Show allowed and forbidden access together.

```text
Allowed:
Route → Service
Service → Repository

Forbidden:
Route ✕ Database
Domain ✕ Framework
```

Use one meaning for each symbol in a document:

- `A → B`: A invokes, feeds, or leads to B.
- `A ✕ B`: A must not directly access B.
- `A ⇄ B`: A and B interact in both directions.

## Decision tree

Use a decision tree when the correct action depends on conditions.

```text
State belongs in the URL?
├─ yes → use route parameters
└─ no
   ↓
Shared across the feature?
├─ yes → use the feature store
└─ no  → use local state
```

## State transition

Name the event on each transition when it is not obvious.

```text
draft
  ↓ submit
pending
  ↓ payment confirmed
paid
```

List invalid transitions when they prevent common errors.

## Table

Use a table for repeated fields, cases, ownership, or trade-offs.

| Case | Result |
|---|---|
| Unknown user | `401` |
| Disabled user | `403` |

Do not use a table for long prose or unrelated facts.

## Truth status

Use status labels when evidence and intent differ:

```text
Observed:
Legacy routes access repositories directly.

Intended:
New routes call the service layer.

Uncertain:
No source defines the migration deadline.
```

Use `Proposed` for a change that is not accepted. Do not present the most common legacy pattern as intended design.

## Canonical evidence

Prefer evidence in this order:

1. Accepted product or architecture decision.
2. Maintained repository documentation.
3. Configuration, tests, and public interfaces.
4. Representative current implementation.
5. Repeated legacy patterns.

Record a conflict instead of silently choosing one source.
