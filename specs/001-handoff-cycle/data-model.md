# Data Model: Subagent Handoff Cycles

**Feature**: specs/001-handoff-cycle | **Date**: 2026-06-09

## Entities

### Review Cycle

A single pass through the review-fix loop.

| Field                | Type             | Description                                                                             |
| -------------------- | ---------------- | --------------------------------------------------------------------------------------- |
| `cycleNumber`        | int              | 0-indexed counter (0 = first review, 1 = re-review after fixes)                         |
| `reviewTaskId`       | GUID             | Dispatcher task ID for the Code Gardener sub-task                                       |
| `fixTaskId`          | GUID?            | Dispatcher task ID for the Refactor Executor sub-task (null if no fixes needed)         |
| `dimensionScores`    | map<string, int> | Agent-reviewer dimension name → score (1–5)                                             |
| `criticalDimensions` | string[]         | Dimension names where score ≤ 2                                                         |
| `issuesFiledCount`   | int              | Number of GitHub issues filed by Code Gardener                                          |
| `outcome`            | enum             | `pass` / `fix_dispatched` / `cap_reached` / `no_progress` / `fixer_failed` / `degraded` |

### Build Review (persisted artifact)

Written to `docs/build-review.md` in the built agent's repo.

| Field                 | Type             | Description                                                |
| --------------------- | ---------------- | ---------------------------------------------------------- |
| `date`                | date             | Build date                                                 |
| `totalCycles`         | int              | Number of review-fix cycles executed (0–2)                 |
| `finalStatus`         | enum             | `passed` / `delivered_with_caveats` / `degraded_fallback`  |
| `dimensionsScored`    | map<string, int> | Final scores from the last review cycle                    |
| `criticalDimensions`  | string[]         | Dimensions that remained ≤ 2 at delivery (empty if passed) |
| `issuesFiledTotal`    | int              | Total issues filed across all cycles                       |
| `issuesResolvedTotal` | int              | Issues resolved by Refactor Executor                       |
| `caveats`             | string[]         | Free-text caveats if delivered with issues                 |
| `mode`                | enum             | `handoff` / `degraded_inline`                              |

### Handoff Contract

Describes a single outbound or inbound handoff in an agent definition.

| Field              | Type   | Description                                         |
| ------------------ | ------ | --------------------------------------------------- |
| `targetAgent`      | string | Name of the agent being dispatched or received from |
| `triggerCondition` | string | When the handoff is dispatched                      |
| `promptTemplate`   | string | The prompt structure sent to the target agent       |
| `expectedCallback` | string | JSON schema or description of what comes back       |
| `failureMode`      | string | What happens when the target agent fails            |

## State Transitions

### Review-Fix Loop State Machine

```
                    ┌────────────────┐
                    │   START        │
                    │  cycle = 0     │
                    └───────┬────────┘
                            │
                            ▼
                    ┌────────────────┐
             ┌──── │  REVIEWING     │ ◄───────────────┐
             │     │  (CG running)  │                  │
             │     └───────┬────────┘                  │
             │             │ callback                   │
             │             ▼                            │
             │     ┌────────────────┐                  │
             │     │  EVALUATING    │                  │
             │     │  parse scores  │                  │
             │     └───────┬────────┘                  │
             │             │                            │
             │     ┌───────┼───────────┐               │
             │     │ all > 2           │ any ≤ 2       │
             │     ▼                   ▼               │
             │  ┌──────┐     ┌────────────────┐        │
             │  │ PASS │     │  cycle < 2?    │        │
             │  └──┬───┘     └───────┬────────┘        │
             │     │                 │yes    │no        │
             │     │                 ▼       ▼          │
             │     │         ┌──────────┐  ┌────────┐  │
             │     │         │ FIXING   │  │ CAP    │  │
             │     │         │(RE runs) │  │REACHED │  │
             │     │         └────┬─────┘  └────────┘  │
             │     │              │                      │
             │     │     ┌────────┼────────┐             │
             │     │     │ Succeeded      │ Failed      │
             │     │     ▼                ▼             │
             │     │  ┌─────────────┐  ┌─────────────┐  │
             │     │  │ scores      │  │FIXER FAILED │  │
             │     │  │ improved?   │  └─────────────┘  │
             │     │  └──────┬──────┘                    │
             │     │         │yes              │no       │
             │     │         └──── (cycle++) ───┘        │
             │     │         │ no
             │     │         ▼
             │     │  ┌─────────────┐
             │     │  │NO PROGRESS  │
             │     │  └─────────────┘
             │     │
    CG fail  │     ▼
             │  ┌──────────┐
             └─►│ DEGRADED │
                │(inline)  │
                └──────────┘

Terminal states: PASS, CAP_REACHED, NO_PROGRESS, DEGRADED
All terminal states → write build-review.md → proceed to Step 6
```
