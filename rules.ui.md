# Ui Rules
# 17 rules · Generated 2026-03-28

## Architecture
MUST: **Always** Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
MUST: - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
MUST: **Always** UI is a metaphor for the model. When implementing a UI interaction, start by asking: what action am I taking on which resource? Work outward from there. If the model is correct, the UI just re-renders from truth.
MUST: **Always** functional core, imperative shell. Pure domain logic in modules and resources. UIs (LiveViews), mix tasks, and igniter tasks are thin imperative shells that call the core. The shell never contains business logic — it translates user intent into core function calls.
MUST: **Always** write moduledocs first, read moduledocs first. Don't read all the code — write the @moduledoc that tells future-you exactly what it needs to know, then trust those docs. Code is implementation; moduledocs are the interface.
MUST: **Always** fix the tool first, then run the tool. Never do one-off manual work. If something needs to happen repeatedly (curation, refactoring, deployment), build or fix the mix task/tool that does it, then execute the task.

## Components
MUST: Use library components and build reusable components. Don't hand-build what a library already handles. When a component exists (calendar, table, form), USE IT. — otherwise agents will ignore this rule or apply it inconsistently.
MUST: **Always** use Cinder (`<Cinder.collection>`) for data tables instead of LiveTable. Cinder is Ash-native, supports DaisyUI theming, URL state sync, and declarative column slots. LiveTable is deprecated — it uses raw Ecto queries and fake streaming (Repo.all then split).
SHOULD: **Always** use the `daisy_ui` theme when using Cinder collections. Pass `theme="daisy_ui"` to `<Cinder.collection>`. This ensures tables use DaisyUI semantic classes (table, table-zebra, btn, badge) consistent with the rest of the app.

## Css
MUST: **Never** put spacing, padding, or styling directly in page templates. Define once in app.css, override only when necessary. Components own their own spacing between themselves — pages don't add it. Internal apps: optimize for maximum information density (minimal spacing). Public-facing apps: more generous spacing by default. All styling layers: 1) DaisyUI component classes, 2) custom components in core_components.ex, 3) app.css for themes, spacing, typography, and semantic layout classes. Anti-pattern: scattering px-4 py-2 gap-4 mb-6 throughout page templates.
MUST: **Always** use DaisyUI component classes (`btn`, `card`, `modal`, `table`, `badge`, `alert`, `tabs`, `menu`, `navbar`, `dropdown`) instead of raw Tailwind utilities. Check https://daisyui.com/components/ before building custom CSS. Example: `class="btn btn-primary"` not `class="px-4 py-2 bg-blue-500 text-white rounded"`.

## Liveview
MUST: - **Always** use `project_eval` for Elixir, never shell — otherwise the result will be incorrect or break downstream behavior
MUST: - **Never** read immediately after write/edit — because read immediately after write/edit will cause subtle bugs or wasted work
MUST: **Never** use `Enum` functions on LiveView streams — they are NOT enumerable. To filter/refresh, refetch data and re-stream with `stream(socket, :items, new_items, reset: true)`, otherwise you will get a protocol error at runtime.

## Pubsub
MUST: NEVER manually reload data after a mutation in handle_event. The PubSub notifier handles it for ALL connected clients. If you're writing |> load_data() at the end of handle_event, you're doing it wrong.
MUST: **Always** Every page has a main entity (resource instance or collection) with a DAG of dependencies. PubSub subscriptions MUST follow this graph. Subscribe in mount, reload in handle_info — ONE handler, not per-event.
MUST: Every resource that participates in multi-user pages MUST have simple_notifiers: [AppName.ResourcePubSub]. The notifier broadcasts to collection topic, instance topic, AND walks belongs_to relationships to notify parents.
