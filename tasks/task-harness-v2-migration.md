# Harness V2 Migration

- Status: done
- Owner: Tung Doan
- Required to start: none. User approved the migration and retention choice.
- Required to integrate/release: none recorded.

## Scope And Non-Goals

Replace v1 execution state with 31 concise task records and a navigation-only index.
Preserve useful decisions/evidence before deleting redundant features, root progress and completed plans.
Use task-local ownership, dependency gates and handoffs. Simplify verification without changing coverage or app code.
No feature implementation, new dependencies, CI, UI tests or permanent state validator.

## Acceptance

- [x] All 31 legacy IDs map uniquely; status, dependencies, acceptance and useful handoffs survive.
- [x] No live v1 routes, global active limit, counter, root progress log or duplicated index state remain.
- [x] Unique durable knowledge has a canonical home; deleted legacy originals remain recoverable in Git.
- [x] `init.sh` is executable, check-only, root-resolving, sequential and fail-fast; missing tools fail.
- [x] Full verification and migration route/dependency checks pass; independent review findings are addressed.

## Inline Plan And Ownership

1. Inspect baseline, retention, dependencies and historical residue.
2. Convert tasks, repair routes and remove approved redundant artifacts.
3. Verify the wrapper, application checks, links/dependencies and independent review; then update provenance.

Parent owns router, verification, canonical repairs, index, migration record, final two legacy conversions and deletion.
Task-conversion worker owns the first 29 task records. History reviewer is read-only. Integration is parent-owned after worker completion.

## Historical Evidence

Baseline and migrated full `./init.sh` passed on iPhone 17 Pro/iOS 26.5; latest XCResult reports 13/13 passed, zero failed/skipped.
The owner selected concise records for all 31 deliveries, Tung Doan ownership, and deletion after extraction.
All old and migrated feature bodies were inspected; checkbox flags and dependency sets match for all 31 IDs. Historical exceptions and parked proposals remain explicit.
Latest one-off checks pass: 489 local links, acyclic dependencies, unchanged app/dependencies/hooks, 12 wrapper runtime cases, Bash syntax and Git whitespace.
Initial LSP checks reported no diagnostics across 45 files. The nine-path follow-up reports only two spelling suggestions for the owner's name, no errors. No permanent validator was added.

Removed 51 approved legacy files: feature/index/progress artifacts and 17 redundant completed plans; removed both empty directories. No live v1 routes remain.
Post-removal full verification passes; XCResult again reports 13/13 passed, zero failed/skipped. The independent review reports no actionable findings; its runtime evidence relies on the parent-run checks.
V2 provenance was initially recorded after these checks; late review corrections were verified afterward. Historical initial handoff: delivery was uncommitted, with no commit, push or PR yet.

Late review found two canonical gaps after removal. Original plans were recovered from Git to preserve import replacement/presentation and tolerant ID resolution. Both repairs pass bounded independent review. Historical prefetch proposals and M3 recovery remain preserved, not approved work.
Retry full verification passes (13/13 tests, zero failed/skipped); log: `/tmp/novels-harness-v2-retry.log`.

## Current Handoff

- Published delivery: [PR #38](https://github.com/tungxuan1656/novels/pull/38), branch `feat/update-skills-and-harness`; open, awaiting review/merge.
- Published HEAD: `61d5dbada62d85a305ed019a0d9011d08987854e` (five commits), confirmed with `gh pr view 38`.
- Review follow-up: restored skill version metadata `2.0.0`, refreshed delivery state, and documented non-atomic copy recovery. These local follow-up fixes are not committed or pushed. Swift and verification commands are unchanged.
- Follow-up verification: full `./init.sh` passes on iPhone 17 Pro/iOS 26.5; XCResult confirms 13/13 tests, zero failed/skipped. Log: `/tmp/novels-pr38-review-fixes.log`. Metadata/changelog/provenance consistency, handoff/local-link assertions, Bash syntax and Git whitespace checks pass. Active LSP checks report no diagnostics across the four changed paths.
- Blockers: none.
- Next action: owner review and publish this follow-up to existing PR #38 for re-review; do not create another PR.
- Limits: no physical-device or iOS 26.0 runtime QA; existing Swift 6 warnings and non-atomic copy recovery remain. Historical task acceptance/evidence does not re-certify those deliveries.
