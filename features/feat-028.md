# feat-028 — Title + Single Body String Reader (amended)

## Goal

Each HTML chapter becomes one optional title + one plain body string. Both raw and AI modes render the raw title on top (body font + 8, bold) plus a single body `Text`. No bold/italic emphasis anywhere. The body string IS the AI input and the AI output is a single string.

## Scope

- `apps/novels/Domain/HtmlParser.swift`: `parseChapter(html:) -> (title: String?, body: String)` replaces the blocks/spans machinery (Tasks 0–2 `parse`/`joinedBodyText` superseded).
- Delete: `apps/novels/Domain/TextSpan.swift`, `apps/novels/Features/Reading/ReaderContentView.swift` (Task 3 renderer superseded).
- `apps/novels/Features/Reading/ReaderViewModel.swift`: `blocks` → `chapterTitle`/`chapterBody`; AI input is the body directly.
- `apps/novels/Features/Reading/ReaderView.swift`: title + single `Text` per mode; sticky `【num】` + title-or-fallback chain kept.
- `apps/novels/Services/PrefetchManager.swift`: body string direct to AI.
- `apps/novels/Persistence/ProcessedChapterCache.swift`: `user_version` 1→2 one-time clear already landed (same unmerged branch — no new migration).
- Docs: `book-reader.md`, `flows.md`, `ai-reading.md`, `ai-service.md`, `local-persistence.md`, `screens.md` (spans/blocks → title + string).

## Non-goals

- No change to `br → "\n\n"` paragraph breaks, whitespace collapse, `AIChunker` budget (default 1300), or retry policy.
- No new cache migration (same branch as the v2 clear).
- Mid-chapter headings merge their text into the body (no styling, no text loss); title takes the first heading only.
- No commit/PR unless user requests.

## Acceptance

- [ ] `parseChapter` returns first-heading title (nil when absent) + plain body; heading-free bodies byte-identical to the old join output.
- [ ] Raw and AI modes render title (body + 8, bold, never translated) + single body `Text`; no emphasis anywhere.
- [ ] No `TextBlock`/`TextSpan`/`ReaderContentView`/`fontFor`/`joinedBodyText`/`firstHeadingText` remains in Swift sources.
- [ ] AI input is the body string by construction; pre-migration entries never served (v2 clear).
- [ ] Docs describe title + string (no spans language); `./init.sh` full PASS; Simulator walk recorded.

## Relevant docs

- `docs/contracts/ai-service.md`
- `docs/product/functional-specs/ai-reading.md`
- `docs/product/functional-specs/book-reader.md`
- `ARCHITECTURE.md` §1/§5

## Plan

Separate plan: `docs/plans/feat-028.md` (Tasks 0–5 landed the exclusion + migration; Tasks 6–7 simplify to title + string per owner ruling 2026-09-07).

File ownership: single sequential writer; no parallel writers.

## Verify

- Baseline `./init.sh --quick`: PASS (2026-09-07; format PASS, lint PASS, drift PASS, build skipped)
- Full `./init.sh` (Tasks 0–5 scope): PASS (2026-09-07, single run, no flake)
- Amended scope: Tasks 6–7 re-verify (quick per task, full + walk to close)

## Handoff

- State: active (reopened 2026-09-07: scope amended from blocks-unification to title + string; Tasks 0–5 evidence stands for exclusion + migration)
- Evidence: `docs/plans/feat-028.md` Tasks 6–7; recon 2026-09-07 (no doc requires emphasis; blast radius mapped)
- Blockers: none
- Next: Task 6 simplify, Task 7 docs + full verify + walk, then done.

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
