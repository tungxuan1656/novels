# AI slop cleanup rubric

Use repository evidence to distinguish compounding drift from valid variation.

## Common signals

| Signal | Evidence to require | Default action |
|---|---|---|
| Duplicate helper | A canonical utility has equivalent semantics and supported consumers | Migrate call sites, verify, then remove the duplicate |
| Speculative abstraction | No declared requirement, one real consumer, and indirection adds no invariant | Inline or remove without changing behavior |
| Dead artifact | No static or dynamic references, registration, configuration, generated ownership, or documented use | Remove the smallest dead unit and its residue |
| Guessed boundary shape | Property probing, unchecked casts, or fallback chains replace an available schema or typed API | Parse at the boundary or use the canonical typed interface |
| Defensive noise | Catch, retry, fallback, or null handling covers states excluded by an enforced contract | Simplify only after proving the contract |
| Stale knowledge | Documentation, comments, plans, or examples contradict code, tests, configuration, or current decisions | Update the canonical owner; remove duplicated stale text |
| Boilerplate padding | Comments restate code, wrappers only rename calls, or tests repeat the same behavior without a distinct risk | Remove low-signal layers while preserving useful coverage |
| Pattern drift | Similar modules implement the same invariant inconsistently and one pattern is canonical | Convert a small batch to the canonical pattern |
| Dependency residue | No source, tool, config, or build path uses the dependency | Remove it through the repository package manager and verify lockfile changes |
| Temporary residue | Debug output, scratch files, abandoned TODOs, fixtures, flags, or compatibility paths have no live owner | Remove only after checking history and current plans for active intent |

## Likely false positives

Preserve these unless stronger evidence proves otherwise:

- Generated files intentionally checked into source control.
- Platform-specific branches and external-system adapters.
- Similar tests that protect different regressions or boundary cases.
- Compatibility paths covered by supported-version policy.
- Code discovered through reflection, plugins, routing, registries, or dependency injection.
- Security, reliability, or performance code whose purpose is documented or tested.
- Work in progress or untracked files owned by the user or another agent.
- An unusual but canonical local pattern.

## Evidence strength

Prefer evidence in this order:

1. Enforced tests, types, schemas, linters, and runtime contracts.
2. Call sites, dependency graphs, registration, build configuration, and CI.
3. Maintained architecture, product, and decision documents.
4. Current feature scope and accepted plans.
5. Version history as context, not proof of current intent.
6. Naming, style, and intuition only as leads.

## Change risk

| Risk | Examples | Action |
|---|---|---|
| Low | Unused import, stale comment, duplicated local expression | Clean within explicit scope and verify |
| Medium | Shared-helper migration, dependency removal, test consolidation, stale plan cleanup | Inspect all consumers and use a separate coherent change |
| High | Public API, data schema, migration, auth, permissions, module deletion, compatibility behavior | Ask for explicit scope before changing |

## Recurrence test

Create a durable guardrail only when the pattern is objective, harmful, likely to recur, and detectable. Prefer a test, type, schema, or existing linter over prose. Keep the rule narrow enough to explain both the forbidden pattern and the correct replacement.

This rubric derives its continuous-cleanup model from OpenAI’s [Harness engineering: leveraging Codex in an agent-first world](https://openai.com/vi-VN/index/harness-engineering/): encode golden principles, scan regularly for deviations, and repay technical debt in small targeted increments.
