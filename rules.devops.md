# Devops Rules
# 8 rules · Generated 2026-03-30

## Architecture
MUST: **Always** Out of the box, `core_components.ex` imports an `<.icon name="hero-x-mark" class="w-5 h-5"/>` component for for hero icons. **Always** use the `<.icon>` component for icons, **never** use `Heroicons` modules or similar
MUST: - **Always** use the imported `<.input>` component for form inputs from `core_components.ex` when available. `<.input>` is imported and using it will save steps and prevent errors
MUST: **Always** UI is a metaphor for the model. When implementing a UI interaction, start by asking: what action am I taking on which resource? Work outward from there. If the model is correct, the UI just re-renders from truth.
MUST: **Always** functional core, imperative shell. Pure domain logic in modules and resources. UIs (LiveViews), mix tasks, and igniter tasks are thin imperative shells that call the core. The shell never contains business logic — it translates user intent into core function calls.
MUST: **Always** write moduledocs first, read moduledocs first. Don't read all the code — write the @moduledoc that tells future-you exactly what it needs to know, then trust those docs. Code is implementation; moduledocs are the interface.
MUST: **Always** fix the tool first, then run the tool. Never do one-off manual work. If something needs to happen repeatedly (curation, refactoring, deployment), build or fix the mix task/tool that does it, then execute the task.
MUST: **Never** duplicate logic that already lives in a resource. If you find yourself re-implementing what a resource already knows (its fields, validations, relationships, actions), you're coding in the wrong place. Ask: which resource is responsible for this? Put the logic there. Responsibility-driven design — every piece of knowledge has exactly one home.
SHOULD: Never say "You're right" or similar validating phrases. When corrected, acknowledge the correction by restating the correct approach and immediately applying it. Don't waste the user's time with empty agreement — show you understood by doing.
