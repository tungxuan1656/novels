# Artifact Catalog

Choose artifacts by knowledge need. Reuse an existing equivalent when it owns
the same truth, even when its name differs.

| Capability | Canonical responsibility | Create when | Omit or reuse when |
|---|---|---|---|
| Agent instruction entry point | Repository-wide routes and operating invariants | Agents need a stable starting point | An existing tool-specific entry point is canonical |
| Architecture overview | Topology, entry points, boundaries, dependency direction, major flows | These facts are costly or unsafe to infer | The repository is trivial or an equivalent exists |
| Documentation index | `Read when` routing across focused sources | Several focused documents require selection | The set is small and obvious |
| Product or domain spec | Durable behavior, rules, states, and edge cases | Behavior is unsafe to infer | Tests or an accessible canonical product source suffice |
| Glossary | Meanings of overloaded domain terms | Terms cause incorrect implementation or support decisions | One vocabulary is already obvious |
| Design principles | Accepted beliefs that resolve recurring trade-offs | The same judgment recurs across decisions | The content is generic advice |
| Decision record | Rationale and consequences of one durable decision | A consequential choice has alternatives | The decision is temporary or obvious |
| Subsystem guide | One subsystem's patterns, boundaries, and verification | A stack, boundary, or tooling difference causes mistakes | Architecture and code make it clear |
| Integration contract | Versioned API, event, webhook, or failure expectations | Systems exchange data across a boundary | A canonical schema or provider contract is accessible |
| Data ownership guide | Domain ownership, lifecycle, migration, retention, and privacy rules | Shared, sensitive, or cross-domain data causes ambiguity | Schema and code make ownership clear |
| Generated reference | Machine-derived schema, API, config, or inventory | Source is large or costly to inspect repeatedly | Generation is not reproducible or the source is easy to query |
| External reference snapshot | Version-pinned agent-readable third-party knowledge | Network access is unreliable or exact versions matter | Official documentation is stable and accessible |
| Execution plan | Scope, sequence, decisions, progress, and recovery | Work spans sessions or has dependent stages | The task is small or an external tracker is canonical |
| Completed plan archive | Historical execution evidence and superseded decisions | Past work prevents repeated investigation | The history has no durable value or lives canonically elsewhere |
| Technical-debt tracker | Known debt, impact, owner, and review date | Debt needs repository-local coordination | An accessible issue tracker is canonical |
| Security guide or threat model | Security boundaries, assets, controls, and residual risk | Security or privacy constraints cross subsystems | The project has no such constraints or a canonical source exists |
| Reliability guide | SLOs, failure behavior, recovery, and operational invariants | Availability or asynchronous failure behavior is material | No non-local reliability constraint exists |
| Observability guide | Signals, dashboards, traces, alert ownership, and debug routes | Agents must verify or diagnose production-like behavior | Tooling is small and self-evident |
| Frontend or design-system guide | Shared interaction, visual, accessibility, or component invariants | Multiple UI surfaces need one source of truth | Rules belong to a single feature or external system |
| Quality or health score | Measured architecture or documentation gaps over time | A recurring gardening process consumes the score | There is no metric, owner, or feedback loop |
| Nested instructions | Scoped routes and rules for one subtree | Tooling or invariants genuinely differ by subtree | Root instructions and focused docs can route the work |

## Missing decisions

An artifact cannot compensate for an unmade decision. When evidence cannot
establish product behavior, architecture, owner, or risk acceptance, report an
open decision in the blueprint with:

- the question to answer;
- the affected artifact or interface;
- the decision owner or role;
- the risk of proceeding without an answer.

Do not create a permanent document solely to hide an unresolved question.

## Lifecycle classes

| Class | Examples | Maintenance contract |
|---|---|---|
| Durable | Architecture, accepted decisions, product specs | Update when behavior, boundaries, or intent changes |
| Active | Execution plans, migrations, temporary exceptions | Update during work; close or archive at a terminal state |
| Historical | Completed plans, replaced decisions | Preserve rationale; mark status and replacement routes |
| Generated | Schemas, API inventories, dependency maps | Record generator, source inputs, and freshness check |
| External | Vendor references, standards snapshots | Record source, version or retrieval date, and refresh trigger |
