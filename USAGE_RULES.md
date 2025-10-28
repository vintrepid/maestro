<!-- usage-rules-start -->
<!-- usage-rules-header -->
# Usage Rules

**IMPORTANT**: Consult these usage rules early and often when working with the packages listed below.
Before attempting to use any of these packages or to discover if you should use them, review their
usage rules to understand the correct patterns, conventions, and best practices.
<!-- usage-rules-header-end -->

<!-- phoenix:ecto-start -->
## phoenix:ecto usage
## Ecto Guidelines

- **Always** preload Ecto associations in queries when they'll be accessed in templates, ie a message that needs to reference the `message.user.email`
- Remember `import Ecto.Query` and other supporting modules when you write `seeds.exs`
- `Ecto.Schema` fields always use the `:string` type, even for `:text`, columns, ie: `field :name, :string`
- `Ecto.Changeset.validate_number/2` **DOES NOT SUPPORT the `:allow_nil` option**. By default, Ecto validations only run if a change for the given field exists and the change value is not nil, so such as option is never needed
- You **must** use `Ecto.Changeset.get_field(changeset, :field)` to access changeset fields
- Fields which are set programatically, such as `user_id`, must not be listed in `cast` calls or similar for security purposes. Instead they must be explicitly set when creating the struct

<!-- phoenix:ecto-end -->
<!-- phoenix:elixir-start -->
## phoenix:elixir usage
## Elixir guidelines

- Elixir lists **do not support index based access via the access syntax**

  **Never do this (invalid)**:

      i = 0
      mylist = ["blue", "green"]
      mylist[i]

  Instead, **always** use `Enum.at`, pattern matching, or `List` for index based list access, ie:

      i = 0
      mylist = ["blue", "green"]
      Enum.at(mylist, i)

- Elixir variables are immutable, but can be rebound, so for block expressions like `if`, `case`, `cond`, etc
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

- **Never** nest multiple modules in the same file as it can cause cyclic dependencies and compilation errors
- **Never** use map access syntax (`changeset[:field]`) on structs as they do not implement the Access behaviour by default. For regular structs, you **must** access the fields directly, such as `my_struct.field` or use higher level APIs that are available on the struct if they exist, `Ecto.Changeset.get_field/2` for changesets
- Elixir's standard library has everything necessary for date and time manipulation. Familiarize yourself with the common `Time`, `Date`, `DateTime`, and `Calendar` interfaces by accessing their documentation as necessary. **Never** install additional dependencies unless asked or for date/time parsing (which you can use the `date_time_parser` package)
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Predicate function names should not start with `is_` and should end in a question mark. Names like `is_thing` should be reserved for guards
- Elixir's builtin OTP primitives like `DynamicSupervisor` and `Registry`, require names in the child spec, such as `{DynamicSupervisor, name: MyApp.MyDynamicSup}`, then you can use `DynamicSupervisor.start_child(MyApp.MyDynamicSup, child_spec)`
- Use `Task.async_stream(collection, callback, options)` for concurrent enumeration with back-pressure. The majority of times you will want to pass `timeout: :infinity` as option

## Mix guidelines

- Read the docs and options before using tasks (by using `mix help task_name`)
- To debug test failures, run tests in a specific file with `mix test test/my_test.exs` or run all previously failed tests with `mix test --failed`
- `mix deps.clean --all` is **almost never needed**. **Avoid** using it unless you have good reason

<!-- phoenix:elixir-end -->
<!-- phoenix:html-start -->
## phoenix:html usage
## Phoenix HTML guidelines

- Phoenix templates **always** use `~H` or .html.heex files (known as HEEx), **never** use `~E`
- **Always** use the imported `Phoenix.Component.form/1` and `Phoenix.Component.inputs_for/1` function to build forms. **Never** use `Phoenix.HTML.form_for` or `Phoenix.HTML.inputs_for` as they are outdated
- When building forms **always** use the already imported `Phoenix.Component.to_form/2` (`assign(socket, form: to_form(...))` and `<.form for={@form} id="msg-form">`), then access those forms in the template via `@form[:field]`
- **Always** add unique DOM IDs to key elements (like forms, buttons, etc) when writing templates, these IDs can later be used in tests (`<.form for={@form} id="product-form">`)
- For "app wide" template imports, you can import/alias into the `my_app_web.ex`'s `html_helpers` block, so they will be available to all LiveViews, LiveComponent's, and all modules that do `use MyAppWeb, :html` (replace "my_app" by the actual app name)

- Elixir supports `if/else` but **does NOT support `if/else if` or `if/elsif`. **Never use `else if` or `elseif` in Elixir**, **always** use `cond` or `case` for multiple conditionals.

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

