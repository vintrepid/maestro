# Current State: Task Runner Pattern Established

## This Session (Session 2): Critical Learning Captured

### 🚨 THE BREAKTHROUGH: Task Runner Workflow 🚨

We established the complete pattern for agent-user communication through tasks.

**The Pattern:**
1. User clicks "Run Task" button → Task becomes active
2. User says "run" → Agent executes
3. Agent follows workflow:
   - **START SESSION: `mix bundles.track init <project> <branch> <bundles>`**
   - Format description markdown
   - Read request (description field)
   - Plan and execute
   - **Log guideline refs as you work: `mix bundles.track ref <id> "context"`**
   - **Document completion (notes field) BEFORE marking complete!**
   - **Log task completion: `mix bundles.track task_complete <id>`**
   - Mark complete if done (only after notes are written)
   - **END SESSION: `mix bundles.track summary`**
   - Learn and capture patterns

**Key Files:**
- `TASK_RUNNER_WORKFLOW.md` - Complete workflow guide (includes completion checklist!)
- `WHAT_WENT_WRONG.md` - Session 2 learning (ALWAYS USE ASH)
- `bootstrap/GUIDELINES.md` - Core principle added (front and center)
- `current_task.json` - Crash recovery state

### What Was Completed

#### Task #20: Better Agent Training
**Request:** "Cleanup this markdown"
**Response:** 
- ✅ Learned the hard way: ALWAYS USE ASH (not browser_eval)
- ✅ Established Task Runner pattern
- ✅ Updated core guidelines (Ash principle front and center)
- ✅ Documented in WHAT_WENT_WRONG.md
- ✅ Updated current_task.json for crash recovery

**Critical Learning:** Tried to update task via browser_eval (failed). User corrected: "Use Ash framework." Immediate success with `Task.update(task, %{field: value})`.

#### Task #21: More Maestro Mix Tasks
**Request:** "Write scripts for yourself. I want to see a lot less shell commands."
**Response:**
- ✅ Created 4 new mix tasks
- ✅ `mix maestro.task.read TASK_ID`
- ✅ `mix maestro.task.update TASK_ID FIELD VALUE`
- ✅ `mix maestro.task.list [OPTIONS]`
- ✅ `mix agents.update FILE MESSAGE`
- ✅ Marked complete with detailed notes

### Infrastructure Now Available

**Mix Tasks for Future Sessions:**
```bash
mix maestro.task.read 20           # Read task details
mix maestro.task.update 20 status done  # Update via Ash
mix maestro.task.list --status todo     # List/filter tasks
mix agents.update FILE MESSAGE     # Update agents repo
```

**Documentation:**
- `TASK_RUNNER_WORKFLOW.md` - Step-by-step execution pattern
- `WHAT_WENT_WRONG.md` - Session 1 & 2 learnings
- `bootstrap/GUIDELINES.md` - ALWAYS USE ASH (first principle)
- `current_task.json` - Session state for crash recovery
- `USAGE_RULES.md` - All library patterns (38KB)

**Agents Repo Updated:**
- `bootstrap/GUIDELINES.md` - Added Ash principle as #1 core principle
- Committed and pushed to origin/main
- Available to ALL projects now

### The Golden Rule (Learned Session 2)

**🚨 ALWAYS USE ASH FOR DATA MODIFICATIONS 🚨**

```elixir
# Read
task = Maestro.Ops.Task.by_id!(task_id)

# Update (THE CORRECT WAY)
{:ok, updated} = Maestro.Ops.Task.update(task, %{
  description: cleaned_description,
  notes: completion_notes,
  status: :done
})
```

**NOT:**
- ❌ browser_eval to manipulate UI
- ❌ Direct SQL updates
- ❌ LiveView assign modifications

**Why:** Ash runs validations, calculations, authorization, hooks. Data actually persists.

## Next Session Priorities

### If User Clicks "Run Task" and Says "run"

1. **Read this file** - Understand current state
2. **Read TASK_RUNNER_WORKFLOW.md** - Follow the pattern
3. **Read the task's description** - That's the request
4. **Format description markdown** - Make it pretty
5. **Execute the work** - Ask questions if needed
6. **Write completion to notes** - Using Ash
7. **Mark complete** - If appropriate
8. **Learn** - Capture patterns

### Available Tools

```bash
mix maestro.task.read TASK_ID      # Read task
mix maestro.task.update TASK_ID notes "..." # Update via Ash
mix maestro.task.list --status todo        # List tasks
mix agents.update FILE MESSAGE     # Update agents repo
mix bundles.track ref ID "context" # Log usage
mix startup.build                  # Update startup.json
```

### Outstanding Tasks

Check active tasks:
```bash
mix maestro.task.list --status todo
```

Or look at Maestro UI: http://localhost:4004/tasks

## Session Statistics

**Session 2:**
- Tasks completed: 2 (Task #20, Task #21)
- Critical learning: ALWAYS USE ASH
- Mix tasks created: 4
- Guidelines updated: 3 files
- Agents repo commits: 1
- Guideline usage logged: 5 references

**Knowledge captured:**
- Task Runner Workflow pattern
- Ash-first principle (front and center)
- Mix tasks for common operations
- Crash recovery state maintained

## For Future You

**When you start:**
1. Read `startup.json` - Everything bundled
2. Read `current_task.json` - Session state
3. Read `TASK_RUNNER_WORKFLOW.md` - How to execute tasks
4. Check for active task: Look at AppState or UI

**When you work:**
- ALWAYS use Ash for data modifications
- Format description markdown
- **Document completion in notes BEFORE marking complete**
- Follow the completion checklist in TASK_RUNNER_WORKFLOW.md
- Mark complete only when truly done AND notes are written
- Learn and capture patterns

**When you finish:**
```bash
mix startup.build  # Update for next agent
git add . && git commit -m "Session summary"
git push origin feature/task-runner
```

**If you crash:**
Read `current_task.json` first - it has everything you need to continue.

## The Pattern That Works

**Description → Notes via Ash → Mark Complete**

```elixir
# 1. Read
task = Maestro.Ops.Task.by_id!(task_id)
IO.puts(task.description)  # The request

# 2. Do work
result = do_the_work()

# 3. Write response (FIRST!)
completion_notes = """
## Completion Note - [Task Name]

**Status:** ✅ Complete

### What Was Done
[Details...]

### Files Modified  
[List...]

### Learnings
[What to remember...]
"""

# 4. Update notes BEFORE marking complete
{:ok, updated} = Maestro.Ops.Task.update(task, %{
  notes: completion_notes,
  status: :done  # Only AFTER notes are written!
})
```

**Remember:** Notes come BEFORE marking complete!

See `TASK_RUNNER_WORKFLOW.md` for the full completion checklist.

This is the way. 🎯
