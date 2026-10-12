# Migrate v1 to v2

Apply only with user approval. No automatic migration or history deletion.
Skill names change: `harness-slim` becomes `harness`; `harness-slim-review`
becomes `harness-review`. Update installed skill selections and invocation
routes explicitly; the upstream repository URL is unchanged.

1. Read `AGENTS.md`, `feature_index.json`, `features/`,
   `progress.md`, existing plans, and `init.sh`. Preserve unrelated changes.
2. Agree whether local tasks or an accessible external tracker owns execution state.
3. For local state, map each selected feature ID to a unique task ID/path.
   Bring title, dependencies, status, scope, acceptance, latest evidence,
   blockers, and next action into that task. If index and history disagree,
   ask the owner; do not guess. Name the task owner.
4. Distinguish start dependencies from integrate/release gates. Reconcile
   cycles or ambiguous gates with owners instead of guessing. Keep a requested
   `tasks/index.md` as roadmap/navigation only; task/tracker owns dependencies
   and status. Update dependency links and inbound routes using the mapping. Keep
   old plan paths when adequate; renaming every historical artifact is unnecessary.
5. Keep legacy feature/index/progress files as explicitly read-only history or
   archive them at an approved location. Remove live writer instructions and
   route references to the new canonical tasks. Do not mirror status back.
6. Replace the global one-active-feature rule with task-local state and
   overlapping-file coordination. Update handoff and done rules.
7. Replace verification arrays/scheduling with the observed read-only root check
   or explicit sequential checks. Remove fixes, installs, swallowed errors;
   preserve necessary workspace coverage. If no check exists, expose the gap.
8. Check all affected routes, dependencies, acceptance, and configured commands.
   Replace live `harness-slim` provenance with `harness`; keep historical markers.
   Review the diff and update the provenance footer to `2.0.0` only after success.

If truth is missing or contradictory, return the blocking question and leave
its old owner intact until resolved. An installed v1 harness can remain v1;
never relabel an incomplete migration as v2.
