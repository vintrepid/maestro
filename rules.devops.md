# Devops Rules
# 43 rules · Generated 2026-03-23

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

## Security
SHOULD: **Always** When performing administrative actions, you can bypass authorization with `authorize?: false`
SHOULD: **Always** **Actions**: auto-generated by strategies (register, sign_in, etc.), can be overridden on the resource
SHOULD: **Always** Include required authentication changes (`GenerateTokenChange`, `HashPasswordChange`, etc.)
SHOULD: - Always set the actor on the query/changeset/input, not when calling the action
SHOULD: - To run actions as a particular user, look that user up and pass it as the `actor` option
SHOULD: - Use `forbid_unless` for required conditions, then `authorize_if` for the final check
SHOULD: - UserIdentity resource optional for OAuth2 (required for multiple providers per user)
