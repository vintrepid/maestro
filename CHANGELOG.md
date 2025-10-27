## 2025-01-27 - Integrate CSS Linter

**Goal:** Integrate css_linter from ~/dev/forks/css_linter into Maestro to analyze and improve CSS class usage across all projects.

**Tasks:**
- [ ] Add css_linter dependency to mix.exs
- [ ] Create UI for viewing CSS analysis results
- [ ] Add mix task integration
- [ ] Document usage in README
- [ ] Test on Maestro codebase

**Branch:** feature/css-linter

---

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

**Goal:** Apply CSS cleanup using DaisyUI components properly

**Branch:** feature/cleanup-analysis-page

**Status:** In Progress 🚧

**Approach Change:**
Initially extracted analysis-specific classes to app.css, but realized this violated our philosophy:
- **DaisyUI for Components** - Use DaisyUI semantic classes
- **Tailwind for Layout** - Use Tailwind utilities for layout
- **Custom Components for Patterns** - Extract to Phoenix components, not CSS

**Final Approach - Pure DaisyUI:**

**Before (original):**
- Unique classes: 200
- Total occurrences: 509

**After (pure DaisyUI):**
- Unique classes: 199 (-1)
- Total occurrences: 512 (+3)

**Changes:**
1. ❌ Removed custom analysis-* classes from app.css
2. ✅ Used DaisyUI table modifiers: `table-zebra` on all tables
3. ✅ Kept inline utilities for layout (`text-right`, `font-mono text-xs`)
4. ✅ Used DaisyUI semantic components: `stats`, `card`, `badge`

