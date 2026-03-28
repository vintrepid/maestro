# Model Rules
# 95 rules · Generated 2026-03-27

## Architecture
MUST: - **Never** merge without approval — otherwise the result will be incorrect or break downstream behavior
MUST: - **NEVER** delete branches after merging without explicit user approval — because delete branches after merging without explicit user approval will cause subtle bugs or wasted work
MUST: - **NEVER** delete branches after merging without explicit user approval — otherwise the result will be incorrect or break downstream behavior
MUST: - **Never** use `@apply` when writing raw css — otherwise agents will ignore this rule or apply it inconsistently.
MUST: **Always** run ALL approved rules in the audit — never skip rules because they lack metadata fields. Rules are curated and approved for a reason. The audit's job is to check and apply rules to files, not to gatekeep which rules are worthy of checking. If a rule can't be checked automatically, report that gap — don't silently skip it.
MUST: **Never** hardcode rule-specific logic in audit/check functions. The rules themselves carry the information needed to check them — their content contains directives (Always/Never), code patterns in backticks, and code blocks showing correct/incorrect examples. The audit function should extract checkable patterns from ANY rule's content generically, not maintain a per-rule mapping.
MUST: **Always** Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
MUST: - **Never** read immediately after write/edit — otherwise the result will be incorrect or break downstream behavior
MUST: - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
MUST: - **Always** manually write your own tailwind-based components instead of using daisyUI for a unique, world-class design — otherwise agents will ignore this rule or apply it inconsistently.
MUST: - **Always** begin your LiveView templates with `<Layouts.app flash={@flash} ...>` which wraps all inner content — otherwise agents will ignore this rule or apply it inconsistently.
MUST: **Always** Phoenix v1.8 moved the `<.flash_group>` component to the `Layouts` module. You are **forbidden** from calling `<.flash_group>` outside of the `layouts.ex` module — otherwise the page will not reflect URL state.
MUST: **Always** UI is a metaphor for the model. When implementing a UI interaction, start by asking: what action am I taking on which resource? Work outward from there. If the model is correct, the UI just re-renders from truth.
MUST: **Always** say "Aha" instead of "You're right" when the user corrects you. Then immediately capture the lesson as a rule. "Aha" signals you learned something new. "You're right" is sycophantic and wastes the correction — it acknowledges without internalizing.
SHOULD: **Always** Sync upstream changes from frameworks (e.g., Phoenix AGENTS.md → `bootstrap/PHOENIX_AGENTS.md`)
SHOULD: **Always** **Usage Rules** (`usage_rules/`) - Package-specific guidelines from dependencies and our forks
SHOULD: - **Always use and maintain this import syntax** in the app.css file for projects generated with `phx.new`
SHOULD: **Always** **Produce world-class UI designs** with a focus on usability, aesthetics, and modern design principles
SHOULD: **Always** Implement **subtle micro-interactions** (e.g., button hover effects, and smooth transitions)
SHOULD: **Always** **Guidelines** (`bootstrap/`, `ui_work/`, `database_work/`, etc.) - Core patterns and best practices
SHOULD: **Always** **Usage tracking**: Track which guidelines agents actually reference during work to optimize future sessions
SHOULD: **Always** The `MyAppWeb.Layouts` module is aliased in the `my_app_web.ex` file, so you can use it without needing to alias it again
SHOULD: **Always** Check for each linter rule's pattern (deprecated functions, bad syntax patterns, etc.)
SHOULD: **Always** If you override the default input classes (`<.input class="myclass px-2 py-1 rounded-lg">)`) class with your own values, no default classes are inherited, so your
SHOULD: **Always** Focus on **delightful details** like hover effects, loading states, and smooth page transitions
SHOULD: **Always** **Real-time Monitoring**: Track which projects are running (ProjectMonitor GenServer checks TCP ports every 10s)
SHOULD: **Always** Tailwindcss v4 **no longer needs a tailwind.config.js** and uses a new import syntax in `app.css`:       @import "tailwindcss" source(none);       @source "../css";       @source "../js";       @source "../../lib/my_app_web";
SHOULD: When the user corrects me, respond with "Aha" — not "You're right." Then immediately capture what I just learned so it doesn't get missed again. **Why:** "You're right" is hollow acknowledgment. It means I heard the words but didn't internalize them. "Aha" signals genuine understanding, and the follow-up action (trapping the info) proves it. **How to apply:** On correction: (1) say "Aha", (2) identify what I missed, (3) save it — as a rule in the pipeline if it's project knowledge, as a memory if it's behavioral. Never let a correction pass without capturing it.
SHOULD: User wants to plan big tasks collaboratively, then have Claude execute autonomously without blocking on confirmations. Always approve and proceed with file edits, writes, and bash commands. Don't stop to ask "should I continue?" — just do the work. **Why:** User walks away after planning and expects work to be done when they return. Blocking on confirmations defeats the purpose. **How to apply:** After aligning on a plan, execute all steps without pausing for approval. Only stop if something is genuinely broken or ambiguous.
SHOULD: - Use `mix precommit` alias when you are done with all changes and fix any pending issues
SHOULD: Don't deploy immediately after writing new code. Compile check is not enough — verify the changes actually work before pushing to production. **Why:** User rejected a fly deploy right after 13 files of new PubSub code were written. Writing code and deploying in the same breath is reckless. **How to apply:** After writing code: compile, test if tests exist, and ideally verify via browser or runtime check. Only deploy when confident changes work.
SHOULD: - **Use Tailwind CSS classes and custom CSS rules** to create polished, responsive, and visually stunning interfaces.
SHOULD: - Write completion notes BEFORE marking task done - document first, status second
SHOULD: - **LiveTable Integration**: Uses vintrepid/live_table fork with DaisyUI styling
SHOULD: - **Linter** — should be enforced by tooling (mix task / compiler check), not agent docs
SHOULD: - Use the already included and available `:req` (`Req`) library for HTTP requests, **avoid** `:httpoison`, `:tesla`, and `:httpc`. Req is included by default and is the preferred HTTP client for Phoenix apps

