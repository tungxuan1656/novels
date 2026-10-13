# AI Log and Cache Organization

- Status: done
- Owner: Codex
- Required to start: none
- Required to integrate/release: native Reader -> Log -> Cache -> Reader smoke testing remains a merge gate; see the re-review coverage limit.

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

## PR #41 Follow-up

User-approved scope: repair the reviewed warning/filter mismatch and hidden configuration events; retain pending AI jobs during cache deletion and explain possible repopulation. Correct the append-only log contract without changing retention.

- [x] Book-scoped failed-run counts drive both the Reader warning and initial Log filter; recovered retries do not count as failed runs.
- [x] Invalid headers/body warnings are searchable and inspectable, including shared request context.
- [x] Cache deletion confirmations explain that pending AI work continues; deterministic tests cover all/per-book deletion before response release.
- [x] The contract describes presentation-only attempt coalescing over the append-only 500-entry ring.
- [x] Full verification passes and the follow-up commit is pushed to the existing PR branch.

## PR #41 Re-review

Repair the two remaining P2 findings without changing request behavior or retention. Reuse this task: parser validity and live Reader warning complete the approved Diagnostics scope. Parent owns production code/observation tests/docs; test worker owns configuration-warning integration tests and their existing URLProtocol fixture visibility.

1. Reproduce invalid JSON warnings through SettingsStore -> AIClient -> DiagnosticsLog and trace sheet observation.
2. Share object parsing, snapshot warning validity before generated headers, and observe Diagnostics for the visible sheet lifetime.
3. Verify focused regressions/full checks, attempt isolated native navigation smoke testing, and update the existing PR.

- [x] Invalid/non-object JSON emits the correct warning even with generated headers; blank/valid empty objects emit none. Request merging and secret-safe summaries are unchanged.
- [x] The Reader sheet follows new failed/recovered run outcomes while visible and releases its observer on dismissal.
- [x] Integration/observation regression tests and full verification pass; record native navigation evidence or an exact blocker without claiming unit tests prove UI behavior.

## Verification and Handoff

- Baseline: clean worktree; `./init.sh` passed (iPhone 17 Pro, iOS 26.5), `/tmp/novels-ai-log-baseline.log`.
- Ownership: parent owns Diagnostics, AI service/prefetch, docs/task/index; cache worker owns Cache Manager, metadata query/model, and cache tests.
- Implemented explicit consumer outcomes/source and linked shared requests; whole-run status/mode filters, concise API attempts, safe endpoint/model details, and a direct link to Cache Manager. Cache inventory queries metadata only and distinguishes saved versions from distinct chapters; database/deletion errors are visible instead of appearing empty or successful.
- Review: two independent read-only passes identified failure masking on cancellation, recovered HTTP errors obscuring local-cache errors, and lost origin context on failed shared consumers. All three are repaired with focused regressions; cancelled shared consumers remain independent of origin failures.
- Red evidence: `/tmp/novels-ai-log-review-red.log` and `/tmp/novels-ai-log-shared-red.log` reproduce the reviewed failures before their repairs.
- Final verification: `./init.sh` passed format, strict lint, build, and 113/113 unit tests (0 failed/skipped), iPhone 17 Pro / iOS 26.5 Simulator, `/tmp/novels-ai-log-final.log`. `git diff --check` passed. Existing actor-isolation warnings are unchanged and outside this task.
- Active LSP: changed Swift paths probed. Standalone SourceKit missing cross-file target symbols and a Vietnamese spelling warning are false positives, checked against the successful Xcode build/tests; no actionable new diagnostic remains.
- Coverage limits: no live provider request, physical-device UI inspection, or iOS 26.0 runtime check. Logs remain RAM-only (500 entries); cache is the existing SQLite store without schema migration.
- Implementation blockers: none. Native navigation verification remains a separate merge gate, not a successful runtime check.
- Publication verification: `./init.sh` passed again before commit/PR, `/tmp/novels-ai-log-pr-verify.log` (iPhone 17 Pro / iOS 26.5 Simulator). Branch `task/history-refactor` includes the preceding reader-cancellation repair and this redesign.
- Handoff: verified implementation on branch `task/history-refactor`, published as PR #41 into `main`. Device/provider smoke testing remains a follow-up coverage limit.
- PR #41 follow-up red evidence: `/tmp/novels-pr41-followup-red.log` reproduced recovered-retry warning, book-scope, and hidden configuration-warning regressions before repair.
- PR #41 follow-up verification: `./init.sh` passed format, strict lint, build, and 119/119 unit tests (0 failed/skipped), iPhone 17 Pro / iOS 26.5 Simulator, `/tmp/novels-pr41-followup-full.log`. Deterministic URLProtocol gates verified all/per-book deletion finishes before the pending response is released and cache is recreated afterward.
- PR #41 follow-up review: an independent read-only review of connected code/tests and the supplied complete diff found no findings. Build/tests were rerun by the parent, not the reviewer. Active LSP reported no actionable new errors; `git diff --check` passed.
- PR #41 re-review red evidence: `/tmp/novels-pr41-rereview-red.log` reproduced real malformed-header warning suppression, valid-empty-body false warnings, and missing initial observer snapshots. A fixture-only missing run.start and an async XCTest autoclosure were corrected during test development.
- PR #41 re-review verification: nine focused integration/observation tests passed; `./init.sh` passed format, strict lint, build, and 128/128 tests (0 failed/skipped), iPhone 17 Pro / iOS 26.5, `/tmp/novels-pr41-rereview-full.log`. Request defaults/auth overrides, cancellation/cache behavior, and secret-safe warning summaries remain covered. Active LSP checked seven changed Swift paths with no actionable new errors; standalone test-module errors are false positives against the successful Xcode tests.
- PR #41 re-review: independent read-only review of the actual diff and connected code found no findings. The reviewer did not run builds/tests or inspect native UI; full verification is author-run evidence.
- Native smoke execution limit: the delegated run exhausted its 35-turn budget after provisioning/booting a dedicated iOS 26.5 simulator (`731AA646-F83D-45B0-922F-5BE8514410C5`) and tearing it down. No app navigation, fixture gateway, pending-response flow, or live sheet-warning injection was executed. This is a verification gap, not an environmental denial or a runtime pass. The existing simulator and user data were not touched; no repository files were changed by this run.
- PR #41 follow-up publication: repairs pushed as `5badfe4` on `task/history-refactor` to https://github.com/tungxuan1656/novels/pull/41. PR #41 re-review handoff: the verified P2 repair is on the same branch for publication to the existing PR. Next action before merge: native Reader -> Log -> Cache -> Reader smoke testing during a pending request, plus a new failure while the Reader sheet remains visible. Native navigation, physical-device, live-provider, and iOS 26.0 runtime behavior remain unverified.
