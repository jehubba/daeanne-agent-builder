# Feature Specification: Subagent Handoff Cycles

**Feature Branch**: `001-handoff-cycle`

**Created**: 2026-06-09

**Status**: Draft

**Input**: User description: "Replace bespoke self-eval with Code Gardener handoff cycle; add handoff cycle guidance as reference material for building agents that use review-fix loops."

## User Scenarios & Testing

### User Story 1 - Agent Builder Hands Off to Code Gardener for Quality Review (Priority: P1)

The Agent Builder Agent finishes building a new agent (Step 4), then dispatches Code Gardener as a sub-task to review the built agent's repo. Code Gardener runs the agent-reviewer skill, scores 8 dimensions, and files GitHub issues for any findings. The Agent Builder resumes, reads the callback, and decides whether to proceed to delivery or dispatch fixes.

**Why this priority**: This is the core feature — without it, the Agent Builder continues using a bespoke 7-criteria check that duplicates existing infrastructure and doesn't file trackable issues.

**Independent Test**: Build a test agent with a deliberately weak description (vague triggers, no DO NOT USE FOR). Run the handoff. Verify Code Gardener files at least one issue on the test repo with a dimension score ≤ 2.

**Acceptance Scenarios**:

1. **Given** the Agent Builder has committed a new agent to its repo, **When** Step 5 executes, **Then** a Code Gardener sub-task is dispatched targeting the new repo with `parentTaskId` linking to the current task.
2. **Given** the Code Gardener completes its review, **When** the Agent Builder resumes from the callback, **Then** it reads the findings and determines whether any dimension scored ≤ 2.
3. **Given** no dimension scores ≤ 2, **When** the Agent Builder evaluates findings, **Then** it proceeds directly to Step 6 (delivery) without dispatching fixes.

---

### User Story 2 - Critical Findings Trigger a Fix Cycle (Priority: P1)

When the Code Gardener review surfaces critical findings (any agent-reviewer dimension scored ≤ 2), the Agent Builder dispatches a Refactor Executor sub-task to address them. After fixes are applied, the Code Gardener is re-dispatched to verify. The loop runs at most 2 cycles.

**Why this priority**: Without the fix cycle, the handoff is review-only — findings get filed but never addressed before delivery. The bounded loop is what makes this a quality gate, not just a report.

**Independent Test**: Build a test agent with missing frontmatter (dimension 2 will score ≤ 2). Run the handoff. Verify Refactor Executor is dispatched, makes a fix commit, and Code Gardener re-reviews. Verify the loop terminates after at most 2 cycles.

**Acceptance Scenarios**:

1. **Given** a Code Gardener review returns a dimension scored ≤ 2 and cycle count is 0, **When** the Agent Builder evaluates the findings, **Then** it dispatches a Refactor Executor sub-task targeting the open issues.
2. **Given** the Refactor Executor completes fixes, **When** the Agent Builder resumes, **Then** it increments the cycle counter and re-dispatches Code Gardener for a second review.
3. **Given** the cycle counter reaches 2 and critical findings still exist, **When** the Agent Builder evaluates, **Then** it proceeds to delivery with documented caveats rather than starting a third cycle.

---

### User Story 3 - Degraded Mode Fallback (Priority: P2)

When the Dispatcher is unavailable or the Code Gardener sub-task fails, the Agent Builder falls back to the existing 7-criteria inline self-evaluation. This ensures the Agent Builder can always deliver even when handoff infrastructure is down.

**Why this priority**: Resilience. The handoff cycle adds a dependency on two external agents. Without a fallback, a Code Gardener failure blocks all agent delivery.

**Independent Test**: Simulate Dispatcher unavailability (mock a failed POST to the tasks endpoint). Verify the Agent Builder detects the failure and runs the inline 7-criteria check instead.

**Acceptance Scenarios**:

1. **Given** the Dispatcher is unreachable, **When** Step 5 attempts to dispatch Code Gardener, **Then** the Agent Builder catches the failure and runs the inline 7-criteria evaluation.
2. **Given** the Code Gardener sub-task returns a Failed status, **When** the Agent Builder reads the callback, **Then** it logs the failure and falls back to inline evaluation.
3. **Given** the fallback runs, **When** the existing inline 7-criteria evaluation completes, **Then** the Agent Builder uses the same pass/fail logic as the current Step 5 and proceeds to delivery with a caveat noting the handoff was skipped.

---

### User Story 4 - Build Review Summary Persisted (Priority: P2)

After the handoff cycle completes (whether via full review, fix cycle, or degraded fallback), the Agent Builder writes a `docs/build-review.md` to the built agent's repo summarizing cycles run, issues filed, issues resolved, and any caveats.

**Why this priority**: Observability. Without a review artifact, there's no record of how the agent was evaluated or what caveats exist.

**Independent Test**: Run a full handoff cycle. Verify `docs/build-review.md` exists in the built agent's repo and contains the expected fields (cycles, status, dimensions, issue counts, caveats).

**Acceptance Scenarios**:

1. **Given** the handoff cycle completes normally, **When** Step 5e executes, **Then** `docs/build-review.md` is committed to the built agent's repo.
2. **Given** the degraded fallback was used, **When** Step 5e executes, **Then** `docs/build-review.md` notes that the handoff was unavailable and inline evaluation was used.

