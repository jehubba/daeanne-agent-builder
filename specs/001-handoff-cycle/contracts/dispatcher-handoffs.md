# Contracts: Dispatcher Sub-Task Handoffs

**Feature**: specs/001-handoff-cycle | **Date**: 2026-06-09

These contracts define the Dispatcher API interactions for the review-fix loop. They are the integration surface between the Agent Builder and its collaborator agents.

---

## Contract 1: Dispatch Code Gardener Review

**Direction**: Agent Builder → Dispatcher → Code Gardener

### Request

```
POST $env:DISPATCHER_URL/tasks
Content-Type: application/json
```

```json
{
  "type": "Code",
  "prompt": "Run in Analysis Only mode against the repository jehubba/daeanne-{agent-name}.\n\nFocus on agent file quality using the agent-reviewer skill.\nProduce findings as GitHub issues on the target repo.\nDo NOT plan or execute refactoring — only analyze and report.\n\nTarget: jehubba/daeanne-{agent-name}\nMode: Analysis Only",
  "parentTaskId": "{TASK_ID}"
}
```

### Response (dispatch)

```json
{
  "id": "{review-task-guid}",
  "status": "Pending"
}
```

### Callback (on completion)

Written to `$env:output_path/callbacks/{review-task-guid}.json`:

```json
{
  "status": "Succeeded | Failed",
  "response": "<Code Gardener Markdown output containing agent-reviewer report with dimension scores>",
  "workDir": "<path>"
}
```

**Parsing rule**: Scan `response` for lines matching `**Score**: N/5` or `Score: N/5` per dimension. Dimension names are: Description Quality, Frontmatter Correctness, Tool Minimality, Scope & Focus, Progressive Loading, Cross-Reference Integrity, Anti-Pattern Detection, Cross-Scope Consistency.

**Critical finding**: Any dimension where extracted score ≤ 2.

**Failure mode**: If `status` is `Failed` or `response` is unparseable → trigger degraded-mode inline evaluation.

---

## Contract 2: Self-Suspend for Callback

**Direction**: Agent Builder → Dispatcher (self)

### Request

```
POST $env:DISPATCHER_URL/tasks/{TASK_ID}/await
Content-Type: application/json
```

```json
{
  "subtaskId": "{review-task-guid or fix-task-guid}"
}
```

### Behavior

- Agent Builder process exits cleanly (`exit 0`)
- Dispatcher transitions task to `Awaiting` status
- On sub-task completion, Dispatcher writes callback JSON and resumes Agent Builder as a new process
- Resumed process has same `$env:TASK_ID` and `$env:output_path`

---

## Contract 3: Dispatch Refactor Executor Fix

**Direction**: Agent Builder → Dispatcher → Refactor Executor

### Request

```
POST $env:DISPATCHER_URL/tasks
Content-Type: application/json
```

```json
{
  "type": "Code",
  "prompt": "Execute fixes for the critical findings filed as issues on jehubba/daeanne-{agent-name}.\n\nWork through the open issues labeled with agent-reviewer findings.\nMake one fix per commit. Reference the issue number in each commit message.\nDo NOT close the issues — the re-review will determine if they pass.\n\nTarget: jehubba/daeanne-{agent-name}\nMode: Execute Plan",
  "parentTaskId": "{TASK_ID}"
}
```

### Callback (on completion)

```json
{
  "status": "Succeeded | Failed",
  "response": "<Refactor Executor output — commits made, issues addressed>",
  "workDir": "<path>"
}
```

**Failure mode**: If `status` is `Failed` → deliver with caveats, do not re-dispatch reviewer.

---

## Contract 4: Build Review Artifact

**Direction**: Agent Builder → built agent's repo (file write)

### Schema

File: `docs/build-review.md` in the built agent's repository.

```markdown
## Build Review — {YYYY-MM-DD}

- **Cycles**: {0|1|2}
- **Final status**: {passed|delivered_with_caveats|degraded_fallback}
- **Mode**: {handoff|degraded_inline}
- **Dimensions scored ≤ 2**: {comma-separated list or "none"}
- **Issues filed**: {count}
- **Issues resolved**: {count}
- **Caveats**: {free text or "none"}
```

### Commit

```
git add docs/build-review.md
git commit -m "docs: add build review summary"
git push origin main
```

---

## Contract 5: Agent Template — Integration Points Section

**Direction**: Agent Builder → generated agent definitions

When the Agent Builder produces an agent that participates in handoffs (per FR-009), the Integration Points section must follow this structure:

```markdown
## Integration Points

### Outbound handoffs

| Target agent | When dispatched     | Prompt structure  | Expected callback |
| ------------ | ------------------- | ----------------- | ----------------- |
| {agent name} | {trigger condition} | {prompt template} | {callback schema} |

### Inbound handoffs

| Source agent | When received       | What this agent does  |
| ------------ | ------------------- | --------------------- |
| {agent name} | {trigger condition} | {behavior on receipt} |
```

This contract is emitted only when the spec indicates the agent needs multi-agent collaboration. The Agent Builder consults `docs/handoff-cycle-spec.md` to select the appropriate pattern (review-fix, sequential, or fan-out).
