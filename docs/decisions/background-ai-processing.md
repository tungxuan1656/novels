# ADR — AI Work Across iOS Background Transitions

- **Date:** 2026-10-16
- **Status:** Proposed implementation; requires Xcode/iPhone verification before merge.
- **Scope:** iPhone, iOS 26.0+; AI rewrite/bilingual and chapter prefetch. No server push or periodic unattended processing.

## Decision

1. Ordinary AI requests use the existing `AIReadingService` and `AIClient` unchanged for wire/cache rules. Each `processedContent` or `reprocess` caller holds a reference-counted UIKit `beginBackgroundTask` assertion **only while the app is in the background**, ending at completion, return to foreground or expiration. iOS typically grants only a short interval and may suspend work afterward; this is not a guarantee.
2. The user may explicitly select **Xử lý trước khi về Home** in the Reader settings sheet. After checking the current cache misses, the app submits a `BGContinuedProcessingTaskRequest` with immediate-fail strategy. The handler observes progress and completion from the **same** `PrefetchManager` worker generation; no extra processing queue or duplicate AI pipeline. Replacement ends that association. Progress, disappearance protection, and cancellation never transfer to the replacement worker. A system Live Activity displays actual completed chapters and allows cancellation.
3. The app registers `com.tungxuan.novels.ai-prefetch.*` at launch, declares that wildcard in Info.plist and opts into `UIBackgroundModes = processing`. No GPU/audio/location modes. The request is never submitted by automatic next-chapter prefetch.
4. On task expiration, complete the system task once with failure and request cancellation of only its worker generation. Do not wait for an AI request still shared with Reader. A completion handler reports success only for a successful batch. On refusal to submit, show an error to the user; the original foreground/short-background behavior still works.
5. A single app-wide `PrefetchManager` instance persists across Reader view recreations while the process survives. Completed chapters remain in the **existing** SQLite cache; a new Reader load after process termination checks misses and resumes normally. In-flight HTTP requests, partial responses, attempts and the FIFO itself are not persistent. An iOS force quit cannot be worked around.

## Constraints / trade-offs

- Continued processing is *only* for a batch explicitly initiated with a button; prefetch from chapter navigation is an automatic workload and may not claim a continued task.
- No background `URLSession` migration for chat-completions POST bodies: response parsing and dependent chunk operations require an active process. Separate import ZIP transfer work would need delegate-based background sessions in a different task.
- Cancellation/expiration is cooperative and prompt, not guaranteed to finish cleanup if iOS kills the process.
- One active user-initiated batch per app process; requests use unique identifiers and `.fail` to avoid late/unexpected work.
- The current worker's 600s per-chapter and 1800s batch budgets still apply. This change does **not** promise indefinite processing or always-on API connectivity.

## Validation (real iPhone required)

- Start uncached rewrite or bilingual chapter, tap Home and lock the phone; confirm best-effort completion or graceful interruption, then reload cache on foreground.
- Start a user-directed batch using the settings button while the next N chapters are uncached. Go Home immediately; inspect the system Live Activity, background API activity and SQLite cache after coming back.
- Cancel via the Live Activity, test app switch/read navigation, book/mode changes and explicit prefetch cancel. Verify one system-task completion and no duplicate requests.
- Test refused submission (system resource limits), offline/online change and API timeout; verify user-facing error and no false completion.
- Force terminate and reopen; validate cached completed chapters remain, missing chapters retry only through normal Reader activation, and no false claim of an automatically relaunched continued task.
- Run `./init.sh` on macOS with Xcode 26+, and additionally manually test on an iPhone running iOS 26.0+. A simulator cannot validate actual background lifetime.

## References

- [Apple: Performing long-running tasks on iOS and iPadOS](https://developer.apple.com/documentation/backgroundtasks/performing-long-running-tasks-on-ios-and-ipados/)
- [Apple: UIApplication.beginBackgroundTask](https://developer.apple.com/documentation/uikit/uiapplication/beginbackgroundtask%28withname%3Aexpirationhandler%3A%29)
- [Background AI & chapter-prefetch contract](../product/functional-specs/chapter-prefetch.md)
