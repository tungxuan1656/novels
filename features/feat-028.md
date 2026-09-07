# feat-028 — Exclude First Heading from AI Translation

## Goal

The first chapter heading renders as its own raw (untranslated) text, while the remaining body keeps the exact current join logic for AI translation.

## Scope

- `apps/novels/Domain/HtmlParser.swift`: shared `joinedBodyText` + `firstHeadingText` helpers (single source of join truth).
- `apps/novels/Features/Reading/ReaderViewModel.swift` (`readRawTextForAI`) and `apps/novels/Services/PrefetchManager.swift` (prefetch join): use the shared helper with `excludingFirstHeading: true`.
- `apps/novels/Features/Reading/ReaderView.swift`: AI branch renders raw heading `Text` + translated body `Text`; raw mode and sticky title untouched.
- `apps/novels/Persistence/ProcessedChapterCache.swift`: `user_version` 1→2 with one-time `DELETE FROM processed_chapters` so stale header-included entries are never served.
- Docs: `docs/contracts/ai-service.md`, `docs/product/functional-specs/ai-reading.md`.

## Non-goals

- No change to `br → "\n\n"`, whitespace collapse, `AIChunker` budget (default 1300), retry policy, or raw-mode rendering.
- No filtering of mid-chapter headings beyond the first heading block.
- No commit/PR unless user requests.

## Acceptance

- [ ] AI input excludes the first heading block; body bytes are identical to current logic for heading-free chapters.
- [ ] AI reading shows raw heading + translated body; sticky title unchanged.
- [ ] Foreground rewrite and prefetch share one join implementation (no duplicated join code).
- [ ] Pre-migration cache entries are never served after upgrade.
- [ ] `./init.sh` full PASS.

## Relevant docs

- `docs/contracts/ai-service.md`
- `docs/product/functional-specs/ai-reading.md`
- `ARCHITECTURE.md` §1/§5

## Plan

Separate plan: `docs/plans/feat-028.md` (4+ files across parser/prefetch/render plus cache migration with invalidation sequencing — 2 substantial signals).

File ownership: single sequential writer (helper → callers → render → migration → docs; no parallel writers).

## Verify

- Baseline `./init.sh --quick`: —
- Full `./init.sh`: —

## Handoff

- State: active
- Evidence: plan approved by owner; branch `feat/028-exclude-heading-from-ai` created for implementation
- Blockers: none
- Next: Task 0 baseline, then Tasks 1–5 via subagent-driven execution.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