- HEEx require special tag annotation if you want to insert literal curly's like `{` or `}`. If you want to show a textual code snippet on the page in a `<pre>` or `<code>` block you *must* annotate the parent tag with `phx-no-curly-interpolation`:

      <code phx-no-curly-interpolation>
        let obj = {key: "val"}
      </code>

  Within `phx-no-curly-interpolation` annotated tags, you can use `{` and `}` without escaping them, and dynamic Elixir expressions can still be used with `<%= ... %>` syntax

- HEEx class attrs support lists, but you must **always** use list `[...]` syntax. You can use the class list syntax to conditionally add classes, **always do this for multiple class values**:

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

- **Never** use `<% Enum.each %>` or non-for comprehensions for generating template content, instead **always** use `<%= for item <- @collection do %>`
- HEEx HTML comments use `<%!-- comment --%>`. **Always** use the HEEx HTML comment syntax for template comments (`<%!-- comment --%>`)
- HEEx allows interpolation via `{...}` and `<%= ... %>`, but the `<%= %>` **only** works within tag bodies. **Always** use the `{...}` syntax for interpolation within tag attributes, and for interpolation of values within tag bodies. **Always** interpolate block constructs (if, cond, case, for) within tag bodies using `<%= ... %>`.

  **Always** do this:

      <div id={@id}>
        {@my_assign}
        <%= if @some_block_condition do %>
          {@another_assign}
        <% end %>
      </div>

  and **Never** do this – the program will terminate with a syntax error:

      <%!-- THIS IS INVALID NEVER EVER DO THIS --%>
      <div id="<%= @invalid_interpolation %>">
        {if @invalid_block_construct do}
        {end}
      </div>

<!-- phoenix:html-end -->
<!-- phoenix:liveview-start -->
## phoenix:liveview usage
## Phoenix LiveView guidelines

- **Never** use the deprecated `live_redirect` and `live_patch` functions, instead **always** use the `<.link navigate={href}>` and  `<.link patch={href}>` in templates, and `push_navigate` and `push_patch` functions LiveViews
- **Avoid LiveComponent's** unless you have a strong, specific need for them
- LiveViews should be named like `AppWeb.WeatherLive`, with a `Live` suffix. When you go to add LiveView routes to the router, the default `:browser` scope is **already aliased** with the `AppWeb` module, so you can just do `live "/weather", WeatherLive`
- Remember anytime you use `phx-hook="MyHook"` and that js hook manages its own DOM, you **must** also set the `phx-update="ignore"` attribute
- **Never** write embedded `<script>` tags in HEEx. Instead always write your scripts and hooks in the `assets/js` directory and integrate them with the `assets/js/app.js` file

### LiveView streams

- **Always** use LiveView streams for collections for assigning regular lists to avoid memory ballooning and runtime termination with the following operations:
  - basic append of N items - `stream(socket, :messages, [new_msg])`
  - resetting stream with new items - `stream(socket, :messages, [new_msg], reset: true)` (e.g. for filtering items)
  - prepend to stream - `stream(socket, :messages, [new_msg], at: -1)`
  - deleting items - `stream_delete(socket, :messages, msg)`

- When using the `stream/3` interfaces in the LiveView, the LiveView template must 1) always set `phx-update="stream"` on the parent element, with a DOM id on the parent element like `id="messages"` and 2) consume the `@streams.stream_name` collection and use the id as the DOM id for each child. For a call like `stream(socket, :messages, [new_msg])` in the LiveView, the template would be:

      <div id="messages" phx-update="stream">
        <div :for={{id, msg} <- @streams.messages} id={id}>
          {msg.text}
        </div>
      </div>

- LiveView streams are *not* enumerable, so you cannot use `Enum.filter/2` or `Enum.reject/2` on them. Instead, if you want to filter, prune, or refresh a list of items on the UI, you **must refetch the data and re-stream the entire stream collection, passing reset: true**:

      def handle_event("filter", %{"filter" => filter}, socket) do
        # re-fetch the messages based on the filter
        messages = list_messages(filter)

        {:noreply,
        socket
        |> assign(:messages_empty?, messages == [])
        # reset the stream with the new messages
        |> stream(:messages, messages, reset: true)}
      end

- LiveView streams *do not support counting or empty states*. If you need to display a count, you must track it using a separate assign. For empty states, you can use Tailwind classes:

      <div id="tasks" phx-update="stream">
        <div class="hidden only:block">No tasks yet</div>
        <div :for={{id, task} <- @stream.tasks} id={id}>
          {task.name}
        </div>
      </div>

  The above only works if the empty state is the only HTML block alongside the stream for-comprehension.

