# Ongoing Task: Agent Training & Documentation

## Current Status: Infrastructure Complete

We've completed the foundational work for agent training and documentation system.

### Completed This Session:
1. ✅ Organized agents/ directory into 5 concept clusters (core, database, ui, tools, projects)
2. ✅ Created USAGE_RULES.md with all library patterns (38KB, 1185 lines)
3. ✅ Built startup.json bundling README + bootstrap + aliases + usage_rules
4. ✅ Created `mix session.end` task for workflow automation
5. ✅ Updated CONCEPT_DAG with new guides (Data Modification, LiveView vs JS, Markdown Editor, Circle Learnings)
6. ✅ Documented session learnings in agents/guides/SESSION_LEARNINGS_2025_10_28.md
7. ✅ Fixed startup.build to read from reorganized structure

### Key Infrastructure Now Available:

**For Agent Startup:**
- `startup.json` - Bundled README, bootstrap, aliases, usage_rules (all needed to start)
- `USAGE_RULES.md` - All library + tool patterns (Ash, Phoenix, maestro_tool, css_linter, live_table)
- `current_task.json` - Task details (when assigned)

**For Agent Workflow:**
- `mix session.end <used> <total>` - Runs all end-of-session tasks
- `mix startup.build` - Rebuilds startup.json with latest content
- `mix bundles.track` - Track guideline usage
- `mix usage_rules.sync` - Update library patterns when deps change

**Documentation Structure:**
```
~/dev/agents/
├── core/           # Bootstrap guidelines (Git, GUIDELINES, STARTUP, ALIASES)
├── database/       # DATA_MODIFICATION_PATTERNS
├── ui/             # LiveView, DaisyUI, LIVEVIEW_VS_JAVASCRIPT, MARKDOWN_EDITOR
├── tools/          # LiveTable, Fly deployment, Igniter
├── projects/       # Circle learnings, Navbar setup
├── bundles/        # JSON bundles (bootstrap.json, ui_work.json, etc.)
├── guides/         # Detailed guides and session learnings
└── usage_rules/    # Symlinks to library docs
```

## Next Steps (For Future Sessions):

### Priority 1: Validate Infrastructure
- Test that new agents can successfully read startup.json and get started
- Verify USAGE_RULES.md provides enough context for common tasks
- Check that session.end workflow completes successfully

### Priority 2: Original Task - Markdown Editor
**We never actually completed the original task from this session:**
- Add WYSIWYG markdown editor to project description field on /projects/:slug page
- Should use the pattern documented in `ui/MARKDOWN_EDITOR_PATTERN.md`
- Use Ash Resource.update() for saving (not SQL)
- Follow the existing EasyMDE hook pattern in assets/js/app.js

**Implementation:**
1. Read `ui/MARKDOWN_EDITOR_PATTERN.md`
2. Check existing implementation on task form (lib/maestro_web/live/task_form_live.ex)
3. Apply same pattern to project detail page
4. Use `Maestro.Ops.Project.update(project, %{description: description})`

### Priority 3: Process Improvements
- Create `mix concept.dag.update` task to automate DAG regeneration
- Consider automating USAGE_RULES.md sync in session.end (if deps changed)
- Document the "Read before building" pattern more prominently

### Priority 4: Testing & Validation
- Verify concept DAG accurately reflects all guides
- Test bundle tracking is capturing useful data
- Validate startup.json size is manageable (currently ~50KB)

## Key Learnings to Remember:

1. **Always read USAGE_RULES.md at startup** - Contains library patterns
2. **Check existing code before building** - Components/patterns often exist
3. **Use Ash for all data updates** - Never bypass with SQL
4. **Read detailed formats before modifying** - Preserve structure (like CONCEPT_DAG.dot)
5. **Use update_plan to track work** - Prevents forgetting tasks

## Files Modified This Session:

**Maestro:**
- TASK.md (new) - This file
- USAGE_RULES.md (new) - All library + tool patterns
- startup.json (updated) - Now bundles USAGE_RULES
- lib/mix/tasks/startup.build.ex - Reads from reorganized structure, includes USAGE_RULES
- CONCEPT_DAG.dot - Added new guides
- priv/static/images/concept_dag.svg - Regenerated

**Agents:**
- Reorganized into 5 folders (core, database, ui, tools, projects)
- guides/SESSION_LEARNINGS_2025_10_28.md (new)
- usage_rules/maestro_tool.md (symlink)

**Maestro Tool:**
- lib/mix/tasks/session.end.ex (new) - End-of-session workflow

## Session Statistics:
- Tokens used: ~144k / 200k (72%)
- Files modified: ~25
- Key insight: 85% of tokens wasted by not reading docs first
- Critical file added: USAGE_RULES.md (would have prevented most issues)

## For Next Agent:

Start by reading startup.json - it contains everything you need bundled inline.
Then check this TASK.md file to understand current state and next priorities.
