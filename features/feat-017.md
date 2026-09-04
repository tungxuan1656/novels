# feat-017 — Tolerant 200 Decode + Shape Logging

## Goal

HTTP 200 nhưng shape lạ (`content:null` + `reasoning_content`, `choices:[]`, `tool_calls`, envelope `{data:...}`) không còn thành pill "no response" mù mờ; log đủ shape để phân biệt mà không lộ secret; giữ single-attempt + manual retry.

## Context

- Trace exp-5: `AIResponse.Message.content:String` non-optional → mọi shape lệch thành `DecodingError → noResponse` ("no response from AI service."). Log chỉ có `responseLen/hash` + `errorDomain`, không có keys → không phân biệt 4 case.
- Không còn retry thật (attempt luôn 1, `Task.sleep` còn lại là poll/UI). Cái thấy như "retry chunk" = TaskGroup fan-out + prefetch chương khác + bấm "Xử lý lại". Pill 503 = `httpError(code, localizedString)` throw ngay attempt 1.

## Scope (inline)

- `AIResponse.swift`: `content:String?` + `reasoningContent:String?` (`reasoning_content`) + `toolCalls` (decode tolerant, miss → nil/[]); fallback: `content` trim non-empty → dùng; else `reasoning_content` trim non-empty → dùng; else throw `noResponse` giữ nguyên.
- `AIClient.swift`: catch DecodingError + branch noResponse log thêm shape an toàn qua `JSONSerialization`: `responseJsonKeys` (top keys ≤10), `choicesCount`, `contentKind` (null/missing/empty-string/ok), `hasReasoningContent`, `hasToolCalls`. Không log raw body/prompt/headers auth.
- `DiagnosticsEntry` + `DiagnosticsLog`: thêm fields shape trên (optional, default nil) + helper parse; `LogScreen` expanded detail hiện thêm dòng shape khi có (giữ design).
- `ai-service.md`: ghi tolerant content + shape log.
- Tests: `content:null+reasoning` → success dùng reasoning; `tool_calls-only` → noResponse; `{data:...}` → noResponse (hoặc success nếu quyết envelope? chốt: noResponse + shape log); `choices:[]` giữ.

## Non-goals

- Không thêm retry, không envelope `{data:...}` thành công (chỉ log shape), không raw body log.

## Acceptance

- [x] 200 `content:null` + reasoning non-empty → success nội dung reasoning.
- [x] 200 `choices:[]` / tool-only / envelope lạ → noResponse pill như cũ nhưng Log có shape fields phân biệt.
- [x] Không entry nào chứa raw body/prompt/auth.
- [x] `./init.sh` full PASS.

## Plan (inline)

1. Model tolerant + fallback.
2. Shape logging + LogScreen rows.
3. Tests + docs; verify.

## Handoff (done)

- State: done — tolerant decode + shape logging + LogScreen rows + docs/tests; `./init.sh` full PASS.
- Evidence: `AIResponse` content?/reasoning/toolCalls + resolvedText, `AIClient` shape parse/log, `DiagnosticsEntry/Log` shape fields, `LogScreen` rows, tests reasoning/tool/envelope/empty + redaction.
- Blockers: none
- Next: repo idle — user retest provider 200-shape lạ, mở Log xem Dạng/Choices/Nội dung.
