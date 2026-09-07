# feat-030 — Auto-inject x-opencode-session per chapter

## Goal

Every AI chunk POST carries a stable `x-opencode-session` header derived from the chapter, so opencode can route consistently and reuse prompt cache, with zero Settings changes.

## Scope

- `apps/novels/Services/AIClient.swift`: derive session value from `AIDiagnosticsContext` and inject when the user did not supply the header.
- `docs/contracts/ai-service.md`: document the auto-inject behavior, override rule, value format, and stability scope.

## Non-goals

- No new Settings key, no Settings UI, no `settings-schema.md` change (current-keys-only stays intact).
- No provider detection (`localhost`/`opencode` sniffing); injection is unconditional when missing — unknown headers are ignored by other providers.
- No change to local `processed_chapters` cache key, retry policy (2 attempts/chunk), chunking, or log redaction rules.
- No test targets (repo decision: build-only verification).

## Acceptance

- [x] Chunk POSTs include `x-opencode-session: novels-<bookId>-c<N>-<mode>` when `AI_CUSTOM_HEADERS` lacks it (case-insensitive).
- [x] User-supplied `x-opencode-session` in `AI_CUSTOM_HEADERS` wins verbatim; app never overwrites it.
- [x] Same chapter shares one session across parallel chunks and both retry attempts; different chapters get different sessions.
- [x] Empty context (`bookId == ""` or `chapterNumber <= 0`) sends no auto header (no `novels--c0-` garbage).
- [x] Full `./init.sh` PASS.

## Relevant docs

- `docs/contracts/ai-service.md` (Request Construction §3, Rules, Examples)
- `ARCHITECTURE.md` §1/§5

## Plan

Bounded inline: 2 files, 1 workspace, <200 lines. Two SDD lanes (code + docs) run parallel — disjoint files, no ownership overlap.

### Task 1 (code lane): Inject derived session header in AIClient

File: `apps/novels/Services/AIClient.swift`
Call site: `complete(prompt:chunk:context:)` line ~53:
`let headers = Self.effectiveRequestHeaders(settingsSnapshot.headers, family: family)`
Helper: `effectiveRequestHeaders(_:family:)` lines 291-302 (currently only injects `anthropic-version` for `.anthropic`).

Change (verbatim names):

1. Add helper next to `effectiveRequestHeaders`:
```swift
static func openCodeSessionValue(bookId: String, chapterNumber: Int, mode: String) -> String {
    guard !bookId.isEmpty, chapterNumber > 0 else { return "" }
    let safeBook = bookId.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    guard !safeBook.isEmpty else { return "" }
    let safeMode = mode.isEmpty ? "rewrite" : mode.lowercased().filter { $0.isLetter || $0.isNumber || $0 == "-" }
    return "novels-\(safeBook)-c\(chapterNumber)-\(safeMode)"
}
```

2. Extend the helper signature (keep old callers compiling — there is only the one call site, update it):
```swift
static func effectiveRequestHeaders(
    _ headers: [String: String],
    family: AIEndpointFamily,
    openCodeSession: String = ""
) -> [String: String] {
    var out = headers
    if family == .anthropic,
       !out.keys.contains(where: { $0.lowercased() == "anthropic-version" }) {
        out["anthropic-version"] = "2023-06-01"
    }
    if !openCodeSession.isEmpty,
       !out.keys.contains(where: { $0.lowercased() == "x-opencode-session" }) {
        out["x-opencode-session"] = openCodeSession
    }
    return out
}
```
Keep the existing anthropic behavior byte-identical (inject only when missing, user value wins).

3. Update the call site to thread the context through (context is already a parameter of `complete`):
```swift
let openCodeSession = Self.openCodeSessionValue(
    bookId: context.bookId,
    chapterNumber: context.chapterNumber,
    mode: context.mode
)
let headers = Self.effectiveRequestHeaders(
    settingsSnapshot.headers,
    family: family,
    openCodeSession: openCodeSession
)
```
Everything downstream (retry loop lines 92+, both attempts share `headers`) is untouched, so both attempts of one chunk and all parallel chunks of one chapter (same `context.bookId/chapterNumber/mode`, differing only in `chunkIndex`) share the session. Prefetch chapters each build their own context, so each chapter gets its own session.

Constraints:
- Only touch `AIClient.swift`. No SettingsStore, Diagnostics, or cache changes.
- Case-insensitive compare for the existing key (a user writing `X-Opencode-Session` still wins).
- No logging changes: session ID flows through existing `headersRedacted` path (only `Authorization` is `<redacted>`); do not add raw prompt/body to logs.
- Keep `actor` isolation and `MainActor` settings snapshot untouched.

Verify for Task 1: `./init.sh --quick` PASS (format + lint + drift).

### Task 2 (docs lane): Document auto-inject in ai-service.md

File: `docs/contracts/ai-service.md`. English prose, sentences <= 25 words.

1. In Request Construction step 3 (custom headers merge), append: when merged headers lack `x-opencode-session` (case-insensitive) the app injects `x-opencode-session: novels-<bookId>-c<chapter>-<mode>` derived from the chapter context; a user-supplied value wins verbatim; empty context sends no header.
2. In Rules, add one bullet with the same behavior in one sentence.
3. In Examples, add: `x-opencode-session: novels-van-gioi-c12-rewrite` on the canonical chat example line.

Constraints: touch only `ai-service.md`. No `settings-schema.md`, product, or design doc changes. No secrets.

Verify for Task 2: `./init.sh --quick` PASS (drift must stay PASS).

## Verify

- Per lane: `./init.sh --quick` PASS (Task 1: format+lint+drift; Task 2: format 0, lint 0/57, drift PASS).
- Final full `./init.sh`: PASS — format 0, lint 0, build PASS iPhone 17 Pro iOS 26.5, drift PASS 21/22, `=== Verification passed ===` (only pre-existing Swift 6 `await` warnings in `AIReadingService.swift`, untouched).
- Task reviews: ora-1 Task 1 Approved + Task 2 Approved; final whole-branch review Clean, safe-to-merge.
- `git diff --stat` (merge-base `ac02f7f`..HEAD): exactly 2 files — `apps/novels/Services/AIClient.swift`, `docs/contracts/ai-service.md` (+ harness scaffolding `feature_index.json` + this file).

## Handoff

- State: done
- Evidence: commits `efacc29` (code) + `96e7ac5` (docs) on `feat/030-opencode-session`; ledger `.agent-work/sdd/feat-030/progress.md`
- Blockers: none
- Next: merge PR to main on request; no commit/push done (not requested).

<!-- harness-slim 1.4.0 · generated 2026-08-24 -->
