# AI Provider Settings Execution Plan

Acceptance and task state: [task](../../tasks/task-ai-provider-settings.md).
Durable behavior: [AI contract](../contracts/ai-service.md), [settings schema](../contracts/settings-schema.md), [settings spec](../product/functional-specs/settings-management.md).

## Boundaries

- Keep `OPENAI_API_URL`, `OPENAI_MODEL`, and existing custom JSON keys. Change the URL label only.
- Retain stored `AI_PROVIDER=openai`; new installs use Auto. Add empty API key and unset thinking defaults.
- Do not infer model capabilities or rewrite endpoint URLs. Model names identify providers only.
- Keep custom headers/body as escape hatches. Do not downgrade requests after provider errors.
- Keep chapter callers schema-free, existing cache identities, two attempts, and cancellation handling.
- Keep credentials in approved UserDefaults storage; do not expose them in rows or diagnostic summaries.

## Deliverables

### 1. Settings and Provider Identity

Files: `apps/novels/Domain/AIProvider.swift`, `apps/novels/Domain/AIThinkingEffort.swift`, `apps/novels/Persistence/DefaultsKeys.swift`, `apps/novels/Persistence/SettingsStore.swift`.

- Define Auto plus OpenAI, Anthropic, Muse, DeepSeek, MiMo, GLM, MiniMax, Kimi, Gemini.
- Resolve Auto by recognized model prefix/name, then exact provider host/suffix, then OpenAI-compatible fallback.
- Treat localhost and proxy hosts as transport addresses, not upstream providers.
- Persist `AI_API_KEY` and `AI_THINKING_EFFORT`; unset effort emits no generated fields.
- Sanitize malformed provider/effort values. Preserve existing values and custom JSON verbatim.

### 2. Request Construction and Schema Seam

Files: `apps/novels/Services/AIRequestOptions.swift`, `apps/novels/Services/AIOutputSchema.swift`, `apps/novels/Services/AIClient.swift`.

- Snapshot settings once per call; resolve provider without changing endpoint family.
- Inject trimmed API key as Bearer unless custom Authorization exists, case-insensitively.
- Add provider/endpoint thinking fields only for explicit effort. Reject undocumented combinations locally.
- For MiMo, reject depth controls instead of inventing low/medium/high; none disables thinking, unset preserves default.
- If custom body contains thinking controls, suppress the generated thinking group, including nested effort.
- Retain shallow custom-body merge and reserved input keys. Merge generated structured format into nested containers without dropping unrelated verbosity/effort.
- Add `outputSchema: AIOutputSchema? = nil` to `complete`. Validate name and schema object before network.
- Add schema instructions and endpoint/provider format when supplied. Reject conflicting custom format rather than weakening schema.
- Validate structured output is a JSON object and is final answer content, never reasoning fallback. Return its string for future feature-specific decoding/semantic validation.
- Preserve legacy text resolution for nil schema; log failures through existing diagnostics and retries.

### 3. Settings UI

Files: `apps/novels/Features/Settings/SettingsView.swift`, `apps/novels/Features/Settings/SettingEditorView.swift`, `apps/novels/Features/Settings/SettingsViewModel.swift`.

- Display URL AI, masked API key, provider identity, and thinking alongside existing fields.
- Use SecureField for key and a provider picker.
- Offer four explicit effort values plus a separate default/unset action. Explain model/proxy rejection and MiMo's binary behavior.
- Show resolved provider for Auto. Do not add schema settings or change navigation.

### 4. Tests, Documentation, and Verification

Files: separate focused suites under `apps/novelsTests/`; canonical contracts/spec/security; `tasks/index.md` for navigation.

- Test Auto/manual precedence, host boundaries, settings round-trip/sanitization, unset compatibility, Bearer override/redaction, and endpoint independence.
- Test every provider mapping, none versus unset, unsupported combinations, thinking-group override, reserved keys, and nested format merge.
- Test schema validation, format choices, conflict rejection, JSON object validation, reasoning-only/refusal/incomplete responses, and nil-schema text compatibility.
- Use URLProtocol fixtures to verify actual headers/body, bounded failures, and cancellation without authenticated calls.
- Format only changed Swift files explicitly; verification never rewrites source.
- Run changed-file LSP diagnostics, `./init.sh --quick`, then full `./init.sh`.
- Review the actual diff; update acceptance/evidence only after checks pass.

## Recovery and Coverage

Unset thinking and an empty API key preserve legacy behavior; custom fields remain available.
No migration deletes credentials or cache. Reprocess manually to apply changes to cached chapters.
Local fixtures prove request construction, not upstream acceptance. Record no live provider, UI, real-device, or iOS 26.0 runtime coverage.
