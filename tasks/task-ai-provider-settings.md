# AI Provider Settings

- Status: done
- Owner: Codex
- Required to start: none; provider-only behavior approved on 2026-10-12
- Required to integrate/release: full verification; authenticated provider smoke tests remain a deployment responsibility

## Scope and Non-Goals

Add URL AI, masked Bearer API key, Auto/manual provider selection, and optional thinking controls. Add an internal optional output-schema request seam without changing chapter rewrite output.
Keep existing settings keys, custom JSON, transport selection, retry, cache, and iOS 26.0 support.
No model-version rules, capability catalog, native Gemini transport, new dependencies, Keychain, automatic downgrades, or schema UI.

## Acceptance

- [x] Existing settings survive; unset new controls preserve requests and prompts.
- [x] Provider selection resolves nine families; URL still selects wire format.
- [x] API key is masked; custom Authorization wins case-insensitively.
- [x] Thinking uses provider-only fields; custom thinking owns the entire group.
- [x] Optional schema adds endpoint format and prompt instructions; nil changes nothing.
- [x] Unsupported configuration, invalid schema, and non-JSON structured results fail explicitly.
- [x] Focused tests and full `./init.sh` pass; limitations are recorded.

## PR #39 Review Repairs

- [x] Reject strict schemas with missing object closure or incomplete required properties, including nested schemas.
- [x] Require transport completion markers for structured results; preserve legacy text parsing.
- [x] Block MiMo depth in the thinking editor unless custom thinking overrides generation.
- [x] Correct the default-provider contract and rerun full verification.

## Sources

- [AI wire contract](../docs/contracts/ai-service.md)
- [Settings schema](../docs/contracts/settings-schema.md)
- [Settings behavior](../docs/product/functional-specs/settings-management.md)
- [Security](../SECURITY.md)
- [Verification policy](../docs/decisions/verification.md)

## Plan

[Detailed execution plan](../docs/plans/task-ai-provider-settings.md).
Codex owns all edits; any delegated review is read-only.

## Verification and Handoff

- Baseline: clean worktree; `./init.sh --quick` passes format/lint on 2026-10-12. Baseline build/tests not run.
- Final repair evidence (2026-10-12): `./init.sh` exits 0; SwiftFormat and strict SwiftLint pass across 70 files, app builds, 44 unit tests pass with zero failures/skips on iPhone 17 Pro / iOS 26.5. Log: `/tmp/novels-pr39-full.log`; xcresult: `/Users/tungdoan/Library/Developer/Xcode/DerivedData/novels-cnquxnfpsaiyolfgmngqnzcxmoca/Logs/Test/Test-novels-2026.10.12_21-28-37-+0700.xcresult`.
- Regression tests reproduced the strict-schema, completion-marker, and MiMo-editor findings before repair. Fixtures now cover nested object constraints, no-network schema rejection, missing/null markers across transports, and manual/Auto MiMo validation with custom overrides. Read-only review identified whitespace normalization in Auto; corrected and covered. Original 37-test feature evidence remains in commit `c5a4b85`.
- LSP probes are incomplete: timeouts and missing cross-file/module context; passing Xcode build/tests are authoritative. Build emits actor-isolation warnings in Swift 5 mode; no Swift 6 migration performed.
- Coverage limits: no authenticated provider/proxy requests, UI execution, real device, or iOS 26.0 runtime verification. JSON mode/prompt-only output does not enforce schema semantics; future callers own typed validation.
- Blockers: none within approved scope.
- Handoff: [PR #39](https://github.com/tungxuan1656/novels/pull/39), branch `task/ai-provider-standardization`, base commit `c5a4b85`. Review repairs are published in commit `2a8a6e3`; next action is PR review. Existing chapter cache is unchanged.
