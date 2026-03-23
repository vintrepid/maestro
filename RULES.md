# Rules
# Curated by Maestro · 2026-03-22 · 197 approved rules

## Architecture

**ALWAYS** - **NEVER** delete branches after merging without explicit user approval — because delete branches after merging without explicit user approval will cause subtle bugs or wasted work
**ALWAYS** **Always** say "Aha" instead of "You're right" when the user corrects you. Then immediately capture the lesson as a rule. "Aha" signals you learned something new. "You're right" is sycophantic and wastes the correction — it acknowledges without internalizing.
**ALWAYS** - **Never** read immediately after write/edit — otherwise the result will be incorrect or break downstream behavior
**ALWAYS** - **NEVER** delete branches after merging without explicit user approval — otherwise the result will be incorrect or break downstream behavior
**ALWAYS** - **Never** merge without approval — otherwise the result will be incorrect or break downstream behavior
**ALWAYS** - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
**ALWAYS** - **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** **Always** Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
**ALWAYS** **Always** UI is a metaphor for the model. When implementing a UI interaction, start by asking: what action am I taking on which resource? Work outward from there. If the model is correct, the UI just re-renders from truth.
**ALWAYS** **Always** run ALL approved rules in the audit — never skip rules because they lack metadata fields. Rules are curated and approved for a reason. The audit's job is to check and apply rules to files, not to gatekeep which rules are worthy of checking. If a rule can't be checked automatically, report that gap — don't silently skip it.
**ALWAYS** - **Never** use `@apply` when writing raw css — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** **Always** design with Functional Core / Imperative Shell. When building features that need both a LiveView UI and a mix task, build both shells simultaneously — this forces proper extraction of shared core modules. Pure logic (triage, parsing, coverage stats) belongs in core modules under `lib/maestro/ops/rules/` with no DB access or IO. Shells (LiveViews, mix tasks) call the core and handle persistence/display. A 700-line mix task with inline heuristics is a red flag — the shell is doing the core's job.
**ALWAYS** **Never** hardcode rule-specific logic in audit/check functions. The rules themselves carry the information needed to check them — their content contains directives (Always/Never), code patterns in backticks, and code blocks showing correct/incorrect examples. The audit function should extract checkable patterns from ANY rule's content generically, not maintain a per-rule mapping.
**ALWAYS** **Always** Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module — otherwise the page will not reflect URL state.
**ALWAYS** - **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design — otherwise agents will ignore this rule or apply it inconsistently.
- NEVER fix things manually (via project_eval, one-off scripts, or inline edits). ALWAYS build the tool first, then let the tool do the work.

**Why:** Vince has corrected this pattern repeatedly across many conversations. The whole point of Maestro is that patterns get captured as reusable tooling. When I fix 90 rules by running eval commands, that work is lost — the next conversation faces the same 90 broken rules with no tool to fix them. When I build `Quality.fix_content/1` and wire it into the pipeline, every future run handles it automatically.

**How to apply:** Before doing ANY bulk operation by hand, ask: "Will the next conversation need to do this too?" If yes, write the function first. The function goes in the functional core. The pipeline calls the function. Then run the pipeline. Never skip the tool-building step to "save time" — it costs 10x more time across conversations.

**The anti-pattern:** "Let me just quickly fix these..." → runs 20 eval commands → work is lost → next conversation repeats everything.

**The correct pattern:** "Let me add fix_content/1 to Quality" → wire into update pipeline → run `mix maestro.rules.update` → done forever.
- User wants to plan big tasks collaboratively, then have Claude execute autonomously without blocking on confirmations. Always approve and proceed with file edits, writes, and bash commands. Don't stop to ask "should I continue?" — just do the work.

**Why:** User walks away after planning and expects work to be done when they return. Blocking on confirmations defeats the purpose.

**How to apply:** After aligning on a plan, execute all steps without pausing for approval. Only stop if something is genuinely broken or ambiguous.
- - Use `mix precommit` alias when you are done with all changes and fix any pending issues
- Don't deploy immediately after writing new code. Compile check is not enough — verify the changes actually work before pushing to production.

