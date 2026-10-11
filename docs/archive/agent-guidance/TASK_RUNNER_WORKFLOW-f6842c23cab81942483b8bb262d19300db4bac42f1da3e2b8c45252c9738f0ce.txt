# Task Runner Workflow Guide

## Overview

The Task Runner pattern enables efficient agent-user communication through structured tasks in Maestro.

## The Workflow

### 1. User Clicks "Run Task"
- Task becomes active in AppState
- Agent is ready to execute

### 2. User Says "run"
- Triggers agent execution
- Agent reads the active task

### 3. Agent Executes Pattern

#### Step 1: Format Description
```elixir
# If description needs markdown cleanup
task = Maestro.Ops.Task.by_id!(task_id)
cleaned = "# Title\n\n**Bold** text..."
Maestro.Ops.Task.update(task, %{description: cleaned})
```

#### Step 2: Read Request
- Description field = User's request
- What needs to be done
- Success criteria

#### Step 3: Plan Approach
- Break down into steps
- Identify questions/blockers
- Consider edge cases

#### Step 4: Execute
- Do the work
- Ask questions if needed
- Use existing tools and patterns
- **Always use Ash for data modifications**

#### Step 5: Document Completion

🚨 **CRITICAL: Notes come BEFORE marking complete!** 🚨

```elixir
completion_notes = """
## Completion Note - [Task Name]

**Status:** ✅ Complete / 🔄 In Progress / ⚠️ Blocked

### What Was Done
- Bullet list of actions taken
- Key decisions made
- Problems solved

### How It Works
[Brief explanation of the solution]

### Testing
[What was tested and results]

### Files Modified
- path/to/file.ex - [what changed]
- path/to/another.ex - [what changed]

### Learnings
- What went well
- What didn't work initially
- What to remember for next time

### Next Steps
[If incomplete or blocked, what's needed next]
"""

# Update notes FIRST
Maestro.Ops.Task.update(task, %{
  notes: completion_notes,
  status: :done  # only if truly complete
})
```

### Completion Checklist

Before marking any task as complete, verify:

- [ ] **Updated task.notes** with completion report (using Ash!)
- [ ] **Verified all success criteria** from description are met
- [ ] **Marked task.status** appropriately:
  - `:done` - Fully complete, tested, working
  - `:in_progress` - Started but not finished
  - `:blocked` - Can't proceed, needs user input
- [ ] **Set completed_at** if marking as done
- [ ] **Committed code changes** with clear messages
- [ ] **Updated current_task.json** for next session (if applicable)
- [ ] **Logged guideline usage** properly:
  - Start session: `mix bundles.track init <project> <branch> <bundles>`
  - Log each guideline you reference: `mix bundles.track ref <guideline_id> "context"`
  - Log task completions: `mix bundles.track task_complete <task_id>`
  - End session: `mix bundles.track summary`

**DO NOT mark task complete until notes are written AND logging is done!**

### Why Completion Notes Matter

Completion notes are **critical** for:
- **Future sessions** understanding what happened
- **Coordinator** tracking progress across projects
- **Learning** from successes and failures
- **Maintaining context** across session boundaries
- **User visibility** - seeing what was done without digging into code

**Without notes:**
- Future sessions don't know what happened ❌
- Can't learn from the work ❌
- Risk duplicate effort ❌
- Context is lost ❌
- Pattern breaks down ❌

### Good Completion Notes Examples

#### Example 1: Code Task (Complete)
```markdown
## Completion Note - Create Mix Tasks for Task Management

**Status:** ✅ Complete

### What Was Done

1. Created 4 new mix tasks in `lib/mix/tasks/maestro/`:
   - `maestro.task.read` - Read task details
   - `maestro.task.update` - Update task fields via Ash
   - `maestro.task.list` - List/filter tasks
   - `maestro.task.complete` - Mark task complete

2. All tasks use Ash framework (not browser manipulation)
3. Added clear documentation and examples
4. Tested all commands successfully

### How It Works

Tasks use `Maestro.Ops.Task` Ash resource:
- `by_id!/1` to fetch tasks
- `update/2` to modify via Ash actions
- `read_all!/1` with filters for listing

### Testing

```bash
mix maestro.task.read 21  # ✓ Shows task details
mix maestro.task.update 21 status done  # ✓ Updates via Ash
mix maestro.task.list --status todo  # ✓ Filters working
```

### Files Modified

- `lib/mix/tasks/maestro/task.read.ex` - New file
- `lib/mix/tasks/maestro/task.update.ex` - New file  
- `lib/mix/tasks/maestro/task.list.ex` - New file
- `lib/mix/tasks/maestro/task.complete.ex` - New file

### Learnings

- Using Ash for updates ensures validations run
- Mix tasks need `Mix.Task.run("app.start")` for Ash
- Clear help text prevents user confusion

### Next Steps

None - task complete!
```

