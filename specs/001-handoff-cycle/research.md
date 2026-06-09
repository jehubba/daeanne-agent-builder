# Research: Subagent Handoff Cycles

**Feature**: specs/001-handoff-cycle | **Date**: 2026-06-09

## Research Questions

No NEEDS CLARIFICATION items in Technical Context. Research focuses on validating design decisions against existing material.

### RQ-1: Can Code Gardener run in Analysis Only mode against an arbitrary repo?

- **Decision**: Yes
- **Rationale**: Code Gardener's workflow doc (`code-gardener.agent.md`) defines Analysis Only as a valid operating mode. The agent-reviewer skill scans for `.agent.md`, `SKILL.md`, etc. at workspace and user-level locations. When dispatched via the Dispatcher, the working directory is the cloned repo — agent-reviewer will discover files there.
- **Alternatives considered**: Dispatch agent-reviewer directly (bypasses Code Gardener orchestration, loses issue-filing). Run a custom reviewer (duplicates existing infrastructure — the exact problem we're solving).

### RQ-2: How does the Dispatcher route callbacks to a suspended parent task?

- **Decision**: Use `parentTaskId` on dispatch + `/tasks/{id}/await` for self-suspension. On sub-task completion, Dispatcher writes callback JSON to `$env:output_path/callbacks/` and resumes the parent as a new process.
- **Rationale**: Documented in `docs/environment-context.md` § Async Sub-Task Pattern. Already used by Step 3 (Research dispatch) in the current AGENT.md.
- **Alternatives considered**: Polling (`GET /tasks/{id}` in a loop) — wastes a process slot and doesn't exit cleanly.

### RQ-3: How to parse agent-reviewer dimension scores from Code Gardener output?

- **Decision**: Parse the callback's `response` field for the agent-reviewer report. Scores follow the format `Score: N/5` per dimension in the structured report template.
- **Rationale**: The agent-reviewer's [report template](../../.agents/skills/agent-reviewer/references/review-report-template.md) uses a consistent format. The Code Gardener preserves this in its output.
- **Alternatives considered**: Structured JSON output from agent-reviewer (not supported — output is Markdown). Parse GitHub issues instead (indirect, requires API calls, slower).
- **Risk**: If the report format changes, the parser breaks. Mitigation: match on dimension names rather than positions; treat unparseable output as a degraded-mode trigger.

### RQ-4: What iteration cap is appropriate for the review-fix loop?

- **Decision**: 2 cycles maximum
- **Rationale**: From `docs/handoff-cycle-spec.md` analysis: Cycle 1 catches structural issues; Cycle 2 catches regressions from fixes; Cycle 3+ indicates a spec problem, not a fixable agent issue. The research findings (§T4) confirm that pipeline self-eval with tracked proposals outperforms unbounded iteration.
- **Alternatives considered**: 1 cycle (insufficient — doesn't catch fix regressions), 3 cycles (diminishing returns, risk of infinite loops on fundamentally broken specs).

### RQ-5: Should the inline 7-criteria check be deleted or retained?

- **Decision**: Retain as degraded-mode fallback
- **Rationale**: The Mode Handling table already defines "Degraded — Dispatcher" mode. Deleting the inline check removes the fallback path. FR-007 requires it.
- **Alternatives considered**: Delete entirely (violates resilience principle — a Dispatcher outage would block all agent delivery).
