# Spec: Subagent Handoff Cycles

> **Status**: Draft
> **Issue**: [#6 — Replace bespoke self-eval with Code Gardener handoff cycle](https://github.com/jehubba/daeanne-agent-builder/issues/6)
> **Author**: Agent Builder review cycle, 2026-06-09

---

## Problem

The Agent Builder Agent's Step 5 runs a bespoke 7-criteria self-evaluation inline. This duplicates the agent-reviewer skill (8 dimensions, 1–5 rubrics, anti-pattern catalog) and the Code Gardener pipeline (orchestration → issue filing → Refactor Executor). When the Agent Builder builds agents, those agents may also need handoff cycles — so the Agent Builder must understand handoff patterns deeply enough to emit them, not just use one.

This spec covers two deliverables:

1. **Replace Step 5** with a Code Gardener handoff cycle (concrete change to AGENT.md)
2. **Add handoff cycle guidance** to the repo as a reference doc the Agent Builder consults when building agents that need review-fix loops (new reference material)

---

## Background: Handoff Patterns in Production

Three handoff architectures exist in the ecosystem (from [research-findings.md](./research-findings.md) §T1):

| Pattern                     | Routing                                        | Coupling                            | Best for                   |
| --------------------------- | ---------------------------------------------- | ----------------------------------- | -------------------------- |
| **Supervisor/Selector**     | Central LLM reads `description` fields, routes | Loose — agents don't know peers     | Dynamic task decomposition |
| **Swarm/Handoff**           | Agents route to each other by name             | Tight — agents must know peer names | Stable task sequences      |
| **Declarative Composition** | YAML references child configs                  | Deterministic — no runtime LLM call | Reproducible pipelines     |

The Daeanne OS uses a **hybrid**: Daeanne acts as Supervisor (decomposes and dispatches), but individual agents use the Swarm/Handoff pattern for known collaborators (e.g., Code Gardener → Refactor Executor). The Dispatcher provides the async glue — `parentTaskId` for suspension, callbacks for resumption.

### The Review-Fix Loop

The specific handoff cycle we need is a **review-fix loop** — a pattern where:

1. An **author agent** produces artifacts
2. A **reviewer agent** evaluates them against criteria and files findings
3. A **fixer agent** addresses critical findings
4. The reviewer re-evaluates (bounded iteration)

This is distinct from a simple handoff (A → B) because it includes a feedback loop with a termination condition.

---

## Architecture: Review-Fix Loop

```
┌─────────────────┐
│  Author Agent    │  Produces artifacts (Step 4)
│  (Agent Builder) │
└────────┬────────┘
         │ commit + dispatch
         ▼
┌─────────────────┐
│  Reviewer Agent  │  Evaluates artifacts, files issues
│  (Code Gardener  │  Uses agent-reviewer skill internally
│   + agent-       │
│     reviewer)    │
└────────┬────────┘
         │ callback with findings
         ▼
┌─────────────────┐     ┌──────────────────┐
│  Decision Gate   │────→│  Fixer Agent      │  Only if critical
│  (Author Agent   │     │  (Refactor        │  findings exist
│   on resumption) │     │   Executor)       │
└────────┬────────┘     └────────┬─────────┘
         │                        │ callback with fixes
         │◄───────────────────────┘
         │
         ▼
    cycle++ ≤ max?
     │yes        │no
     ▼            ▼
  re-dispatch   deliver with
  reviewer      documented caveats
```

### Termination Conditions

The loop terminates when any of:

1. **Pass**: No dimension scores ≤ 2 (no critical findings)
2. **Iteration cap**: 2 review-fix cycles completed (prevent infinite loops)
3. **No progress**: Fixer's changes didn't improve scores on the flagged dimensions
4. **Fixer failure**: Refactor Executor sub-task fails (deliver with caveats)

### Why 2 Cycles Maximum

- Cycle 1 catches structural issues (missing sections, bad frontmatter, scope creep)
- Cycle 2 catches issues introduced by fixes (regression) or issues masked by the first batch
- Cycle 3+ indicates a fundamental spec problem — the Author should escalate, not iterate

---

## Detailed Design: Step 5 Replacement

### Current Step 5 (to be replaced)

```
Invoke self-eval-loop skill. Evaluate 7 criteria inline.
If score < 4/7, iterate. If 4-6/7, deliver with caveats. If 7/7, deliver.
```

### New Step 5 — Quality Review (handoff cycle)

#### Step 5a — Commit and push artifacts

Before review, ensure the built agent artifacts are committed to the new repo (Step 4c already does this). The reviewer needs a real repo to scan.

```powershell
# Already done in Step 4c — verify artifacts are pushed
cd "$env:output_path\<agent-repo>"
git log --oneline -1  # Confirm HEAD has the initial build commit
```

#### Step 5b — Dispatch Code Gardener for review

Dispatch a Code Gardener sub-task targeting the new agent's repo. Use the Async Sub-Task Pattern from [environment-context.md](./environment-context.md):

```powershell
$reviewTask = Invoke-RestMethod "$env:DISPATCHER_URL/tasks" -Method Post `
  -Body (ConvertTo-Json @{
      type         = "Code"
      prompt       = @"
Run in Analysis Only mode against the repository jehubba/daeanne-<agent-name>.

Focus on agent file quality using the agent-reviewer skill.
Produce findings as GitHub issues on the target repo.
Do NOT plan or execute refactoring — only analyze and report.

Target: jehubba/daeanne-<agent-name>
Mode: Analysis Only
"@
      parentTaskId = $env:TASK_ID
  }) -ContentType "application/json"

# Self-suspend and wait for callback
Invoke-RestMethod "$env:DISPATCHER_URL/tasks/$($env:TASK_ID)/await" -Method Post `
  -Body (ConvertTo-Json @{ subtaskId = $reviewTask.id }) `
  -ContentType "application/json"

exit 0
```

**On resumption**, the callback contains the Code Gardener's analysis output including any filed issues.

#### Step 5c — Evaluate findings and decide

Read the callback result and check for critical findings:

```powershell
$cb = Get-ChildItem "$env:output_path\callbacks" -Filter "*.json" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$result = Get-Content $cb.FullName | ConvertFrom-Json

# Parse findings from the Code Gardener's output
# Critical = any agent-reviewer dimension scored ≤ 2
```

**Decision matrix:**

| Finding severity                          | Cycle count | Action                                                                    |
| ----------------------------------------- | ----------- | ------------------------------------------------------------------------- |
| No critical findings (all dimensions > 2) | Any         | Proceed to Step 6 (deliver)                                               |
| Critical findings exist                   | < 2         | Dispatch Refactor Executor (Step 5d)                                      |
| Critical findings exist                   | ≥ 2         | Deliver with documented caveats                                           |
| Code Gardener task failed                 | Any         | Log failure, fall back to inline eval (7-criteria check as degraded mode) |

#### Step 5d — Dispatch Refactor Executor for fixes (conditional)

Only reached when critical findings exist and cycle count < 2.

```powershell
$fixTask = Invoke-RestMethod "$env:DISPATCHER_URL/tasks" -Method Post `
  -Body (ConvertTo-Json @{
      type         = "Code"
      prompt       = @"
Execute fixes for the critical findings filed as issues on jehubba/daeanne-<agent-name>.

Work through the open issues labeled with agent-reviewer findings.
Make one fix per commit. Reference the issue number in each commit message.
Do NOT close the issues — the re-review will determine if they pass.

Target: jehubba/daeanne-<agent-name>
Mode: Execute Plan
"@
      parentTaskId = $env:TASK_ID
  }) -ContentType "application/json"

Invoke-RestMethod "$env:DISPATCHER_URL/tasks/$($env:TASK_ID)/await" -Method Post `
  -Body (ConvertTo-Json @{ subtaskId = $fixTask.id }) `
  -ContentType "application/json"

exit 0
```

**On resumption**, increment the cycle counter and loop back to Step 5b (re-dispatch Code Gardener).

#### Step 5e — Record review outcome

Before proceeding to Step 6, record the review cycle outcome in the agent's repo:

```powershell
# Write review summary to the agent's repo
$summary = @"
## Build Review — $(Get-Date -Format 'yyyy-MM-dd')

- **Cycles**: $cycleCount
- **Final status**: $status
- **Dimensions scored ≤ 2**: $criticalDimensions
- **Issues filed**: $issueCount
- **Issues resolved**: $resolvedCount
- **Caveats**: $caveats
"@

Set-Content "$env:output_path\<agent-repo>\docs\build-review.md" $summary
cd "$env:output_path\<agent-repo>"
git add docs/build-review.md
git commit -m "docs: add build review summary"
git push origin main
```

---

## Degraded Mode: Inline Fallback

If the Dispatcher is unavailable or the Code Gardener sub-task fails, fall back to the current 7-criteria inline check. This ensures the Agent Builder can always deliver, even when the handoff infrastructure is down.

The inline fallback maps to the existing Mode Handling table under "Degraded — Dispatcher."

---

## Reference: Agent-Reviewer Dimensions

The Code Gardener invokes the agent-reviewer skill, which scores 8 dimensions. The Agent Builder should understand these because they define what "quality" means for the artifacts it produces:

| #   | Dimension                 | What it checks                                 | Critical threshold                           |
| --- | ------------------------- | ---------------------------------------------- | -------------------------------------------- |
| 1   | Description Quality       | Trigger phrases, accuracy, length              | ≤ 2: generic or misleading                   |
| 2   | Frontmatter Correctness   | YAML validity, required fields, tool refs      | ≤ 2: invalid YAML or missing required fields |
| 3   | Tool Minimality           | Least-privilege tool list                      | ≤ 2: Swiss-army agent with all tools         |
| 4   | Scope & Focus             | Single responsibility, clear boundaries        | ≤ 2: multiple competing personas             |
| 5   | Progressive Loading       | SKILL.md size, reference structure             | ≤ 2: monolithic 500+ line SKILL.md           |
| 6   | Cross-Reference Integrity | Handoff targets, skill refs resolve            | ≤ 2: broken references                       |
| 7   | Anti-Pattern Detection    | 12-pattern catalog                             | ≤ 2: multiple anti-patterns detected         |
| 8   | Cross-Scope Consistency   | Instruction conflicts, tool-workflow alignment | ≤ 2: conflicting instructions                |

**The Agent Builder should build agents that score ≥ 3 on all dimensions on first review.** The handoff cycle is a safety net, not a substitute for quality authoring.

---

## Guidance: Building Agents That Use Handoff Cycles

When the Agent Builder builds an agent that itself needs a review-fix loop or any multi-agent handoff, it should follow these patterns:

### Pattern 1: Review-Fix Loop (this spec)

Use when an agent produces artifacts that need quality validation by another agent.

**Structure:**

```
Author → Reviewer (dispatch + await) → [Fixer (dispatch + await) → Reviewer]* → Deliver
```

**Key decisions:**

- **Iteration cap**: Always set one. 2 is recommended for review loops; 3 max for complex domains.
- **Critical threshold**: Define what score/severity triggers the fix cycle. Use the reviewer's existing rubric — don't invent a new one.
- **Degraded fallback**: If the reviewer/fixer pipeline is unavailable, the author must have an inline fallback.
- **Progress detection**: If scores don't improve after a fix cycle, stop iterating.

### Pattern 2: Sequential Handoff (no loop)

Use when an agent produces work that another agent continues without feedback.

**Structure:**

```
Agent A → Agent B (dispatch + await) → Agent A continues
```

**Example**: Agent Builder dispatches Research Agent before building. No review of research quality — the builder just uses whatever comes back.

**Key decisions:**

- **Failure handling**: What if the downstream agent fails? Always have a fallback.
- **Result parsing**: Define what the callback JSON structure looks like.

### Pattern 3: Fan-Out / Fan-In

Use when an agent needs multiple independent sub-tasks done in parallel.

**Structure:**

```
Coordinator → [Agent A, Agent B, Agent C] (parallel dispatch) → await all → synthesize
```

**Daeanne Dispatcher limitation**: The Dispatcher doesn't natively support `await-all`. Implement as sequential dispatches with individual awaits, or dispatch all and poll statuses.

### Implementing Handoffs in Agent Definitions

Every agent that participates in a handoff must document:

1. **What it sends**: The dispatch prompt structure and any context it passes
2. **What it expects back**: The callback JSON schema
3. **How it resumes**: What it does when the callback arrives
4. **What happens on failure**: Degraded behavior when the partner agent fails

In the agent template (Step 4a), add these to the Integration Points section:

```markdown
## Integration Points

### Outbound handoffs

| Target agent | When dispatched     | Prompt structure  | Expected callback |
| ------------ | ------------------- | ----------------- | ----------------- |
| <agent name> | <trigger condition> | <prompt template> | <JSON schema>     |

### Inbound handoffs

| Source agent | When received       | What this agent does  |
| ------------ | ------------------- | --------------------- |
| <agent name> | <trigger condition> | <behavior on receipt> |
```

---

## Async Sub-Task Mechanics (Reference)

All handoffs in the Daeanne OS use the same Dispatcher pattern. Extracted from [environment-context.md](./environment-context.md) for convenience:

```powershell
# 1. Dispatch sub-task
$sub = Invoke-RestMethod "$env:DISPATCHER_URL/tasks" -Method Post `
  -Body (ConvertTo-Json @{
      type         = "<TaskType>"
      prompt       = "<detailed prompt>"
      parentTaskId = $env:TASK_ID
  }) -ContentType "application/json"

# 2. Self-suspend (Dispatcher resumes this task on callback)
Invoke-RestMethod "$env:DISPATCHER_URL/tasks/$($env:TASK_ID)/await" -Method Post `
  -Body (ConvertTo-Json @{ subtaskId = $sub.id }) `
  -ContentType "application/json"

exit 0  # Exit cleanly. New process resumes on callback.

# 3. On resumption — read callback
$cb = Get-ChildItem "$env:output_path\callbacks" -Filter "*.json" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$result = Get-Content $cb.FullName | ConvertFrom-Json
```

**Critical**: `parentTaskId` links the sub-task to the parent. The Dispatcher uses this to route the callback. Without it, the parent task never resumes.

---

## Acceptance Criteria

From issue #6, refined:

- [ ] Step 5 dispatches Code Gardener as a sub-task against the built agent's repo
- [ ] Code Gardener runs agent-reviewer and files issues for findings
- [ ] Critical findings (any dimension ≤ 2) trigger a Refactor Executor sub-task
- [ ] Max 2 review-fix cycles before delivering with documented caveats
- [ ] The bespoke 7-criteria check is retained as a degraded-mode fallback
- [ ] The handoff cycle guidance is available as a reference doc for building other agents
- [ ] The agent template (Step 4a) includes Integration Points with handoff documentation structure
- [ ] `docs/build-review.md` is generated in every built agent's repo

---

## Implementation Plan

| Step | Change                                                                                         | File                                     |
| ---- | ---------------------------------------------------------------------------------------------- | ---------------------------------------- |
| 1    | Replace Step 5 in AGENT.md with the new 5a–5e substeps                                         | `AGENT.md`                               |
| 2    | Move the 7-criteria check to a degraded-mode note under Step 5                                 | `AGENT.md`                               |
| 3    | Add handoff documentation structure to the agent template (Step 4a)                            | `AGENT.md`                               |
| 4    | Add this spec as a permanent reference doc                                                     | `docs/handoff-cycle-spec.md` (this file) |
| 5    | Update `docs/daeanne-integration.md` Self-Evaluation Loop section to reference the new pattern | `docs/daeanne-integration.md`            |

Steps 1–3 modify AGENT.md. Step 4 is this document. Step 5 updates the integration guide.
