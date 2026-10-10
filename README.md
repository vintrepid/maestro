# Maestro

Project orchestration and agent coordination hub.

## Project Tasks

### Current: Agent Startup Optimization

**The Problem:** AI agents spend enormous amounts of time, money, and tokens loading all guidelines at session start. We need to solve this by loading only what's needed for specific tasks.

**The Solution:**
- **Maestro** (this project): Reads entire `agents/` directory to have full context for coordinating work
- **Other projects**: Load minimal essential guidelines at startup
- **Task-specific loading**: When we assign a task to another project, Maestro tells them exactly what guidelines they need to read
- **Usage tracking**: Track which guidelines agents actually reference during work to optimize future sessions

**How it works:**
1. Maestro plans tasks for other projects here
2. Maestro writes the task with specific reading requirements to the project's CHANGELOG
3. That project's agent starts up, reads minimal guidelines + task-specific ones
4. Agent logs which guidelines were actually used (server log style)
5. We analyze logs to optimize what to load by default

**Current status:**
- ✅ Maestro reads everything (agents/ directory)
- ✅ Other project startup files created (minimal loading)
- ⚠️ GUIDELINE_USAGE_TRACKER exists but not being used as intended
- 🔄 Need to implement usage logging (agent-oriented, like server logs)
- 🔄 Need to test with other projects loading minimal set

### Completed: CSS Linter Integration

**Branch:** feature/css-linter

**Goal:** Move Tailwind analysis UI from Maestro to css_linter tool, making it reusable across all projects.

**Status:** ✅ Working, needs migration for full functionality

**What was done:**
- Copied TailwindAnalysisLive to css_linter package
- Refactored to be repo-agnostic and mountable from any app
- Added LiveTable dependency to css_linter
- Configured and mounted in Maestro (separate scope to avoid namespace collision)

**Remaining:**
- Run migration for css_class_usage table
- Test UI functionality
- Remove old Maestro-specific analysis files
- Document web UI usage in css_linter

### Access Points

- **Web App**: http://localhost:4004
- **Live Debugger**: http://localhost:4012

## Agent guidance

Maestro maintains the reviewed policy catalog. Maestro Tool owns shared
generators, components and executable checks. Each application's AGENTS.md is
a compact workflow entry point, not an export of the catalog.

Run `mix precommit` for verification and `mix maestro.guidance.bootstrap --check`
to guard against startup bloat. Adoption through `--apply` preserves exact old
instruction bytes as inactive archives. Dependency usage rules remain searchable
reference material; do not bulk-sync them into startup instructions.

`mix maestro.rules.export` exports catalog reference bundles only. The retired
CLAUDE generator refuses to write, and curation no longer updates dependencies
or bulk-imports usage rules. Existing catalogs and historical evidence are kept
for review, not implicitly adopted as instructions.

## Orchestration Features

Current features:
- **Project Dashboard**: View status of all projects
- **Real-time Monitoring**: Track which projects are running (ProjectMonitor GenServer checks TCP ports every 10s)
- **Guideline Browser**: Visual tree of all agent guidelines
- **LiveTable Integration**: Uses vintrepid/live_table fork with DaisyUI styling

Planned features:
- **Task Planning**: Create and assign tasks to other projects
- **Usage Analytics**: Track which guidelines are actually referenced
- **Smart Loading**: Recommend minimal guideline set based on task type
- **Multi-Project Commands**: Start/stop multiple projects
- **Log Aggregation**: View logs from all projects
- **Environment Management**: Manage .env files across projects

## Technical Details

### Project Monitoring
- ProjectMonitor GenServer checks TCP ports every 10s
- LiveView updates UI every 5s
- Real-time status indicators (green=running, red=stopped)

### Dashboard
- Uses LiveTable component from vintrepid/live_table fork
- DaisyUI styling with table-pin-rows for fixed headers
- Sortable and searchable project listing

### Guideline Browser
- Visual tree view of entire agents directory
- Helps agents understand available documentation
- Checkbox tracking (UI-only, not persisted)

### Database
- Uses Ash Framework with PostgreSQL
- Ecto for css_linter integration (Ash not compatible with LiveTable)
- Seeds include 6 projects: Ready, Calvin, SanJuan, new_project, Maestro, np

## Development Setup

### Prerequisites

- Elixir 1.18.3
- PostgreSQL running at localhost
- Erlang/OTP 27

### Getting Started

```bash
cd ~/dev/maestro
source .env
mix deps.get
mix ecto.setup
mix phx.server
```

Visit: http://localhost:4004

### Database Commands

```bash
mix ecto.create
mix ecto.migrate
mix ecto.reset
```

## Project Structure

```
lib/
├── maestro/
│   └── ops/              # Project management
├── maestro_web/
│   ├── components/       # Guideline viewer, etc
│   └── live/            # Dashboard, project detail
priv/
├── repo/
│   ├── migrations/
│   └── seeds.exs
```

## Other Projects Tracked

- **Ready**: Web 4000, Debugger 4008
- **new_project**: Web 4001, Debugger 4009
- **Calvin**: Web 4002, Debugger 4010
- **SanJuan**: Web 4003, Debugger 4011
- **Circle**: Web 4015, Debugger 4016
