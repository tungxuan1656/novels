# Task Roadmap

This index owns navigation and roadmap scope only. Each linked task owns status, ownership, dependencies, evidence and handoff.
Use descriptive task slugs for new approved work; do not continue the legacy numeric counter.

## Bilingual Reading

- [Validated processing](task-bilingual-processing.md).
- [Reader and English learning](task-bilingual-learning.md).
- [Bilingual partial language hiding](task-bilingual-hide-language.md).
- [Configurable sentence audio](task-audio-tts.md).
- [Sentence audio device fixes](task-sentence-audio-device-fixes.md).
- [Sentence audio replay and inline loading](task-audio-session-cache.md).
- [Detailed implementation plan](plans/bilingual-reading.md).

## Reader Diagnostics

- [Failed prefetch chapter recovery](task-prefetch-failed-chapter-recovery.md).

- [Navigation performance](task-navigation-performance.md).
- [Reader cancellation and diagnostic outcomes](task-reader-diagnostics-cancellation.md).
- [AI log and cache organization](task-ai-log-cache-organization.md).
- [PR 45 background-prefetch lifecycle repairs](task-pr45-background-prefetch-lifecycle.md).

## AI Configuration

- [AI provider settings](task-ai-provider-settings.md).

## Harness Maintenance

- [Harness v2 migration](task-harness-v2-migration.md).

## Historical Deliveries

These records preserve the 31 legacy work items. Their acceptance and verification are historical, not current behavior or fresh coverage.
Read canonical specs and decisions for current behavior. Follow only the selected task, not the entire history.

| Previous ID | Task |
|---|---|
| feat-001 | [Native Persistence Foundation](task-persistence-foundation.md) |
| feat-002 | [App Shell + Home Library](task-app-shell-library.md) |
| feat-003 | [Catalog Import + ZIP Ingestion](task-catalog-zip-import.md) |
| feat-004 | [Offline Book Reader](task-offline-reader.md) |
| feat-005 | [Settings + Cache Manager](task-settings-cache-manager.md) |
| feat-006 | [AI Reading](task-ai-reading.md) |
| feat-007 | [Chapter Prefetch](task-chapter-prefetch.md) |
| feat-008 | [Hardening + Release Readiness](task-release-hardening.md) |
| feat-009 | [Lint / Format Tooling & Git Hooks](task-swift-tooling-hooks.md) |
| feat-010 | [Tolerant ZIP Ingestion Hotfix](task-tolerant-zip-ingestion.md) |
| feat-011 | [AI Prompt Setting & Inline Rewrite Reading Sheet](task-ai-prompt-rewrite.md) |
| feat-012 | [Prompt Sync & Inline AI Rewrite Picker](task-prompt-picker-sync.md) |
| feat-013 | [Edge Swipe Prev/Next Chapter](task-edge-swipe-navigation.md) |
| feat-014 | [Diagnostic Log Viewer (in-session, timeline)](task-diagnostic-log-viewer.md) |
| feat-015 | [Parallel Chunks + Bounded Retry + Loading-Only UI](task-parallel-chunks-retry.md) |
| feat-016 | [No Auto-Retry + Fix Stuck Loading](task-manual-retry-loading.md) |
| feat-017 | [Tolerant 200 Decode + Shape Logging](task-tolerant-ai-response.md) |
| feat-018 | [Rewrite + Prefetch Correctness (consolidating feat-015/016/017)](task-rewrite-prefetch-correctness.md) |
| feat-019 | [Chapter-Run Log + Raw JSON View](task-chapter-run-json-log.md) |
| feat-020 | [Fastlane iOS Diawi Distribution](task-fastlane-diawi.md) |
| feat-021 | [Reader theme trio](task-reader-theme-trio.md) |
| feat-022 | [Reading Position Restore (Simple)](task-reading-position-restore.md) |
| feat-023 | [Reader + Prefetch Correctness Round 2](task-reader-prefetch-guards.md) |
| feat-024 | [Prefetch FIFO Queue Refactor (feat-023 extend)](task-prefetch-fifo-queue.md) |
| feat-025 | [Log Viewer Correctness (title + realtime + grouping)](task-log-viewer-correctness.md) |
| feat-026 | [Reader five themes](task-reader-five-themes.md) |
| feat-027 | [Remove letter spacing](task-remove-letter-spacing.md) |
| feat-028 | [Title + Single Body String Reader](task-title-body-reader.md) |
| feat-029 | [Chapter scroll reset on swipe](task-chapter-scroll-reset.md) |
| feat-030 | [Auto-inject x-opencode-session per chapter](task-opencode-session-header.md) |
| feat-031 | [Verification and Documentation Alignment](task-verification-docs-alignment.md) |

## Retention

The owner approved concise migrated records and removal of redundant feature/index/progress files and completed plans.
Records retain dependencies, acceptance, useful evidence, blockers and follow-ups. Older implementation detail remains in Git history.
Do not recreate duplicate state or execute historical next actions without current approval.
