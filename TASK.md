# Task: Optimize Agent Startup Load Times

## Problem

AI agents spend enormous amounts of time, money, and tokens loading all guidelines at session start (currently 276KB). We need to reduce this by 60-80% for non-Maestro sessions while maintaining effectiveness.

## Current Process

When an agent reads guidelines, it:
1. **Parse the markdown** - Understand structure, sections, headings
2. **Extract patterns** - Identify rules, examples, do/don't patterns
3. **Build internal knowledge** - Convert prose into actionable rules
4. **Context linking** - Connect related concepts across files

This happens every session, wasting tokens and time on repeated processing.

## Optimization Strategies

### Strategy 1: Pre-concatenate and Compress

Merge all startup files into one and compress.

**Pros:**
- Single file = fewer token overhead from multiple file headers
- Reduced I/O operations
- Could gzip compress before sending

**Cons:**
- Loses file boundaries (harder to reference "see GUIDELINES.md section X")
- Harder to debug which file has which rule
- Still need to process all the text

**Potential savings:** 10-20% (mostly from headers/structure overhead)

**Verdict:** Minimal gains, not worth the tradeoffs

---

### Strategy 2: Pre-digest into Structured Format ⭐ RECOMMENDED

Convert prose guidelines into machine-readable structured format that's faster to parse and understand.

**Example structured format:**

```json
{
  "rules": [
    {
      "id": "git_workflow_1",
      "category": "git",
      "rule": "Always work on feature branches",
      "priority": "critical",
      "applies_to": ["all"],
      "examples": ["git checkout -b feature/name"],
      "anti_patterns": ["git commit directly to main"]
    },
    {
      "id": "pk_standard_public",
      "category": "database",
      "rule": "Public resources use integer PK + slug",
      "priority": "high",
      "context": "Public-facing resources in URLs",
      "examples": [
        "integer_primary_key :id",
        "attribute :slug, :string"
      ],
      "rationale": "Performance + UX + SEO"
    }
  ],
  "patterns": {
    "database_primary_keys": {
      "public_resources": {
        "strategy": "integer + slug",
        "use_when": "Users see in URLs",
        "example": "/trips/summer-rafting"
      },
      "internal_resources": {
        "strategy": "integer only",
        "use_when": "Internal-only data",
        "example": "assignments, messages"
      },
      "users": {
        "strategy": "integer + uuid_v7",
        "use_when": "Authentication resources",
        "example": "auth tokens, API access"
      }
    },
    "ash_resources": {
      "create_steps": [
        "Check resource type (public/internal/user)",
        "Apply appropriate PK strategy",
        "Generate slugs for public resources",
        "Add get_by_slug action for public",
        "Use integer IDs in relationships"
      ]
    }
  },
  "decision_trees": {
    "choose_primary_key": [
      {
        "question": "Will users see this in URLs?",
        "yes": "use integer + slug",
        "no": "next_question"
      },
      {
        "question": "Is this for authentication?",
        "yes": "use integer + uuid_v7",
        "no": "use integer only"
      }
    ]
  }
}
```

**Pros:**
- Drastically reduced tokens (50-70% savings!)
- Faster to parse and understand
- Can be indexed/searched efficiently
- Only load relevant sections for task
- Version-able and testable

**Cons:**
- Loses some nuance from prose
- Need tooling to maintain (keep JSON in sync with docs)
- Examples must be compressed

**Potential savings:** 50-70% reduction in tokens

---

### Strategy 3: Task-Specific Bundles ⭐ RECOMMENDED

Pre-create bundles for common task types, combining structured rules from multiple guideline sources.

**Bundle structure:**

```
agents/bundles/
  crud_feature.json         # Basic CRUD operations
  ui_work.json             # DaisyUI + LiveView + Phoenix patterns
  database_work.json       # Ash + PK standards + migrations
  auth_work.json           # Authentication patterns
  deployment.json          # Fly deployment
  background_jobs.json     # Oban patterns
```

**Example bundle (ui_work.json):**