- **Never** use the deprecated `phx-update="append"` or `phx-update="prepend"` for collections

### LiveView tests

- `Phoenix.LiveViewTest` module and `LazyHTML` (included) for making your assertions
- Form tests are driven by `Phoenix.LiveViewTest`'s `render_submit/2` and `render_change/2` functions
- Come up with a step-by-step test plan that splits major test cases into small, isolated files. You may start with simpler tests that verify content exists, gradually add interaction tests
- **Always reference the key element IDs you added in the LiveView templates in your tests** for `Phoenix.LiveViewTest` functions like `element/2`, `has_element/2`, selectors, etc
- **Never** tests again raw HTML, **always** use `element/2`, `has_element/2`, and similar: `assert has_element?(view, "#my-form")`
- Instead of relying on testing text content, which can change, favor testing for the presence of key elements
- Focus on testing outcomes rather than implementation details
- Be aware that `Phoenix.Component` functions like `<.form>` might produce different HTML than expected. Test against the output HTML structure, not your mental model of what you expect it to be
- When facing test failures with element selectors, add debug statements to print the actual HTML, but use `LazyHTML` selectors to limit the output, ie:

      html = render(view)
      document = LazyHTML.from_fragment(html)
      matches = LazyHTML.filter(document, "your-complex-selector")
      IO.inspect(matches, label: "Matches")

### Form handling

#### Creating a form from params

If you want to create a form based on `handle_event` params:

    def handle_event("submitted", params, socket) do
      {:noreply, assign(socket, form: to_form(params))}
    end

When you pass a map to `to_form/1`, it assumes said map contains the form params, which are expected to have string keys.

You can also specify a name to nest the params:

    def handle_event("submitted", %{"user" => user_params}, socket) do
      {:noreply, assign(socket, form: to_form(user_params, as: :user))}
    end

#### Creating a form from changesets

When using changesets, the underlying data, form params, and errors are retrieved from it. The `:as` option is automatically computed too. E.g. if you have a user schema:

    defmodule MyApp.Users.User do
      use Ecto.Schema
      ...
    end

And then you create a changeset that you pass to `to_form`:

    %MyApp.Users.User{}
    |> Ecto.Changeset.change()
    |> to_form()

Once the form is submitted, the params will be available under `%{"user" => user_params}`.

In the template, the form form assign can be passed to the `<.form>` function component:

    <.form for={@form} id="todo-form" phx-change="validate" phx-submit="save">
      <.input field={@form[:field]} type="text" />
    </.form>

Always give the form an explicit, unique DOM ID, like `id="todo-form"`.

#### Avoiding form errors

**Always** use a form assigned via `to_form/2` in the LiveView, and the `<.input>` component in the template. In the template **always access forms this**:

    <%!-- ALWAYS do this (valid) --%>
    <.form for={@form} id="my-form">
      <.input field={@form[:field]} type="text" />
    </.form>

And **never** do this:

    <%!-- NEVER do this (invalid) --%>
    <.form for={@changeset} id="my-form">
      <.input field={@changeset[:field]} type="text" />
    </.form>

- You are FORBIDDEN from accessing the changeset in the template as it will cause errors
- **Never** use `<.form let={f} ...>` in the template, instead **always use `<.form for={@form} ...>`**, then drive all form references from the form assign as in `@form[:field]`. The UI should **always** be driven by a `to_form/2` assigned in the LiveView module that is derived from a changeset

<!-- phoenix:liveview-end -->
<!-- phoenix:phoenix-start -->
## phoenix:phoenix usage
## Phoenix guidelines

- Remember Phoenix router `scope` blocks include an optional alias which is prefixed for all routes within the scope. **Always** be mindful of this when creating routes within a scope to avoid duplicate module prefixes.

- You **never** need to create your own `alias` for route definitions! The `scope` provides the alias, ie:

      scope "/admin", AppWeb.Admin do
        pipe_through :browser

        live "/users", UserLive, :index
      end

  the UserLive route would point to the `AppWeb.Admin.UserLive` module

- `Phoenix.View` no longer is needed or included with Phoenix, don't use it

<!-- phoenix:phoenix-end -->
<!-- ash_phoenix-start -->
## ash_phoenix usage
_Utilities for integrating Ash and Phoenix_

[ash_phoenix usage rules](deps/ash_phoenix/usage-rules.md)
<!-- ash_phoenix-end -->
<!-- ash-start -->
## ash usage
_A declarative, extensible framework for building Elixir applications._

