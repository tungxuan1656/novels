# Tolerant AI Response Decoding & Shape Diagnostics

- Status: done
- Owner: Tung Doan
- Required to start: [feat-016](task-manual-retry-loading.md)
- Required to integrate/release: none
- Previous ID: feat-017

## Scope and non-goals

Support non-standard HTTP 200 AI response shapes and instrument detailed diagnostic shape metadata without logging raw prompt or payload secrets:
- Tolerant decoding in `AIResponse.swift`: decode optional `content`, `reasoning_content` (`reasoningContent`), and `tool_calls` (`toolCalls`); fallback logic resolves trimmed `content` if non-empty, otherwise trimmed `reasoning_content`, throwing standard `noResponse` only if neither contains text.
- Diagnostic shape inspection in `AIClient.swift`: on decoding failure or empty response, inspect top-level JSON keys (up to 10), choices count, content kind, reasoning flag, and tool call presence using `JSONSerialization`.
- Log presentation: add shape diagnostic fields to `LogEntry` and `DiagnosticsLog`, displaying structural metadata in expanded log views. Note: log viewer layouts and structured entries were later refined in [task-chapter-run-json-log](task-chapter-run-json-log.md) and [task-log-viewer-correctness](task-log-viewer-correctness.md); consolidated rewrite behavior is governed by [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).

Non-goals: No additional retry logic, no treating arbitrary JSON envelopes (`{data: ...}`) as valid content, and no logging of full bodies or auth secrets.

## Acceptance

- [x] 200 `content:null` + non-empty reasoning → success with reasoning content.
- [x] 200 `choices:[]` / tool-only / odd envelope → same noResponse pill as before, but Log has distinguishing shape fields.
- [x] No entry contains raw body/prompt/auth.
- [x] `./init.sh` full PASS.

## Sources

- [ARCHITECTURE.md](../ARCHITECTURE.md)
- [docs/contracts/ai-service.md](../docs/contracts/ai-service.md)
- [docs/decisions/diagnostic-log-viewer.md](../docs/decisions/diagnostic-log-viewer.md)
- [SECURITY.md](../SECURITY.md)
- [apps/novels/Services/AIClient.swift](../apps/novels/Services/AIClient.swift)
- [apps/novels/Domain/](../apps/novels/Domain/)

## Verification and handoff

- Evidence: Historical verification passed at feature completion. Executed `./init.sh` full PASS across format, lint, build, test, and drift. Targeted tests verified reasoning fallback, tool call handling, empty choices handling, and secret redaction. Behavior was subsequently consolidated in [task-rewrite-prefetch-correctness](task-rewrite-prefetch-correctness.md).
- Blockers: None.
- Next: HISTORICAL: Manual verification of non-standard provider responses and shape log rows.
