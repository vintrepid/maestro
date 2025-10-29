# Session Learnings - October 28, 2025 (Session 2)

## Session Context

**Branch:** feature/task-runner  
**Focus:** Task Runner Pattern establishment and agent coordination  
**Token Usage:** ~107k / 200k (54%)  

## Critical Breakthrough: Task Runner Pattern

### The Problem We Solved

Previous session built infrastructure but never completed the original task. This session established a working pattern for agent execution.

### The Pattern That Emerged

**Task Runner Workflow:**
1. User clicks "Run Task" button → Task becomes active
2. User says "run" → Agent executes
3. Agent follows: Format → Read → Plan → Execute → Document → Learn
4. **Description = Request** (what user wants)
5. **Notes = Response** (what agent completed)
6. **Always use Ash** for data modifications

### Key Learning #1: ALWAYS USE ASH 🚨

**The Mistake:**
- Task #20: Tried to update task using `browser_eval` and UI manipulation
- Changes didn't persist
- Wasted 10+ tool calls

**The Correction:**
- User said: "Use Ash framework, read and write with resource"
- Immediate success with `Task.update(task, %{field: value})`

**Why It Matters:**
- Browser changes don't persist
- LiveView manages its own state
- Ash runs validations, calculations, authorization
- Data actually saves

