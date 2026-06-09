# Research Findings — Agent Building Patterns

> **Status**: Complete  
> **Research task**: 55d37a71-0146-47c4-a22c-8da1d33e7020  
> **Completed**: 2026-06-09T02:48:00Z  
> **Self-eval score**: 4.1/5  
> **Sources**: 11 primary GitHub sources, 7 sub-questions

---

## Summary

Seven sub-questions investigated against primary GitHub sources (framework source code, agent definition
files, commit histories). Key finding: the ecosystem is pre-standardization — no universal agent spec
format exists, but five schema traditions have converged on a common core field set. The dominant
patterns for meta-agent routing, interview-mode design, and self-evaluation are documented below with
source citations.

---

## T1 — Meta-agent Architecture Patterns

Three dominant patterns in production frameworks:

### Supervisor/Selector (AutoGen, CrewAI hierarchical)

A meta-level LLM reads agent `description` fields and routes tasks. **Critical insight**: the
`description` is the routing signal, not the `system_message`. Agent descriptions must be written for
a meta-LLM audience, not a human one.

- AutoGen `SelectorGroupChat`: LLM call selects which agent speaks next based on descriptions.
- AutoGen `SocietyOfMindAgent`: wraps a sub-team as a single agent — recursive meta-agent composition.
- CrewAI `Crew`: hierarchical mode uses a manager LLM to delegate to sub-agents.

[Sources: microsoft/autogen _selector_group_chat.py; crewAIInc/crewAI, 2026]

### Swarm/Handoff (AutoGen SwarmGroupChat)

Agents route to each other by name; no central coordinator. Lower latency, but requires agents to know
peer names — tight coupling. Better for stable task sequences; worse for dynamic decomposition.

[Source: microsoft/autogen _swarm_group_chat.py, 2026]

### Declarative Composition (Google ADK)

YAML files reference child agent configs by name. Meta-agent = assembly step, not a runtime LLM call.
Deterministic, testable, versionable — but inflexible for runtime task discovery.

[Source: google/adk-python multi_agent_seq_config, 2026]

**Design implication for this agent**: Use the Supervisor/Selector pattern mentally — the Agent Builder
Agent is itself a supervisor that builds other supervisors. Write the `description` field of every agent
it produces as a routing signal for Daeanne's selector logic.

---

## T2 — Agent Specification Formats

Five distinct schema traditions found. All converge on: `name + description + instructions + tools + model + version`.

| Format | Primary concern | Fields beyond core |
|--------|-----------------|--------------------|
| Google ADK YAML | Simplicity, LLM-facing | `output_key`, JSON Schema validation |
| AOF K8s CRD | Infrastructure ops | `memory`, `observability`, `security`, `costControl`, `trustScore` |
| Microsoft GovernedAgent | Governance, accountability | `sponsor`, `policy`, `capabilities` allowlist, `agentDID` |
| Spec-kitty YAML | Rich behavioral spec | `avoidance-boundary`, `success-definition`, `handoff-to/from`, `mode-defaults` |
| Markdown+frontmatter (Copilot CLI) | Human-readable, prose-driven | `tools[]` in frontmatter, pipeline steps as H2 sections |

**Daeanne OS uses Markdown+frontmatter** (`.agent.md` files). The critical differentiator fields to
adopt from other formats: `avoidance-boundary`, `success-definition`, and explicit `mode-defaults`
(interactive vs headless behavior).

---

## T3 — Interview-Based Agent Design

**Production consensus: conditional clarification.** No production framework implements a structured
multi-turn requirements interview loop before acting. The closest pattern is mode-based switching.

**Five design rules from primary sources:**

1. **Tool-first**: resolve ambiguity via available tools before asking the user
2. **One question at a time**: consensus across all examples — never ask multiple questions at once
3. **Mode-aware**: interactive contexts ask; headless contexts assume and label the assumption
4. **Blocking only**: only ask when ambiguity would cause materially wrong output; otherwise proceed
5. **Mode switching** (deepagents `ambiguity_guidance`): explicit flag for interactive vs headless behavior

**Implementation for Agent Builder Agent**: Use `interview_mode: true/false` flag. When true and
non-trivial ambiguities exist, send one email with ≤5 numbered questions. When false or headless,
proceed with documented assumptions.

[Sources: langchain-ai/deepagents; NousResearch/hermes-agent; ValueCell-ai/valuecell; Priivacy-ai/spec-kitty, 2025-2026]

---

## T4 — Self-Evaluation Loops

Two architectures:

### Built-in reflection (AutoGen `reflect_on_tool_use`)

After tool calls complete, the agent re-reads results and synthesizes before returning. Improves single
responses. Configured via `AssistantAgentConfig.reflect_on_tool_use: bool`.

[Source: microsoft/autogen _assistant_agent.py, 2026]

### Pipeline-explicit self-eval (jehubba/research-agent Phase 7)

1. Load eval criteria file with behavioral anchors (1–5 scale per dimension)
2. Score dimensions: Pipeline Compliance (2x weight), Accuracy (2x), Task Completion (2x), Citation Completeness (1.5x), Confidence Calibration (1.5x), Source Diversity (1x), Scope Discipline (1x)
3. Dimensions ≤2 → mandatory GitHub issue (not optional)
4. Append eval note to the artifact itself (self-annotating)
5. File improvement proposals as tracked issues