## Ash
MUST: **Always** model recurring values (sites, categories, status codes) as Ash resources — never scatter string/atom literals through LiveViews. Example: if you have `status in [:active, :archived]`, create a `Status` resource or `Ash.Type.Enum`, otherwise literals drift across files.
MUST: **Always** keep ALL domain logic in Ash resources. LiveViews are thin wrappers: `mount`, `handle_params`, `handle_event` (delegate to action), `render`. Never put `File.read!`, `System.cmd`, or `Repo.all` in a LiveView — call an Ash action instead.
MUST: - **Always** invoke `mix ecto.gen.migration migration_name_using_underscores` when generating migration files, so the correct timestamp and conventions are applied — otherwise agents will ignore this rule or apply it inconsistently.
MUST: - **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email` — otherwise agents will ignore this rule or apply it inconsistently.
MUST: - You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields — otherwise agents will ignore this rule or apply it inconsistently.
SHOULD: **Always** remember: `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
SHOULD: **Always** For Polymorphic relationships, you can model them using `Ash.Type.Union`; see the “Polymorphic Relationships” guide for more information. ```elixir
SHOULD: **Never** `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
SHOULD: **Always** Configure foreign key constraints in your data layer if they have them (see `references` in AshPostgres)
SHOULD: **Always** remember: `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
SHOULD: **Always** **String prompts**: Processed as EEx templates with `@input` and `@context` variables
SHOULD: **Always** remember: `relationship` - Fetch relationship data (e.g., `/posts/123/relationships/comments`)
SHOULD: **Always** remember: `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
SHOULD: **Always** remember: `relationship` - Fetch relationship data (e.g., `/posts/123/relationships/comments`)
SHOULD: **Always** **Messages with PromptTemplate**: Processed using LangChain's `apply_prompt_templates`
SHOULD: **Always** The `author` relationship can include both public and private attributes when loaded
SHOULD: **Always** Be descriptive with relationship names (e.g., use `:authored_posts` instead of just `:posts`)
SHOULD: **Always** **Vectorization**: Convert text attributes into vector embeddings for semantic search
SHOULD: **Always** The `load` option serves dual purposes: loading relationships/calculations and making any loaded attributes visible (including private ones)
SHOULD: - **Embedded**: For resources embedded in other resources (`data_layer: :embedded`) (typically JSON under the hood)

