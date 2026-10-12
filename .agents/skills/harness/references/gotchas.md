# Core Failure Modes

| Failure | Smallest correction |
|---|---|
| Shared index or root progress becomes a merge hotspot | Keep execution state in each task or sufficient external tracker |
| Task files are mistaken for locks | Coordinate overlapping source ownership and integration |
| Syntax checks are called full verification | Run observed project checks; state uncovered behavior |
| Verification fixes source or suppresses failures | Use check-only modes, strict failure propagation, no installs |
| Docs/plans expand without changing a decision | Link canonical truth; delete unjustified phases, abstractions, and duplicated prose |

Preserve necessary security, data-integrity, accessibility, and recovery rules.
A short document that omits critical behavior is not a successful simplification.
Do not delete legacy history merely to reduce context.

See [migration](migration-v2.md), [handoff](memory-persistence-pattern.md), and
[coordination](multi-agent-pattern.md). The [runtime archive](gotchas-full.md)
is historical, engine-specific material, not Harness requirements.