**Why this outperforms built-in reflection**: externalizes criteria (reproducible), creates observable
scores (measurable), generates trackable proposals (durable improvement). Built-in reflection improves
a single response; pipeline self-eval improves the agent over time.

**Criteria that work**: pipeline compliance, citation completeness, scope discipline.  
**Hard to self-correct**: source diversity (agents retrieve from familiar sources by default).

---

## T5 — Prompt Engineering Best Practices

Elements shared by all high-quality agent definitions inspected:

| Element | Why it matters |
|---------|----------------|
| YAML frontmatter (name, description, tools) | Enables routing and tool declaration |
| Identity + explicit scope: "I do NOT do Z" | Prevents scope creep |
| Numbered procedural pipeline steps | Reproducible execution |
| `avoidance-boundary` / forbidden actions list | Hard constraints are harder to violate |
| Output format spec with examples | Removes ambiguity about deliverables |
| Invocation mode handling (interactive vs headless) | Prevents blocking in automated contexts |
| Machine-readable handoff block | Enables orchestration by parent agents |
| Success-definition with measurable criteria | Agent knows when it is done |

**Anti-patterns confirmed:**

- Ambiguous description that doesn't enable routing ("A helpful agent that does things")
- No `avoidance-boundary` → agent scope-creeps into adjacent domains
- Instructions that list capabilities without specifying procedure
- No stopping conditions → agent doesn't know when it's done
- Omitting headless/autonomous mode handling

---

## T6 — GitHub-Integrated Agent Development

**jehubba/research-agent is the primary production example** of the full loop:

```
Agent runs → scores itself → files issue (Category, File, Risk, Evidence, Acceptance Criteria)
→ human/Copilot applies as PR → commit references issue → agent improves on next run
```

The loop works because proposals are **specific**: not "improve quality" but "Source Diversity scored
2-3 across three reports; retrieval failures were root causes — add explicit fallback in Step 3."
Vague proposals don't survive to implementation.

**Implementation**: Every agent built should be wired to its own GitHub repo. Self-eval proposals go to
that repo as issues. The Agent Builder Agent's own improvement issues go to jehubba/daeanne-agent-builder.

---

## T7 — Versioning and Iterative Improvement

Two traditions:

- **Semver in YAML annotations** (AOF `aof.agenticops.org/version: "1.2.0"`, GovernedAgent CRD)
- **Git commits as changelog** (jehubba/research-agent — each commit includes what changed, why, and what evidence motivated it; no separate CHANGELOG.md)

**Daeanne OS**: adopt git-commit-as-changelog. Meaningful commit messages with evidence suffice.

**Confirmed ecosystem gaps:**

- No standard agent changelog format
- No agent-specific regression testing framework
- No golden-dataset comparison to detect behavioral regressions after prompt updates

---

## Confidence Assessment

| Claim | Confidence |
|-------|------------|
| AutoGen uses `description` as routing signal | High — primary source code inspected |
| Google ADK uses JSON-schema-validated YAML | High — primary source inspected |
| Conditional clarification is dominant Q&A pattern | High — 4 independent primary sources |
| `reflect_on_tool_use` is first-class AutoGen feature | High — AssistantAgentConfig inspected |
| Pipeline self-eval outperforms ad-hoc reflection | Medium — one primary example; no controlled comparison |
| No standard agent changelog format exists | Medium — 5 repos inspected; private orgs may differ |
| No regression testing framework for agents | Medium — absence of evidence ≠ evidence of absence |

---

## Sources

1. [microsoft/autogen](https://github.com/microsoft/autogen/tree/main/python/packages/autogen-agentchat) — Primary, 2026
2. [crewAIInc/crewAI](https://github.com/crewAIInc/crewAI) — Primary, 2026 (53k+ stars)
3. [google/adk-python](https://github.com/google/adk-python/blob/main/contributing/samples/multi_agent/multi_agent_seq_config/sub_agents/code_writer_agent.yaml) — Primary, 2026
4. [microsoft/spec-to-agents](https://github.com/microsoft/spec-to-agents) — Primary, 2025-2026
5. [agenticdevops/aof — 01-agent.yaml](https://github.com/agenticdevops/aof/blob/main/docs/schemas/01-agent.yaml) — Primary, 2025
6. [microsoft/agent-governance-toolkit](https://github.com/microsoft/agent-governance-toolkit) — Primary, 2026
7. [Priivacy-ai/spec-kitty](https://github.com/Priivacy-ai/spec-kitty) — Primary, 2025
8. [jehubba/research-agent](https://github.com/jehubba/research-agent) — Primary, 2026
9. [langchain-ai/deepagents](https://github.com/langchain-ai/deepagents/blob/main/libs/code/deepagents_code/agent.py) — Primary, 2026
10. [NousResearch/hermes-agent](https://github.com/NousResearch/hermes-agent) — Primary, 2025
11. [ValueCell-ai/valuecell](https://github.com/ValueCell-ai/valuecell) — Primary, 2025
