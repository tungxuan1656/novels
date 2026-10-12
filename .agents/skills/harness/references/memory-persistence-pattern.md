# Task-Local Memory and Handoff

Use the canonical task or accessible tracker as the restart record. Do not
create a second root progress log or persist facts already owned by a spec,
decision, architecture map, code, or test.

At a material handoff, record:

- current status and named owner;
- completed outcome and exact verification evidence;
- blockers or unresolved decisions;
- one next action and the focused source it needs.

Update the selected task, not every active task. Preserve evidence needed for
recovery without copying the whole transcript. Follow repository policy for
history; do not silently delete completed work. Indexes, if already needed for
navigation, link to tasks without mirroring status.

Runtime auto-memory is separate from repository task tracking. Its precedence,
extraction, and permissions depend on the installed tool; do not prescribe a
universal hierarchy or background extractor here.

See [context selection](./context-engineering-pattern.md) and
[concurrent work](./multi-agent-pattern.md).
