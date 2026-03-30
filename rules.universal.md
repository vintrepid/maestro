# Universal Rules
# 12 rules · Generated 2026-03-30

## Architecture
MUST: **Always** Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
MUST: - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
MUST: **Always** UI is a metaphor for the model. When implementing a UI interaction, start by asking: what action am I taking on which resource? Work outward from there. If the model is correct, the UI just re-renders from truth.
MUST: **Always** functional core, imperative shell. Pure domain logic in modules and resources. UIs (LiveViews), mix tasks, and igniter tasks are thin imperative shells that call the core. The shell never contains business logic — it translates user intent into core function calls.
MUST: **Always** write moduledocs first, read moduledocs first. Don't read all the code — write the @moduledoc that tells future-you exactly what it needs to know, then trust those docs. Code is implementation; moduledocs are the interface.
MUST: **Always** fix the tool first, then run the tool. Never do one-off manual work. If something needs to happen repeatedly (curation, refactoring, deployment), build or fix the mix task/tool that does it, then execute the task.
MUST: **Never** duplicate logic that already lives in a resource. If you find yourself re-implementing what a resource already knows (its fields, validations, relationships, actions), you're coding in the wrong place. Ask: which resource is responsible for this? Put the logic there. Responsibility-driven design — every piece of knowledge has exactly one home.
SHOULD: Never say "You're right" or similar validating phrases. When corrected, acknowledge the correction by restating the correct approach and immediately applying it. Don't waste the user's time with empty agreement — show you understood by doing.

## Ash
MUST: **Always** use Ash resource actions (`Resource.read!()`, `Resource.update()`, `Resource.by_id!()`) to query and mutate data — never raw SQL, `Repo.all`, `Ecto.Query`, or `browser_eval` for data operations. Ash resources are the API. SQL and browser are escape hatches for debugging only.

## Components
MUST: **Always** use Cinder (`<Cinder.collection>`) for data tables instead of LiveTable. Cinder is Ash-native, supports DaisyUI theming, URL state sync, and declarative column slots. LiveTable is deprecated — it uses raw Ecto queries and fake streaming (Repo.all then split).
SHOULD: **Always** use the `daisy_ui` theme when using Cinder collections. Pass `theme="daisy_ui"` to `<Cinder.collection>`. This ensures tables use DaisyUI semantic classes (table, table-zebra, btn, badge) consistent with the rest of the app.

## Elixir
SHOULD: Never use regex or text manipulation to modify Elixir source code. Always use Igniter and Sourceror for AST-based code transformations. Regex-based code edits are fragile, miss edge cases, and break on formatting changes. AST manipulation is correct by construction.