```json
{
  "bundle": "ui_work",
  "version": "1.0",
  "includes": ["daisyui", "liveview", "phoenix_components"],
  "rules": [
    {
      "id": "daisyui_philosophy",
      "rule": "Use DaisyUI for components, Tailwind for layout",
      "examples": {
        "good": "btn btn-primary",
        "bad": "px-4 py-2 rounded bg-blue-500"
      }
    },
    {
      "id": "liveview_streams",
      "rule": "Use streams for collections to avoid memory issues",
      "pattern": "stream(socket, :items, items)",
      "required_attributes": ["phx-update=\"stream\"", "id on parent"]
    }
  ],
  "components": {
    "button": "btn btn-{variant}",
    "table": "table table-{options}",
    "form": "form-control with label + input"
  },
  "quick_reference": {
    "button_variants": ["primary", "secondary", "accent", "ghost"],
    "table_options": ["pin-rows", "zebra", "xs", "sm", "md", "lg"]
  }
}
```

**Task specification in Maestro:**

```elixir
%Task{
  project: "calvin",
  description: "Add user profile page with role badges",
  bundles: [:ui_work, :auth_work],
  context: "User has roles: guide, scheduler, admin",
  extra_guidelines: [
    "Use Calvin color coding: green=active, red=unavailable"
  ]
}
```

**Pros:**
- Minimal loading for specific tasks
- Can version bundles separately
- Easy to test "did we include enough?"
- Agent only reads what's needed
- Can track which bundles are used most

**Cons:**
- Need to maintain bundles
- Tasks might span multiple bundles
- Initial setup effort

**Potential savings:** 70-80% for focused tasks

---

### Strategy 4: Embeddings + RAG Approach

Store guideline embeddings, retrieve only relevant sections during work.

**Pros:**
- Load only what's needed when needed
- Most token-efficient long-term
- Scales to unlimited guidelines
- Can retrieve examples on demand

**Cons:**
- Need embedding infrastructure
- Retrieval might miss important context
- Adds complexity and latency
- Requires vector database

**Potential savings:** 80-90% but with complexity tradeoff

**Verdict:** Worth exploring later, after bundles are proven

---

## Recommended Implementation Plan

**Phase 1: Create Structured Format**

1. Convert key guidelines to structured JSON:
   - Git workflow rules
   - Database PK standards
   - DaisyUI component patterns
   - LiveView best practices
   - Phoenix conventions

2. Create converter tool to help maintain sync between prose and JSON

3. Test with one project (Calvin) to verify effectiveness

**Phase 2: Build Task Bundles**

1. Identify common task types:
   - CRUD feature
   - UI work
   - Database/schema work
   - Authentication work
   - Deployment
   - Background jobs

2. Create bundle files combining relevant structured rules

3. Add bundle loading to agent startup

4. Track bundle usage and effectiveness

**Phase 3: Maestro Integration**

1. Add task specification format to Maestro
2. Create UI for task planning with bundle selection
3. Write tasks to project CHANGELOG with bundle requirements
4. Track which bundles were actually used vs specified

**Phase 4: Iterate and Refine**

1. Analyze usage logs (GUIDELINE_USAGE_TRACKER)
2. Refine bundles based on actual usage
3. Create new bundles for patterns that emerge
4. Remove redundant content from bundles

## Expected Results

- **Non-Maestro sessions:** 60-80% reduction in startup tokens
- **Maestro sessions:** Still reads everything (coordinator needs full context)
- **Task completion:** Same or better quality with focused context
- **Maintenance:** Easier to update rules in structured format
- **Testing:** Can verify bundle completeness programmatically

## Success Metrics

1. Token count reduction: Target 60-80% for non-Maestro sessions
2. Task completion rate: Maintain 100% (no reduction in quality)
3. Time to first output: Reduce by 50%+
4. Guideline reference rate: Track if agents need to look up additional docs
5. Bundle accuracy: Track if specified bundles were sufficient

## Next Steps

1. Create `agents/bundles/` directory structure
2. Design structured format schema
3. Convert first bundle (ui_work) as proof of concept
4. Test with Calvin on simple UI task
5. Measure token savings and effectiveness
6. Iterate on format based on learnings
