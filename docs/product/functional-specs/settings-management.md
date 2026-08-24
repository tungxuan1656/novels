# Settings Management

> Stores, restores, and sanitizes settings for catalog, AI, prefetch, and typography.

## Flow (ordered steps actor / system)

1. On launch, system restores settings from the persistent settings store. Missing or invalid values are sanitized to defaults before features read them. Legacy keys are migrated to current keys and persisted.
2. Actor opens Settings. System shows groups: catalog address, AI (service address, model, provider, custom headers/body, unit size, AI actions with key/name/prompt), prefetch N, typography (font, size, line height, spacing).
3. Actor edits a value. System validates and saves to the persistent settings store. Next operation uses the new value.
4. Invalid edits fallback to defaults on next launch without crashing. Typography restores on launch to style the reader. No network at launch.

## Rules (business rules, link to business-rules.md)

- Missing or invalid values fallback to defaults: catalog URL, AI address, model `gpt-4o`, N=3, unit size 1300, provider `openai` ([business-rules.md](../business-rules.md) BR-12).
- Unknown provider → `openai`; invalid action list → translate + summary ([business-rules.md](../business-rules.md) BR-12).
- Legacy keys are migrated automatically ([business-rules.md](../business-rules.md) BR-12).
- Typography persists and applies to every render; missing values use defaults ([business-rules.md](../business-rules.md) BR-11).
- Prefetch N only respects 1..10, else 3 ([business-rules.md](../business-rules.md) BR-08).

## States

- **Settings lifecycle:** defaults → restored → sanitized/migrated → edited → persisted
- Sanitize runs offline at launch.

## Cases

| Case | Result |
|------|--------|
| No stored settings (first launch) | Use all defaults |
| Headers/body JSON invalid | Treated as empty, proceed |
| Provider unknown | Normalized to `openai` |
| Action list empty/malformed | Reset to translate + summary |
| Prefetch N is 0, 99, "abc" | Use 3 |
| Legacy keys present | Migrated to current keys |

## Acceptance

- [ ] Launch restores settings and replaces invalid/missing values with defaults.
- [ ] Editing catalog, AI, prefetch, or typography persists and survives restart.
- [ ] Unknown provider or bad action list corrects to `openai` and translate + summary.
- [ ] Legacy keys are migrated.
- [ ] Typography changes apply to reader and persist.

## Links

- Domain: [domain-model.md](../domain-model.md) (AIAction, TypographySetting)
- Flows: [flows.md](../flows.md) §7 Settings
- Integrations: [integrations.md](../integrations.md) §1 Remote Book Catalog, §2 AI Processing Service
- Rules: [business-rules.md](../business-rules.md) BR-08, BR-11, BR-12
- Tech counterpart: [docs/specs/settings-management.md](../../specs/settings-management.md)
