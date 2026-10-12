# Assessment and Delivery Profiles

Use this assessment to discover documentation needs. A profile supplies a
starting baseline; each capability still requires a specific pressure signal.

## Assessment dimensions

| Dimension | Lower pressure | Higher pressure | Documentation pressure |
|---|---|---|---|
| Project stage | Stable or short-lived | Greenfield, migration, legacy recovery | Make assumptions, decisions, and transition state explicit |
| Product and domain | One obvious workflow | Several domains, rules, or state machines | Product specs, glossary, domain maps |
| Topology | One runtime and store | Monorepo, services, queues, deployment planes | Architecture, subsystem maps, integration contracts |
| Stack | One familiar stack | Polyglot, client plus server plus infra | Scoped guides and stack-specific verification |
| Integrations | Few local calls | APIs, webhooks, identity, payment, async events | Interface contracts, ownership, failure behavior |
| Data | Simple local data | Shared schemas, migrations, PII, lineage | Generated references, data ownership, retention rules |
| Risk | Internal and reversible | Security, privacy, money, compliance, availability | Security, reliability, operational constraints |
| Delivery horizon | One-session tasks | Multi-stage work, migrations, programmes | Execution plans, decision history, handoffs |
| Coordination | One maintainer | Teams, agents, worktrees, ownership boundaries | Routes, ownership, local instructions, indexes |
| Change rate | Stable contracts | Frequent topology, dependency, or schema changes | Freshness checks and generated truth |
| Generated surface | Small and inspectable | Large APIs, schemas, config, clients | Reproducible generated references |

Do not use line count as a decision rule. A small payment service can require
more documentation than a large internal utility.

## Delivery profiles

### Compact

Typical shape: one runtime, one main workflow, one maintainer, low risk, and an
obvious layout.

Start with:

- a concise instruction entry point when agents need one;
- routes to the README, code, tests, and verification commands;
- an architecture overview only when boundaries are costly to infer.

Usually omit indexes, category directories, plan archives, health scores, and
cross-cutting guides.

### Growing

Typical shape: several workflows or components, recurring feature work, and a
small team.

Start with:

- root instructions and an architecture overview;
- focused product, domain, subsystem, or decision documents where facts are
  unsafe to infer;
- an index only when several documents require routing;
- execution plans for multi-session work.

Add contracts, generated references, or cross-cutting guides only when their
corresponding pressure exists.

### Established

Typical shape: several deployables or domains, concurrent work, non-trivial
operational risk, and long-running changes.

Start with:

- root routing, an architecture map, and a documentation index;
- indexed design and product or domain material;
- active and completed execution plans when repository-local planning is
  canonical;
- subsystem, integration, data, and cross-cutting guides for shared invariants;
- generated references with freshness checks.

### Federated

Typical shape: a monorepo, many domains or teams, several deployment planes,
concurrent agents, and strong reliability or compliance requirements.

Start with:

- a thin root router and root architecture map;
- domain-local indexes or scoped instructions when rules differ;
- explicit ownership for product, design, data, operations, security, and
  reliability truth;
- durable decision and plan history when work spans teams or quarters;
- reproducible generated references, health signals, and automated gardening
  when someone owns the measurement loop.

Keep routes shallow. Federation does not justify duplicating root rules in each
subtree.

## Promotion and demotion

Promote a capability when an agent cannot safely discover a fact, or when a
credible risk requires a durable constraint. Common triggers include:

- business behavior cannot be recovered from code and tests;
- an external contract, event, or schema has an unclear owner;
- an architectural choice has meaningful alternatives or consequences;
- active work cannot resume across sessions;
- security, privacy, money, or availability constraints are non-local;
- a large generated surface is too costly to inspect directly;
- several documents exist but agents cannot select the next source;
- concurrent ownership causes contradictory edits or duplicated truth.

Demote or omit a capability when its information is obvious, canonical and
accessible elsewhere, or cannot be maintained. For a greenfield repository,
use an accepted constraint or credible risk as evidence; mark unaccepted design
as `Proposed` or `Uncertain`.
