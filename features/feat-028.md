# feat-028 — Exclude First Heading from AI Translation

## Goal

The first chapter heading renders as its own raw (untranslated) text, while the remaining body keeps the exact current join logic for AI translation.

## Scope

- `apps/novels/Domain/HtmlParser.swift`: shared `joinedBodyText` helper (single source of join truth; `firstHeadingText` added in Task 1 then removed in Task 3 when render unification made it unused).
- `apps/novels/Features/Reading/ReaderViewModel.swift` (`readRawTextForAI`) and `apps/novels/Services/PrefetchManager.swift` (prefetch join): use the shared helper with `excludingFirstHeading: true`.
- `apps/novels/Features/Reading/ReaderView.swift` + new `ReaderContentView.swift`: one shared block renderer for raw and AI modes (owner ruling: no parallel heading+body in AI branch; proper extract, no lint-limit change); AI branch renders heading block raw above translated body; sticky title untouched.
- `apps/novels/Persistence/ProcessedChapterCache.swift`: `user_version` 1→2 with one-time `DELETE FROM processed_chapters` so stale header-included entries are never served.
- Docs: `docs/contracts/ai-service.md`, `docs/product/functional-specs/ai-reading.md`.

## Non-goals

- No change to `br → "\n\n"`, whitespace collapse, `AIChunker` budget (default 1300), retry policy, or raw-mode rendering.
- No filtering of mid-chapter headings beyond the first heading block.
- No commit/PR unless user requests.

## Acceptance

- [x] AI input excludes the first heading block; body bytes are identical to current logic for heading-free chapters.
- [ ] AI reading shows raw heading + translated body; sticky title unchanged. (NOT verified — interactive Simulator walk impossible in this headless CLI environment; deferred to manual QA.)
- [x] Foreground rewrite and prefetch share one join implementation (no duplicated join code).
- [x] Pre-migration cache entries are never served after upgrade.
- [x] `./init.sh` full PASS.

## Relevant docs

- `docs/contracts/ai-service.md`
- `docs/product/functional-specs/ai-reading.md`
- `ARCHITECTURE.md` §1/§5

## Plan

Separate plan: `docs/plans/feat-028.md` (4+ files across parser/prefetch/render plus cache migration with invalidation sequencing — 2 substantial signals).

File ownership: single sequential writer (helper → callers → render → migration → docs; no parallel writers).

## Verify

- Baseline `./init.sh --quick`: PASS (2026-09-07; format PASS, lint PASS, drift PASS, build skipped)
- Full `./init.sh`: PASS (2026-09-07, single run, no flake — format 0/59, lint 0 violations in 59 files, build OK for iPhone 17 Pro / iOS 26.5 Simulator with only pre-existing warnings, drift PASS, no test targets by decision)
- Greps: `joinedBodyText(from:excludingFirstHeading:)` called with `true` in both `ReaderViewModel.readRawTextForAI` and `PrefetchManager`; only remaining `joined(separator: "\n\n")` outside the helper is the AI-output join in `AIReadingService` (chunk outputs, not raw body); `PRAGMA user_version=2` + one-time `DELETE FROM processed_chapters` on version 1 confirmed in `ProcessedChapterCache`
- Simulator walk: NOT performed — headless CLI environment with no interactive Simulator session or AI backend; acceptance box for raw-heading render left unchecked for manual QA

## Handoff

- State: done
- Evidence: Tasks 0–4 reviewed clean; Task 5 docs (`ai-service.md` heading-exclusion + version-2 invalidation, `ai-reading.md` same facts in product language), full `./init.sh` PASS 2026-09-07, grep evidence above; interactive Simulator walk deferred (see unchecked box)
- Blockers: none
- Next: run the interactive Simulator walk (heading chapter in Rewrite mode + prefetch over heading/heading-free chapters) as manual QA before release.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
