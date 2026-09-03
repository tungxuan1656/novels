# Settings Management

> Stores, restores, and sanitizes current settings for catalog, AI, prefetch, and typography. No legacy migration.

## Flow (ordered steps actor / system)

1. On launch, system restores current settings from `UserDefaults` via `@Observable` store. Missing or invalid values are sanitized to defaults before features read them. Unknown and legacy keys are ignored.
2. Actor opens Settings. System shows groups: catalog address, AI (service address, model, provider, custom headers/body, unit size, Prompt system prompt), prefetch N, typography (font, size, line height, spacing).
3. Actor edits a value. System validates and saves to `UserDefaults` via the `@Observable` store. Next operation uses the new value.
4. Invalid edits fallback to defaults on next launch without crashing. Typography restores on launch to style the reader. No network at launch.

## Rules (business rules, link to business-rules.md)

- Missing or invalid current values fallback to defaults: catalog URL, AI address, model `gpt-4o`, N=3, unit size 1300, provider `openai`, default `AI_PROMPT` ([business-rules.md](../business-rules.md) BR-12).
- Unknown provider → `openai` ([business-rules.md](../business-rules.md) BR-12).
- Empty prompt → default prompt ([business-rules.md](../business-rules.md) BR-12).
- Only current keys exist. Unknown and legacy keys are ignored and defaults apply (no migration) ([business-rules.md](../business-rules.md) BR-12, `../../contracts/settings-schema.md`).
- Typography persists via `UserDefaults` and applies to every render. Missing values use defaults ([business-rules.md](../business-rules.md) BR-11).
- Prefetch N only respects 1..10, else 3 ([business-rules.md](../business-rules.md) BR-08).

## States

- **Settings lifecycle:** defaults → restored → sanitized → edited → persisted (current keys only)
- Sanitize runs offline at launch.

## Cases

| Case | Result |
|------|--------|
| No stored settings (first launch) | Use all defaults |
| Headers/body JSON invalid | Treated as empty, proceed |
| Provider unknown | Normalized to `openai` |
| Prompt empty/missing | Fallback to default prompt |
| Prefetch N is 0, 99, "abc" | Use 3 |
| Unknown or legacy key present | Ignored. Current defaults apply |

## Acceptance

- [ ] Launch restores current settings and replaces invalid or missing values with defaults. Unknown and legacy keys are ignored.
- [ ] Editing catalog, AI, prefetch, or typography persists via `UserDefaults` + `@Observable` and survives restart.
- [ ] Unknown provider or empty prompt corrects to `openai` and default `AI_PROMPT`.
- [ ] Typography changes apply to reader and persist.
- [ ] No legacy migration occurs.

## Links

- Domain: [domain-model.md](../domain-model.md) (AI_PROMPT, TypographySetting)
- Flows: [flows.md](../flows.md) §7 Settings
- Integrations: [integrations.md](../integrations.md) §1 Remote Book Catalog, §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-08, BR-11, BR-12
- Contracts: [settings-schema](../../contracts/settings-schema.md), [local-data](../../contracts/local-data.md); Decisions: [local-persistence](../../decisions/local-persistence.md), [book-identity](../../decisions/book-identity.md); Security: [SECURITY.md](../../../SECURITY.md)
