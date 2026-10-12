# Concurrent Task Coordination

Each task or canonical tracker owns its own state and handoff. Independent
tasks can be active concurrently; no shared mutable index, global counter, or
root progress log is needed. A requested roadmap index links to tasks and
changes only with membership/scope; it does not mirror execution state.

Before parallel writes:

1. Assign unique tracker-derived IDs or descriptive task slugs and named owners.
2. Check known concurrent work, not just the current checkout, for collisions.
3. Agree file ownership or integration order for overlapping changes.
4. Distinguish start dependencies from integrate/release gates; define
   verification after integration without serializing independent implementation.

Separate task files reduce metadata merge conflicts. They do not lock source
files, protect against two owners selecting the same scope, or replace branch
and review policies already used by the repository.

Use separate workspaces only when repository policy or overlapping writes
require them. Do not add a scheduler, lock service, swarm, or mandatory agents.
Prefer inline execution when one person or agent can safely finish the task.

When delegating, provide the exact scope, relevant decisions, allowed files,
constraints, and expected evidence. Research can run read-only; the coordinator
must synthesize its result before issuing a specific implementation request.

See [context selection](./context-engineering-pattern.md) and
[task handoff](./memory-persistence-pattern.md).
