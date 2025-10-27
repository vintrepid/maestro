# Guideline Usage Tracker

This file tracks which sections of agents/GUIDELINES.md are actually referenced during agent sessions to optimize future initialization.

## How to Use

When you reference a specific guideline section during work, add an entry:

```
## [Agent] - [Date] [Time]
**Referenced**: [Section Name from GUIDELINES.md]
**Context**: [Why you needed it - brief description]
**Session phase**: [initialization | during_work | verification]
```

## Usage Log

---

## Tidewave - 2025-01-27 14:35 UTC (Session Start)

**Session goal**: Track guideline usage to optimize initialization

**Plan**: 
1. Create tracker file to log which guideline sections get used
2. During work, log every time I reference GUIDELINES.md
3. After 10+ sessions, analyze which sections are actually needed
4. Create optimized initialization that preloads high-frequency sections

**High-value sections identified so far** (from reading the full doc):
- Git Workflow (branch management, commits, merging)
- Data Import & Migration Best Practices
- Code Verification
- Communication & Workflow
- Branch Management (never delete branches)

**Sections I haven't needed yet in this session**:
- Ash Framework patterns (not working with Ash currently)
- Legacy Database Integration (no legacy DB work)
- LiveView Component Patterns (no LiveView work yet)
- DaisyUI Component Usage (no UI work yet)

---

## Analysis (To be updated after 10+ sessions)

After collecting data, we'll identify:
- **Critical sections** (needed in 80%+ of sessions) → Preload these
- **Common sections** (needed in 40-80% of sessions) → Quick reference
- **Rare sections** (needed in <40% of sessions) → On-demand only

