# AI Log and Cache Organization

- Status: done
- Owner: Codex
- Required to start: none
- Required to integrate/release: none

## Scope and Non-goals

Implement the approved split: an AI-processing timeline and the existing SQLite-backed Cache Manager. Preserve reader lifetime fixes, transport/retry behavior, cache keys, retention, and security. No persisted logs, second cache, schema migration, or new dependencies.

## Acceptance

- [x] Main log lists processing runs by book/chapter/mode, newest first, with reader/prefetch/manual origin, outcome, elapsed time, progress, and cause.
- [x] Request details expose attempts, endpoint/model, transport outcome, and RAM-only JSON; validation remains distinct from HTTP success.
- [x] Cache hits and general queue events no longer crowd the AI timeline; status/mode filters retain full selected-run context.
- [x] Cache Manager reads actual saved chapters/modes and update times from SQLite, with book titles and existing confirmed deletion actions.
- [x] Focused regression tests and full `./init.sh` pass.

## Sources

- [Diagnostics decision](../docs/decisions/diagnostic-log-viewer.md).
- [Local data contract](../docs/contracts/local-data.md).
- [Settings specification](../docs/product/functional-specs/settings-management.md).
- [Security](../SECURITY.md).

## Plan

1. Inspect log grouping, request lifecycle, and cache UI/query boundaries.
2. Implement AI run presentation and independently owned cache inventory with focused tests and canonical documentation.
3. Review, run full verification, and record handoff.

## Verification and Handoff

- Baseline: clean worktree; `./init.sh` passed (iPhone 17 Pro, iOS 26.5), `/tmp/novels-ai-log-baseline.log`.
- Ownership: parent owns Diagnostics, AI service/prefetch, docs/task/index; cache worker owns Cache Manager, metadata query/model, and cache tests.
- Implemented explicit consumer outcomes/source and linked shared requests; whole-run status/mode filters, concise API attempts, safe endpoint/model details, and a direct link to Cache Manager. Cache inventory queries metadata only and distinguishes saved versions from distinct chapters; database/deletion errors are visible instead of appearing empty or successful.
- Review: two independent read-only passes identified failure masking on cancellation, recovered HTTP errors obscuring local-cache errors, and lost origin context on failed shared consumers. All three are repaired with focused regressions; cancelled shared consumers remain independent of origin failures.
- Red evidence: `/tmp/novels-ai-log-review-red.log` and `/tmp/novels-ai-log-shared-red.log` reproduce the reviewed failures before their repairs.
- Final verification: `./init.sh` passed format, strict lint, build, and 113/113 unit tests (0 failed/skipped), iPhone 17 Pro / iOS 26.5 Simulator, `/tmp/novels-ai-log-final.log`. `git diff --check` passed. Existing actor-isolation warnings are unchanged and outside this task.
- Active LSP: changed Swift paths probed. Standalone SourceKit missing cross-file target symbols and a Vietnamese spelling warning are false positives, checked against the successful Xcode build/tests; no actionable new diagnostic remains.
- Coverage limits: no live provider request, physical-device UI inspection, or iOS 26.0 runtime check. Logs remain RAM-only (500 entries); cache is the existing SQLite store without schema migration.
- Blockers: none.
- Publication verification: `./init.sh` passed again before commit/PR, `/tmp/novels-ai-log-pr-verify.log` (iPhone 17 Pro / iOS 26.5 Simulator). Branch `task/history-refactor` includes the preceding reader-cancellation repair and this redesign.
- Handoff: verified implementation on branch `task/history-refactor`, approved for publication as a PR into `main`. Device/provider smoke testing remains a follow-up coverage limit.