**Why:** User rejected a fly deploy right after 13 files of new PubSub code were written. Writing code and deploying in the same breath is reckless.

**How to apply:** After writing code: compile, test if tests exist, and ideally verify via browser or runtime check. Only deploy when confident changes work.
- - Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps
- **Always** The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
- - **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
- **Always** Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
- **Always** If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
- - **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
- **Always** **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
- **Always** Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:

      @import "tailwindcss" source(none);
      @source "../css";
      @source "../js";
      @source "../../lib/my_app_web";
- **Always** Focus on **delightful details** like hover effects, loading states, and smooth page transitions
- - Write completion notes BEFORE marking task done - document first, status second
- When the user corrects me, respond with "Aha" — not "You're right." Then immediately capture what I just learned so it doesn't get missed again.

**Why:** "You're right" is hollow acknowledgment. It means I heard the words but didn't internalize them. "Aha" signals genuine understanding, and the follow-up action (trapping the info) proves it.

**How to apply:** On correction: (1) say "Aha", (2) identify what I missed, (3) save it — as a rule in the pipeline if it's project knowledge, as a memory if it's behavioral. Never let a correction pass without capturing it.
- - **Maestro** (this project): Reads entire `agents/` directory to have full context for coordinating work
- - **LiveTable Integration**: Uses vintrepid/live_table fork with DaisyUI styling
- **Always** **Guidelines** (`bootstrap/`, `ui_work/`, `database_work/`, etc.) - Core patterns and best practices
- **Always** Sync upstream changes from frameworks (e.g., Phoenix AGENTS.md → `bootstrap/PHOENIX_AGENTS.md`)
- - **Linter** — should be enforced by tooling (mix task / compiler check), not agent docs
- - **Task-specific loading**: When we assign a task to another project, Maestro tells them exactly what guidelines they need to read
- - Configured and mounted in Maestro (separate scope to avoid namespace collision)
- **Always** Check for each linter rule's pattern (deprecated functions, bad syntax patterns, etc.)
- **Always** **Usage tracking**: Track which guidelines agents actually reference during work to optimize future sessions
- **Always** **Usage Rules** (`usage_rules/`) - Package-specific guidelines from dependencies and our forks
- **Always** **Real-time Monitoring**: Track which projects are running (ProjectMonitor GenServer checks TCP ports every 10s)
- **Never** `mix maestro.update` is NOT just an ingestion pipeline. It must also WRITE the curated, approved rules back into AGENTS.md and skill files. The DB is the source of truth. The output step is the whole point.

**Why:** Maestro curates agent knowledge. If it only reads rules into a DB but never writes them back out to the files agents actually read (AGENTS.md, .claude/skills/), then the curation is pointless. The approved rules in the DB should produce the AGENTS.md that ships with projects.

**How to apply:** `maestro.update` should: (1) ingest from sources, (2) triage/dedup, (3) WRITE approved rules back to AGENTS.md and skill reference files. `usage_rules.sync` handles raw dep linking. Maestro handles the curated, quality-controlled output. These are complementary — sync provides raw input, maestro provides curated output.

**Critical:** Do NOT ask clarifying questions about this. The user has explained it multiple times. Just build the output step.
- When delivering tasks to other project agents, write `current_task.json` (not MAESTRO_TASK.json). The chain is:
- CLAUDE.md → human-readable project rules
- AGENTS.md → tells agents to read current_task.json + follow CLAUDE.md
- current_task.json → the actual task payload (JSON, machine-readable)

Never modify CLAUDE.md to add task pointers. JSON files are for agent consumption, MD files are for humans.

**Why:** Vince doesn't want CLAUDE.md cluttered with agent plumbing. Agents should read AGENTS.md which points to current_task.json.
**How to apply:** When handing off work to another project, write current_task.json and verify AGENTS.md references it.
- When building features, always design with Functional Core / Imperative Shell architecture. Extract pure logic into core modules under `lib/maestro/ops/rules/` (or domain-correct path) with no DB access or IO. Shells (LiveViews, mix tasks) call the core.

