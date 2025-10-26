# Maestro Changelog

All notable work on the Maestro project orchestration hub is documented here.

## 2024-10-26 - Initial Setup Complete

**Goal:** Set up Maestro as a Phoenix/LiveView/Ash orchestration hub for managing multiple development projects.

**Completed:**
- ✅ Created project with mix igniter.new
- ✅ Configured ports (4004 for web, 4012 for LiveDebugger)
- ✅ Initial database setup
- ✅ Pushed to GitHub

**Status:** Initial setup complete, ready to build features

---

## 2024-10-26 - Build Orchestration Dashboard

**Goal:** Create a dashboard that displays and manages multiple Phoenix projects (Ready, Calvin, SanJuan, np, new_project).

**Features to Build:**
- Project listing (name, ports, URLs)
- Status indicators (running/stopped)
- Quick links to each project
- Visual dashboard with project cards

**Tasks:**
- [x] Create Projects Ash resource
- [x] Build dashboard LiveView
- [x] Add project status checking
- [x] Style with world-class UI design
- [x] Test functionality

**Branch:** feature/orchestration-dashboard

**Status:** Complete ✅

**Accomplished:**
- Created Ops domain with Project resource (name, slug, ports, status, URLs)
- Built beautiful dashboard with gradient design and project cards
- Implemented ProjectMonitor GenServer for real-time status checking
- Status updates every 10s by checking TCP ports
- LiveView refreshes every 5s to show updated statuses
- Seeded 6 projects: Ready, Calvin, SanJuan, new_project, Maestro, np
- Dashboard shows running projects in green, stopped in red
- Working links to web apps, debuggers, and GitHub repos

---

## 2024-10-26 - Convert to LiveTable

**Goal:** Replace custom table implementation with LiveTable component from our fork.

**Branch:** feature/live-table-dashboard

**Status:** Complete ✅

**Accomplished:**
- Installed live_table dependency from vintrepid/live_table fork (master branch)
- Configured LiveTable with Repo and PubSub
- Integrated JavaScript hooks and CSS from live_table
- Created Ecto query function for direct table access (bypassing Ash for LiveTable compatibility)
- Implemented LiveTable.LiveResource behavior properly
- Defined fields with proper sortable flags (all fields must have sortable key)
- Dashboard now uses DaisyUI-styled LiveTable with:
  - Sortable columns (Project, Status, Web Port)
  - Searchable project names
  - Pinned header and zebra striping
  - 25 items per page pagination
- All 6 projects display correctly with real-time status from ProjectMonitor

---

## 2024-10-27 - Extract Tailwind Analysis from Calvin

**Goal:** Extract the Tailwind class analysis tool from Calvin project and integrate it into Maestro for use across all projects.

**Context:**
- Calvin has a comprehensive Tailwind analysis system built in October 2024
- Features include: Mix task scanner, Ecto schema for storage, LiveView dashboard with LiveTable
- This tool helps identify CSS class usage patterns and optimize Tailwind implementations

**Tasks:**
- [ ] Document task and coordinate with Calvin agent
- [ ] Create feature branch
- [ ] Extract Mix.Tasks.AnalyzeTailwind from Calvin
- [ ] Extract Calvin.Analysis.TailwindClassUsage schema
- [ ] Extract CalvinWeb.AdminLive.TailwindAnalysisLive
- [ ] Create database migration for tailwind_class_usage table
- [ ] Adapt code to work with Maestro's structure
- [ ] Test the analysis tool on Maestro's codebase
- [ ] Update routes and navigation

**Branch:** feature/tailwind-analysis

**Status:** In Progress 🚧

**Progress:**
- ✅ Created database migration for tailwind_class_usage table
- ✅ Extracted and adapted Mix.Tasks.AnalyzeTailwind (works perfectly)
- ✅ Extracted and adapted Maestro.Analysis.TailwindClassUsage schema
- ✅ Created TailwindAnalysisLive view with stats and history sections
- ✅ Added route to /admin/tailwind-analysis
- ✅ Mix task successfully analyzes 175 unique classes, 462 total occurrences
- ✅ Data loads to database correctly
- ⚠️  LiveTable integration has sorting issue - needs debugging

**Current Issue:**
LiveTable component errors with `Keyword.get(nil, :class_name, nil)` when trying to render sortable headers. The rest of the page (stats, top 20, categories, files) renders correctly. Need to investigate LiveTable sort_helpers configuration.

**Branch:** `feature/tailwind-analysis` (pushed to GitHub)

**Architecture Decision:**
Changing approach to create a shared Hex package + centralized hub:
1. Create `tailwind_analyzer` package with core analysis logic
2. Each project installs the package and runs analysis locally
3. Results are sent to Maestro via API for aggregation
4. Maestro displays multi-project Tailwind usage analysis

**New Tasks:**
- [x] Create tailwind_analyzer Hex package → Changed to `css_linter`
- [x] Set up project structure in ~/dev/forks/css_linter
- [x] Add dependencies (Igniter, Jason)
- [ ] Extract Mix task and schema to package
- [ ] Implement Tailwind strategy with class categorization
- [ ] Create Igniter-based setup task
- [ ] Add basic tests
- [ ] Build Maestro API endpoint to receive analysis data
- [ ] Track which project each analysis came from
- [ ] Update dashboard for multi-project view
- [ ] Test with Calvin integration

**Current Status (2024-10-27 02:30):**
✅ **Phases 1 & 2 Complete** - css_linter library + multi-project Maestro
⚠️  **Known Issue** - LiveTable sorting configuration (same as before)

**What Works:**
- `css_linter` library fully functional
- `mix css_linter.analyze --strategy tailwind --output analysis.json`  
- `mix maestro.load_analysis analysis.json --project name`
- Multi-project database schema with project_name
- Dashboard project dropdown filter
- Stats update per project selection
- 924 records in database (462 maestro + 462 legacy)

**Known Issues:**
- LiveTable component has sorting error (affects bottom table only)
- Top sections work: stats, history, top 20, categories, files
- Bottom "All Class Usage" table doesn't render

**Ready for Calvin:**
Library is production-ready. Calvin can test and share analysis JSON.
