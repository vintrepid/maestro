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
```elixir
completion_notes = """
## Completion Note - [Task Name]

**Status:** ✅ Complete / 🔄 In Progress / ⚠️ Blocked

### What Was Done
- Bullet list of actions taken

### Files Modified
- List of changed files

### Questions/Issues
- Any blockers or decisions needed

### Next Steps
- What remains (if incomplete)
"""

Maestro.Ops.Task.update(task, %{
  notes: completion_notes,
  status: :done  # if complete
})
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
4. **Document thoroughly** in notes
5. **Learn and capture** patterns
6. **Mark complete** when appropriate

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
✅ Learning was captured if applicable
✅ Task status reflects reality (done/in_progress/blocked)

## For Future Sessions

When you crash and restart:
1. Read `current_task.json`
2. Check for active task in AppState
3. Follow this workflow
4. Continue where you left off