**Why:** When logic lives in a mix task, it inevitably gets duplicated in the LiveView. Building both surfaces at the same time forces proper extraction of shared core functions. A 700-line mix task with inline heuristics, regex lists, and YAML parsing is a red flag — the shell is doing the core's job.

**How to apply:** Before writing any business logic in a mix task or LiveView, ask: "Would I need to duplicate this in the other shell?" If yes, it belongs in a core module. Build the core first, then wire both shells.
- **Always** The `agents/` directory is **symlinked into each project** (e.g., `maestro/agents -> ~/dev/agents`)
- **Always** When a task file (like MAESTRO_TASK.json) provides detailed descriptions of what exists and what needs to be done, trust it and move directly to execution. Don't launch explore agents or re-read everything the task already describes.

**Why:** User observed that ~50% of a session was wasted on redundant code review. The task file had all the context needed.

**How to apply:** Read the task, do minimal targeted reads (just enough to make the edit), then write code. Use the task description as the source of truth for what exists. Only read files to get the exact insertion points for edits.

## Ash

**ALWAYS** - You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** - **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email` — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** **Always** keep ALL domain logic in Ash resources. LiveViews are thin wrappers: `mount`, `handle_params`, `handle_event` (delegate to action), `render`. Never put `File.read!`, `System.cmd`, or `Repo.all` in a LiveView — call an Ash action instead.
**ALWAYS** - **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** **Always** model recurring values (sites, categories, status codes) as Ash resources — never scatter string/atom literals through LiveViews. Example: if you have `status in [:active, :archived]`, create a `Status` resource or `Ash.Type.Enum`, otherwise literals drift across files.
- - Create **custom change modules** for reusable transformation logic:
  ```elixir
  defmodule MyApp.Changes.SlugifyTitle do
    use Ash.Resource.Change

    def change(changeset, _opts, _context) do
      title = Ash.Changeset.get_attribute(changeset, :title)

      if title do
        slug = title |> String.downcase() |> String.replace(~r/[^a-z0-9]+/, "-")
        Ash.Changeset.change_attribute(changeset, :slug, slug)
      else
        changeset
      end
    end
  end

  # Usage in resource:
  change {MyApp.Changes.SlugifyTitle, []}
  ```
- - `can_action_name?(actor, params \\ %{}, opts \\ [])` - Returns `true`/`false` for authorization checks
- - The action has `before_action` or `around_action` hooks that need to read or modify the record
- **Never** `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- **Always** Configure foreign key constraints in your data layer if they have them (see `references` in AshPostgres)
- **Always** remember: `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- **Always** **String prompts**: Processed as EEx templates with `@input` and `@context` variables
- **Always** remember: `relationship` - Fetch relationship data (e.g., `/posts/123/relationships/comments`)
- - Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- - Fields which are set programmatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct
- - Prefer domain code interfaces to call actions instead of directly building queries/changesets and calling functions in the `Ash` module
- - Create **custom validation modules** for complex validation logic:
  ```elixir
  defmodule MyApp.Validations.UniqueUsername do
    use Ash.Resource.Validation

    @impl true
    def init(opts), do: {:ok, opts}

    @impl true
    def validate(changeset, _opts, _context) do
      # Validation logic here
      # Return :ok or {:error, message}
    end
  end

  # Usage in resource:
  validate {MyApp.Validations.UniqueUsername, []}
  ```
- **Always** remember: `relationship` - Fetch relationship data (e.g., `/posts/123/relationships/comments`)
- **Always** remember: `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- - A change reads the current record state (e.g., `Ash.Changeset.get_data/2`) and cannot be rewritten atomically
- - **Embedded**: For resources embedded in other resources (`data_layer: :embedded`) (typically JSON under the hood)
- **Always** For Polymorphic relationships, you can model them using `Ash.Type.Union`; see the “Polymorphic Relationships” guide for more information.

