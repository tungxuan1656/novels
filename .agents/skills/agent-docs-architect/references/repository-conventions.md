# Repository Conventions

Use this convention for a new repository or when the current documentation
system is materially incomplete. Reuse an adequate repository-native convention
instead. Do not rename working sources merely to conform.

## Naming rules

- Use `AGENTS.md` for the root agent router when no equivalent entry point
  exists.
- Use `ARCHITECTURE.md` for the root system map when the repository needs one.
- Use uppercase root filenames for stable, cross-cutting entry documents such
  as `SECURITY.md` or `RELIABILITY.md`.
- Use lowercase `kebab-case.md` for topic documents, plans, and generated
  references.
- Use lowercase plural `kebab-case` directory names for collections.
- Put `index.md` in a collection only when it has several children that require
  routing. An index routes; it does not duplicate its children.
- Keep one topic per file. Split only when a file owns more than one class of
  truth or routes become unclear.

## Baseline maps

### Compact

```text
AGENTS.md                  # only when agents need a stable router
ARCHITECTURE.md            # only when topology is not obvious
```

Route to existing README, code, tests, and commands. Do not create `docs/` by
default.

### Growing

```text
AGENTS.md
ARCHITECTURE.md
docs/
├── product-specs/         # conditional
├── design-docs/           # conditional
└── exec-plans/            # conditional; only for multi-session work
```

Add `docs/index.md` only when the root router cannot select the relevant
focused source directly.

### Established or federated

```text
AGENTS.md
ARCHITECTURE.md
docs/
├── index.md
├── design-docs/
│   ├── index.md
│   ├── core-beliefs.md
│   └── <decision-or-topic>.md
├── product-specs/
│   ├── index.md
│   └── <domain-or-workflow>.md
├── exec-plans/
│   ├── active/
│   ├── completed/
│   └── tech-debt-tracker.md
├── generated/
│   └── <schema-or-inventory>.md
├── references/
│   └── <provider-or-tool>-llms.txt
├── DATA.md                 # conditional
├── FRONTEND.md             # conditional
├── OBSERVABILITY.md        # conditional
├── RELIABILITY.md          # conditional
└── SECURITY.md             # conditional
```

Create only the directories and documents justified by an assessment. Keep
domain-local documentation near the relevant code when it reduces routing
depth; keep repository-wide cross-cutting truth at the root.

## Migration rules

- Keep an existing adequate name and add routes to it.
- Rename or move only when discovery, ownership, or lifecycle is materially
  broken.
- Before moving or retiring a source, migrate canonical truth and incoming
  links.
- Treat generated files as outputs. Record the generator and source inputs.
- Treat external snapshots as copies with a source, version or date, and a
  refresh trigger.