#### Example 2: Blocked Task
```markdown
## Completion Note - Fix Navigation Bug

**Status:** ⚠️ Blocked

### What Was Done

1. Identified root cause: LiveView assigns not persisting
2. Tested multiple approaches:
   - Socket assigns ❌ (cleared on navigation)
   - Session storage ❌ (security concerns)
   - Database ❓ (need user decision)

3. Prepared three solutions with trade-offs

### Questions for User

**Which approach should we use?**

A) Store in database (persistent, slower)
B) Use ETS cache (fast, lost on restart)  
C) Rethink the feature requirement

I recommend A for reliability.

### Files Modified

None yet - waiting for decision.

### Next Steps

1. User decides on approach
2. Implement chosen solution
3. Test thoroughly
4. Update this task when complete
```

#### Example 3: In Progress Task
```markdown
## Completion Note - Implement User Authentication

**Status:** 🔄 In Progress (70% complete)

### What Was Done

1. ✅ Set up AshAuthentication with password strategy
2. ✅ Created User resource with authentication
3. ✅ Added login/register LiveViews
4. 🔄 Working on session management
5. ⏳ TODO: Password reset flow
6. ⏳ TODO: Email confirmation

### Files Modified

- `lib/myapp/accounts/user.ex` - Ash resource with auth
- `lib/myapp_web/live/auth/login_live.ex` - New
- `lib/myapp_web/live/auth/register_live.ex` - New
- `lib/myapp_web/router.ex` - Added auth routes

### Current Issue

Session token not persisting across page refreshes. Need to:
1. Store token in secure cookie
2. Load user from token on mount
3. Add logout functionality

### Next Steps

1. Fix session persistence (next session)
2. Add password reset flow
3. Add email confirmation
4. Write tests

Estimate: 2-3 more sessions to complete.
```

#### Step 6: Learn
- Capture patterns
- Update guidelines if needed
- Document in session learnings

## Task Types & Handling

### Code Tasks (like Task #21)
- Create/modify code files
- Write tests if applicable
- Commit with clear messages
- Mark complete when done

### Cleanup Tasks (like Task #20)
- Format markdown
- Refactor code
- Update documentation
- Mark complete when done

### Coordination Tasks (like Task #19)
- May involve other projects
- Write detailed spec
- May remain open for external completion
- Don't mark complete until user confirms

### Learning Tasks
- Capture knowledge
- Update guidelines
- Create documentation
- Mark complete when captured

## Communication Protocol

**Description (User → Agent):**
- Clear request
- Success criteria
- Context if needed

**Notes (Agent → User):**
- Completion report
- What was done
- Files modified
- Questions/blockers
- Next steps

## Key Principles

1. **Always use Ash** for data modifications
2. **Format markdown** to make descriptions readable
3. **Ask questions** when unclear
4. **Document thoroughly** in notes (BEFORE marking complete!)
5. **Log guideline usage** throughout session (`mix bundles.track`)
6. **Learn and capture** patterns
7. **Mark complete** only when truly done AND notes are written
8. **Never skip completion notes or logging** - they're not optional

## Example Session

```bash
# User clicks "Run Task" on Task #21
# User: "run"

# Agent:
# 1. Reads description: "Create mix tasks"
# 2. Plans: 4 tasks needed
# 3. Creates files
# 4. Tests tasks
# 5. Commits work
# 6. Updates notes with completion report
# 7. Marks task as done
# 8. Logs learning
```

## Tools Available

- `mix maestro.task.read TASK_ID` - Read task details
- `mix maestro.task.update TASK_ID FIELD VALUE` - Update task
- `mix maestro.task.list` - List tasks
- `mix agents.update FILE MESSAGE` - Update agents repo
- `mix bundles.track` - Log guideline usage

## Files to Reference

- `WHAT_WENT_WRONG.md` - Common mistakes
- `USAGE_RULES.md` - Library patterns (Ash section critical)
- `bootstrap/GUIDELINES.md` - Core principles
- `current_task.json` - Session state

## Success Indicators

✅ Task description is well-formatted markdown
✅ Work is completed or blocker is documented
✅ Completion notes are detailed and clear
✅ Ash was used for all data modifications
✅ **Guideline usage logged throughout session**
✅ Learning was captured if applicable
✅ Task status reflects reality (done/in_progress/blocked)
✅ **Session logged with `mix bundles.track` (init/ref/task_complete/summary)**

## For Future Sessions

When you crash and restart:
1. Read `current_task.json`
2. Check for active task in AppState
3. Follow this workflow
4. Continue where you left off