[ash usage rules](deps/ash/usage-rules.md)
<!-- ash-end -->
<!-- ash_authentication-start -->
## ash_authentication usage
_Authentication extension for the Ash Framework._

[ash_authentication usage rules](deps/ash_authentication/usage-rules.md)
<!-- ash_authentication-end -->
<!-- usage_rules-start -->
## usage_rules usage
_A dev tool for Elixir projects to gather LLM usage rules from dependencies_

## Using Usage Rules

Many packages have usage rules, which you should *thoroughly* consult before taking any
action. These usage rules contain guidelines and rules *directly from the package authors*.
They are your best source of knowledge for making decisions.

## Modules & functions in the current app and dependencies

When looking for docs for modules & functions that are dependencies of the current project,
or for Elixir itself, use `mix usage_rules.docs`

```
# Search a whole module
mix usage_rules.docs Enum

# Search a specific function
mix usage_rules.docs Enum.zip

# Search a specific function & arity
mix usage_rules.docs Enum.zip/1
```


## Searching Documentation

You should also consult the documentation of any tools you are using, early and often. The best 
way to accomplish this is to use the `usage_rules.search_docs` mix task. Once you have
found what you are looking for, use the links in the search results to get more detail. For example:

```
# Search docs for all packages in the current application, including Elixir
mix usage_rules.search_docs Enum.zip

# Search docs for specific packages
mix usage_rules.search_docs Req.get -p req

# Search docs for multi-word queries
mix usage_rules.search_docs "making requests" -p req

# Search only in titles (useful for finding specific functions/modules)
mix usage_rules.search_docs "Enum.zip" --query-by title
```


<!-- usage_rules-end -->
<!-- usage_rules:elixir-start -->
## usage_rules:elixir usage
# Elixir Core Usage Rules

## Pattern Matching
- Use pattern matching over conditional logic when possible
- Prefer to match on function heads instead of using `if`/`else` or `case` in function bodies
- `%{}` matches ANY map, not just empty maps. Use `map_size(map) == 0` guard to check for truly empty maps

## Error Handling
- Use `{:ok, result}` and `{:error, reason}` tuples for operations that can fail
- Avoid raising exceptions for control flow
- Use `with` for chaining operations that return `{:ok, _}` or `{:error, _}`

## Common Mistakes to Avoid
- Elixir has no `return` statement, nor early returns. The last expression in a block is always returned.
- Don't use `Enum` functions on large collections when `Stream` is more appropriate
- Avoid nested `case` statements - refactor to a single `case`, `with` or separate functions
- Don't use `String.to_atom/1` on user input (memory leak risk)
- Lists and enumerables cannot be indexed with brackets. Use pattern matching or `Enum` functions
- Prefer `Enum` functions like `Enum.reduce` over recursion
- When recursion is necessary, prefer to use pattern matching in function heads for base case detection
- Using the process dictionary is typically a sign of unidiomatic code
- Only use macros if explicitly requested
- There are many useful standard library functions, prefer to use them where possible

## Function Design
- Use guard clauses: `when is_binary(name) and byte_size(name) > 0`
- Prefer multiple function clauses over complex conditional logic
- Name functions descriptively: `calculate_total_price/2` not `calc/2`
- Predicate function names should not start with `is` and should end in a question mark.
- Names like `is_thing` should be reserved for guards

## Data Structures
- Use structs over maps when the shape is known: `defstruct [:name, :age]`
- Prefer keyword lists for options: `[timeout: 5000, retries: 3]`
- Use maps for dynamic key-value data
- Prefer to prepend to lists `[new | list]` not `list ++ [new]`

## Mix Tasks

- Use `mix help` to list available mix tasks
- Use `mix help task_name` to get docs for an individual task
- Read the docs and options fully before using tasks

## Testing
- Run tests in a specific file with `mix test test/my_test.exs` and a specific test with the line number `mix test path/to/test.exs:123`
- Limit the number of failed tests with `mix test --max-failures n`
- Use `@tag` to tag specific tests, and `mix test --only tag` to run only those tests
- Use `assert_raise` for testing expected exceptions: `assert_raise ArgumentError, fn -> invalid_function() end`
- Use `mix help test` to for full documentation on running tests

## Debugging

- Use `dbg/1` to print values while debugging. This will display the formatted value and other relevant information in the console.

<!-- usage_rules:elixir-end -->
<!-- usage_rules:otp-start -->
## usage_rules:otp usage
# OTP Usage Rules

## GenServer Best Practices
- Keep state simple and serializable
- Handle all expected messages explicitly
- Use `handle_continue/2` for post-init work
- Implement proper cleanup in `terminate/2` when necessary

