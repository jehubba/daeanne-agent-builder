# Tasks: Subagent Handoff Cycles

**Input**: Design documents from `specs/001-handoff-cycle/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/

## Format: `[ID] [P?] [Story?] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- **[TDD-AGENT]**: Test task handled by the TDD Agent before implementation
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Branch creation and environment reference update

- [X] T001 Create feature branch `feat/6-handoff-cycle` from `main`
- [X] T002 Add `docs/handoff-cycle-spec.md` to the Agent Builder's own Environment section doc list in `AGENT.md`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core structural changes that must be in place before user story work

**âš ï¸ CRITICAL**: No user story work can begin until this phase is complete

- [X] T003 [TDD-AGENT] Write seam test: verify AGENT.md Step 5 section heading and substep structure (5aâ€“5e) exist after implementation â€” test by parsing headings in `AGENT.md`
- [X] T004 Refactor current Step 5 in `AGENT.md` â€” rename to "Step 5 â€” Quality review (handoff cycle)" and add substep skeleton (### Step 5a through ### Step 5e) with placeholder descriptions

**Checkpoint**: AGENT.md has the new Step 5 skeleton â€” substeps ready to be filled

---

## Phase 3: User Story 1 â€” Code Gardener Handoff Review (Priority: P1) ðŸŽ¯ MVP

**Goal**: Step 5 dispatches Code Gardener for review, parses callback, and decides whether to proceed or fix

**Independent Test**: Build a well-formed agent, run Step 5, verify Code Gardener is dispatched and AGENT.md proceeds to delivery on a passing review

### Tests for User Story 1

- [X] T005 [TDD-AGENT] [US1] Write contract test: verify Step 5b dispatch prompt matches Contract 1 schema in `specs/001-handoff-cycle/contracts/dispatcher-handoffs.md`
- [X] T006 [TDD-AGENT] [US1] Write contract test: verify Step 5c callback parsing logic matches the dimension score extraction rule in Contract 1

### Implementation for User Story 1

- [X] T007 [US1] Write Step 5a (commit verification) in `AGENT.md` â€” local PowerShell code block verifying artifacts are committed and pushed (no Dispatcher call; this is a pre-flight check before dispatch)
- [X] T008 [US1] Write Step 5b (dispatch Code Gardener) in `AGENT.md` â€” PowerShell code block per Contract 1 (POST to `$env:DISPATCHER_URL/tasks`, self-suspend via `/await`, `exit 0`)
- [X] T009 [US1] Write Step 5c (evaluate findings) in `AGENT.md` â€” callback reading, dimension score parsing, decision matrix table (all > 2 â†’ deliver, any â‰¤ 2 â†’ fix, CG failed â†’ degrade)

**Checkpoint**: Step 5 dispatches Code Gardener and correctly evaluates the callback. No fix cycle yet â€” critical findings result in delivery with caveats.

---

## Phase 4: User Story 2 â€” Fix Cycle with Refactor Executor (Priority: P1)

**Goal**: Critical findings trigger Refactor Executor dispatch, followed by re-review, bounded to 2 cycles

**Independent Test**: Build a deliberately weak agent (missing frontmatter), run Step 5, verify Refactor Executor is dispatched, fixes are committed, and Code Gardener re-reviews

### Tests for User Story 2

- [X] T010 [TDD-AGENT] [US2] Write contract test: verify Step 5d dispatch prompt matches Contract 3 schema in `specs/001-handoff-cycle/contracts/dispatcher-handoffs.md`
- [X] T011 [TDD-AGENT] [US2] Write integration test: verify the review-fix loop terminates after 2 cycles when critical findings persist (mock callbacks)

### Implementation for User Story 2

- [X] T012 [US2] Write Step 5d (dispatch Refactor Executor) in `AGENT.md` â€” PowerShell code block per Contract 3, conditional on critical findings + cycle < 2
- [X] T013 [US2] Add cycle counter and loop-back logic to Step 5c in `AGENT.md` â€” increment cycle on resumption from fix, re-dispatch Code Gardener (Step 5b)
- [X] T014 [US2] Add no-progress detection to Step 5c in `AGENT.md` â€” compare current scores to previous cycle's scores, terminate if unchanged (FR-011)

**Checkpoint**: Full review-fix loop works with 2-cycle cap and no-progress detection

---

## Phase 5: User Story 3 â€” Degraded Mode Fallback (Priority: P2)

**Goal**: When Dispatcher or Code Gardener fails, fall back to inline 7-criteria evaluation

**Independent Test**: Block Dispatcher, run Step 5, verify inline evaluation runs and agent delivers with caveat

### Tests for User Story 3

- [X] T015 [TDD-AGENT] [US3] Write integration test: verify Dispatcher connection failure triggers inline evaluation fallback

### Implementation for User Story 3

- [X] T016 [US3] Add try/catch around the Dispatcher dispatch in Step 5b of `AGENT.md` â€” on failure, jump to degraded inline evaluation
- [X] T017 [US3] Add Code Gardener failure handling to Step 5c in `AGENT.md` â€” if callback status is `Failed` or response unparseable, fall back to inline eval
- [X] T018 [US3] Move current 7-criteria check to a "Degraded mode fallback" note under Step 5 in `AGENT.md` â€” preserve exact criteria, label as fallback

**Checkpoint**: Agent Builder always delivers â€” Dispatcher down or CG failure triggers inline eval with documented caveat

---

## Phase 6: User Story 4 â€” Build Review Persistence (Priority: P2)

**Goal**: Every build produces a `docs/build-review.md` in the built agent's repo

**Independent Test**: Run a full handoff cycle, verify `docs/build-review.md` exists with correct fields

### Tests for User Story 4

- [X] T019 [TDD-AGENT] [US4] Write contract test: verify build-review.md output matches Contract 4 schema in `specs/001-handoff-cycle/contracts/dispatcher-handoffs.md`

### Implementation for User Story 4

- [X] T020 [US4] Write Step 5e (record review outcome) in `AGENT.md` â€” PowerShell code block generating `docs/build-review.md` per Contract 4 schema, git add/commit/push
- [X] T021 [US4] Add degraded-mode variant to Step 5e in `AGENT.md` â€” when inline eval was used, write `Mode: degraded_inline` and `Cycles: 0`

**Checkpoint**: `docs/build-review.md` generated for both normal and degraded builds

---

## Phase 7: User Story 5 â€” Handoff Guidance for Built Agents (Priority: P3)

**Goal**: Agent template includes Integration Points section; Builder consults handoff-cycle-spec.md for multi-agent agents

**Independent Test**: Request an agent spec with a review-fix loop, verify the built definition includes outbound/inbound handoff tables

### Tests for User Story 5

- [X] T022 [TDD-AGENT] [US5] Write contract test: verify the agent template (Step 4a) includes Integration Points section matching Contract 5 structure

### Implementation for User Story 5

- [X] T023 [US5] Add Integration Points section (outbound + inbound handoff tables) to the agent template in Step 4a of `AGENT.md` â€” per Contract 5
- [X] T024 [US5] Add `docs/handoff-cycle-spec.md` to the conditional reads in the built agent template's Environment section (Step 4a of `AGENT.md`) â€” consult when spec requires multi-agent collaboration

**Checkpoint**: Built agents that need handoffs get proper Integration Points documentation

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Integration guide update, validation, cleanup

- [X] T025 [P] Update Self-Evaluation Loop section in `docs/daeanne-integration.md` to reference the new handoff cycle pattern instead of the inline eval description
- [X] T026 Run Code Gardener in Analysis Only mode against this repo's `AGENT.md` â€” verify all 8 agent-reviewer dimensions score â‰¥ 3 (quickstart scenario 4)
- [X] T027 Run quickstart.md validation scenario 1 (happy path) if Dispatcher is available
- [X] T028 Run quickstart.md validation scenario 2 (fix cycle) if Dispatcher is available â€” verify RE dispatch and re-review
- [X] T029 Run quickstart.md validation scenario 3 (degraded mode) â€” simulate Dispatcher unavailability, verify inline fallback
- [X] T030 Create PR `feat/6-handoff-cycle` → `main` with body referencing `Closes #6`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies â€” start immediately
- **Foundational (Phase 2)**: Depends on Phase 1 â€” BLOCKS all user stories
- **US1 (Phase 3)**: Depends on Phase 2 â€” core handoff dispatch
- **US2 (Phase 4)**: Depends on Phase 3 (Step 5c must exist for loop logic)
- **US3 (Phase 5)**: Depends on Phase 3 (Step 5b must exist for try/catch wrapping)
- **US4 (Phase 6)**: Depends on Phase 3 (Step 5 skeleton must exist for Step 5e)
- **US5 (Phase 7)**: Independent of US1â€“US4 (modifies Step 4a, not Step 5) â€” can start after Phase 2
- **Polish (Phase 8)**: Depends on all user stories being complete

### User Story Dependencies

- **US1 (P1)**: Foundation only â€” no other story dependencies
- **US2 (P1)**: Depends on US1 (extends Step 5c with loop logic)
- **US3 (P2)**: Depends on US1 (wraps Step 5b dispatch with error handling)
- **US4 (P2)**: Depends on US1 (adds Step 5e after Step 5c/5d)
- **US5 (P3)**: Independent â€” modifies Step 4a template, not Step 5

### Within Each User Story

- `[TDD-AGENT]` test tasks FIRST â†’ then implementation
- Each checkpoint is independently verifiable

### Parallel Opportunities

Within Phase 3 (US1):

```
T005, T006 can run in parallel (both are contract tests)
T007, T008 can run in parallel (different substeps, different code blocks)
```

After Phase 3 completes:

```
US3 (Phase 5) and US4 (Phase 6) can run in parallel (different substeps)
US5 (Phase 7) can run in parallel with US2, US3, US4 (different step)
```

Within Phase 8 (Polish):

```
T025 and T026 can run in parallel (different files)
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (branch)
2. Complete Phase 2: Foundational (Step 5 skeleton)
3. Complete Phase 3: User Story 1 (dispatch + evaluate)
4. **STOP and VALIDATE**: Code Gardener dispatches and callback is parsed correctly
5. Deploy/demo if ready â€” agents get reviewed even without the fix loop

### Incremental Delivery

1. Setup + Foundational â†’ Step 5 skeleton in place
2. US1 â†’ Code Gardener dispatches and evaluates â†’ **MVP** (review-only, no fix loop)
3. US2 â†’ Fix cycle works â†’ full review-fix loop
4. US3 â†’ Degraded fallback â†’ resilient delivery
5. US4 â†’ Build review persisted â†’ observable builds
6. US5 â†’ Handoff guidance in template â†’ built agents can handoff too
7. Polish â†’ integration guide updated, validated, PR merged

