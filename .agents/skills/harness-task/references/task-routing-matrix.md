# Task Routing Matrix

Assess project scale, task complexity, and impact together. Do not calculate a
numeric score: use the strongest concrete signals and select the smallest
artifact level that keeps the work safe and resumable.

## Signals

| Dimension | Lighter signals | Stronger signals |
|---|---|---|
| Project scale | One component, obvious ownership, one workflow | Several workspaces, deployables, domains, owners, or concurrent workstreams |
| Task complexity | One coherent change, known interfaces, one session | Dependent phases, uncertain interfaces, several subsystems, multiple sessions or agents |
| Impact | Local, reversible, narrow failure radius | Public contracts, security, privacy, data integrity, migrations, deployment, external state, or costly rollback |

Project scale changes the coordination and discovery cost of a task. It does
not make a local edit substantial merely because the repository is large.
Likewise, a small repository does not make a security or migration task light.

## Selection

| Artifact level | Select when | Do not select merely because |
|---|---|---|
| No feature | The request is read-only, or the change is clear, bounded, reversible, and safe to finish in one session | The repository contains feature templates or an active feature exists |
| Feature with inline plan | Scope, acceptance, evidence, or handoff should persist, but the work is one bounded unit without a durable staged execution need | The task has several ordinary implementation steps |
| Feature with separate plan | Work has dependent phases, several subsystem or agent owners, cross-session recovery needs, migration or rollback sequencing, or high-impact controls that must remain durable | The task is described at length or touches many files mechanically |

Use this order:

1. If the request is already inside an active feature's scope, reuse that
   feature and reassess only whether its plan should remain inline or become a
   separate linked plan.
2. If an accessible external tracker already owns sufficient scope,
   acceptance, dependencies, and handoff, reuse it instead of creating local
   feature state.
3. If the request is a question, review, lookup, or read-only investigation,
   select no feature unless the user explicitly requests a durable artifact.
4. For repository changes, start at no feature and escalate only when concrete
   complexity, impact, or persistence signals justify the cost.
5. Prefer an inline plan unless the plan must survive, coordinate, or control
   execution independently of the feature record.

## Borderline cases

- A documentation typo in a federated monorepo remains no feature.
- A focused bug with clear behavior and targeted verification normally remains
  no feature.
- An explicitly planned backlog item may use a feature with an inline plan even
  when implementation fits one session, because the feature is project memory.
- A small authentication, authorization, privacy, or destructive data change
  may require a feature; use a separate plan only when durable sequencing,
  recovery, or review controls are actually needed.
- A long-running documentation migration can require a feature and separate
  plan even though it changes no code.
- An unrelated small request must not change the active feature's state. If it
  could affect that feature's acceptance or evidence, clarify or include it in
  the feature instead of silently treating it as separate work.

## Progress

Write a progress block only when all of these are true:

1. Repository-local feature state is the canonical execution record.
2. Work on that feature produced a material result, blocker, handoff, or next
   action.
3. The new block adds restart value without duplicating feature scope or
   durable decisions.

Do not write progress for no-feature work, read-only work, unchanged state, or
work tracked sufficiently in an accessible external system.