**Key Learning:**
- Don't create custom CSS classes for page-specific patterns
- Use DaisyUI components as-is (they're already semantic)
- Use Tailwind utilities inline for simple styling
- Only extract to Phoenix components for reusable UI patterns

**Result:**
- ✅ Cleaner CSS (no page-specific classes)
- ✅ Better DaisyUI usage (table-zebra for stripes)
- ✅ More maintainable (following framework conventions)
- ✅ Visual design unchanged

**Next:** Consider extracting reusable table patterns to Phoenix components if needed across multiple pages


---

## 2024-10-27 - Class Combination Analysis

**Goal:** Identify most common class combinations across entire project

**Method:** Analyzed all class attributes, sorted classes alphabetically within each, grouped and counted

**Results:**
- **Total class attributes:** 203
- **Unique combinations:** 123
- **Single-use combos:** 90 (73%) - Healthy!
- **Used 3+ times:** 20 (16%) - Extraction candidates

**Top Patterns Found:**

HIGH VALUE (4+ uses):
1. **Icon sizing** - h-4 w-4 (3x), h-6 w-6 (3x), with hover effects (4x)
2. **Nav item** - 11-class combo used 4x (biggest opportunity!)
3. **Fieldset** - fieldset mb-2 (4x)

MEDIUM VALUE (3 uses):
4. **Card pattern** - bg-base-100 card shadow-xl (3x) → Already created section_card!
5. **Form labels** - label mb-1 (3x)
6. **Muted text** - text-base-content/70 text-sm (3x)

**Components Created:**
- ✅ simple_table (applied)
- ✅ section_card (ready to use)
- ✅ page_header (ready to use)
- ✅ stats_grid (ready to use)

**Recommendations for Future:**
1. Use section_card component where "bg-base-100 card shadow-xl" appears
2. Consider nav_item component for navigation (11 classes!)
3. Consider icon component with size variants
4. Project is well-optimized overall (73% single-use is healthy)

**Key Insight:**
Most duplication is in navigation/menu patterns and icons. 
The analysis confirms our component extraction strategy was correct! 🎯


---

## TODO: Next Session - Fix the Automated Component Replacement Tool

**Priority:** HIGH - Need this for Calvin (much bigger app)

**Problem:**
- Automated sed/perl/regex replacements keep breaking HTML structure
- Ambiguous closing tags cause mismatched replacements
- Manual editing is too slow for large codebases

**What Failed:**
1. Perl regex with nested capture groups - broke tag matching
2. Sed with line ranges - couldn't handle variable closing tag positions
3. Simple string replacement - ambiguous patterns (multiple `</div></div>`)

**Why It's Critical:**
- Calvin is a much bigger app than Maestro
- Can't manually edit 50+ card instances
- Need reliable automation for `simple_card` component application

**Success Criteria:**
- Tool can reliably replace card HTML without breaking structure
- Handles nested tags correctly
- Verifies syntax after each replacement
- Can process entire project or single file
- Provides rollback on error

**Approach Ideas:**
1. **AST-based replacement** - Parse HEEx to AST, modify, regenerate
2. **Phoenix formatter integration** - Use existing parser
3. **Template-based with verification** - Replace, compile, rollback on error
4. **Interactive mode** - Show each replacement, ask for confirmation
5. **Igniter-based transformation** - Use Igniter's code modification tools

**Test Case:**
The 5 cards in `lib/maestro_web/live/admin_live/tailwind_analysis_live.ex`
- Known patterns
- Already have manual guide
- Can verify expected output (67 unique, 144 total)

**Deliverable:**
A working tool that can:
```bash
mix components.replace simple_card lib/maestro_web/live/admin_live/
# or
mix components.replace --interactive simple_card **/*.ex
```

**Blocked Work:**
- Calvin CSS cleanup (much larger scope)
- Applying other components (page_header, section_card, stats_grid)
- Future component extractions

---

## 2024-10-27 - User Profile Page

**Goal:** Create a user profile editing page where users can edit their profile information.

**Features to Build:**
- User profile LiveView at /profile
- Form to edit name and bio
- User menu in navbar with avatar/dropdown
- Profile link in user menu

**Tasks:**
- [x] Create ProfileLive at /profile
- [x] Add name and bio fields to User resource
- [x] Add update_profile action to User
- [x] Create migration for new fields
- [x] Add /profile route
- [x] Create user menu component in navbar
- [x] Pass current_user to layout properly
- [ ] Test the profile page functionality
- [ ] Verify UI/UX

**Branch:** feature/user-profile-page

**Status:** In Progress 🚧


---

## 2024-10-27 - Git Status Display & Guidelines Viewer

**Goal:** Add git branch status to navbar and create guidelines viewer widget for tracking agent documentation reading.

**Branch:** feature/display-git-branch

**Accomplished:**
- [x] Created GitWidget component with git status functionality
- [x] Created GuidelinesViewer component for displaying documentation tree
- [x] Added file opening functionality (open files in VSCodium)
- [x] Moved git status to navbar as compact dropdown
- [x] Refactored to use DaisyUI navbar-start/navbar-end pattern
- [x] Made widgets self-contained (fetch their own data)
- [x] Centralized file opening in helper module
- [x] Created core_components for reusable card/section patterns
- [x] Rebuilt profile page following DaisyUI-first guidelines
- [x] Read all key guidelines (GUIDELINES.md, DAISYUI.md, CSS_CLEANUP_GUIDELINES.md)
- [x] Created GUIDELINE_USAGE_TRACKER.md for session tracking

**Components Created:**
- `lib/maestro_web/components/git_widget.ex` - Git status display
- `lib/maestro_web/components/guidelines_viewer.ex` - Documentation tree viewer
- `lib/maestro_web/live/helpers/file_opener.ex` - File opening helper

**Key Learnings:**
- DaisyUI semantic classes (navbar-start, navbar-end) eliminate need for custom CSS
- Self-contained components that fetch their own data are more reusable
- Guideline tracking via tracker file in git is better than UI-only state

**Status:** Complete ✅

**Next Steps:**
- Consider adding database persistence for guideline tracking if needed
- Test file opening functionality across different file types
- Add more comprehensive git operations (branch switching, etc.)

