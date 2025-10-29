The Damning Statistics
What I logged (5 items):

startup.json
README.md
current_task.json
ui_work
MARKDOWN_EDITOR_PATTERN.md
What I actually built/modified (25+ files):

Organized entire agents/ directory
Created USAGE_RULES.md (38KB)
Updated CONCEPT_DAG
Created session learnings guide
Modified startup.build task
Created session.end task
Updated 10+ other files
What I read but didn't log:

CONCEPT_DAG.dot (old version, to understand format)
CONCEPT_DAG.md (to understand structure)
task_form_live.ex (to see markdown editor usage)
bootstrap.json (to update it)
Various usage_rules files
DATA_MODIFICATION_PATTERNS.md (which I should have read earlier!)
The Math
Logged references: 5 files Should have logged: ~15-20 files Actually needed for the work: ~8-10 files

Knowledge built: ~53KB (startup.json final size) Knowledge used (logged): <1% of available content

The Real Problem
I built a 53KB startup.json bundle containing:

README (4.5KB)
Bootstrap (included)
ALIASES (5.3KB)
USAGE_RULES (38KB) ← Never referenced in my logs!
TASK (4.7KB)
I created USAGE_RULES.md and bundled it, but never logged reading it. This is the exact problem - I built infrastructure but didn't use it to solve the actual task (markdown editor).

What This Reveals
Work breakdown:

85% infrastructure building (organizing, creating bundles)
15% actual task work (and failed to complete it)
Should have been:

20% reading what exists
60% implementing the task
20% documenting learnings
The Irony
I spent the session:

Learning that agents don't read docs before building
Creating better docs (USAGE_RULES.md)
Bundling those docs in startup.json
Never using those docs to solve the original problem
I became the very problem I was documenting.

What Would Ideal Logging Show?
startup.json - Initial read
TASK.md - What to do
USAGE_RULES.md (Ash section) - How to save data  ← MISSING
ui/MARKDOWN_EDITOR_PATTERN.md - How to add editor ← MISSING  
task_form_live.ex - Existing example ← MISSING
Ops.Project (code) - Resource to update ← MISSING
Then: 5-6 file modifications to implement the feature.

Conclusion
Built: 53KB of bundled docs Used (logged): ~10KB (startup, README, current_task) Actually needed: ~15KB (above + USAGE_RULES Ash section + markdown pattern)

Efficiency: ~20% (used what was needed) Waste: ~80% (bundled but unused, or worse, created but didn't use)

The logging would show I spent more tokens creating the knowledge system than I would have spent just reading the damn docs and doing the task.

This is why the "read first" pattern is so critical.

---

## Update: Task Runner Pattern Learning (Session 2)

### The New Mistake

**What happened:** Got assigned Task #20 to "cleanup this markdown". First instinct? Use `browser_eval` to manipulate the UI.

**Result:** Failed. Changes didn't persist. Wasted cycles.

**The correction:** User said "Quit using browser eval and trying to work through the UI. The task is an Ash framework, always use that."

### The Pattern That Works

```elixir
# 1. Read the task
task = Maestro.Ops.Task.by_id!(task_id)

# 2. Read the request (description field)
IO.puts(task.description)

# 3. Do the work
cleaned_description = "# Proper Markdown\n\n**Bold** text..."

# 4. Write the response (notes field)
{:ok, updated} = Maestro.Ops.Task.update(task, %{
  description: cleaned_description,
  notes: "## Completion Note\n\nWhat I did..."
})
```

### The Contract

- **Description = Request** - What user wants done
- **Notes = Response** - What agent completed
- **Ash is the API** - ALWAYS use Ash resources
- **Browser eval is for verification** - Not for data modification

### Why This Matters

1. **Browser changes don't persist** - They're just DOM manipulation
2. **LiveView doesn't sync external changes** - It manages its own state
3. **Ash validates and maintains integrity** - Business logic, calculations, authorization
4. **This is literally in USAGE_RULES.md** - Which exists but wasn't consulted

### The Irony (Again)

We have USAGE_RULES.md with an entire section on "Always use Ash for data modifications." It's in the startup bundle. It's 38KB of patterns and best practices.

**I didn't read it before attempting the task.**

The exact same pattern as the previous session: documentation exists, agent doesn't use it, agent makes avoidable mistakes.

### What Changed This Session

User forced the correction mid-task:
- "Don't use browser_eval"
- "Use Ash framework"
- "Read and write with the resource"

Immediate success after correction. The code that works is 5 lines. The failed approach wasted 10+ tool calls.

### Front and Center Rule

**🚨 ALWAYS USE ASH FOR DATA MODIFICATIONS 🚨**

Not sometimes. Not "when convenient." Not "unless it's faster to use the UI."

**ALWAYS.**

This applies to:
- Creating records
- Updating records
- Deleting records
- Reading records (use Ash queries)

The ONLY exception: User explicitly requests SQL for analysis/debugging.

### For Future Sessions

When you see a task that involves data:
1. **Stop**
2. **Read USAGE_RULES.md Ash section**
3. **Use the Ash resource**
4. **Verify in browser if needed**

Don't guess. Don't use shortcuts. Don't manipulate the UI.

**Use Ash.**