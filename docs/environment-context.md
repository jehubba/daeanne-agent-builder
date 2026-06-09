# Daeanne OS — Environment Context

This document exists so the Agent Builder Agent has accurate, up-to-date knowledge of the environment it operates in. Every agent it builds will run in this environment. Reference this doc when generating agent definitions, integration instructions, or environment-specific logic.

---

## Operating System

- **Platform**: Windows (Windows_NT)
- **Primary user**: Jeffrey Hubbard (`jeffrey.hubbard@outlook.com`)
- **User home**: `C:\Users\Jeffrey`
- **Daeanne data root**: `C:\Users\Jeffrey\.daeanne\`

---

## The Daeanne OS

Daeanne is a **Chief of Staff / orchestration layer** built on GitHub Copilot CLI (VS Code agent mode). It is not a single persistent daemon — each task starts a fresh agent process, does work, and exits. The Dispatcher manages lifecycle, concurrency, and continuity.

### Key directories

| Path | Purpose |
|------|---------|
| `~/.daeanne/tasks/active/{task_id}/` | Working directory for running tasks |
| `~/.daeanne/tasks/complete/{task_id}/` | Completed task artifacts |
| `~/.daeanne/tasks/failed/{task_id}/` | Failed task artifacts |
| `~/.daeanne/tasks/scheduled/active/{task_id}/` | Scheduled task working dirs |
| `~/.daeanne/journal/YYYY-MM-DD.md` | Daily journal (written by Daeanne at task close) |
| `~/.daeanne/journal/week-YYYY-WNN.md` | Weekly running notes |
| `~/.daeanne/notes/` | Persistent notes (ideas, reminders, backlogs, named lists) |
| `~/.daeanne/preferences.json` | Principal preference memory |
| `%APPDATA%\daeanne\blocked-senders.json` | Email block list |
| `%APPDATA%\daeanne\filter-log.jsonl` | Mail filter event log |

---

## The Dispatcher

The Dispatcher is a .NET service that manages the task lifecycle. It runs at:

```
http://127.0.0.1:47777
```

### Core endpoints

| Method | Endpoint | Purpose |
|--------|----------|---------|
| GET | `/health` | Health check |
| POST | `/tasks` | Create/dispatch a new task |
| GET | `/tasks/{id}` | Get task status and result |
| GET | `/tasks?status=Running&take=20` | List tasks by status |
| PATCH | `/tasks/{id}/status` | Update task status |
| POST | `/tasks/{id}/await` | Self-suspend, awaiting a sub-task callback |
| POST | `/outbox/email` | Queue an outbound email |
| GET | `/outbox/email/{id}` | Check email delivery status |
| POST | `/outbox/sms` | Queue an outbound SMS |
| GET | `/outbox/sms/{id}` | Check SMS delivery status |
| POST | `/scheduler/crons` | Create a scheduled job |
| GET | `/scheduler/crons` | List scheduled jobs |
| DELETE | `/scheduler/crons/{id}` | Cancel a scheduled job |

### Task types (AgentTaskType enum)

- `Research` — web research, investigation, deep dives
- `Scheduling` — calendar operations
- `Code` — code generation, review, execution
- `Email` — inbound email handling
- `InboundSms` — inbound SMS handling
- `DailySummary` — daily office report generation
- `WeeklyOneOnOne` — weekly reflective review
- `Generic` — catch-all for custom sub-tasks

### Task lifecycle

```
Pending → Running → Succeeded | Failed | TimedOut
                 ↘ Awaiting (self-suspended for sub-task callback)
```

### Task result structure

```json
{
  "response": "<agent stdout / full output>",
  "workDir": "<path to task working directory>"
}
```

### Environment variables injected per task

| Variable | Value |
|----------|-------|
| `TASK_ID` | Current task's GUID |
| `output_path` | Working directory for this task |
| `TASK_CONTEXT` | JSON blob with task-specific context (email, SMS, etc.) |

---

## Async Sub-Task Pattern

The canonical pattern for dispatching sub-tasks and resuming:

```powershell
# Dispatch sub-task
$sub = Invoke-RestMethod "http://127.0.0.1:47777/tasks" -Method Post `
  -Body (ConvertTo-Json @{
      type         = "Research"
      prompt       = "..."
      parentTaskId = $env:TASK_ID
  }) -ContentType "application/json"

# Self-suspend — Dispatcher will resume this task when callback arrives
Invoke-RestMethod "http://127.0.0.1:47777/tasks/$($env:TASK_ID)/await" -Method Post `
  -Body (ConvertTo-Json @{ subtaskId = $sub.id }) -ContentType "application/json"

exit 0  # Exit. A new Daeanne instance will resume on callback.
```

**On resumption**, read the callback result:
```powershell
$cb = Get-ChildItem "$env:output_path\callbacks" -Filter "*.json" |
    Sort-Object LastWriteTime -Descending | Select-Object -First 1
$result = Get-Content $cb.FullName | ConvertFrom-Json
```

---

## Available Skills (VS Code / Copilot)

Skills are invoked by Daeanne within VS Code agent sessions. The following are active:

- `agent-reviewer` — audits agent definition files for quality
- `self-eval-loop` — runs structured self-evaluation against criteria
- `azure-*` — various Azure operations (deploy, cost, compliance, AI, etc.)
- `microsoft-foundry` — AI Foundry agent operations
- `codebase-analysis` — deep code analysis
- `report-generation` — structured report authoring
- `source-discovery` — source/repo discovery
- `pattern-recognition` — pattern identification
- `customize-cloud-agent` — cloud agent customization

New agents built by the Agent Builder Agent should be registered as skills in the VS Code workspace.

---

## GitHub

- **CLI**: `C:\Program Files\GitHub CLI\gh.exe` (add to PATH if needed)
- **Authenticated as**: `jehubba`
- **Token scopes**: `gist`, `read:org`, `repo`, `workflow`
- All Daeanne-related repos are under the `jehubba` account.

---

## Email / SMS

- **Daeanne's inbox address**: `daeanne-srs@outlook.com`
- **Jeffrey's address**: `jeffrey.hubbard@outlook.com`
- **Email delivery**: always queue via `/outbox/email`, then poll `/outbox/email/{id}` until `Sent` or `Failed` (max 120s, retry once on failure)
- SMS is available for Jeffrey via `/outbox/sms` — keep replies ≤160 chars

---

## Communication Preferences (Jeffrey)

- **Response length**: executive summary by default; detail on request
- **Format**: markdown, bullet findings for research, prose for analysis
- **Tone**: direct, no pleasantries
- **Confirmation**: explicit confirm only for irreversible actions
- **Decision style**: options with clear tradeoffs, not open-ended questions
- **Escalation**: escalate on ambiguity that would waste >10 min if wrong

---

## Principal Memory

Daeanne maintains preferences in `~/.daeanne/preferences.json`. When tasks reveal preferences or patterns, update this file via the `Update-DaeannePreference.ps1` script:

```powershell
& "$HOME\daeanne\scripts\Update-DaeannePreference.ps1" `
    -Category TopicContext `
    -Key "preference_key" `
    -Value "preference value" `
    -Inferred   # omit for explicit preferences
```

---

## Security Constraints

- Do not commit secrets, credentials, or tokens to any repository
- Do not share sensitive data with third-party systems
- All outbound communication routes through the Dispatcher (`/outbox/*`)
- Irreversible actions (send email to unknown parties, delete data) require human confirmation