## Process Communication
- Use `GenServer.call/3` for synchronous requests expecting replies
- Use `GenServer.cast/2` for fire-and-forget messages.
- When in doubt, use `call` over `cast`, to ensure back-pressure
- Set appropriate timeouts for `call/3` operations

## Fault Tolerance
- Set up processes such that they can handle crashing and being restarted by supervisors
- Use `:max_restarts` and `:max_seconds` to prevent restart loops

## Task and Async
- Use `Task.Supervisor` for better fault tolerance
- Handle task failures with `Task.yield/2` or `Task.shutdown/2`
- Set appropriate task timeouts
- Use `Task.async_stream/3` for concurrent enumeration with back-pressure

<!-- usage_rules:otp-end -->
<!-- ash_oban-start -->
## ash_oban usage
_The extension for integrating Ash resources with Oban._

[ash_oban usage rules](deps/ash_oban/usage-rules.md)
<!-- ash_oban-end -->
<!-- ash_ai-start -->
## ash_ai usage
_Integrated LLM features for your Ash application._

[ash_ai usage rules](deps/ash_ai/usage-rules.md)
<!-- ash_ai-end -->
<!-- igniter-start -->
## igniter usage
_A code generation and project patching framework_

[igniter usage rules](deps/igniter/usage-rules.md)
<!-- igniter-end -->
<!-- ash_postgres-start -->
## ash_postgres usage
_The PostgreSQL data layer for Ash Framework_

[ash_postgres usage rules](deps/ash_postgres/usage-rules.md)
<!-- ash_postgres-end -->
<!-- usage-rules-end -->

<!-- maestro_tool-start -->
## maestro_tool usage
# MaestroTool Agent Guidelines

## Overview

MaestroTool is a standalone development tool for standardizing Phoenix/LiveView/Ash project configuration.

## Usage

### Installation

Add to your project's mix.exs:

```elixir
def deps do
  [
    {:maestro_tool, github: "vintrepid/maestro_tool", only: [:dev]}
  ]
end
```

### Available Tasks

#### `mix maestro_tool.project.update`

Standardizes project configuration with:
- `.env` file with project-specific ports
- Updated `README.md` with correct information
- Git remote setup (GitHub)
- Agents symlink creation

**Options:**
- `--github-user` - GitHub username (default: vintrepid)

**Example:**
```bash
mix maestro_tool.project.update
mix maestro_tool.project.update --github-user myusername
```

**Behavior:**
- Idempotent - safe to run multiple times
- Won't overwrite existing `.env` files
- Only updates README if it has default Phoenix content
- Adds git remote only if missing

## Project Ports

The tool automatically detects project-specific ports:
- maestro: 4004/4012
- circle: 4015/4016
- ready: 4000/4008
- calvin: 4002/4010
- san_juan: 4003/4011
- new_project: 4001/4009
- default: 4000/4012

## Development

### Structure

```
maestro_tool/
├── lib/
│   ├── maestro_tool/
│   │   └── application.ex
│   ├── mix/
│   │   └── tasks/
│   │       └── maestro_tool.project.update.ex
│   └── maestro_tool.ex
├── test/
├── mix.exs
├── README.md
├── CHANGELOG.md
└── AGENTS.md (this file)
```

### Adding New Tasks

1. Create new file in `lib/mix/tasks/`
2. Use `Mix.Task` behavior
3. Add `@shortdoc` and `@moduledoc`
4. Namespace with `Mix.Tasks.MaestroTool.*`

Example:
```elixir
defmodule Mix.Tasks.MaestroTool.Analyze do
  @moduledoc """
  Analyzes project structure.
  """
  
  use Mix.Task

  @shortdoc "Analyze project structure"

  def run(args) do
    # Your logic here
  end
end
```

### Testing

```bash
mix test
```

### Release Process

1. Update CHANGELOG.md
2. Bump version in mix.exs
3. Commit changes
4. Tag release: `git tag v0.X.0`
5. Push: `git push --tags`

## Best Practices

- Keep dependencies minimal
- Make tasks idempotent
- Provide clear error messages
- Document all options
- Test across different project types

## Related Documentation