---

### User Story 5 - Handoff Guidance Available for Building Other Agents (Priority: P3)

The Agent Builder has access to a reference document (`docs/handoff-cycle-spec.md`) that describes three handoff patterns (review-fix loop, sequential handoff, fan-out/fan-in) with implementation guidance. When building an agent that needs multi-agent collaboration, the Agent Builder consults this reference and emits the appropriate Integration Points section.

**Why this priority**: This extends the Agent Builder's capability beyond its own handoff. Agents it builds can also use handoff cycles — but only if the builder knows the patterns.

**Independent Test**: Request an agent spec that requires quality validation (e.g., "build a code review agent that hands off to a fixer"). Verify the built agent's definition includes an Integration Points section with outbound/inbound handoff tables.

**Acceptance Scenarios**:

1. **Given** a spec requests an agent with a review-fix loop, **When** the Agent Builder reaches Step 4a, **Then** the generated agent definition includes an Integration Points section with outbound and inbound handoff tables.
2. **Given** the handoff reference doc exists at `docs/handoff-cycle-spec.md`, **When** the Agent Builder starts a build, **Then** it reads the reference alongside the other docs in the Environment section.

---

### Edge Cases

- What happens when the Code Gardener review produces findings but none are dimension-scored (e.g., informational notes only)? → Treat as no critical findings; proceed to delivery.
- What happens when the Refactor Executor makes changes that introduce new critical findings on different dimensions? → The re-review catches them; the iteration cap still applies.
- What happens when the built agent's repo doesn't exist yet (Step 4c failed)? → The Code Gardener dispatch will fail; fall back to inline evaluation.
- What happens when scores don't improve after a fix cycle? → Stop iterating (no-progress termination); deliver with caveats documenting the stalled dimensions.

## Requirements

### Functional Requirements

- **FR-001**: Step 5 MUST dispatch a Code Gardener sub-task via the Dispatcher, targeting the built agent's repo, using the async sub-task pattern (`parentTaskId` + `await`).
- **FR-002**: The Code Gardener sub-task MUST run in Analysis Only mode and use the agent-reviewer skill to score 8 dimensions.
- **FR-003**: The Agent Builder MUST parse the callback to identify any dimension scored ≤ 2 as a critical finding.
- **FR-004**: When critical findings exist and the cycle count is below 2, the Agent Builder MUST dispatch a Refactor Executor sub-task to fix the filed issues.
- **FR-005**: After fixes, the Agent Builder MUST re-dispatch Code Gardener for a verification review.
- **FR-006**: The review-fix loop MUST terminate after at most 2 cycles, regardless of remaining findings.
- **FR-007**: When the Dispatcher is unreachable or the Code Gardener sub-task fails, the Agent Builder MUST fall back to the existing 7-criteria inline evaluation.
- **FR-008**: The Agent Builder MUST write a `docs/build-review.md` summary to the built agent's repo before proceeding to delivery.
- **FR-009**: The agent template (Step 4a) MUST include an Integration Points section with outbound and inbound handoff table structures.
- **FR-010**: The Agent Builder MUST consult `docs/handoff-cycle-spec.md` when building agents that require multi-agent handoffs.
- **FR-011**: The review-fix loop MUST detect no-progress conditions (scores unchanged after a fix cycle) and terminate early rather than re-dispatching.

### Key Entities

- **Review Cycle**: One pass of Code Gardener analysis + optional Refactor Executor fix. Max 2 per build.
- **Critical Finding**: Any agent-reviewer dimension scored ≤ 2 on the 1–5 scale.
- **Build Review**: Summary artifact (`docs/build-review.md`) recording cycles, scores, issues, and caveats.
- **Handoff Pattern**: A reusable multi-agent collaboration structure (review-fix, sequential, fan-out).

## Success Criteria

### Measurable Outcomes

- **SC-001**: Built agents receive a Code Gardener review before delivery in 100% of normal-mode builds (non-degraded).
- **SC-002**: Critical findings (dimension ≤ 2) are addressed by a fix cycle before delivery in 100% of cases where cycle count is below the cap.
- **SC-003**: The review-fix loop never exceeds 2 cycles per build.
- **SC-004**: Every built agent's repo contains a `docs/build-review.md` with review outcome data.
- **SC-005**: When handoff infrastructure is unavailable, the Agent Builder still delivers with inline evaluation — zero builds blocked by infrastructure failure.
- **SC-006**: Agents built with handoff requirements include Integration Points with documented outbound/inbound handoff tables.

## Assumptions

- The Dispatcher supports the async sub-task pattern (`parentTaskId` + `/await` endpoint) as documented in `environment-context.md`.
- Code Gardener can run in Analysis Only mode against any repo containing agent definition files.
- The agent-reviewer skill scores all 8 dimensions and the scores are parseable from the Code Gardener's output.
- The Refactor Executor can be directed to fix specific GitHub issues by referencing them in the prompt.
- The bespoke 7-criteria inline check (current Step 5) remains available as a degraded fallback; it is not deleted.
- The Dispatcher's `await` mechanism correctly routes callbacks when a sub-task completes; the parent task resumes in a new process with access to `$env:output_path/callbacks/*.json`.
