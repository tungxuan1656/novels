# feat-025 — Log Viewer Correctness (title + realtime + grouping)

## Goal

The log stops showing duplicate titles, updates itself while open, and groups
correctly by run — still minimal, RAM-only, no over-engineering.

## Scope

- `apps/novels/Features/Diagnostics/LogScreen.swift`: filter `bookId` before
  `build()` + per-entry `initialFilter`; origin title from `sorted.last` with a
  source suffix (`API done/total` / `"Cache"` / `"Dùng chung"`); status no longer
  sticky-failed via sort-desc timestamp comparison (strictly newer terminal
  success wins, ties read failed; muted-cancel / keyHash-join / skip rules kept);
  `shortEvent` bounded to 16 chars; `groupCell` shows `N items · HH:mm:ss–HH:mm:ss`
  (date added when the range spans days); `positionText` drops `bookId` when
  already filtered; JSON gated on `body != nil`; intra-group entry filtering +
  auto-expand + `Divider()`; footnote when the count reaches 500.
- `apps/novels/Services/DiagnosticsLog.swift`: `append` yields a Void tick with
  no Task capture in the actor; `updates()` single-subscriber stream with
  newest-1 buffering + `subscribe()` generation tokens so a stale cancel never
  kills a fresh subscription; `DiagnosticsStore.observe()` debounces 250ms on
  the MainActor, flushes the final refresh, and ends only its own generation
  on cancellation; `.refreshable` on `LogScreen`; `errorCount` reuses
  `LogEntry.isError` (same definition as the
  error filter — HTTP >= 400, error domain/code, fail/error/timeout/cancel
  markers, muted cancels excluded).
- `apps/novels/Domain/DiagnosticsEntry.swift`: `LogEntry` gains an injectable
  `timestamp` (defaults to now) so ordering tests are deterministic, plus the
  shared `cancelReason` / `isMutedCancel` / `isError` predicates so Services
  and Features use one definition.
- Tests: update `LogScreenGroupingTests` + `DiagnosticsLogTests` only where
  behavior changed on purpose.

## Non-goals

- No ring growth past 500, no body persistence, no Picker/new chips, no flat
  search, no bulk toolbar, no complex highlight, no per-group `isPartial` flag,
  no 1s polling.

## Acceptance

- [x] Opening from a book shows only that book's logs; `initialFilter=.error`
      auto-expands failed groups.
- [x] No two identical titles: `"Rewrite · Ch 455 · API 3/5"` vs
      `"Rewrite · Ch 455 · Cache"`.
- [x] New entries appear while staying on screen (debounced); pull-to-refresh
      works; leaving the screen ends observation (no zombie task).
- [x] Old fail + later retry success reads `"Thành công"`; tied timestamps read
      failed.
- [x] Search expands only matching groups and shows only matching entries inside.
- [x] JSON opens from any entry with a body, bounds kept, never an empty sheet.
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/product/functional-specs/` (log viewer)
- `docs/design/screens.md`
- `docs/contracts/ai-service.md`
- `ARCHITECTURE.md` §1/§5

## Plan

1. P0 grouping/filter/title + strict-newer status
   (`LogRunBuilder.build/makeGroup/status/title`, `runGroups/filteredGroups`).
2. P1 realtime `AsyncStream` (actor yields, MainActor debounces) + `.refreshable`
   + `errorCount` reuses `isError`.
3. P1 preview/detail/JSON + burst intra-filter + divider + auto-expand +
   footnote at 500.
4. Update tests only where behavior changed on purpose; quick check each step,
   full check at sign-off.

## Verify

- `./init.sh --quick` each step
- `./init.sh` full at sign-off
- Targeted: `LogScreenGroupingTests`, `DiagnosticsLogTests`

## Handoff

- State: done
- Evidence: `./init.sh` full PASS 2026-09-06 (format 0, lint 0 --strict, build PASS, test PASS incl. LogScreenGroupingTests + DiagnosticsLogTests, drift PASS 21/22)
- Blockers: none (tree uncommitted — not committed as not requested)
- Next: repo idle — user retests Log screen (book filter, API vs Cache titles, realtime, retry success, search, JSON) on Simulator
