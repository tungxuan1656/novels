# feat-017 — Tolerant 200 Decode + Shape Logging

## Goal

HTTP 200 with an odd shape (`content:null` + `reasoning_content`, `choices:[]`, `tool_calls`, envelope `{data:...}`) no longer becomes an opaque "no response" pill; log enough shape to tell cases apart without leaking secrets; keep single-attempt + manual retry.

## Context

- Trace exp-5: `AIResponse.Message.content:String` non-optional → every off-shape response becomes `DecodingError → noResponse` ("no response from AI service."). Logs only had `responseLen/hash` + `errorDomain` with no keys → the 4 cases were indistinguishable.
- No real retry remains (attempt always 1, remaining `Task.sleep` is poll/UI). What looks like "chunk retry" is TaskGroup fan-out + prefetch of other chapters + tapping "Xử lý lại". The 503 pill is `httpError(code, localizedString)` thrown right at attempt 1.

## Scope (inline)

- `AIResponse.swift`: `content:String?` + `reasoningContent:String?` (`reasoning_content`) + `toolCalls` (tolerant decode, missing → nil/[]); fallback: trimmed non-empty `content` → use it; else trimmed non-empty `reasoning_content` → use it; else throw the unchanged `noResponse`.
- `AIClient.swift`: on DecodingError + the noResponse branch, log extra safe shape via `JSONSerialization`: `responseJsonKeys` (top keys ≤10), `choicesCount`, `contentKind` (null/missing/empty-string/ok), `hasReasoningContent`, `hasToolCalls`. No raw body/prompt/auth-headers logging.
- `DiagnosticsEntry` + `DiagnosticsLog`: add the shape fields above (optional, default nil) + parse helper; `LogScreen` expanded detail shows an extra shape line when present (design unchanged).
- `ai-service.md`: document tolerant content + shape logging.
- Tests: `content:null+reasoning` → success using reasoning; `tool_calls-only` → noResponse; `{data:...}` → noResponse (envelope decision: noResponse + shape log); `choices:[]` unchanged.

## Non-goals

- No added retry, no `{data:...}` envelope treated as success (shape logging only), no raw body logging.

## Acceptance

- [x] 200 `content:null` + non-empty reasoning → success with reasoning content.
- [x] 200 `choices:[]` / tool-only / odd envelope → same noResponse pill as before, but Log has distinguishing shape fields.
- [x] No entry contains raw body/prompt/auth.
- [x] `./init.sh` full PASS.

## Plan (inline)

1. Tolerant model + fallback.
2. Shape logging + LogScreen rows.
3. Tests + docs; verify.

## Handoff (done)

- State: done — tolerant decode + shape logging + LogScreen rows + docs/tests; `./init.sh` full PASS.
- Evidence: `AIResponse` content?/reasoning/toolCalls + resolvedText, `AIClient` shape parse/log, `DiagnosticsEntry/Log` shape fields, `LogScreen` rows, reasoning/tool/envelope/empty + redaction tests.
- Blockers: none
- Next: repo idle — user retests an odd-shape provider 200, opens Log to check the "Dạng"/Choices/"Nội dung" rows.
