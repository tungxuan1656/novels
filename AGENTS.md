# AGENTS.md

Novels is an offline-first iPhone reader with Vietnamese UI. Download one ZIP book package and read offline.
Support iOS 26.0+; app Debug and Release use device family `1`.

## Read When Needed

- Topology, toolchain, code boundaries and flows: [ARCHITECTURE.md](ARCHITECTURE.md).
- Product: [overview](docs/product/overview.md), [domain model](docs/product/domain-model.md), [business rules](docs/product/business-rules.md), [flows](docs/product/flows.md).
- Terms, integrations and feature behavior: [glossary](docs/product/glossary.md), [integrations](docs/product/integrations.md), `docs/product/functional-specs/`.
- Design: [navigation](docs/design/navigation.md), [screens](docs/design/screens.md), [design system](docs/design/design-system.md).
- Wire and storage contracts: [contracts index](docs/contracts/index.md).
- Decisions: [technical index](docs/decisions/index.md), [product decisions](docs/product/decisions.md), [SECURITY.md](SECURITY.md).
- Persistence and identity: [local persistence](docs/decisions/local-persistence.md), [book identity](docs/decisions/book-identity.md), [local data](docs/contracts/local-data.md), [settings](docs/contracts/settings-schema.md).
- Support scope and verification policy: [iOS scope](docs/decisions/ios-scope.md), [focused unit verification](docs/decisions/verification.md).
- Roadmap and task links: [tasks/index.md](tasks/index.md). Verification commands: `init.sh`.

Read the relevant spec or decision before changing product behavior or architecture. Ask when evidence conflicts.

## Repository Boundaries

- `apps/novels.xcodeproj`: shared `novels` scheme; one SwiftUI app module under `apps/novels/`.
- `apps/novelsTests/`: focused unit tests in separate files for difficult or high-risk logic. No UI tests or blanket coverage.
- Keep one processed-chapter SQLite cache; use FileManager/Codable for books and UserDefaults for settings/session.
- Do not introduce SwiftData, Core Data, Keychain, or background scheduling without an approved decision.
- Write docs, code and comments in English. Vietnamese is for user-facing strings and quoted UI examples.
- Preserve unrelated changes and the tracked sample ZIP. Follow [SECURITY.md](SECURITY.md) for secrets and logging.

## Work Scope

- Start only user-approved work. Keep changes inside its scope and acceptance criteria.
- Use no task record for small, clear work or read-only requests. Read only relevant sources.
- Use skill `harness-task` for non-trivial intake; select other installed skills only when relevant.
- Keep durable local work in `tasks/task-<slug>.md`; use descriptive slugs or existing tracker IDs, not global counters.
- Read the selected task and linked sources, not all task history.
- Keep bounded plans inline. Link a separate plan only for sequencing, coordination, or recovery needs.
- Keep durable behavior and decisions in canonical docs/tests, not task history.

## Ownership And Handoff

- Each task owns its status, owner, acceptance, dependencies, evidence, blockers and next action.
- Use `todo`, `active`, `blocked`, or `done`. Independent tasks can be active concurrently.
- Separate dependencies required to start from integration/release gates; do not serialize independent implementation.
- Agree file ownership or integration order before parallel edits. A task record is not a lock.
- `tasks/index.md` owns roadmap/navigation only. Update it when tasks or roadmap scope change, not on status changes.
- Update only the affected task at a material handoff. Do not create a shared root progress log.
- Record baseline failures; repair them only within approved scope. Ask about unclear ownership or repeated verification failures.
- Mark done only when acceptance passes and full verification evidence is recorded. Done does not require PR merge.
- Disclose uncommitted work and share an accessible PR, branch, or commit when handing off.
- Before removing a task, extract durable knowledge and check incoming links, dependents and the retention decision.

## Verification

- Full: `./init.sh` runs format, lint, build and focused unit tests. Run it before task completion, commit or push.
- Quick: `./init.sh --quick` (alias `-q`) runs format and lint, explicitly skipping build and unit tests.
- Help: `./init.sh --help`. Checks run sequentially and stop at the first failure.
- SwiftFormat and SwiftLint are required. Missing tools fail; verification never fixes source or installs dependencies.
- Build/test outputs are allowed. Unit tests isolate temporary data and bypass production startup.
- The staged-Swift pre-commit hook is a fast gate, not a substitute for full verification.
- Update `init.sh` and affected canonical docs when check commands or workspace modules change.
- Disclose coverage limits: iOS 26.5 simulator checks do not prove iOS 26.0 runtime behavior.

<!-- harness 2.0.0 | migrated 2026-10-12 | repository-specific rules retained -->
