# Instructions for Circle Agent

## Task Assignment

You have been assigned Task #8: **Implement Interests Feature**

View the full task at: http://localhost:4015/tasks (once your server is running)

Or directly in your database:
```sql
SELECT * FROM tasks WHERE title = 'Implement Interests Feature';
```

## Required Reading for This Task

**IMPORTANT:** The `agents` directory in your project root is a symlink to `~/dev/agents`.
All paths below are relative to that shared agents directory.

### Guideline Bundles to Load

Read these files from your symlinked `agents/bundles/` directory:

#### 1. Bootstrap Bundle (Essential Core)
**File:** `agents/bundles/bootstrap.json`  
**Full path:** `~/dev/agents/bundles/bootstrap.json`  
**Read with:** `cat agents/bundles/bootstrap.json` or `File.read!("agents/bundles/bootstrap.json")`  
**Size:** ~7KB  
**Contains:**
- Git workflow (feature branches, commits, never merge)
- Code verification (tests, precommit)
- Communication guidelines (when to ask vs proceed)
- Core code quality rules
- Server restart guidelines

#### 2. Database Work Bundle (For Schema Design)
**File:** `agents/bundles/database_work.json`  
**Full path:** `~/dev/agents/bundles/database_work.json`  
**Read with:** `cat agents/bundles/database_work.json` or `File.read!("agents/bundles/database_work.json")`  
**Size:** ~7KB  
**Contains:**
- Polymorphic relations patterns (entity_type/entity_id)
- Ash resource setup and patterns
- Primary key types and CAST usage
- Database schema best practices
- Migration patterns

#### 3. UI Work Bundle (For LiveView Components)
**File:** `agents/bundles/ui_work.json`  
**Full path:** `~/dev/agents/bundles/ui_work.json`  
**Read with:** `cat agents/bundles/ui_work.json` or `File.read!("agents/bundles/ui_work.json")`  
**Size:** ~7KB  
**Contains:**
- LiveView patterns and lifecycle
- DaisyUI component usage
- Phoenix templates and conventions
- Form handling with AshPhoenix
- Table and card layouts

### How to Access These Files

```bash
# Verify the symlink exists
ls -la agents
# Should show: agents -> /Users/vince/dev/agents

# List available bundles
ls agents/bundles/

# Read a bundle
cat agents/bundles/bootstrap.json
cat agents/bundles/database_work.json
cat agents/bundles/ui_work.json
```

## Total Reading: ~21KB vs 276KB (92% reduction!)

## What To Do

1. **Read the task description** (it's in your database)
   - Contains complete schema designs
   - Migration templates
   - Service implementation guides
   - UI specifications

2. **Load the three bundles above**
   - They contain the patterns you need
   - Refer back to them as needed

3. **Reference Maestro's implementation**
   - Maestro has implemented this as "Resources"
   - You're implementing it as "Interests" (user-facing naming)
   - Maestro is located at: `~/dev/maestro`
   - Files to reference:
     ```
     ~/dev/maestro/lib/maestro/resources/resource.ex
     ~/dev/maestro/lib/maestro/resources/tag.ex
     ~/dev/maestro/lib/maestro/resources/resource_tag.ex
     ~/dev/maestro/lib/maestro/resources/tag_hierarchy.ex
     ~/dev/maestro/lib/maestro/resources/bookmark_importer.ex
     ~/dev/maestro/lib/maestro/resources/web_scraper.ex
     ~/dev/maestro/lib/maestro_web/live/resources_live.ex
     ~/dev/maestro/lib/maestro_web/live/resource_form_live.ex
     ~/dev/maestro/lib/maestro_web/live/bookmark_import_live.ex
     ~/dev/maestro/lib/maestro_web/components/resource_table.ex
     ```
   
   **To read these files:**
   ```bash
   cat ~/dev/maestro/lib/maestro/resources/resource.ex
   # or use your file reading tools
   ```

4. **Implement the feature**
   - Follow the implementation steps in the task
   - Use the schema designs provided
   - Adapt the UI to Circle's design language
   - Test as you go

5. **Track guideline usage** (Optional but Helpful)
   ```bash
   mix bundles.track ref <guideline_id> "context"
   ```

## Key Adaptations for Circle

- **Naming:** "Resources" → "Interests"
- **Context:** Meta-level tracking → User-facing bookmarks
- **Owner:** Generic polymorphic → Primarily User-owned
- **UI:** Admin-style → User-friendly, personal collection

## Questions?

If anything is unclear:
1. Check the relevant bundle for the pattern
2. Reference Maestro's implementation
3. Ask the user if still stuck (better to ask than guess wrong)

## Success Criteria

- [ ] All 4 Ash resources created and migrated
- [ ] Can create/view/edit interests through UI
- [ ] Can create and assign tags
- [ ] Can import browser bookmarks
- [ ] Tag hierarchy works (parent/child tags)
- [ ] Tests pass

Good luck! You've got everything you need. 🚀
