# Reader Diagnostics Cancellation

- Status: done
- Owner: Codex
- Required to start: none
- Required to integrate/release: none

## Scope and non-goals

Keep current-chapter AI and prefetch running while the user opens Diagnostics. Explain API outcomes and failures without requiring raw JSON inspection. The user confirmed opening Diagnostics during the reported `NSURLErrorDomain -999` failure and approved both repairs.

Do not change provider payloads, streaming, timeout values, cache persistence, log retention, or cancellation on actual Reader exit/mode/chapter changes.

## Acceptance

- [x] Opening Diagnostics preserves current-chapter processing and prefetch; returning does not send duplicate current-chapter requests.
- [x] Actual Reader exit still cancels work; cancellation is not retried or counted as an API failure.
- [x] Log rows explain sending, HTTP/network errors, invalid responses, success and cancellation; failed runs identify the affected chunk/attempt.
- [x] Error-focused entry preserves the full run context and later success; logs remain observable while requests run.
- [x] Focused regression tests and full `./init.sh` pass; runtime coverage limits are recorded.

## Sources

- [Diagnostics decision](../docs/decisions/diagnostic-log-viewer.md)
- [AI contract](../docs/contracts/ai-service.md)
- [Prefetch behavior](../docs/product/functional-specs/chapter-prefetch.md)
- [Navigation](../docs/design/navigation.md)
- [Security](../SECURITY.md)

## Plan

1. Add focused cancellation/classification tests and preserve processing only on an accepted Diagnostics push.
2. Normalize cancelled transport errors and make run/row diagnostics explain outcomes with complete context.
3. Update canonical behavior, run full verification, and record evidence.

## Verification and handoff

- Baseline: Initial worktree clean. Screenshot shows cancellation after about three seconds, before provider completion. Code inspection identifies Reader disappearance cancellation; the user confirmed opening Log at that point.
- Implementation: Only an accepted Log push preserves Reader processing. Actual exit still cancels; transport cancellation is logged once without retry. Error-focused entry expands complete failed runs rather than removing sibling events or recovery. No provider/streaming/cache-retention change.
- Regression evidence: `BilingualPipelineTests` covers Log cover/return without duplicate current requests, background prefetch completion, and actual exit cancellation. `AIClientConfigurationTests` covers one cancelled attempt and no retry. `DiagnosticsOutcomeTests` covers cancellation classification, sibling failure, terminal recovery, invalid HTTP-200 output, wrapper-to-API cause/attempt resolution, and semantic failure after a recovered retry.
- Review: Resolved the independent review finding that `chunk.fail`/`prefetch.error-continue` hid the underlying API failure. Summaries use the final outcome of the matching request, not an earlier retry or cancelled sibling.
- Full verification: `./init.sh` passed on 2026-10-13: SwiftFormat, strict SwiftLint, build, and 101 unit tests (101 passed, 0 failed, 0 skipped), iPhone 17 Pro / iOS 26.5 Simulator. Evidence: `/tmp/novels-diagnostics-final.log` and Xcode test result bundle. `git diff --check` passed.
- Diagnostics: Active LSP probes of changed Swift files have no remaining actionable errors; standalone SourceKit cross-file lookup false positives were dispositioned using successful Xcode compilation. Existing actor-isolation warnings in unchanged declarations/function references remain outside scope.
- Coverage limits: URLProtocol fixtures and ViewModel tests, not live provider calls or native navigation/UI automation. iOS 26.5 simulator verification does not prove iOS 26.0 runtime behavior.
- Handoff: Changes remain uncommitted on local branch `main`; no PR or push.
- Blockers: None.
- Next: On the user's device, process Song ngữ and open Log while the request is running; inspect any remaining provider/structured-output failure separately using the improved cause and JSON viewer.
