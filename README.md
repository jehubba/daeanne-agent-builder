# Daeanne Agent Builder Agent

A meta-agent for the **Daeanne OS** that builds new agents from a plain-language spec (job description). When you identify a capability gap in the agent OS, describe what you need — the Agent Builder Agent handles the rest.

## What It Does

1. **Receives a spec** — a natural-language description of the agent to build (its purpose, inputs, outputs, when to invoke it)
2. **Conducts an interview** (optional) — asks targeted clarifying questions before building, to get the spec right the first time
3. **Researches patterns** — dispatches a research sub-task on relevant agent-building techniques if the problem domain is new
4. **Builds the agent** — generates the agent definition file (SKILL.md / .agent.md), supporting docs, and repo structure
5. **Runs self-evaluation** — reviews its own output against quality criteria before delivering
6. **Provisions the agent** — creates or updates the GitHub repo, commits all artifacts, and provides integration instructions

## How to Invoke (via Daeanne)

Dispatch a task of type `Generic` with the following prompt structure:

```
task_type: AgentBuilder
spec: |
  <plain-language description of the agent to build>
  
  Purpose: ...
  When to invoke: ...
  Inputs: ...
  Outputs: ...
  Special requirements: ...

interview_mode: true   # set false to skip clarifying questions
```

Daeanne will dispatch this as a task and return the built agent artifacts.

## Repository Structure

```
daeanne-agent-builder/
├── AGENT.md                    # The agent builder agent definition (prompt + instructions)
├── docs/
│   ├── environment-context.md  # Daeanne OS environment reference
│   ├── daeanne-integration.md  # How to interact with Daeanne and the Dispatcher
│   └── research-findings.md    # Research: meta-agent patterns and best practices
├── .github/
│   └── ISSUES_TEMPLATE.md      # Template for tracking agent improvement requests
└── README.md
```

## Self-Improvement

This agent is plugged into its own repository. When it identifies improvements to its own behavior — new patterns, better interview questions, gaps in environment knowledge — it files a GitHub issue to track the change. Periodic review of open issues should be part of the system maintenance cycle.

## Environment

This agent is designed to run exclusively within the Daeanne OS on a single-tenant Windows machine. It is not a general-purpose agent and should not be invoked outside of that context. See `docs/environment-context.md` for full environment details.