- [README.md](README.md) - User-facing documentation
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [TOOLS.md](https://github.com/vintrepid/agents/blob/main/TOOLS.md) - Creating tools guide
<!-- maestro_tool-end -->

<!-- css_linter-start -->
## css_linter usage
# CssLinter Agent Guidelines

## Overview

CssLinter is a CSS analysis tool with pluggable strategies for scanning and reporting on CSS class usage patterns.

## Usage

### Installation

Add to your project's mix.exs:

```elixir
def deps do
  [
    {:css_linter, github: "vintrepid/css_linter", only: [:dev]}
  ]
end
```

### Available Tasks

#### `mix css_linter.analyze`

Analyzes CSS class usage in your project.

**Options:**
- `--strategy` - Analysis strategy to use (default: "tailwind")
- `--output` - Output file path for JSON export
- `--paths` - Comma-separated list of paths to scan (default: "lib")

**Examples:**
```bash
# Analyze with Tailwind strategy
mix css_linter.analyze --strategy tailwind

# Export to JSON
mix css_linter.analyze --strategy tailwind --output analysis.json

# Scan specific paths
mix css_linter.analyze --paths "lib,priv/templates"
```

## Strategies

### Tailwind

Categorizes Tailwind CSS classes into groups:
- Layout (flex, grid, display)
- Spacing (padding, margin, gap)
- Sizing (width, height)
- Typography (font, text)
- Colors (bg, text, border colors)
- Effects (shadow, opacity, blur)
- DaisyUI Components
- And more...

### Custom Strategies

Create your own strategy by implementing the `CssLinter.Strategy` behavior:

```elixir
defmodule MyApp.CustomStrategy do
  @behaviour CssLinter.Strategy

  def categorize(class_name) do
    # Return category atom or nil
  end
  
  def category_name(category) do
    # Return human-readable category name
  end
end
```

## Development

### Structure

```
css_linter/
├── lib/
│   ├── css_linter/
│   │   ├── application.ex
│   │   ├── reporter.ex
│   │   ├── scanner.ex
│   │   ├── strategy.ex
│   │   ├── strategies/
│   │   │   └── tailwind.ex
│   │   └── schema/
│   ├── mix/
│   │   └── tasks/
│   │       └── css_linter.analyze.ex
│   └── css_linter.ex
├── test/
├── mix.exs
├── README.md
├── INSTALLATION.md
├── CHANGELOG.md
└── AGENTS.md (this file)
```

### Adding New Strategies

1. Create new file in `lib/css_linter/strategies/`
2. Implement `CssLinter.Strategy` behavior
3. Define `categorize/1` and `category_name/1` functions
4. Register in strategy loader

### Testing

```bash
mix test
```

### Release Process

1. Update CHANGELOG.md
2. Bump version in mix.exs
3. Commit changes
4. Tag release: `git tag v0.X.0`
5. Push: `git push --tags`

## Output Format

### Console Report

```
CSS Analysis Report
==================

Total Files Scanned: 45
Total Classes Found: 258 unique (1,191 occurrences)

Top 10 Classes:
  flex: 45 occurrences
  gap-4: 32 occurrences
  btn: 28 occurrences

By Category:
  layout: 156 occurrences (45 unique)
  spacing: 134 occurrences (38 unique)
```

### JSON Export

```json
{
  "summary": {
    "total_files": 45,
    "total_classes": 258,
    "total_occurrences": 1191
  },
  "classes": [
    {
      "name": "flex",
      "category": "layout",
      "count": 45,
      "files": [...]
    }
  ]
}
```

## Best Practices

- Run analysis regularly to track CSS usage trends
- Export JSON for historical tracking
- Use with Tailwind purge configuration
- Create custom strategies for project-specific patterns

## Related Documentation

- [README.md](README.md) - User-facing documentation
- [INSTALLATION.md](INSTALLATION.md) - Installation guide
- [CHANGELOG.md](CHANGELOG.md) - Version history
- [TOOLS.md](https://github.com/vintrepid/agents/blob/main/TOOLS.md) - Creating tools guide

## CSS Class Analysis & Cleanup

### Running Analysis

```bash
mix css_linter.analyze --strategy tailwind --output analysis.json
```

### Cleanup Process

1. Run analysis to identify high-usage patterns
2. Extract repeated combinations (3+ occurrences) to semantic classes
3. Create meaningful class names (`.page-section` not `.px-8-py-6`)
4. Run analysis again to verify reduction
5. Target: 20-26% reduction in unique classes

### Where to Put Extracted Styles

**Global CSS** (assets/css/app.css) - Application-wide patterns:
```css
.page-section {
  @apply px-8 py-6;
}
```

**Phoenix Components** (lib/*_web/components/) - Reusable UI patterns with markup

**Keep in Template** - Simple layout and one-off adjustments

### Integration Features

**Web UI** (when mounted in app):
- Visual class usage statistics
- Category breakdowns
- Sortable and searchable analysis results
- Track cleanup progress over time
<!-- css_linter-end -->

<!-- live_table-start -->
## live_table usage
# LiveTable LLM Usage Guidelines

This document provides clear rules and patterns for AI assistants to help developers use the LiveTable library correctly. Follow these guidelines when generating code suggestions or helping with LiveTable implementation.

## Core Principles

### 1. Field Key Mapping is Critical
**RULE**: Field keys in `fields()` function MUST match exactly with:
- Schema field names (for simple tables)
- Select clause keys (for custom queries)

### 2. Two Primary Usage Patterns
LiveTable supports exactly two patterns - choose the correct one:

#### Pattern A: Simple Tables (Single Schema)
```elixir
use LiveTable.LiveResource, schema: YourApp.Product
```
- Use when querying a single Ecto schema
- Field keys must match schema field names exactly
- No custom `data_provider` needed in `mount/3`

#### Pattern B: Complex Tables (Custom Queries)
```elixir
use LiveTable.LiveResource
# Must define custom data provider in mount/3
```
- Use for joins, computed fields, or complex logic
- Field keys must match select clause keys exactly
- Requires custom data provider assignment

## Critical Don'ts

### DON'T Mix Patterns
**NEVER** use `schema:` parameter with custom queries:
```elixir
# WRONG - Don't do this
use LiveTable.LiveResource, schema: User  # Remove this line
def mount(_params, _session, socket) do
  socket = assign(socket, :data_provider, {MyApp.Users, :complex_query, []})
  {:ok, socket}
end
```

### DON'T Misalign Field Keys
**NEVER** use field keys that don't match your data source:
```elixir
# WRONG - Field key doesn't match schema field
def fields do
  [
    user_name: %{label: "Name"}  # Schema field is 'name', not 'user_name'
  ]
end
```

### DON'T Forget Required Dependencies
**NEVER** generate LiveTable code without the core dependency:
```elixir
# REQUIRED in mix.exs
{:live_table, "~> 0.3.1"}
# Add {:oban, "~> 2.19"} only if using export functionality
```

### DON'T Skip Asset Setup
**NEVER** implement LiveTable without proper asset configuration

## Required Setup Checklist

When implementing with LiveTable, ALWAYS ensure:

### 1. Dependencies
```elixir
# In mix.exs deps function
{:live_table, "~> 0.3.1"}
# Add {:oban, "~> 2.19"} only if using exports
```

### 2. Configuration
```elixir
# In config/config.exs
config :live_table,
  repo: YourApp.Repo,
  pubsub: YourApp.PubSub

# Add Oban config only if using exports
# config :your_app, Oban,
#   repo: YourApp.Repo,
#   queues: [exports: 10]
```

### 3. JavaScript Assets
```javascript
// In assets/js/app.js
import hooks_default from "../../deps/live_table/priv/static/live-table.js";

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: hooks_default,  // Required
  // ... other config
});
```

### 4. CSS Assets
```css
/* In assets/css/app.css */
@source "../../deps/live_table/lib";
@import "../../deps/live_table/priv/static/live-table.css";
```

## Implementation Templates

### Template A: Simple Table (Single Schema)
```elixir
defmodule YourAppWeb.ProductLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource, schema: YourApp.Product

  def fields do
    [
      # Keys MUST match Product schema fields exactly
      id: %{label: "ID", sortable: true},
      name: %{label: "Product Name", sortable: true, searchable: true},
      price: %{label: "Price", sortable: true},
      stock_quantity: %{label: "Stock", sortable: true}
    ]
  end

  def filters do
    [
      in_stock: Boolean.new(:stock_quantity, "in_stock", %{
        label: "In Stock Only",
        condition: dynamic([p], p.stock_quantity > 0)
      })
    ]
  end
end
```

### Template B: Complex Table (Custom Query)
```elixir
defmodule YourAppWeb.OrderReportLive.Index do
  use YourAppWeb, :live_view
  use LiveTable.LiveResource  # NO schema parameter

  def mount(_params, _session, socket) do
    # REQUIRED: Assign custom data provider as {Module, Function, Arguments}
    socket = assign(socket, :data_provider, {YourApp.Orders, :list_with_details, []})
    {:ok, socket}
  end

  def fields do
    [
      # Keys MUST match select clause keys exactly
      order_id: %{label: "Order #", sortable: true},
      customer_name: %{label: "Customer", sortable: true, searchable: true},
      total_amount: %{label: "Total", sortable: true}
    ]
  end
end
```

```elixir
# Corresponding context function
defmodule YourApp.Orders do
  def list_with_details do
    from o in Order,
      join: c in Customer, on: o.customer_id == c.id,
      select: %{
        order_id: o.id,        # Field key must match this
        customer_name: c.name, # Field key must match this
        total_amount: o.total_amount
      }
  end
end
```

## Field Configuration Rules

### Basic Field Options
```elixir
field_name: %{
  label: "Display Name",      # Always provide
  sortable: true,            # REQUIRED if field should be sortable
  searchable: true,          # REQUIRED if field should be searchable
}
```

### Custom Rendering with `renderer`

**CRITICAL**: Use `renderer:` for custom cell formatting, not `component:` or `value:`.

The `renderer` function can receive either:
- **function/1**: Receives only the cell value
- **function/2**: Receives the cell value AND the full record/row

```elixir
# Function/1: Access only the cell value
status: %{
  label: "Status",
  renderer: fn value -> 
    content_tag(:span, String.upcase(value), class: "badge badge-#{value}")
  end
}

# Function/2: Access cell value AND full record for conditional rendering
priority: %{
  label: "Priority",
  renderer: fn value, record ->
    class = if record.urgent, do: "text-red-600 font-bold", else: "text-gray-500"
    content_tag(:span, value, class: class)
  end
}

# Using Phoenix.Component ~H sigil for complex markup
user_info: %{
  label: "User",
  renderer: fn _value, record ->
    assigns = %{user: record}
    ~H"""
    <div class="flex items-center gap-2">
      <img src={@user.avatar_url} class="w-8 h-8 rounded-full" />
      <span>{@user.name}</span>
    </div>
    """
  end
}
```

**Why function/2 is powerful**: Access to the full record lets you use data from ANY field, not just the current column's field. For example, showing a status badge that changes color based on a different field's value.

### Association Sorting (Custom Queries Only)
```elixir
# When sorting by joined table fields
product_name: %{
  label: "Product",
  sortable: true,
  assoc: {:order_items, :name}  # Must match query alias and field
}
```

## Filter Types

### Boolean Filter
```elixir
Boolean.new(:field_name, "param_name", %{
  label: "Filter Label",
  condition: dynamic([alias], alias.field_name > 0)
})
```

### Range Filter
```elixir
Range.new(:field_name, "param_name", %{
  type: :number,  # or :date
  label: "Range Label",
  min: 0,
  max: 1000
})
```

### Select Filter
```elixir
Select.new({:table_alias, :field_name}, "param_name", %{
  label: "Select Label",
  options: [
    %{label: "Display", value: ["actual_value"]},
    %{label: "All Active", value: ["active", "pending"]}
  ]
})
```

## Template Usage

### Required Template Structure
```elixir
# In your .html.heex template
<.live_table
  fields={fields()}
  filters={filters()}
  options={@options}    # Required
  streams={@streams}    # Required
/>
```

## Common Error Patterns to Avoid

### 1. Field Key Mismatch
```elixir
# Schema has 'email' field, but using wrong key
email_address: %{label: "Email"}  # Wrong
email: %{label: "Email"}          # Correct
```

### 2. Missing Data Provider for Custom Queries
```elixir
# Wrong - Custom query without data provider
use LiveTable.LiveResource
def fields do
  [complex_field: %{label: "Complex"}]
end
# Missing: data_provider assignment in mount/3
```

### 3. Schema with Custom Query
```elixir
# Wrong - Using both schema and custom query
use LiveTable.LiveResource, schema: User
def mount(_params, _session, socket) do
  socket = assign(socket, :data_provider, {App.Users, :custom_query, []})
end
```

## Decision Tree for LLMs

When helping with LiveTable implementation:

1. **Is it a single table query?**
   - YES → Use Pattern A (with `schema:`)
   - NO → Use Pattern B (custom data provider)

2. **Are there joins or computed fields?**
   - YES → Must use Pattern B
   - NO → Can use Pattern A

3. **Do field keys match the data source?**
   - Schema pattern → Keys match schema fields
   - Custom pattern → Keys match select clause

4. **Are all required assets configured?**
   - Check deps, config, JS hooks, CSS imports

5. **Is the template structure correct?**
   - Verify `fields()`, `filters()`, `@options`, `@streams`

## Quick Reference

### Must-Have Functions
- `fields()` - Always required
- `filters()` - Optional but recommended

### Must-Have Template Props
- `fields={fields()}`
- `filters={filters()}`
- `options={@options}`
- `streams={@streams}`

### Must-Have Dependencies
- `{:live_table, "~> 0.3.1"}` (always required)
- `{:oban, "~> 2.19"}` (only if using exports)

### Must-Have Config
- LiveTable repo and pubsub config (always required)
- Oban queue configuration (only if using exports)
- JavaScript hooks import
- CSS imports

This document ensures LLMs provide accurate, complete LiveTable implementations every time.
<!-- live_table-end -->
<!-- usage-rules-end -->
