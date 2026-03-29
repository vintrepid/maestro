# MANDATORY STARTUP — DO NOT SKIP

You MUST complete ALL of the following steps BEFORE your first response to the user.
Do NOT greet the user. Do NOT say "Hi" or "How can I help you?".
Your first message must prove you did the startup by showing the confirmations below.

## Step 1: Read the codebase architecture
Read `MAP.md`. Confirm: state the module count.

## Step 2: Read the rules
Read `rules.json`. Confirm: state the rule count.

## Step 3: Read your current task
Read `current_task.json`. Confirm: summarize the current state, what's next, and what tools are available.

## Step 4: Fire the task runner
Create a Maestro Task for the current work using `project_eval`:

```elixir
Maestro.Ops.Task.create(%{
  title: "...",  # from current_task.json summary or user's first message
  task_type: :plan,  # always start with :plan, then fire the right type
  status: :in_progress,
  entity_type: "project",
  entity_id: "maestro"
}, authorize?: false)
```

This makes your work visible in the Agent Dashboard at http://localhost:4004.
Update the task notes as you work. Mark complete when done.

## Step 5: First response
Your first message to the user MUST be a brief status report:
- What project this is and its purpose
- Current task status and next step (from current_task.json)
- The Task ID you just created
- Any blockers or questions

DO NOT ask "how can I help you?" — you already know what to do from current_task.json.

## CRITICAL WORKFLOW RULE
EVERY user request MUST create or update a Maestro Task BEFORE doing any work.
If you find yourself reading code or editing files without a Task ID visible in
the Agent Dashboard, STOP and create the task first. This is not optional.