```elixir
- - **Prompt-backed Actions**: Create actions where the implementation is handled by an LLM
- - Use hooks like `Ash.Changeset.after_transaction/2`, `Ash.Changeset.before_transaction/2` to add additional logic
  outside the transaction.
- **Always** remember: `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- **Always** **Messages with PromptTemplate**: Processed using LangChain's `apply_prompt_templates`
- - **OpenAI API endpoints**: Uses `AshAi.Actions.Prompt.Adapter.StructuredOutput` (leverages OpenAI's structured output features)
- - **Non-OpenAI endpoints**: Uses `AshAi.Actions.Prompt.Adapter.RequestJson` (requests JSON in the prompt)
- - `can_action_name(actor, params \\ %{}, opts \\ [])` - Returns `{:ok, true/false}` or `{:error, reason}`
- - **Anthropic**: Uses `AshAi.Actions.Prompt.Adapter.CompletionTool` (uses tool calling for structured outputs)
- **Always** The `author` relationship can include both public and private attributes when loaded
- - **`StructuredOutput`**: Best for OpenAI models, uses native structured output capabilities
- **Always** Be descriptive with relationship names (e.g., use `:authored_posts` instead of just `:posts`)
- - **`CompletionTool`**: Uses tool calling to generate structured outputs, good for models that support function calling
- **Always** **Vectorization**: Convert text attributes into vector embeddings for semantic search
- - Use hooks like `Ash.Changeset.after_action/2`, `Ash.Changeset.before_action/2` to add additional logic
  inside the same transaction.
- - **Avoid redundant validations** - Don't add validations that duplicate attribute constraints:
  ```elixir
  # WRONG - redundant validation
  attribute :name, :string do
    allow_nil? false
    constraints min_length: 1
  end

  validate present(:name) do  # Redundant! allow_nil? false already handles this
    message "Name is required"
  end

  validate attribute_does_not_equal(:name, "") do  # Redundant! min_length: 1 already handles this
    message "Name cannot be empty"
  end

  # CORRECT - let attribute constraints handle basic validation
  attribute :name, :string do
    allow_nil? false
    constraints min_length: 1
  end
  ```
- **Always** The `load` option serves dual purposes: loading relationships/calculations and making any loaded attributes visible (including private ones)

## Components

**ALWAYS** Use library components and build reusable components. Don't hand-build what a library already handles. When a component exists (calendar, table, form), USE IT. — otherwise agents will ignore this rule or apply it inconsistently.

## Css

**ALWAYS** - **Never** use `@apply` when writing raw css — otherwise the result will be incorrect or break downstream behavior
**ALWAYS** **Never** use Tailwind utility classes directly in HEEx templates. Push ALL utilities into semantic CSS classes in `app.css`. Templates use only semantic class names like `class="page-header"` instead of `class="flex items-center justify-between mb-4"`, otherwise every template becomes a wall of utilities that's impossible to maintain consistently.
**ALWAYS** **Always** use DaisyUI component classes (`btn`, `card`, `modal`, `table`, `badge`, `alert`, `tabs`, `menu`, `navbar`, `dropdown`) instead of raw Tailwind utilities. Check https://daisyui.com/components/ before building custom CSS. Example: `class="btn btn-primary"` not `class="px-4 py-2 bg-blue-500 text-white rounded"`.
- **Always** remember: `lib/maestro_web/live/admin_live/tailwind_analysis_live.ex` (lines 205, 293, 325, 343, 373)

## Elixir

**ALWAYS** - **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors — otherwise the result will be incorrect or break downstream behavior
**ALWAYS** - **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors — because nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors will cause subtle bugs or wasted work
**ALWAYS** - Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)
**ALWAYS** - **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
**ALWAYS** **Never** nest multiple modules in the same file — it causes cyclic dependencies and compilation errors. Each module gets its own file at the path matching its name, e.g. `MyApp.Foo.Bar` lives in `lib/my_app/foo/bar.ex`.
**ALWAYS** **Always** Elixir variables are immutable within block expressions. You MUST bind the result of if/case/cond to a variable. Writing `socket = assign(...)` inside an if block without binding the if result does nothing.
**ALWAYS** **Never** use bracket access on Elixir lists — `list[0]` is invalid and will return `nil` silently (lists don't implement Access). Use `Enum.at(list, 0)`, `hd(list)`, or pattern matching `[first | _rest] = list`.
**ALWAYS** **Always** Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- **Always** remember: `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps
- **Always** Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
  you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:

      # INVALID: we are rebinding inside the `if` and the result never gets assigned
      if connected?(socket) do
        socket = assign(socket, :val, val)
      end

      # VALID: we rebind the result of the `if` to a new variable
      socket =
        if connected?(socket) do
          assign(socket, :val, val)
        end
- **Always** Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- **Always** **Number Range** (`:number_range`) - numeric fields → min/max inputs
  - Options: `min`, `max`, `step`
- **Always** **Checkbox** (`:checkbox`) - single checkbox for "show only X"
  - Options: `value`, `label`
- **Always** remember: `row_click={fn item -> JS.navigate(~p"/path/#{item.id}") end}` - row interactivity
- - `page_size={[default: 25, options: [10, 25, 50, 100]]}` - configurable with dropdown
- **Always** **Text** (`:text`) - string/atom fields → contains/starts_with/ends_with
  - Options: `operator`, `case_sensitive`, `placeholder`
- **Always** **Multi-Select** (`:multi_select`) - array fields → tag-based selection
  - Options: `options`, `prompt`, `match_mode` (:any/:all)
- - **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
- **Always** remember: `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
- **Always** remember: `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps
- - Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option
- - Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- - Predicate function names should not start with `is` and should end in a question mark.
- **Always** Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- - Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- **Always** To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- **Always** remember: `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
- - Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- - Set up processes such that they can handle crashing and being restarted by supervisors
- **Always** use pattern matching in function heads for recursion base cases. Example: `def process([]), do: :done` and `def process([h | t]), do: handle(h); process(t)` — never use `if Enum.empty?(list)` inside the function body.
- - Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- - There are many useful standard library functions, prefer to use them where possible
- - Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- **Always** **Multi-Checkboxes** (`:multi_checkboxes`) - array fields → checkbox interface
  - Options: `options`, `match_mode` (:any/:all)
- **Always** **Date Range** (`:date_range`) - date/datetime fields → date pickers
  - Options: `include_time`, `format`
- - **Select** (`:select`) - enum attributes → dropdown
  - Options: `options`, `prompt`
- **Always** remember: `theme="modern"` - built-in themes: default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel
- **Always** **Boolean** (`:boolean`) - boolean fields → true/false radio buttons
  - Options: `labels` map with `true`/`false` keys
- - When recursion is necessary, prefer to use pattern matching in function heads for base case detection

## Heex

**ALWAYS** - HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`) — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** **Always** use `{...}` syntax for interpolation in HEEx tag attributes, and `{@assign}` for values in tag bodies. Use `<%= ... %>` only for block constructs (`if`, `for`, `case`). Example: `<div id={@id}>{@name}</div>` — never `<div id="<%= @id %>">`
**ALWAYS** - **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`) — otherwise agents will ignore this rule or apply it inconsistently.
- - Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`**. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

  **Never do this (invalid)**:

      <%= if condition do %>
        ...
      <% else if other_condition %>
        ...
      <% end %>

  Instead **always** do this:

      <%= cond do %>
        <% condition -> %>
          ...
        <% condition2 -> %>
          ...
        <% true -> %>
          ...
      <% end %>
- - For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)
- - When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- - HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

      <a class={[
        "px-2 text-white",
        @some_flag && "py-5",
        if(@other_condition, do: "border-red-500", else: "border-blue-100"),
        ...
      ]}>Text</a>

  and **always** wrap `if`'s inside `{...}` expressions with parens, like done above (`if(@other_condition, do: "...", else: "...")`)

  and **never** do this, since it's invalid (note the missing `[` and `]`):

      <a class={
        "px-2 text-white",
        @some_flag && "py-5"
      }> ...
      => Raises compile syntax error on invalid HEEx attr syntax
- **Always** HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

## Liveview

**ALWAYS** **Always** use `handle_params/3` to drive page state from the URL — pages must be bookmarkable. Example: `def handle_params(params, _uri, socket), do: {:noreply, apply_params(socket, socket.assigns.live_action, params)}`
**ALWAYS** **Never** use `Enum` functions on LiveView streams — they are NOT enumerable. To filter/refresh, refetch data and re-stream with `stream(socket, :items, new_items, reset: true)`, otherwise you will get a protocol error at runtime.
**ALWAYS** - **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`
**ALWAYS** **Always** Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module — because skipping this step causes inconsistent or broken results
**ALWAYS** **Always** handle authentication flow at the router level with proper redirects — use `live_session` with `on_mount` hooks, e.g. `live_session :authenticated, on_mount: [{AppWeb.LiveUserAuth, :require_authenticated}]`
**ALWAYS** - **Always** provide an unique DOM id alongside `phx-hook` otherwise a compiler error will be raised
**ALWAYS** - **Never** read immediately after write/edit — because read immediately after write/edit will cause subtle bugs or wasted work
**ALWAYS** - **Never** use `@apply` when writing raw css — because use `@apply` when writing raw css will cause subtle bugs or wasted work
**ALWAYS** **Always** set `phx-update="ignore"` on elements with `phx-hook` that manage their own DOM. Example: `<div id="chart" phx-hook="ChartHook" phx-update="ignore">` — otherwise LiveView will overwrite the hook's DOM changes on re-render.
**ALWAYS** - **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")` — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** - Remember anytime you use `phx-hook="MyHook"` and that JS hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute — otherwise agents will ignore this rule or apply it inconsistently.
**ALWAYS** - **Always** use `project_eval` for Elixir, never shell — otherwise the result will be incorrect or break downstream behavior
**ALWAYS** - **Never** merge without approval — because merge without approval will cause subtle bugs or wasted work
**ALWAYS** - **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset
- - Created Ecto query function for direct table access (bypassing Ash for LiveTable compatibility)
- - Dashboard now uses DaisyUI-styled LiveTable with:
  - Sortable columns (Project, Status, Web Port)
  - Searchable project names
  - Pinned header and zebra striping
  - 25 items per page pagination
- - LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
         socket
         |> assign(:messages_empty?, messages == [])
         # reset the stream with the new messages
         |> stream(:messages, messages, reset: true)}
      end
- - LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- - colocated hooks names **MUST ALWAYS** start with a `.` prefix, i.e. `.PhoneNumber`
- - **Avoid LiveComponent's** unless you have a strong, specific need for them
- **Always** Installed live_table dependency from vintrepid/live_table fork (master branch)
- **Always** remember: `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- **Always** This tool helps identify CSS class usage patterns and optimize Tailwind implementations
- **Always** Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- - **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Always** Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- - When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")
- **Always** remember: `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- **Always** Demonstrated CSS cleanup on page_inventory_live.ex:
  - Before: 30 unique classes, 35 occurrences
  - After: 24 unique classes, 26 occurrences (20-26% reduction)
  - Extracted patterns to global CSS with semantic names
  - Maintained visual design while improving code quality
- - [x] Read all key guidelines (GUIDELINES.md, DAISYUI.md, CSS_CLEANUP_GUIDELINES.md)
- **Always** DaisyUI semantic classes (navbar-start, navbar-end) eliminate need for custom CSS
- **Always** remember: `lib/maestro_web/live/admin_live/tailwind_analysis_live.ex` (lines 205, 293, 325, 343, 373)
- **Always** v1.2.0: Added Circle patterns (multi_select_ui, empty_state, junction_table_management)
- **Always** [TOOLS.md](https://github.com/vintrepid/agents/blob/main/TOOLS.md) - Creating tools guide
- **Always** [ ] **Marked task.status** appropriately:
  - `:done` - Fully complete, tested, working
  - `:in_progress` - Started but not finished
  - `:blocked` - Can't proceed, needs user input
- **Never** [feedback_build_tools_not_fixes.md](feedback_build_tools_not_fixes.md) — NEVER fix things manually; always build the tool first, then let the tool do the work
- **Always** Hand off project-specific work to the right project agent (e.g. Calvin agent does Calvin code)
- - Write skills, mix tasks, and templates that make project agents more effective
- - [user_role.md](user_role.md) — Vince's vision: Maestro orchestrates agents, never does project-specific coding
- **Always** [feedback_auto_approve.md](feedback_auto_approve.md) — Execute autonomously after planning; never block on confirmations
- **Always** [general] Task types (research, feature, bug, etc) are just strategies - each type has patterns for how to execute. Don't invent approaches, follow the type's established pattern _(2025-11-01)_
- **Always** Features include: Mix task scanner, Ecto schema for storage, LiveView dashboard with LiveTable
- **Always** [feedback_aha_not_youre_right.md](feedback_aha_not_youre_right.md) — Say "Aha" not "You're right"; then capture the lesson immediately
- **Always** [feedback_move_faster.md](feedback_move_faster.md) — Trust task descriptions, don't over-research; move directly to execution
- - When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>
- - LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @streams.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.
- - When updating an assign that should change content inside any streamed item(s), you MUST re-stream the items
  along with the updated assign:

      def handle_event("edit_message", %{"message_id" => message_id}, socket) do
        message = Chat.get_message!(message_id)
        edit_form = to_form(Chat.change_message(message, %{content: message.content}))

        # re-insert message so @editing_message_id toggle logic takes effect for that stream item
        {:noreply,
         socket
         |> stream_insert(:messages, message)
         |> assign(:editing_message_id, String.to_integer(message_id))
         |> assign(:edit_form, edit_form)}
      end

  And in the template:

      <div id="messages" phx-update="stream">
        <div :for={{id, message} <- @streams.messages} id={id} class="flex group">
          {message.username}
          <%= if @editing_message_id == message.id do %>
            <%!-- Edit mode --%>
            <.form for={@edit_form} id="edit-form-#{message.id}" phx-submit="save_edit">
              ...
            </.form>
          <% end %>
        </div>
      </div>

## Pubsub

**ALWAYS** NEVER manually reload data after a mutation in handle_event. The PubSub notifier handles it for ALL connected clients. If you're writing |> load_data() at the end of handle_event, you're doing it wrong.
**ALWAYS** Every resource that participates in multi-user pages MUST have simple_notifiers: [AppName.ResourcePubSub]. The notifier broadcasts to collection topic, instance topic, AND walks belongs_to relationships to notify parents.
**ALWAYS** **Always** Every page has a main entity (resource instance or collection) with a DAG of dependencies. PubSub subscriptions MUST follow this graph. Subscribe in mount, reload in handle_info — ONE handler, not per-event.

## Routing

**ALWAYS** - Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.
- - You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

## Security

- **Always** When performing administrative actions, you can bypass authorization with `authorize?: false`
- - To run actions as a particular user, look that user up and pass it as the `actor` option
- - UserIdentity resource optional for OAuth2 (required for multiple providers per user)
- - Use `forbid_unless` for required conditions, then `authorize_if` for the final check
- - Always set the actor on the query/changeset/input, not when calling the action
- **Always** **Actions**: auto-generated by strategies (register, sign_in, etc.), can be overridden on the resource
- **Always** Include required authentication changes (`GenerateTokenChange`, `HashPasswordChange`, etc.)

## Testing

- Verify features by calling Ash resource actions directly (via project_eval or tests), NOT by clicking in the browser. UI is a metaphor for the model — if the action works, the UI follows.
- - Prefer to use raising versions of functions whenever possible, as opposed to pattern matching