## Elixir
MUST: **Always** Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
MUST: - Elixir lists **do not support index based access via the access syntax**   **Never do this (invalid)**:       i = 0       mylist = ["blue", "green"]       mylist[i]   Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:       i = 0       mylist = ["blue", "green"]       Enum.at(mylist, i)
MUST: - **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors — otherwise the result will be incorrect or break downstream behavior
MUST: - **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors — because nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors will cause subtle bugs or wasted work
MUST: - **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
MUST: **Never** nest multiple modules in the same file — it causes cyclic dependencies and compilation errors. Each module gets its own file at the path matching its name, e.g. `MyApp.Foo.Bar` lives in `lib/my_app/foo/bar.ex`.
MUST: **Never** use bracket access on Elixir lists — `list[0]` is invalid and will return `nil` silently (lists don't implement Access). Use `Enum.at(list, 0)`, `hd(list)`, or pattern matching `[first | _rest] = list`.
MUST: **Always** Elixir variables are immutable within block expressions. You MUST bind the result of if/case/cond to a variable. Writing `socket = assign(...)` inside an if block without binding the if result does nothing.
SHOULD: **Always** remember: `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
SHOULD: **Always** remember: `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason
SHOULD: **Always** use pattern matching in function heads for recursion base cases. Example: `def process([]), do: :done` and `def process([h | t]), do: handle(h); process(t)` — never use `if Enum.empty?(list)` inside the function body.
SHOULD: **Always** remember: `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps
SHOULD: **Always** Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc   you *must* bind the result of the expression to a variable if you want to use it and you CANNOT rebind the result inside the expression, ie:       # INVALID: we are rebinding inside the `if` and the result never gets assigned       if connected?(socket) do         socket = assign(socket, :val, val)       end       # VALID: we rebind the result of the `if` to a new variable       socket =         if connected?(socket) do           assign(socket, :val, val)         end
SHOULD: **Always** **Number Range** (`:number_range`) - numeric fields → min/max inputs   - Options: `min`, `max`, `step`
SHOULD: **Always** **Checkbox** (`:checkbox`) - single checkbox for "show only X"   - Options: `value`, `label`
SHOULD: **Always** remember: `row_click={fn item -> JS.navigate(~p"/path/#{item.id}") end}` - row interactivity
SHOULD: **Always** **Text** (`:text`) - string/atom fields → contains/starts_with/ends_with   - Options: `operator`, `case_sensitive`, `placeholder`
SHOULD: **Always** **Multi-Select** (`:multi_select`) - array fields → tag-based selection   - Options: `options`, `prompt`, `match_mode` (:any/:all)
SHOULD: - **Always use `start_supervised!/1`** to start processes in tests as it guarantees cleanup between tests
SHOULD: **Always** remember: `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps
SHOULD: **Always** Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
SHOULD: **Always** To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
SHOULD: - Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
SHOULD: **Always** **Date Range** (`:date_range`) - date/datetime fields → date pickers   - Options: `include_time`, `format`
SHOULD: **Always** remember: `theme="modern"` - built-in themes: default, modern, retro, futuristic, dark, daisy_ui, flowbite, compact, pastel
SHOULD: **Always** **Multi-Checkboxes** (`:multi_checkboxes`) - array fields → checkbox interface   - Options: `options`, `match_mode` (:any/:all)
SHOULD: **Always** **Boolean** (`:boolean`) - boolean fields → true/false radio buttons   - Options: `labels` map with `true`/`false` keys
SHOULD: **Always** Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
SHOULD: - Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
SHOULD: - Predicate function names should not start with `is` and should end in a question mark.

## Security
SHOULD: **Always** When performing administrative actions, you can bypass authorization with `authorize?: false`
SHOULD: **Always** **Actions**: auto-generated by strategies (register, sign_in, etc.), can be overridden on the resource
SHOULD: **Always** Include required authentication changes (`GenerateTokenChange`, `HashPasswordChange`, etc.)
SHOULD: - Always set the actor on the query/changeset/input, not when calling the action
SHOULD: - To run actions as a particular user, look that user up and pass it as the `actor` option
SHOULD: - Use `forbid_unless` for required conditions, then `authorize_if` for the final check
SHOULD: - UserIdentity resource optional for OAuth2 (required for multiple providers per user)

## Testing
SHOULD: - Prefer to use raising versions of functions whenever possible, as opposed to pattern matching
SHOULD: Verify features by calling Ash resource actions directly (via project_eval or tests), NOT by clicking in the browser. UI is a metaphor for the model — if the action works, the UI follows.
