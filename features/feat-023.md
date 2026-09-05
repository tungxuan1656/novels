# feat-023 — Reader + Prefetch Correctness Round 2

## Goal

Fix four reported defects from live testing (stale chapter content 450/451, prefetch-count confusion 20-vs-3, frozen/misleading status vs cache-hit log, sliding-window chapter loss) plus resource worst-case guards, without changing shipped product contracts.

## Scope

- `ReaderViewModel.swift`: generation-guarded AI writes, `setAIMode` cancel, conditional nil-out, epoch-guarded poll, single cancel path, trigger debounce.
- `ReaderView.swift`: identity-gated AI section only (no layout/copy change).
- `PrefetchManager.swift`: log-only N fields, bounded in-batch retry, failed-first next window, overlap-preserving top-up, runtime cap, end-of-book message.
- `ProcessedChapterCache.swift`: chunked `batchStatus` + never-miss-all on query failure.
- `LogScreen.swift`: terminal-success contract for hit/shared/allCached, muted cancel (no red).
- `SettingsView(Model).swift` + `SettingsStore.swift`: effective-N display, truthful copy, one trim rule (range `0...1000 else 3` unchanged, no migration).
- `chapter-prefetch.md` (§4 Step 5) + `settings-schema.md` amendments only.
- Tests: new `ReaderStaleGuardTests.swift`; extend Prefetch/Settings/Log suites in place.

## Non-goals

- No durable FIFO queue, no event-driven status, no cache-version migration, no outer-chapter concurrency (roadmap in plan with owner decisions).
- No budget/timeout/range-policy changes; no new log event types or schema changes.
- No UI redesign, no copy changes beyond the settings editor truthfulness fix.

## Acceptance

- [x] ch450 + rewrite, prefetch 451 done, open Log, back → ch450 content stays ch450; rapid next/prev x5 → content always matches header; mode switch mid-spinner → no ghost content (`ReaderStaleGuardTests` 4/4 + generation/epoch guards).
- [x] `" 20"` saves as 20; invalid input message matches block behavior; Log `batchCheck` shows `effectiveN=20` (trim rule + effective row + storedN/effectiveN log).
- [x] Cache-hit group badges Success; cancel-on-navigate never red; Log peek + return resyncs status (badge contract + epoch-guarded poll + resync/resume tests).
- [x] Reported walk 450→451→450→451 shows continuous forward progress, no silent skip; transient failure retried once; steady reading ≈ 1 tail fetch per next (bounded retry + overlap top-up + debounce).
- [x] N=1000 behaves capped with honest message; query failure never mass-refetches; end-of-book message distinct (hardCap 10 + chunked batchStatus + keep-state).
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/plans/feat-023.md` (separate plan: 5 phases + roadmap)
- `docs/product/functional-specs/chapter-prefetch.md` (§4-5)
- `docs/contracts/settings-schema.md` (BR-08)
- `docs/product/flows.md` (§6)
- `ARCHITECTURE.md` §1/§5

## Plan

Separate (`docs/plans/feat-023.md`): 5 sequential phases (P1 state guard → P2 status/log → P3 count transparency → P4 bounded retry/window → P5 resource guards), each TDD with own acceptance; roadmap deferred with owner confirmations.

1. Lane R (reader/state): `ReaderViewModel.swift` + `ReaderView.swift` — Phases 1, 2-poll, 4-debounce, sequential.
2. Lane S (settings/log): Settings + `LogScreen` + manager log-only fields — Phase 3 + Phase 2-badge, may parallel Lane R Phase 1 (no shared files until merge).
3. Lane P (prefetch engine): `PrefetchManager` + `ProcessedChapterCache` — Phases 4-engine, 5, after Lane R Phase 1.

## Verify

- `./init.sh --quick` per phase (loop)
- `./init.sh` full to close
- Manual acceptance walks per phase (exact reported scenarios)

## Handoff

- State: done
- Evidence: Lane R `bfed666`/`634ae88`/`758a26e`/`b75f78c` + Lane S `360ebbb`/`af25fab` + Lane P `3ebf9de`/`9225cc9`/`33be48b`; all review loops closed (re-reviews clean, parked minors ledgered: R M1/M4 + S 11-14 + P log-spam); `./init.sh` full PASS 2026-09-06 (format 0/98, lint 0, build PASS, test PASS incl. StaleGuard/Grouping/Integration, drift 21/22)
- Blockers: none (tree uncommitted — not committed as not requested)
- Next: user retests on device/Simulator the 4 reported walks (450/451 content, N=20 prefetch, Log badge/state, 450→451→450→451 progress); roadmap items (durable queue, event-driven status, cache migration) need owner sign-off per plan
- Blockers: none (owner confirmations have plan defaults: hardCap 10, 1 in-batch retry, returnFromLog = zero-API-for-current, truthful block copy, budgets/timeouts unchanged)
- Next: Phase 0 baseline `./init.sh`, then Phase 1 Lane R
