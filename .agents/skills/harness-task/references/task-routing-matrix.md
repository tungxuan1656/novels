# Task Routing Matrix

Use the strongest concrete signals, not a score or file-count threshold.

| Level | Use when |
|---|---|
| No task record | Read-only request, or clear reversible work safe within one session |
| Task with inline plan | Scope, acceptance, or handoff must persist, but execution is one bounded unit |
| Task with separate plan | Dependent phases, several owners, cross-session recovery, migration/rollback sequencing, or durable high-impact controls |

## Selection

1. Reuse an approved in-scope task or sufficient accessible external tracker.
2. For read-only work, use no record unless the user requests a durable artifact.
3. Start other work at no record and escalate only for concrete risk or persistence needs.
4. Prefer inline planning unless execution must be coordinated or recovered independently.

A large monorepo typo remains lightweight. A three-line authorization change
needs relevant safeguards, not automatically a separate plan. A mechanical
multi-file rename does not become substantial solely because of file count.
Documentation migrations can need plans when inbound links and multiple teams
must coordinate. Never invent phases to justify a plan.

## State and concurrency

Keep status and material handoff in the selected task or tracker only. Several
independent tasks can be active. Use unique descriptive or tracker-derived IDs,
a named owner, and agreed file ownership for overlapping edits. Check known
concurrent work as well as the current checkout before choosing a task ID.
Do not modify unrelated tasks, a shared mutable index, or a root progress log.
