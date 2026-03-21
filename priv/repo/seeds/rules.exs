# Seed rules from Calvin's CLAUDE.md learnings and USAGE_RULES corrections
# These are proposed — Vince reviews and approves in the UI

alias Maestro.Ops.Rule

rules = [
  # === Architecture (from Calvin CLAUDE.md) ===
  %{
    content: "UI is a metaphor for the model. When implementing a UI interaction, start by asking: what action am I taking on which resource? Work outward from there. If the model is correct, the UI just re-renders from truth.",
    category: :architecture,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "Core principle discovered through multiple Calvin sessions. Agents kept getting lost in DOM manipulation instead of modeling the action correctly.",
    applies_to: ["all"],
    tags: ["philosophy", "liveview"]
  },
  %{
    content: "ALL domain logic belongs in Ash resources. LiveViews are thin wrappers: mount, handle_params, handle_event (delegate to action), render. This includes data loading with fallback logic, business rules, formatting, availability checks.",
    category: :ash,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "Recurring mistake — agents put business logic in LiveViews, causing duplication when same resource appears in multiple contexts (www and myAO).",
    applies_to: ["ash"],
    tags: ["liveview", "resources"]
  },
  %{
    content: "If values represent instances of a thing (sites, categories, codes), they MUST be modeled as a resource. Never scatter string/atom literals through LiveViews or components.",
    category: :ash,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "Hard-coded czar codes and itinerary types were scattered everywhere, making changes require touching 20+ files.",
    applies_to: ["ash"],
    tags: ["resources"]
  },
  %{
    content: "Never use raw Ecto (from() queries) when Ash is available. Ash executes Ecto underneath. Always use Ash actions.",
    category: :ash,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "Agent bypassed Ash authorization and validations by writing raw Ecto queries.",
    applies_to: ["ash"],
    tags: ["resources"]
  },

  # === PubSub (from Calvin PubSub rollout) ===
  %{
    content: "Every page has a main entity (resource instance or collection) with a DAG of dependencies. PubSub subscriptions MUST follow this graph. Subscribe in mount, reload in handle_info — ONE handler, not per-event.",
    category: :pubsub,
    severity: :must,
    source_project_slug: "calvin",
    source_commit: "787eff7",
    source_context: "Built ResourcePubSub notifier that walks belongs_to DAG. Every LiveView gets a default handle_info via CalvinWeb macro.",
    applies_to: ["ash", "liveview"],
    tags: ["pubsub", "realtime", "dag"]
  },
  %{
    content: "NEVER manually reload data after a mutation in handle_event. The PubSub notifier handles it for ALL connected clients. If you're writing |> load_data() at the end of handle_event, you're doing it wrong.",
    category: :pubsub,
    severity: :must,
    source_project_slug: "calvin",
    source_commit: "787eff7",
    source_context: "Before PubSub, every handle_event had manual reload calls. Multi-user updates were broken — only the acting user saw changes.",
    applies_to: ["ash", "liveview"],
    tags: ["pubsub", "realtime"]
  },
  %{
    content: "Every resource that participates in multi-user pages MUST have simple_notifiers: [AppName.ResourcePubSub]. The notifier broadcasts to collection topic, instance topic, AND walks belongs_to relationships to notify parents.",
    category: :pubsub,
    severity: :must,
    source_project_slug: "calvin",
    source_commit: "787eff7",
    source_context: "The ResourcePubSub Ash notifier pattern. Broadcasts on create/update/destroy to resource:Name and resource:Name:id topics.",
    applies_to: ["ash", "liveview"],
    tags: ["pubsub", "realtime", "dag"]
  },

  # === LiveView (from Calvin + USAGE_RULES corrections) ===
  %{
    content: "Every page URL reflects state — handle_params drives what's displayed. Pages must be bookmarkable.",
    category: :liveview,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "LiveView page standard from Calvin CLAUDE.md.",
    applies_to: ["liveview"],
    tags: ["liveview"]
  },
  %{
    content: "Never use deprecated live_redirect and live_patch. Use <.link navigate={href}> and <.link patch={href}> in templates, push_navigate and push_patch in LiveViews.",
    category: :liveview,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude's training data includes many examples with the old deprecated functions.",
    applies_to: ["liveview"],
    tags: ["liveview", "deprecated"]
  },
  %{
    content: "When using phx-hook=\"MyHook\" that manages its own DOM, you MUST also set phx-update=\"ignore\" on that element.",
    category: :liveview,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Without phx-update=ignore, LiveView will clobber the hook's DOM changes on re-render.",
    applies_to: ["liveview"],
    tags: ["liveview", "hooks"]
  },
  %{
    content: "Never write embedded <script> tags in HEEx. Write hooks in assets/js/ and integrate with app.js.",
    category: :liveview,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Inline scripts break CSP and don't work with LiveView's DOM patching.",
    applies_to: ["liveview"],
    tags: ["liveview", "security"]
  },

  # === HEEx (corrections Claude gets wrong) ===
  %{
    content: "HEEx uses {expr} for interpolation in tag attributes and tag bodies. Use <%= expr %> ONLY for block constructs (if, cond, case, for). NEVER use <%= %> for simple value interpolation.",
    category: :heex,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude frequently generates old-style <%= @value %> instead of {@value} in modern Phoenix.",
    applies_to: ["phoenix"],
    tags: ["heex", "templates"]
  },
  %{
    content: "Elixir does NOT support if/else if. NEVER use else if or elsif in templates. Use cond or case for multiple conditionals.",
    category: :heex,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude generates else if blocks that cause compile errors.",
    applies_to: ["elixir"],
    tags: ["heex", "elixir"]
  },
  %{
    content: "HEEx class attributes support lists with [...] syntax for conditional classes: class={[\"base\", @flag && \"active\"]}. NEVER omit the brackets.",
    category: :heex,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Missing brackets causes compile error.",
    applies_to: ["phoenix"],
    tags: ["heex", "templates"]
  },
  %{
    content: "To show literal curly braces { } in HEEx (e.g. code snippets), annotate the parent tag with phx-no-curly-interpolation.",
    category: :heex,
    severity: :should,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules.",
    applies_to: ["phoenix"],
    tags: ["heex"]
  },
  %{
    content: "HEEx comments use <%!-- comment --%>. NEVER use HTML comments <!-- --> as they'll be sent to the client.",
    category: :heex,
    severity: :should,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules.",
    applies_to: ["phoenix"],
    tags: ["heex"]
  },

  # === CSS (from Calvin) ===
  %{
    content: "No Tailwind utility classes in templates. Push ALL utilities into semantic CSS classes in app.css. Templates use only semantic class names. Grid layout utilities are OK inline.",
    category: :css,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "Core Calvin principle. When www and myAO need different looks for the same component, CSS handles it — not the template.",
    applies_to: ["all"],
    tags: ["css", "tailwind", "components"]
  },

  # === Forms (corrections Claude gets wrong) ===
  %{
    content: "ALWAYS use to_form/2 to create form assigns. NEVER pass raw changesets to templates. Access form fields via @form[:field], not @changeset[:field].",
    category: :forms,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude frequently generates deprecated changeset-in-template patterns that cause runtime errors.",
    applies_to: ["phoenix"],
    tags: ["forms", "liveview"]
  },
  %{
    content: "ALWAYS use <.form for={@form}> with <.input field={@form[:field]}>. NEVER use <.form let={f}> — that's the old deprecated syntax.",
    category: :forms,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude's training data has many examples with the old let= syntax.",
    applies_to: ["phoenix"],
    tags: ["forms", "liveview", "deprecated"]
  },

  # === Components (from Vince's philosophy) ===
  %{
    content: "Use library components and build reusable components. Don't hand-build what a library already handles. When a component exists (calendar, table, form), USE IT.",
    category: :components,
    severity: :must,
    source_project_slug: "calvin",
    source_context: "Vince's philosophy: components over bespoke UI. Contradicts Phoenix AGENTS.md advice to avoid LiveComponents.",
    applies_to: ["all"],
    tags: ["components", "philosophy"]
  },

  # === Testing (from Calvin) ===
  %{
    content: "Verify features by calling Ash resource actions directly (via project_eval or tests), NOT by clicking in the browser. UI is a metaphor for the model — if the action works, the UI follows.",
    category: :testing,
    severity: :should,
    source_project_slug: "calvin",
    source_context: "From Calvin CLAUDE.md. Browser testing is slow and flaky. Resource actions are the source of truth.",
    applies_to: ["ash"],
    tags: ["testing"]
  },

  # === Streams (Claude gets wrong) ===
  %{
    content: "LiveView streams are NOT enumerable. You cannot use Enum functions on them. To filter/refresh, refetch data and re-stream with reset: true.",
    category: :liveview,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude generates Enum.filter(@streams.items) which causes runtime errors.",
    applies_to: ["liveview"],
    tags: ["liveview", "streams"]
  },
  %{
    content: "ALWAYS use LiveView streams for collections (not plain list assigns) to avoid memory ballooning. Parent element needs phx-update=\"stream\" and a DOM id. Children consume @streams.name with {id, item} tuples.",
    category: :liveview,
    severity: :should,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Without streams, large collections cause OOM on the server.",
    applies_to: ["liveview"],
    tags: ["liveview", "streams"]
  },

  # === Elixir (things Claude genuinely gets wrong) ===
  %{
    content: "Elixir variables are immutable within block expressions. You MUST bind the result of if/case/cond to a variable. Writing `socket = assign(...)` inside an if block without binding the if result does nothing.",
    category: :elixir,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude frequently generates if blocks that mutate a variable inside without binding the result.",
    applies_to: ["elixir"],
    tags: ["elixir"]
  },
  %{
    content: "Elixir lists do NOT support index-based access via brackets (list[0] is invalid). Use Enum.at/2, pattern matching, or hd/tl.",
    category: :elixir,
    severity: :must,
    source_project_slug: "maestro",
    source_context: "From usage_rules. Claude generates list[i] which compiles but returns nil (lists implement Access but not for integer keys).",
    applies_to: ["elixir"],
    tags: ["elixir"]
  },

  # === Routing ===
  %{
    content: "Phoenix router scope blocks include an alias prefix. You NEVER need to create your own alias for route definitions — the scope provides it.",
    category: :routing,
    severity: :should,
    source_project_slug: "maestro",
    source_context: "From Phoenix usage_rules. Claude adds redundant aliases that cause double-prefixed module names.",
    applies_to: ["phoenix"],
    tags: ["routing"]
  }
]

for attrs <- rules do
  case Rule.propose(attrs) do
    {:ok, rule} ->
      IO.puts("Created rule: #{rule.category} — #{String.slice(rule.content, 0..60)}...")
    {:error, error} ->
      IO.puts("Failed: #{inspect(error)}")
  end
end

IO.puts("\nDone. #{length(rules)} rules proposed. Review at http://localhost:4004/rules")
