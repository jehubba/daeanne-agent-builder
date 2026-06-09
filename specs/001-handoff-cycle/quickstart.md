# Quickstart: Subagent Handoff Cycles

**Feature**: specs/001-handoff-cycle | **Date**: 2026-06-09

This guide validates that the handoff cycle works end-to-end after implementation.

## Prerequisites

- Daeanne Dispatcher running at `$env:DISPATCHER_URL` (typically `http://127.0.0.1:47777`)
- GitHub CLI authenticated as `jehubba`
- Code Gardener agent available (symlinked from `~/.agents/skills/`)
- Refactor Executor agent available
- Agent-reviewer skill installed

## Validation Scenario 1: Happy Path (Code Gardener review passes)

### Setup

1. Build a well-formed test agent manually (or use a previous Agent Builder output):

   ```powershell
   gh repo create jehubba/daeanne-test-handoff --public --description "Test agent for handoff validation"
   # Add a minimal but correct AGENT.md with valid frontmatter, description, all sections
   ```

2. Verify Code Gardener can reach the repo:
   ```powershell
   gh repo view jehubba/daeanne-test-handoff
   ```

### Run

Trigger the Agent Builder with a spec that produces an agent targeting the test repo. Step 5 should:

1. Dispatch Code Gardener → verify sub-task appears in Dispatcher (`GET /tasks?status=Running`)
2. Code Gardener completes → callback written to `$env:output_path/callbacks/`
3. Agent Builder resumes → parses scores → all dimensions > 2
4. Proceeds to Step 6 without dispatching fixes

### Expected Outcome

- `docs/build-review.md` exists in the test repo
- Contains `Final status: passed`, `Cycles: 1`, `Mode: handoff`
- No Refactor Executor was dispatched

## Validation Scenario 2: Fix Cycle Triggered

### Setup

Build a deliberately weak test agent:

- Missing YAML frontmatter (Dimension 2: Frontmatter Correctness will score ≤ 2)
- Vague description like "A helpful agent" (Dimension 1: Description Quality will score ≤ 2)

### Run

Trigger the Agent Builder. Step 5 should:

1. Dispatch Code Gardener → files issues for dimensions 1 and 2
2. Agent Builder detects critical findings → dispatches Refactor Executor
3. Refactor Executor fixes frontmatter and description → commits
4. Agent Builder re-dispatches Code Gardener → re-reviews
5. If passing, proceeds to delivery; if still failing, hits iteration cap (2)

### Expected Outcome

- `docs/build-review.md` shows `Cycles: 2` (or 1 if first fix resolved everything)
- GitHub issues exist on the test repo from Code Gardener
- Fix commits reference issue numbers
- Final status is `passed` or `delivered_with_caveats`

## Validation Scenario 3: Degraded Mode

### Setup

Stop the Dispatcher (or block the port):

```powershell
# Verify Dispatcher is unreachable
try { Invoke-RestMethod "http://127.0.0.1:47777/health" } catch { "Dispatcher down — good" }
```

### Run

Trigger the Agent Builder. Step 5 should:

1. Attempt to dispatch Code Gardener → catch the connection failure
2. Fall back to the 7-criteria inline evaluation
3. Proceed to delivery

### Expected Outcome

- `docs/build-review.md` shows `Mode: degraded_inline`, `Cycles: 0`
- Agent is delivered with a caveat noting the handoff was skipped

## Validation Scenario 4: Re-run Code Gardener Against This Repo

After implementing the changes to AGENT.md, validate the Agent Builder's own definition quality:

```powershell
# Invoke Code Gardener in Analysis Only mode against daeanne-agent-builder
# This is the same flow the Agent Builder will use on agents it builds
```

Use the Code Gardener agent in VS Code:

> "Run in Analysis Only mode against this repository. Focus on agent file quality using the agent-reviewer skill."

### Expected Outcome

- All 8 agent-reviewer dimensions score ≥ 3
- No critical findings (dimension ≤ 2) on AGENT.md
- The new Step 5 structure is recognized as a valid execution pipeline

## Cleanup

```powershell
gh repo delete jehubba/daeanne-test-handoff --yes
```
