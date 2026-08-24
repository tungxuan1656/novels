# Settings Management

> Stores, restores, and sanitizes current settings for catalog, AI, prefetch, and typography. No legacy migration.

## Flow (ordered steps actor / system)

1. On launch, system restores current settings from `UserDefaults` via `@Observable` store. Missing or invalid values are sanitized to defaults before features read them; unknown/legacy keys are ignored.
2. Actor opens Settings. System shows groups: catalog address, AI (service address, model, provider, custom headers/body, unit size, AI actions with key/name/prompt), prefetch N, typography (font, size, line height, spacing).
3. Actor edits a value. System validates and saves to `UserDefaults` via the `@Observable` store. Next operation uses the new value.
4. Invalid edits fallback to defaults on next launch without crashing. Typography restores on launch to style the reader. No network at launch.

## Rules (business rules, link to business-rules.md)

- Missing or invalid current values fallback to defaults: catalog URL, AI address, model `gpt-4o`, N=3, unit size 1300, provider `openai` ([business-rules.md](../business-rules.md) BR-12).
- Unknown provider → `openai`; invalid action list → translate + summary ([business-rules.md](../business-rules.md) BR-12).
- Only current keys exist; unknown/legacy keys are ignored and defaults apply (no migration) ([business-rules.md](../business-rules.md) BR-12, `../../contracts/settings-schema.md`).
- Typography persists via `UserDefaults` and applies to every render; missing values use defaults ([business-rules.md](../business-rules.md) BR-11).
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
| Action list empty/malformed | Reset to translate + summary |
| Prefetch N is 0, 99, "abc" | Use 3 |
| Unknown/legacy key present | Ignored; current defaults apply |

## Acceptance

- [ ] Launch restores current settings and replaces invalid/missing values with defaults; unknown/legacy keys are ignored.
- [ ] Editing catalog, AI, prefetch, or typography persists via `UserDefaults` + `@Observable` and survives restart.
- [ ] Unknown provider or bad action list corrects to `openai` and translate + summary.
- [ ] Typography changes apply to reader and persist.
- [ ] No legacy migration occurs.

## Links

- Domain: [domain-model.md](../domain-model.md) (AIAction, TypographySetting)
- Flows: [flows.md](../flows.md) §7 Settings
- Integrations: [integrations.md](../integrations.md) §1 Remote Book Catalog, §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-08, BR-11, BR-12
- Contracts: [settings-schema](../../contracts/settings-schema.md), [local-data](../../contracts/local-data.md); Decisions: [local-persistence](../../decisions/local-persistence.md), [book-identity](../../decisions/book-identity.md); Security: [SECURITY.md](../../../SECURITY.md)
