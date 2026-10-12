# Auto-Inject Chapter Session Header

- Status: done
- Owner: Tung Doan
- Previous ID: feat-030
- Required to start: [feat-006](task-ai-reading.md)
- Required to integrate/release: none recorded.

## Scope And Non-Goals

Inject `x-opencode-session` from chapter context in `AIClient.complete(prompt:chunk:context:)`; document the override and stability rules.
No Settings key/UI, provider sniffing, cache-key, retry, chunking, or logging changes.

## Acceptance

- [x] Missing header receives `novels-<bookId>-c<N>-<mode>`; lookup is case-insensitive.
- [x] A custom header wins verbatim.
- [x] Parallel chunks and both attempts share the chapter session; different chapters differ.
- [x] Empty `bookId` or nonpositive chapter sends no auto header.
- [x] Full `./init.sh` passes under the then-current build-only policy.

## Sources

- [AI service contract](../docs/contracts/ai-service.md).
- [Architecture](../ARCHITECTURE.md); [current verification policy](../docs/decisions/verification.md).
- `apps/novels/Services/AIClient.swift`.

## Verification And Handoff

Historical evidence, not fresh coverage: quick and full verification passed; format/lint/build/drift passed on iPhone 17 Pro/iOS 26.5.
No test target existed for this change. Existing Swift 6 warnings in `AIReadingService.swift` were out of scope.
Code `efacc29` and docs `96e7ac5` passed task and final reviews.
[PR #34](https://github.com/tungxuan1656/novels/pull/34) merged on 2026-09-07 (`5af1787`).
The later [verification alignment](task-verification-docs-alignment.md) restores focused unit checks; it does not retroactively certify this header.

Blockers: none recorded. Next action: none; completed and merged.
