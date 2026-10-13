# Navigation Performance

- Status: done
- Owner: Codex
- Required to start: none
- Required to integrate/release: none

## Scope and Non-Goals

Fix reported hitches entering the AI Log and Cache Manager and returning from Settings to Home. Move expensive local reads off the main actor, avoid unchanged library reloads, reuse diagnostic grouping, and load cache details on expansion. Preserve book validation, diagnostic retention/redaction, reader work during Log navigation, and confirmed cache deletion. No new persistence, dependencies, or UI-test target.

## Acceptance

- [x] Local book scans and cache inventory/metadata reads for these screens do not run on the main actor.
- [x] Returning from Settings reuses the loaded library; import, deletion and pull-to-refresh still update it.
- [x] Cache counts distinguish versions and chapters without decoding all metadata on entry; book details load on demand.
- [x] Log remains current and book-scoped without rebuilding run groups for every UI read.
- [x] Cancellation or stale reads cannot overwrite newer state; storage failures remain visible and deletion stays scoped.
- [x] Focused regression tests and full `./init.sh` pass; device-testing limits are disclosed.
- [x] PR #42 follow-up: live Log runs use titles for existing books absent from the initial snapshot, with one background library scan rather than repeated per-ID validation.

## Sources

- [Architecture](../ARCHITECTURE.md)
- [Book library](../docs/product/functional-specs/book-library.md)
- [Settings and cache](../docs/product/functional-specs/settings-management.md)
- [Diagnostic viewer decision](../docs/decisions/diagnostic-log-viewer.md)
- [Local data](../docs/contracts/local-data.md)
- [Focused verification](../docs/decisions/verification.md)

## Plan

1. Make existing local-read boundaries concurrency-safe without weakening validation.
2. Update library refresh, cache summary/detail loading, and diagnostic presentation.
3. Add focused regressions, run full verification, and hand off the three navigation paths for physical-device testing.

## Verification and Handoff

- Baseline: clean worktree; investigation measured library scan warm median 18.44 ms on the Mac against simulator data (2 books / 2,170 chapters). Synthetic SQLite metadata decoding took about 59 ms for 2,000 versions and 292 ms for 10,000 versions. These are not iPhone animation measurements.
- Evidence (2026-10-13): full `./init.sh` passed SwiftFormat, strict SwiftLint (zero violations), simulator build and all 142 focused unit tests (zero failed or skipped). `git diff --check` passed. Simulator: iPhone 17 Pro, iOS 26.5.
- Focused coverage: `NavigationLoadingTests` checks off-main reads/deletion, library reuse/force/invalidation, cancelled and stale loads, retryable failures, lazy cache details, scoped deletion, and a run recovering during Log title loading. Additional tests cover SQLite inventory counts and observable diagnostic-group cache invalidation.
- Review: a bounded read-only review found the Log recovery window during background title loading; refreshing again before initial filtering fixes it and has a focused test. The review did not claim exhaustive coverage.
- Remaining diagnostics: existing actor-isolation warnings in unrelated AI/prefetch code remain outside scope. Standalone SourceKit probes lack Xcode cross-file target context and report missing symbols; these were marked false positive after the successful full build/tests, not suppressed in source.
- Limits: no physical-device frame timings or Instruments trace; iOS 26.5 simulator checks do not establish iOS 26.0 runtime behavior. Cache detail expansion still renders the existing per-version list; this change targets screen entry, not list virtualization.
- Manual validation (2026-10-13): user reported successful testing and requested a branch and PR. Device model, OS version and frame timings were not provided.
- Delivery: branch `perf/navigation-loading` for the requested PR. Canonical library and cache specs updated; no new dependencies or storage schema.
- Blockers: none for the implementation handoff.
- Next: re-review PR #42 with the title-loading repair; no merge requested.

## PR #42 Review Follow-Up

- Scope: restore titles for runs appearing after opening Log, including an initially empty Log, and avoid repeated folder/chapter validation when IDs differ from folder names. Reuse the existing validated background library scan; no new metadata reader or observer lifecycle.
- Reproduction: both new live-run regressions failed before the repair (wrong title, no library scan, per-ID lookup for the initial book).
- Focused verification: `NavigationLoadingTests` and `DiagnosticsObservationTests` pass after the repair, including the existing recovery-during-title-load test. Tests assert one off-main library scan and zero per-ID title lookups.
- Synthetic benchmark on the Mac, not device frame timing: 24 books / 1,920 chapters, six warmed samples. Matching folder/ID: previous per-ID lookup median 12.43 ms, single background scan 11.37 ms. ID drift: 119.70 ms versus 8.91 ms. Both mappings were asserted equal; full book validation remains unchanged.
- Full verification (2026-10-13): `./init.sh` passed SwiftFormat, strict SwiftLint (zero violations), simulator build and all 144 unit tests (zero failed or skipped) on iPhone 17 Pro / iOS 26.5. `git diff --check` passed. The new tests wait for observer readiness before appending the later run; initial readiness uses a non-run marker because assigning an unchanged snapshot does not trigger Observation.
- Review: bounded independent current-source review found no confirmed defect in the named repair paths; it did not inspect raw Git diff or run builds/tests. Parent inspected the diff and ran the full gate. Active SourceKit probes on the four changed Swift files timed out; compiler/test results, not empty diagnostics, are the verification evidence.
- Delivery: repair stays on `perf/navigation-loading` in PR #42. No architecture refactor, optional `refresh()` equality optimization, or device-performance claim.
