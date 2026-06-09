# Daeanne Integration Guide

This document explains how the Agent Builder Agent interacts with Daeanne and the wider Daeanne OS. It is both a reference for the Agent Builder Agent itself and a template for the integration docs it should produce for agents it builds.

---

## How Daeanne Dispatches Agents

Daeanne dispatches work by POSTing tasks to the Dispatcher. Each task gets its own working directory, process, and lifecycle. The Agent Builder Agent is dispatched the same way as any other agent.

### Dispatching the Agent Builder Agent

From Daeanne's context, dispatch like this:

```powershell
$body = @{
    type   = "Generic"
    prompt = @"
task_type: AgentBuilder

spec: |
  <Name>: <Agent Name>
  <Purpose>: <What this agent does and why>
  <When to invoke>: <Signal phrases or conditions that should trigger this agent>
  <Inputs>: <What context / parameters it needs>
  <Outputs>: <What it produces — files, emails, actions>
  <Special requirements>: <Constraints, integrations, tone, scope limits>

interview_mode: true
"@
} | ConvertTo-Json

$task = Invoke-RestMethod "http://127.0.0.1:47777/tasks" `
    -Method Post -Body $body -ContentType "application/json"
```

### When to dispatch vs. inline

| Situation | Action |
|-----------|--------|
| Building a new agent | Dispatch Agent Builder Agent |
| Reviewing/auditing an existing agent | Invoke `agent-reviewer` skill directly |
| Quick agent edits | Do inline — no need for Agent Builder |
| New agent replaces or wraps an existing one | Dispatch Agent Builder Agent with context on what's being replaced |

---

## How the Agent Builder Agent Calls Back

On completion, the Agent Builder Agent:

1. Writes all artifacts to its working directory (`$env:output_path`)
2. Commits artifacts to the agent's new GitHub repo
3. Sets `resultJson` with:
   ```json
   {
     "response": "<summary of what was built>",
     "workDir": "<path>",
     "repoUrl": "<GitHub repo URL>",
     "agentFile": "<path to AGENT.md or SKILL.md>",
     "nextSteps": "<what Daeanne needs to do to activate the agent>"
   }
   ```
4. PATCHes its task to `Succeeded`
5. Sends a completion email to Jeffrey

---

## How New Agents Are Activated

After the Agent Builder Agent completes, activation requires:

1. **Review the built agent** — read `AGENT.md` (or `SKILL.md`) and the generated docs
2. **Register as a VS Code skill** — copy or symlink the skill file into the workspace `.github/` or skills directory, or follow the agent-specific instructions
3. **Update Daeanne's instructions** — add the new skill's invocation pattern to the agent profile so future Daeanne instances know about it

The Agent Builder Agent will provide explicit instructions for step 3 in its completion email.

---

## Interview Mode

When `interview_mode: true`, the Agent Builder Agent does NOT immediately build. Instead:

1. It analyzes the spec
2. Identifies ambiguities, missing information, or design decisions that require input
3. Sends an email to Jeffrey with a numbered list of questions
4. Suspends, waiting for a reply
5. On receiving the reply (new Email task referencing this task), it incorporates the answers and builds

This requires the follow-up email to reference the original task (via reply-to threading). Daeanne will recognize the thread and re-dispatch the Agent Builder with the original spec + answers combined.

---

## Self-Evaluation Loop

The Agent Builder Agent runs its output through the `self-eval-loop` skill before delivering. The evaluation criteria are:

1. **Completeness** — Does the agent definition cover all required behaviors?
2. **Scope precision** — Are the `WHEN` triggers specific enough? Vague enough for edge cases?
3. **Environment fidelity** — Are all environment assumptions correct per `docs/environment-context.md`?
4. **Integration correctness** — Does the Dispatcher interaction code use the correct patterns?
5. **Tone/character alignment** — Does the agent's character match the Daeanne OS aesthetic?
6. **Testability** — Is it clear how to verify the agent works correctly?

If the self-eval identifies issues, the agent iterates before delivering.

---

## Self-Improvement via GitHub Issues

The Agent Builder Agent files GitHub issues against its own repo (`jehubba/daeanne-agent-builder`) when it identifies improvements it cannot make autonomously:

```powershell
$env:PATH += ";C:\Program Files\GitHub CLI"
gh issue create `
    --repo jehubba/daeanne-agent-builder `
    --title "Improvement: <short title>" `
    --body "<detailed description of the improvement and why it matters>"
```

Daeanne should periodically review open issues on this repo as part of system maintenance.

---

## Adding the Agent Builder to Daeanne's Instructions

Once the Agent Builder Agent is validated and active, add the following to Daeanne's agent profile under the **Tool Use Policy** or **Orchestration Pipeline** sections:

```
## Agent Builder Agent

When you identify a gap in the agent OS — a capability that doesn't exist and would 
require a new specialized agent — dispatch the Agent Builder Agent rather than building 
the agent inline.

Dispatch trigger: Any request requiring a new reusable agent to be created.

```powershell
$body = @{
    type   = "Generic"
    prompt = "task_type: AgentBuilder`nspec: |`n  <your spec here>`ninterview_mode: true"
} | ConvertTo-Json
$task = Invoke-RestMethod "http://127.0.0.1:47777/tasks" `
    -Method Post -Body $body -ContentType "application/json"
```

The agent will handle research, spec clarification, agent authoring, self-evaluation,
and GitHub provisioning. Your job is to provide a clear spec and respond to interview
questions if asked.
```
