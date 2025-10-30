# New Project Setup - Issues & Fixes Needed

## Current Problems

### 1. Form Handling Added to Wrong Place
**What happened:** Chelekom's installer added form handling docs to AGENTS.md
**What I did:** Copied it to PHOENIX_AGENTS.md (general guidelines)
**What should happen:** Should be in Chelekom-specific docs
**Fix needed:** 
- Remove form handling from PHOENIX_AGENTS.md
- Create chelekom-specific usage guide
- Check Chelekom hex for their official docs

### 2. Missing USAGE_RULES.md Generation
**What's missing:** `mix usage_rules.sync` not run during setup
**Impact:** No dependency usage rules available
**Current state:** We have usage_rules in startup.json, but not project-specific USAGE_RULES.md
**Fix needed:** Add to maestro.project.update

### 3. Usage Rules Too Long
**Problem:** Agents skip reading USAGE_RULES because it's too long
**Example:** "when I tell him to read something, if it's too long he doesn't bother"
**Question:** What do agents actually need from usage_rules?
**Options:**
  a) Generate summary/highlights only
  b) Load specific package rules on-demand
  c) Build task-specific usage rules bundles
  d) Include only in startup.json, not separate file

### 4. Incomplete maestro.project.update
**Currently does:**
- .env file (but with wrong ports)
- README.md
- Git remote
- Agents symlink
- AGENTS.md (now added)

**Should also do:**
- Run `mix usage_rules.sync` to generate USAGE_RULES.md
- Verify live_debugger config exists in dev.exs
- Verify Tidewave plug exists in endpoint.ex
- Generate startup.json
- Read ports from Maestro DB (not hardcoded)

### 5. Failed Chelekom Install
**What failed:** mishka_chelekom installer timed out on spinner
**What succeeded:** Dependency installed, but installer script didn't complete
**Workaround:** Generate components manually as needed
**Question:** What did we miss from the failed install?
  - Possibly generated all components?
  - Possibly added Chelekom-specific config?
  - Need to check Chelekom docs for install steps

## Action Items

### Immediate
1. Check what Chelekom installer should have done
2. Check if USAGE_RULES.md exists in Chelekom
3. Document what maestro.project.update should do

### Short Term  
1. Remove form handling from PHOENIX_AGENTS.md (it's Chelekom-specific)
2. Add `mix usage_rules.sync` to maestro.project.update
3. Fix port reading in maestro.project.update
4. Add live_debugger/tidewave checks

### Long Term
1. Solve "usage rules too long" problem
2. Task-specific bundle loading
3. Multi-agent orchestration (PORT_MANAGEMENT.md)

## Standard New Project Flow (What It Should Be)

```bash
# 1. Create project
cd ~/dev
mix igniter.new myproject \
  --with phx.new \
  --with-args "--no-ecto" \
  --install ash,ash_phoenix \
  --install ash_admin,live_debugger \
  --install mishka_chelekom,ash_money \
  --no-setup \
  --yes

cd myproject

# 2. Setup Cldr
mkdir -p lib/mix/tasks
cp ~/dev/agents/templates/project.setup.ex lib/mix/tasks/
mix project.setup --yes

# 3. Add maestro_tool and run update
# Add {:maestro_tool, github: "vintrepid/maestro_tool", only: [:dev]} to mix.exs
mix deps.get
mix maestro_tool.project.update  # Should do EVERYTHING

# 4. Generate usage rules
mix usage_rules.sync  # Should be in project.update

# 5. Generate startup.json
cd ~/dev/maestro
mix startup.build myproject  # Could be automated

# 6. Start work
cd ~/dev/myproject
source .env
mix phx.server
open http://localhost:XXXX/tidewave
```

## Questions for User

1. **Form handling docs** - Where should Chelekom-specific docs go?
2. **Usage rules** - What do agents actually need? Full file or summaries?
3. **Failed install** - Should I investigate what Chelekom installer was supposed to do?
4. **maestro.project.update scope** - Should it do usage_rules.sync and startup.json generation?
5. **Port management** - Priority on fixing DB port reading?
