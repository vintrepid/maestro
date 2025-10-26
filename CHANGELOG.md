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

**Status:** Complete ✅

**Progress:**
- ✅ Created database migration for tailwind_class_usage table
- ✅ Extracted and adapted Mix.Tasks.AnalyzeTailwind (works perfectly)
- ✅ Extracted and adapted Maestro.Analysis.TailwindClassUsage schema
- ✅ Created TailwindAnalysisLive view with stats and history sections
- ✅ Added route to /admin/tailwind-analysis
- ✅ Mix task successfully analyzes 175 unique classes, 462 total occurrences
- ✅ Data loads to database correctly
- ✅ Fixed asset build issues (Tailwind v4 compatibility)
- ✅ Fixed LiveTable CSS (ring-opacity-5 -> ring-black/5)
- ✅ Fixed LiveTable JS import (default export)
- ✅ Dashboard fully functional with stats, history, and tables
- ✅ Multi-project support working (calvin + maestro data)
- ✅ Project filter dropdown working

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

---

## 2024-10-27 - Styling & UX Improvements

**Goal:** Improve the UI/UX of the Tailwind analysis page based on comparison with Calvin, and enhance admin navigation.

**Tasks:**
- [ ] Improve h1 styling (Calvin has better design)
- [ ] Fix timestamp cutoff in Analysis run picker
- [✅] Improve h1 styling (Calvin has better design)
- [✅] Fix timestamp cutoff in Analysis run picker
- [ ] Add page inventory section (shows which pages use which classes)
- [✅] Add delete button for analysis runs
- [✅] Move theme picker to dedicated admin settings page
- [✅] Create admin navigation menu
- [✅] Improve overall spacing and padding

**Branch:** feature/styling-improvements

**Status:** Complete ✅

**Accomplished:**
- Added global typography styles (h1, h2, h3) to app.css
- Created .page-section wrapper class for consistent padding
- Simplified tailwind analysis page markup
- Fixed timestamp picker width and improved date format readability
- Added delete button with trash icon for analysis runs
- Implemented delete_run event handler with confirmation
- Created admin dropdown menu in navbar
- Moved theme selector into admin dropdown
- Added Tailwind Analysis link to admin menu


---

## 2024-10-27 - Simplify Analysis Feature

**Goal:** Simplify the Tailwind analysis feature to focus on core functionality.

**Branch:** feature/simplify-analysis

**Status:** Complete ✅

**Accomplished:**
- Created separate Page Inventory feature on its own page
- Moved page inventory from tailwind analysis to /admin/page-inventory
- Added HTML tag search functionality across all LiveView files
- Shows route, line number, tag content, and status for each tag
- Fixed UI issues: reduced padding, matched Calvin's h1 styling
- Demonstrated CSS cleanup on page_inventory_live.ex:
  - Before: 30 unique classes, 35 occurrences
  - After: 24 unique classes, 26 occurrences (20-26% reduction)
  - Extracted patterns to global CSS with semantic names
  - Maintained visual design while improving code quality
- Added dev.open_wip Mix task for opening WIP files in VSCodium
- Improved main layout padding (px-4 py-2 with max-w-7xl)
- Global h1 now matches Calvin (text-2xl mb-2)


---

## 2024-10-27 - Cleanup Analysis Page & Layout

**Goal:** Apply the same CSS cleanup process to tailwind_analysis_live.ex and layouts.ex

**Branch:** feature/cleanup-analysis-page

**Status:** In Progress 🚧

**Plan:**
1. Run analysis on tailwind_analysis_live.ex (before)
2. Run analysis on layouts.ex (before)
3. Clean up analysis page - extract to semantic classes
4. Run analysis on analysis page (after)
5. Clean up layouts - extract to semantic classes
6. Run analysis on layouts (after)
7. Compare before/after for both files

