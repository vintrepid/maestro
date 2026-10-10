# Coordination Pattern

**For Maestro coordinators: Use the tool, don't do it manually!**

## The One Command

```bash
mix maestro.task.request TASK_ID PROJECT_PATH
```

Example:
```bash
mix maestro.task.request 49 ~/dev/chelekom
```

## That's It!

The tool:
- ✅ Creates complete task package
- ✅ Updates task status
- ✅ Includes all workflow documentation
- ✅ Is idempotent (safe to re-run)

## If Your Session Crashes

Just run the command again. It overwrites safely, no duplicates created.

## Don't Do This

- ❌ Manually create TASK_PACKAGE.md
- ❌ Manually create current_task.json  
- ❌ Call Ash directly for coordination
- ❌ Create timestamped files

## Do This

- ✅ Use the tool
- ✅ Trust it's idempotent
- ✅ Re-run if needed

**All documentation is in the tool itself** - check the @moduledoc and generated files.
