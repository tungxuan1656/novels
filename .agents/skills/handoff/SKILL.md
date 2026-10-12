---
name: handoff
description: Create a compact handoff document for another agent to continue work. Use only when the user explicitly asks to hand off, transfer, or summarize work for a new session.
---

Summarize only the restart context needed by the next person or agent. For a
local same-user session, a temporary OS file is sufficient. Across people or
machines, use an accessible canonical task/tracker, PR, branch, or commit; do
not make another person depend on a local temporary file. Confirm the shared
destination before writing when it is unclear. State where uncommitted work
exists and what the recipient must obtain before continuing.

Include the current outcome, evidence, blockers, and next action. Suggest a
skill only when it helps that action, not a mandatory pipeline.

Do not duplicate content already captured in other artifacts (specs, plans,
ADRs, issues, commits, diffs, or task records). Reference them by path or URL
instead. When Harness is active, cite the selected canonical task or
tracker and its handoff rather than creating a competing work log.

Redact any sensitive information, such as API keys, passwords, or personally identifiable information.

If the user passed arguments, treat them as a description of what the next session will focus on and tailor the doc accordingly.