**Documented:**
- Added as #1 core principle in `bootstrap/GUIDELINES.md`
- Front and center for all future agents
- WHAT_WENT_WRONG.md Session 2 section
- USAGE_RULES.md already had it (but I didn't read it first!)

### Key Learning #2: Mix Tasks > Shell Commands

**Task #21:** Created 4 mix tasks to replace repetitive shell commands

**What We Built:**
```bash
mix maestro.task.read TASK_ID           # Read task details
mix maestro.task.update TASK_ID FIELD   # Update via Ash  
mix maestro.task.list [OPTIONS]         # List/filter tasks
mix agents.update FILE MESSAGE          # Update agents repo
```

**Why It Matters:**
- Reusable across sessions
- Proper error handling
- Self-documenting with `--help`
- Less typing, fewer mistakes

### Key Learning #3: Coordination Pattern

**Task #22:** Successfully coordinated Maestro → Circle

**The Pattern:**
1. **Maestro creates task** in UI
2. **Maestro generates package:**
   - `task_<name>.json` - Machine-readable spec
   - `current_task.json` - Copy for execution
   - `TASK.md` - Human-readable instructions
3. **Project agent reads** current_task.json
4. **Project agent executes** the work
5. **Project agent reports** via `COMPLETION-<name>.md`
6. **Maestro reads completion** and updates task

**What Worked:**
- Simple task package format
- Minimal instructions (Circle already has guidelines)
- Clear success criteria
- COMPLETION file provides perfect record
- Total time: ~10 minutes

**Discovery:** Entity fields were create-only, needed to add them to `:update` action

### Key Learning #4: Format First, Always

**Every task started with:**
```elixir
task = Task.by_id!(task_id)
formatted_desc = "# Title\n\n**Bold** text..."
Task.update(task, %{description: formatted_desc})
```

**Benefits:**
- Makes requests clear
- Shows professionalism
- Easier to read later
- Sets expectations

## Infrastructure Built

### Documentation Created

1. **TASK_RUNNER_WORKFLOW.md** - Complete step-by-step guide
2. **WHAT_WENT_WRONG.md** - Session 1 & 2 learnings
3. **TASK.md** - Updated with current session state
4. **current_task.json** - Crash recovery state

### Mix Tasks Created

- `lib/mix/tasks/maestro/task.read.ex`
- `lib/mix/tasks/maestro/task.update.ex`
- `lib/mix/tasks/maestro/task.list.ex`
- `lib/mix/tasks/agents.update.ex`

### Core Principle Added

Updated `~/dev/agents/bootstrap/GUIDELINES.md`:
- Added "ALWAYS USE ASH" as **first** core principle
- Includes code examples
- Task Runner pattern documented
- Committed and pushed to agents repo

### Ash Schema Enhanced

- Added `entity_type` and `entity_id` to Task `:update` action
- Enables task reassignment between projects
- Critical for coordination pattern

## Tasks Completed

### Task #20: Better Agent Training
- Established Task Runner pattern
- Captured critical "Always use Ash" learning
- Updated all documentation
- Formatted description with markdown

### Task #21: More Maestro Mix Tasks  
- Created 4 mix tasks
- Replaced shell commands with proper tools
- Tested and documented
- Marked complete

### Task #22: Circle UI Cleanup
- Demonstrated coordination pattern
- Generated task package for Circle
- Circle executed successfully
- Read completion and updated task
- **Pattern validated!**

### Task #23: Coordination Discussion (Created)
- Document when Maestro should do work vs. assign
- Efficiency vs. learning tradeoff
- Future enhancement: "run" automation

## Patterns Established

### 1. Task Execution Pattern

```
User: "run"
↓
Agent:
1. Format description (make it pretty)
2. Read request (description field)
3. Plan approach
4. Execute (ask if unclear)
5. Document completion (notes field via Ash)
6. Mark complete if done
7. Learn and capture patterns
```

### 2. Coordination Pattern

```
Maestro → Other Project:
1. Create task in Maestro UI
2. Generate task package (JSON + TASK.md)
3. Copy to project's current_task.json
4. User tells project "run"
5. Project executes and creates COMPLETION-<name>.md
6. User tells Maestro "Circle completed"
7. Maestro reads completion and updates task
```

### 3. Learning Pattern

```
User: "learn"
↓
Agent:
1. Create/update SESSION_LEARNINGS_<date>.md
2. Document problems + solutions
3. Update relevant guides
4. Commit to appropriate repos
```

## Anti-Patterns Identified

### Don't Do This:
❌ Use `browser_eval` for data modifications  
❌ Assume UI changes persist  
❌ Skip reading USAGE_RULES.md before attempting data tasks  
❌ Mark tasks complete when they're just queued  
❌ Forget to update future you (startup.json, TASK.md)  

### Do This:
✅ Always use Ash for data modifications  
✅ Format description markdown first  
✅ Read existing documentation before building  
✅ Create mix tasks for repeated operations  
✅ Document completion in notes via Ash  
✅ Update startup.json at end of session  

## Statistics

**Tasks:**
- Completed: 3 (Tasks #20, #21, #22)
- Created: 1 (Task #23)

**Files Created:**
- TASK_RUNNER_WORKFLOW.md
- WHAT_WENT_WRONG.md (Session 2 section)
- 4 mix task files
- Circle task package (3 files)
- This file

**Files Modified:**
- TASK.md (updated state)
- startup.json (rebuilt)
- current_task.json (maintained)
- lib/maestro/ops/task.ex (added entity fields)
- ~/dev/agents/bootstrap/GUIDELINES.md (core principle)

**Commits:**
- Maestro: 5 commits
- Agents repo: 1 commit
- Circle: 1 commit (by Circle agent)

**Guidelines Logged:**
- git_feature_branch
- daisyui_for_components
- use_ash_for_data (multiple times!)
- usage_tracking

## For Next Session

### Must Read First:
1. startup.json - Has everything bundled
2. TASK.md - Current state
3. TASK_RUNNER_WORKFLOW.md - How to execute tasks
4. USAGE_RULES.md Ash section - BEFORE data tasks!

### Available Tools:
```bash
mix maestro.task.read TASK_ID
mix maestro.task.update TASK_ID FIELD VALUE
mix maestro.task.list [OPTIONS]
mix agents.update FILE MESSAGE
mix bundles.track ref ID "context"
mix startup.build
```

### Pattern to Follow:
When user says "run":
1. Read task with `mix maestro.task.read TASK_ID`
2. Format description if needed
3. Execute following Task Runner pattern
4. Document in notes using Ash
5. Mark complete if appropriate
6. Learn from the work

### Outstanding Tasks:
- Task #23: Coordination efficiency discussion
- Task #19: Circle UI alignment (Maestro side)
- Task #20: Has more instructions (future you sessions)

## Key Insights

### 1. Documentation Without Usage is Wasted

Session 1 created USAGE_RULES.md (38KB of patterns). Session 2 made a mistake that was documented in USAGE_RULES.md. **I didn't read it first.**

**Lesson:** Read docs BEFORE attempting, not after failing.

### 2. Simple Task Packages Work

Circle already has guidelines. They don't need verbose instructions. Simple JSON + TASK.md with clear objectives works perfectly.

**Lesson:** Don't over-specify when the agent is already trained.

### 3. Coordination Creates Overhead

Task #22 took ~10 minutes total, but required:
- Task package creation
- Context switching (Maestro → Circle)
- Completion file reading

For a simple UI change, Maestro could have done it faster.

**Lesson:** Balance efficiency vs. learning opportunities. Document criteria in Task #23.

### 4. Mix Tasks Compound Value

Every session that uses `mix maestro.task.read` saves time. Mix tasks are an investment that pays dividends.

**Lesson:** Convert repeated patterns to mix tasks proactively.

### 5. Ash Schema is Contract

The `:update` action's `accept` list defines what can be changed. Entity fields being create-only was intentional design.

**Lesson:** Read resource definitions to understand constraints before attempting updates.

## Recommendations

### For Immediate Next Session:

1. **Run Task #23** - Discuss coordination efficiency
2. **Create automation** - `mix maestro.task.trigger` for "run" command
3. **Test pattern again** - Assign another small task to Circle
4. **Document criteria** - When Maestro does work vs. assigns

### For Long Term:

1. **Bundle refinement** - Measure what's actually used
2. **Completion polling** - Automate checking for COMPLETION files
3. **Multi-agent orchestration** - Handle multiple projects concurrently
4. **Learning analytics** - Track which guidelines prevent mistakes

## Success Metrics

✅ Task Runner Pattern established and documented  
✅ Core principle (Always Ash) propagated to all projects  
✅ Coordination pattern validated with real execution  
✅ Mix tasks created for common operations  
✅ Future you can pick up where we left off  
✅ No crashes or lost context  
✅ Learning captured for reuse  

## Grade: A 🎯

Established working patterns, validated coordination, created reusable tools, and documented everything for future agents. The infrastructure from Session 1 is now being used effectively in Session 2.

**Next session will be even faster because the patterns are established.**
