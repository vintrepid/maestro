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
