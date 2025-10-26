# Agent Guidelines - Project Initialization

## Quick Start (Use This Every Session)

**When user says "Hi", do these 4 steps:**

1. **Check context** (2 commands):
   ```bash
   git branch --show-current
   tail -50 agents/AGENT_CHAT.md
   ```

2. **Read current task** (1 command):
   ```bash
   head -100 CHANGELOG.md
   ```

3. **Quick check-in** (1 sentence in AGENT_CHAT.md):
   ```
   ## [Project] Agent - [timestamp]
   Session start on branch [name]. Ready to work on [task from CHANGELOG].
   ```

4. **Acknowledge**: "Ready! Current branch: X, working on: Y"

**That's it. ~4 tool calls, <5% of session budget.**

---

## Reference Documentation (Read On-Demand Only)

The following docs exist but should ONLY be read when you need specific information:

### Workflow & Patterns
- `agents/GUIDELINES.md` - Git workflow, data migrations, verification steps
- `agents/project-specific/{project}/*.md` - Project domain knowledge
- Framework patterns already in system prompt (Phoenix, LiveView, Ash, Ecto)

### Library Usage Rules
- `deps/*/usage-rules.md` - Correct usage of dependencies
- `~/dev/forks/live_table/usage_rules.md` - Our LiveTable fork
- `~/dev/forks/css_linter/README.md` - Our CSS Linter fork

### When to Read Reference Docs
- **Git workflow questions** → Read agents/GUIDELINES.md (Git Workflow section)
- **Data import issues** → Read agents/GUIDELINES.md (Data Import section)
- **Project domain questions** → Read agents/project-specific/{project}/
- **Library-specific errors** → Read relevant usage-rules.md
- **Testing requirements** → Read agents/GUIDELINES.md (Testing section)

---

## Essential Workflow Rules (Always Follow)

### Git
- **Always work on feature branches**, never on master/main
- Frequent commits with clear messages
- Push branches for review, **never delete without approval**
- Never merge without user approval

### Verification
- Run `mix precommit` before marking work complete (if available)
- Test changes appropriately (code tests, UI verification)
- Take 1-2 fix attempts, then ask user if stuck

### Communication
- Keep responses concise (1-3 sentences when possible)
- No unnecessary preamble or postamble
- Ask when requirements unclear, proceed when clear

---

## Usage Rules Already Loaded

These are in your system prompt, don't read again:
- Phoenix v1.8 guidelines
- LiveView patterns and streams
- Elixir best practices
- Ecto guidelines
- HEEx template syntax
- Form handling patterns

---

## Old Initialization Protocol (Deprecated)

~~Read all guidelines, all library docs, all project docs every session~~

**Why this was bad:** Burned 15+ tool calls and 16% of session budget on initialization.

**New approach:** Quick context check (4 calls), read reference docs only when needed.
