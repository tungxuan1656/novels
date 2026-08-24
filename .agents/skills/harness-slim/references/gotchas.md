# Gotchas — Harness Slim (Core Failure Modes)

> Slim core: 5 failure modes that affect `AGENTS.md`, `feature_index.json`, `progress.md`, and `init.sh` even without a full harness runtime. For the full 15 runtime gotchas (memory extraction, permissions, fork, team memory), see [Gotchas Full](gotchas-full.md) — only load when hacking the harness engine itself.

---

## 1. Derivable Content Doesn't Belong in Memory

**Symptom**: Memory index fills with architecture details that stale quickly.

**Cause**: Agent saves what's derivable from codebase (architecture, code patterns, version history).

**Fix**: Exclude derivable content by design. Type taxonomy should forbid saving what's in the repo already.

---

## 2. Context Builders are Memoized but Manually Invalidated

**Symptom**: Model sees stale data for entire session.

**Cause**: Context builder cached at startup, but mutation doesn't clear cache.

**Fix**: Every mutation point must explicitly clear its corresponding cache:

```typescript
// Example: Cache invalidation at mutation point
async function editFile(path: string, content: string) {
  await writeFile(path, content);
  context.cache.invalidate(`file:${path}`); // MUST invalidate
}
```

---

## 3. Skill Listing Budgets Are Tight

**Symptom**: Skill description truncated, can't trigger properly.

**Cause**: Skill descriptions concatenated and capped per entry (~150 chars). Front-loaded trigger language gets priority.

**Fix**: Front-load distinctive trigger language:

```markdown
✓ Good: "harness-patterns: Memory, permissions, context engineering, multi-agent"
✗ Bad: "A comprehensive skill for understanding and implementing various patterns related to AI agent harnesses and runtime systems..."
```

---

## 4. Orphaned Progress Blocks Accumulate

**Symptom**: `progress.md` fills with orphaned blocks not referenced by `feature_index.json`.

**Cause**: Two-step save (progress block then index) — crash or interruption between steps leaves an orphaned progress block, same principle as orphaned topic files in the full harness.

**Fix**: Periodic sweep deletes progress blocks not referenced by the index. Orphans don't corrupt the index but consume space and confuse resume. Keep `progress.md` append-only and sweep unreferenced blocks during maintenance.

---

## 5. Silent Empty Verification

**Symptom**: `init.sh` passes with SKIP but repo has build/test evidence (e.g., `package.json` scripts, test directories, CI workflows).

**Cause**: All task arrays are empty — no BUILD/TEST tasks were generated from repository evidence, so every phase prints SKIP and exits zero.

**Fix**: Require at least one BUILD/TEST task or an explicit commented SKIP with evidence explaining why verification is intentionally absent. See [Write init.sh](../SKILL.md#write-initsh-from-evidence) for evidence-based generation rules.

---

## Related Reading

- [Memory Persistence Pattern](memory-persistence-pattern.md) — Gotchas #1, #4
- [Context Engineering Pattern](context-engineering-pattern.md) — Gotchas #2, #3
