# Settings Management

> Stores, restores, and sanitizes current settings for catalog, AI, audio, prefetch, and typography. No legacy migration.

## Flow (ordered steps actor / system)

1. On launch, system restores current settings from `UserDefaults` via `@Observable` store. Missing or invalid values are sanitized to defaults before features read them. Unknown and legacy keys are ignored.
2. Actor opens Settings. System shows groups: catalog address, AI (URL AI, model, masked API key, Auto/manual provider, thinking, custom headers/body, unit size, separate Vietnamese and bilingual prompts), audio (Apple/API source with API-only masked key and model), prefetch N, typography (font, size, line height).
3. Actor edits a value. System validates and saves to `UserDefaults` via the `@Observable` store. Next operation uses the new value.
4. Invalid edits fallback to defaults on next launch without crashing. Typography restores on launch to style the reader. No network at launch.

## Rules (business rules, link to business-rules.md)

- Missing or invalid current values fallback to defaults: catalog URL, AI address, model `gpt-4o`, N=3, unit size 1300, provider `auto`, empty API key, unset thinking, mode-specific default `AI_PROMPT` / `AI_BILINGUAL_PROMPT` ([business-rules.md](../business-rules.md) BR-12).
- Unknown provider → `auto` ([business-rules.md](../business-rules.md) BR-12).
- Empty prompt → its own mode-specific default prompt ([business-rules.md](../business-rules.md) BR-12).
- Both prompts use multiline editors. The bilingual editor always explains the required `paragraphs/id/vi/en` JSON shape; an empty draft shows a matching example placeholder, not interleaved prose. The app appends immutable JSON/ID instructions to custom bilingual prompts; guidance is not saved as user input. Prompt edits do not invalidate cached chapters; use manual reprocess.
- Only current keys exist. Unknown and legacy keys are ignored and defaults apply (no migration) ([business-rules.md](../business-rules.md) BR-12, `../../contracts/settings-schema.md`).
- Typography persists via `UserDefaults` and applies to every render. Missing values use defaults ([business-rules.md](../business-rules.md) BR-11).
- Prefetch N only respects 0..1000, else 3 ([business-rules.md](../business-rules.md) BR-08).
- Audio source/key/model persist independently of AI settings. Apple is default; unknown source resets to Apple and blank model to the supplied default. Hidden API fields retain their values. API key uses SecureField and never displays its value in a row; edits do not call network. See [settings schema](../../contracts/settings-schema.md).
- AI reading mode persists app-wide via `AI_MODE` (default `none`); unknown or missing → `none`.
- Cache Manager first loads saved-version and distinct-chapter counts outside UI execution. Expanding a book loads its SQLite chapter/mode metadata and update times on demand. Refresh and deletion invalidate loaded details. Book titles resolve from the local repository with slug fallback. It does not use the session diagnostics ring as inventory. Keep confirmed per-book/all deletion and explicit storage errors; no individual-version deletion or new store. Deletion removes rows present at that moment and does not stop current AI or prefetch jobs. Inventory guidance and both confirmations explain that those jobs may save new versions afterward; deletion does not guarantee the cache remains empty.

## States

- **Settings lifecycle:** defaults → restored → sanitized → edited → persisted (current keys only)
- Sanitize runs offline at launch.

## Cases

| Case | Result |
|------|--------|
| No stored settings (first launch) | Use all defaults |
| Headers/body JSON invalid | Treated as empty, proceed |
| Provider unknown | Normalized to `auto` |
| Existing provider `openai` | Retained as manual selection |
| Thinking unset | Preserve provider default; send no generated thinking fields |
| Thinking `none` | Send explicit disable control; never replace with low |
| Model rejects effort/schema | Fail through existing error handling; never downgrade |
| MiMo depth selected (manual or Auto) | Show binary-only warning and block saving low/medium/high in the thinking editor; default/none remain available. Custom thinking overrides suppress generated depth and permit saving. |
| Prompt empty/missing | Fallback to default prompt |
| Prefetch N is 0 | Valid, disables prefetch |
| Prefetch N is 1001, -1, "abc" | Use 3 |
| `AI_MODE` unknown or missing | Use `none` |
| Unknown or legacy key present | Ignored. Current defaults apply |

## Acceptance

- [ ] Launch restores current settings and replaces invalid or missing values with defaults. Unknown and legacy keys are ignored.
- [ ] Editing catalog, AI, audio, prefetch, or typography persists via `UserDefaults` + `@Observable` and survives restart.
- [ ] Unknown provider or empty prompt corrects to `auto` and mode-specific defaults.
- [ ] Existing configuration stays intact; API key is masked and custom Authorization wins.
- [ ] Auto identifies provider without changing endpoint transport or guessing model capabilities.
- [ ] Four explicit thinking levels and a provider-default reset are available; schema has no UI.
- [ ] Typography changes apply to reader and persist.
- [ ] No legacy migration occurs.

## Links

- Domain: [domain-model.md](../domain-model.md) (AI_PROMPT, AI_BILINGUAL_PROMPT, TypographySetting)
- Flows: [flows.md](../flows.md) §7 Settings
- Integrations: [integrations.md](../integrations.md) §1 Remote Book Catalog, §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-08, BR-11, BR-12
- Contracts: [settings-schema](../../contracts/settings-schema.md), [local-data](../../contracts/local-data.md); Decisions: [local-persistence](../../decisions/local-persistence.md), [book-identity](../../decisions/book-identity.md); Security: [SECURITY.md](../../../SECURITY.md)
