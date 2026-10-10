# maestro

This project uses the first-party Phoenix/LiveView, Ash and Maestro Tool stack.

- Work from the user's current request; inspect the owning source and model.
- Use the existing Mix tool for repeatable work. Repair it and rerun it when it fails.
- Shared construction and enforcement belong in Maestro Tool; application behavior belongs in its Ash models and tests.
- Verify with `mix precommit`. Use `mix help TASK` for task options and prerequisites.
- Before changing tests, consult `docs/TESTING_GUIDELINES.md` when present.
- For checkout, release and managed-server operations, use the task workflow in this project's resolved `maestro_tool/usage-rules/agent-workflow.md`.

Dependency usage rules are searchable reference material (`mix usage_rules.search_docs`), not automatically adopted instructions. Do not bulk-import them or export a rule corpus into this file.
