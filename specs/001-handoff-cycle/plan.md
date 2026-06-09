# Implementation Plan: Subagent Handoff Cycles

**Branch**: `feat/6-handoff-cycle` | **Date**: 2026-06-09 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-handoff-cycle/spec.md`

## Summary

Replace the Agent Builder's bespoke 7-criteria inline self-evaluation (Step 5) with a review-fix handoff cycle that dispatches Code Gardener → agent-reviewer → Refactor Executor via the Daeanne Dispatcher. Retain the inline check as a degraded-mode fallback. Add handoff pattern guidance as a reference doc so the Agent Builder can emit handoff cycles in agents it builds.

## Technical Context

**Language/Version**: Markdown (AGENT.md prompt definition) + PowerShell 5.1 (code blocks within AGENT.md)

**Primary Dependencies**: Daeanne Dispatcher (async sub-task API), GitHub CLI or MCP (issue filing, repo operations)

**Storage**: Git repos (agent artifacts, build review docs) — no database

**Testing**: Re-run Code Gardener against this repo's AGENT.md to verify the new Step 5 is well-formed; manual integration test by building a test agent

**Target Platform**: Daeanne OS on Windows (Jeffrey's machine)

**Project Type**: Agent definition (Markdown prompt engineering, not compiled code)

**Performance Goals**: N/A — no runtime performance concerns for prompt definitions

**Constraints**: No external dependencies without approval. All handoff mechanics use existing Dispatcher endpoints. No new services, no new runtimes.

**Scale/Scope**: 3 files modified (AGENT.md, docs/daeanne-integration.md, docs/handoff-cycle-spec.md already exists). ~100 lines of AGENT.md rewritten (Step 5 + template update).

## Constitution Check

_GATE: Constitution is an unfilled template — no project-specific gates to check. Pass by default._

No violations. No complexity justifications needed.

## Project Structure

### Documentation (this feature)

```text
specs/001-handoff-cycle/
├── plan.md              # This file
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
├── contracts/           # Phase 1 output (handoff contract schemas)
└── tasks.md             # Phase 2 output (/speckit.tasks command)
```

### Source (repository root)

```text
AGENT.md                           # Primary target — Step 5 rewrite + template update
docs/
├── handoff-cycle-spec.md          # Already exists — handoff pattern reference
├── daeanne-integration.md         # Update Self-Evaluation Loop section
├── environment-context.md         # Read-only reference
└── research-findings.md           # Read-only reference
.github/
└── eval-criteria.md               # Read-only — workflow compliance dimension
```

**Structure Decision**: No new directories. Changes target existing files plus one already-created reference doc. This is a prompt engineering change, not a code project.
