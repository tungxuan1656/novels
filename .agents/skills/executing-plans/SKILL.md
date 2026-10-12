---
name: executing-plans
description: Execute an approved inline or written plan with proportional checks, task-local evidence, and handoff; stop for unresolved scope or unsafe changes.
---

# Executing Plans

## Overview

Load a plan, review it critically, execute its tasks, and report verified
results.

**Announce at start:** "I'm using the executing-plans skill to implement this plan."

For independent tasks that benefit from delegated execution, use
`subagent-driven-development` only when it is installed and the user authorizes
that approach. This skill remains self-contained when it is not installed.

## The Process

### Step 1: Load and Review Plan
1. Confirm the approved workspace. Use the current working tree or create a
   native git worktree when repository policy, task risk, or user scope calls
   for isolation.
2. Read the canonical inline or separate plan and linked acceptance. Do not
   create another plan or root progress log just for execution.
3. Review critically - identify any questions or concerns about the plan
4. If concerns: Raise them with your human partner before starting
5. If no concerns: Track needed deliverables and proceed. Establish the
   relevant verification baseline before editing; identify pre-existing failures.

### Step 2: Execute Tasks

For each task:
1. Record active state using the canonical task/tracker vocabulary (`active`
   for Harness tasks; `in_progress` for session todo tools)
2. Implement the approved deliverable with its affected callers, tests, fixtures,
   configuration, and docs. Adjust mechanical details without expanding scope;
   consequential changes to behavior or approach need a decision.
3. Run relevant checks as changes land, not only at the end. Do not fix source
   or install dependencies inside verification scripts.
4. Mark complete only when acceptance and checks pass. Update evidence and
   handoff in the canonical task or tracker, not a second execution log.

### Step 3: Complete Development

After all tasks complete and verification is fresh, follow the repository's
branch, review, and delivery policy. Do not require an external finishing skill.

## When to Stop and Ask for Help

**STOP executing immediately when:**
- Hit a blocker (missing dependency, test fails, instruction unclear)
- Plan has critical gaps preventing starting
- You don't understand an instruction
- Verification fails repeatedly

**Ask for clarification rather than guessing.**

## When to Revisit Earlier Steps

**Return to Review (Step 1) when:**
- Partner updates the plan based on your feedback
- Fundamental approach needs rethinking

**Don't force through blockers** - stop and ask.

## Remember
- Review plan critically first
- Preserve approved behavior and constraints; avoid duplicated implementation prose
- Don't skip verifications
- Reference skills when plan says to
- Stop when blocked, don't guess
- Follow the repository and user's workspace, branch, review, and delivery policy
