# Changelog — harness-slim

All notable changes to `harness-slim` templates and mirrored rules. Agent reads only entries between installed repo marker and current skill `metadata.json` version.

Maintainer rule: every change that affects `templates/*` or rules mirrored into `AGENTS.md`/`init.sh` must bump `metadata.json` version and add an entry here. Archive old majors to `CHANGELOG.archive.md` when this file exceeds ~2 major versions.

Types: `breaking-rules` (AGENTS.md rules), `breaking-script` (init.sh structure), `additive` (new field/section), `non-breaking-doc` (skill-side docs only, no repo action).

## 1.4.0 — 2026-08-21

| Change | Artifact | Type | Update action |
|---|---|---|---|
| Feature-tracking decision table (No feature / Inline / External with >=2 signals) | `templates/agents.md` (Plans) + `SKILL.md` §Create or update artifacts | breaking-rules | Replace the two `Plans` bullets in `AGENTS.md` with the 3-row decision table from `SKILL.md`. Do not create `docs/plans/` for bounded work. |
| `init.sh` BUILD/TEST guard (fail if no BUILD/TEST tasks while evidence exists) | `templates/init.sh` | breaking-script | Insert guard block after `MAX_JOBS` validation: `if [ "${#BUILD_TASKS[@]}" -eq 0 ] && [ "${#TEST_TASKS[@]}" -eq 0 ]; then echo FAIL...; exit 2; fi`. Do not modify task arrays. |
| Slim `references/gotchas.md` to 5 core failure modes, archive 15 to `gotchas-full.md` | `references/gotchas.md` | non-breaking-doc | none — skill-side reference only, no repo change |

Notes: repos with marker `<!-- harness-slim 1.3.x -->` or earlier should apply both breaking rows above with surgical edits and user approval.

## 1.3.0 — 2026-08-15 (example placeholder for prior baseline)

- Initial slim baseline before 1.4.0. Future entries follow same table format.
