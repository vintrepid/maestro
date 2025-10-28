# Polymorphic Relations Guide

A step-by-step guide for implementing polymorphic relationships in the application.

## What are Polymorphic Relations?

Polymorphic relations allow a model to belong to multiple other models through a single association. Instead of having separate foreign keys for each possible parent type, we use two fields:
- A "type" field (string) - The type of the parent (e.g., "Project", "Task", "User")
- An "id" field (string/integer) - The ID of the parent record

**Common naming patterns:**
- `entity_type` / `entity_id` (generic)
- `parent_type` / `parent_id` (for hierarchies)
- `owner_type` / `owner_id` (for ownership)
- `commentable_type` / `commentable_id` (for comments)
- `taggable_type` / `taggable_id` (for tags)

> **Note:** This guide uses `entity_type`/`entity_id` as examples, but you should choose names that make sense for your domain. The pattern and implementation steps are the same regardless of the field names.

## Example Use Case

Tasks can belong to either Projects or other Tasks:
```elixir
# Task belongs to Project
task.entity_type = "Project"
task.entity_id = "uuid-of-project"

# Task belongs to another Task
task.entity_type = "Task"  
task.entity_id = "2"
```

## Implementation Checklist

### 1. Schema Setup
If the polymorphic fields don't exist, add them to your schema:

```elixir
# In lib/my_app/resource.ex
attributes do
  # Use names that fit your domain!
  # entity_type/entity_id, parent_type/parent_id, owner_type/owner_id, etc.
  attribute :entity_type, :string do
    allow_nil? false
  end
  
  attribute :entity_id, :string do
    allow_nil? false
  end
end
```

### 2. Add New Entity Type to Options

Update any form dropdowns to include the new entity type:

```elixir
# In lib/my_app_web/live/form_live.ex
defp entity_type_options do
  [
    {"Project", "Project"},
    {"Task", "Task"},        # Add new type here
    {"User", "User"}         # And here
  ]
end
```

### 3. Update Display Name Calculation

Extend the `display_name` calculation to handle the new entity type:

```elixir
# In lib/my_app/resource.ex
calculations do
  calculate :display_name, :string, expr(
    cond do
      not is_nil(title) and entity_type == "Project" ->
        fragment("? || ' - ' || (SELECT name FROM projects WHERE id = CAST(? AS uuid))", title, entity_id)
      
      not is_nil(title) and entity_type == "Task" ->
        fragment("? || ' - ' || (SELECT title FROM tasks WHERE id = CAST(? AS integer))", title, entity_id)
      
      not is_nil(title) and entity_type == "User" ->
        fragment("? || ' - ' || (SELECT name FROM users WHERE id = CAST(? AS uuid))", title, entity_id)
      
      true -> title
    end
  )
end
```

**Important Notes:**
- Use correct CAST type: `uuid` for UUID primary keys, `integer` for integer keys
- Reference the correct display field: `name`, `title`, `email`, etc.
- Match the table name exactly

### 4. Update get_entity_name Helper

Add a clause for the new entity type in all places that resolve entity names:

```elixir
# In LiveView and Components
defp get_entity_name("Project", entity_id) when not is_nil(entity_id) do
  case Repo.get(MyApp.Project, entity_id) do
    nil -> nil
    project -> project.name
  end
end

defp get_entity_name("Task", entity_id) when not is_nil(entity_id) do
  case MyApp.Task.by_id(entity_id) do
    {:ok, task} -> task |> MyApp.load!([:display_name]) |> Map.get(:display_name)
    _ -> nil
  end
end

defp get_entity_name("User", entity_id) when not is_nil(entity_id) do
  case Repo.get(MyApp.User, entity_id) do
    nil -> nil
    user -> user.name
  end
end

defp get_entity_name(_, _), do: nil
```

**Update in these files:**
- Form LiveView (e.g., `task_form_live.ex`)
- List components (e.g., `task_table.ex`)
- Any other component that displays entity relationships

### 5. Add Child Records Table (If Applicable)

If you want to show child records on the parent detail page:

```elixir
# In the parent's LiveView render
<%= if @task do %>
  <div class="card bg-base-100 shadow-xl mt-6">
    <div class="card-body">
      <div class="flex items-center justify-between mb-4">
        <h3 class="card-title">Sub-tasks</h3>
        <.link navigate={~p"/tasks/new?entity_type=Task&entity_id=#{@task.id}"} class="btn btn-sm btn-primary">
          <.icon name="hero-plus" class="w-4 h-4" />
          New Sub-task
        </.link>
      </div>
      <MyAppWeb.Components.TaskTable.task_table
        id="task-subtasks-table"
        query_fn={fn -> task_subtasks_query(@task.id) end}
      />
    </div>
  </div>
<% end %>
```

Add the query function:

```elixir
defp task_subtasks_query(task_id) do
  import Ecto.Query
  from t in Task,
    where: t.entity_type == "Task" and t.entity_id == ^to_string(task_id),
    order_by: [desc: t.inserted_at]
end
```

### 6. Update New Record Links

When creating child records, pre-fill the entity fields:

```elixir
<.link navigate={~p"/tasks/new?entity_type=Task&entity_id=#{@task.id}"}>
  New Sub-task
</.link>
```

The form's mount function should handle these params:

```elixir
def mount(params, _session, socket) do
  # ...
  initial_params = %{}
  initial_params = if params["entity_type"], 
    do: Map.put(initial_params, :entity_type, params["entity_type"]), 
    else: initial_params
  initial_params = if params["entity_id"], 
    do: Map.put(initial_params, :entity_id, params["entity_id"]), 
    else: initial_params
  
  form = AshPhoenix.Form.for_create(Resource, :create, params: initial_params)
  # ...
end
```

## Testing Checklist

After implementing:

1. ✅ Can create child record from parent detail page
2. ✅ Child records display correct parent name
3. ✅ Parent detail page shows all child records
4. ✅ Display names resolve correctly (e.g., "Child Title - Parent Title")
5. ✅ New entity type shows in dropdown
6. ✅ Entity name resolves in tables and forms
7. ✅ Clicking "New [Child]" button pre-fills entity fields correctly

## Common Pitfalls

### 1. Wrong CAST Type
```elixir
# ❌ Wrong - using integer CAST for UUID
fragment("SELECT name FROM projects WHERE id = CAST(? AS integer)", entity_id)

# ✅ Correct
fragment("SELECT name FROM projects WHERE id = CAST(? AS uuid)", entity_id)
```

### 2. Incorrect Table/Column Names
```elixir
# ❌ Wrong - table doesn't exist
fragment("SELECT name FROM project WHERE ...")

# ✅ Correct - use plural table names
fragment("SELECT name FROM projects WHERE ...")
```

### 3. Missing Nil Checks
```elixir
# ❌ Wrong - can crash if entity_id is nil
case Repo.get(Project, entity_id) do

# ✅ Correct - guard against nil
defp get_entity_name("Project", entity_id) when not is_nil(entity_id) do
```

### 4. Forgetting to Load Calculations
```elixir
# ❌ Wrong - display_name won't be loaded
task = Task.by_id!(id)

# ✅ Correct
task = Task.by_id!(id, load: [:display_name])
```

### 5. Inconsistent entity_id Types
```elixir
# Be consistent with string vs integer
where: t.entity_id == ^to_string(task_id)  # If stored as string
where: t.entity_id == ^task_id             # If stored as integer
```

## Pattern Summary

For each new polymorphic relation:
1. **Options** - Add to `entity_type_options/0`
2. **Display** - Add to `display_name` calculation with correct CAST
3. **Resolve** - Add to `get_entity_name/2` in all relevant files
4. **Children** - Add table and query if showing child records
5. **Links** - Add "New Child" link with pre-filled params
6. **Test** - Verify all display names and relationships work

## Example: Adding "Comment" Entity Type

If comments can belong to Tasks or Projects:

```elixir
# 1. Add to options
defp entity_type_options do
  [
    {"Project", "Project"},
    {"Task", "Task"},
    {"Comment", "Comment"}  # New
  ]
end

# 2. Update display_name in Comment resource
calculate :display_name, :string, expr(
  cond do
    not is_nil(title) and entity_type == "Task" ->
      fragment("? || ' - ' || (SELECT title FROM tasks WHERE id = CAST(? AS integer))", title, entity_id)
    not is_nil(title) and entity_type == "Project" ->
      fragment("? || ' - ' || (SELECT name FROM projects WHERE id = CAST(? AS uuid))", title, entity_id)
    true -> title
  end
)

# 3. Add get_entity_name for Comment
defp get_entity_name("Comment", entity_id) when not is_nil(entity_id) do
  case Comment.by_id(entity_id) do
    {:ok, comment} -> comment |> MyApp.load!([:display_name]) |> Map.get(:display_name)
    _ -> nil
  end
end

# 4. Test creating comments on tasks and projects
```

## Related Files to Update

When adding a polymorphic relation, check these files:
- `lib/my_app/ops/[resource].ex` - Schema and calculations
- `lib/my_app_web/live/[resource]_form_live.ex` - Form options and entity resolution
- `lib/my_app_web/components/[resource]_table.ex` - Table entity resolution
- Any detail/show pages that display related records

## Quick Reference

| Step | File Pattern | What to Add |
|------|-------------|-------------|
| Options | `*_form_live.ex` | `entity_type_options/0` |
| Display Calc | Resource schema | `display_name` calculation |
| Resolve Entity | LiveView/Components | `get_entity_name/2` clauses |
| Child Table | Detail LiveView | Table component + query |
| New Links | Detail LiveView | Link with params |

## Naming Your Polymorphic Fields

Choose field names that clearly express the relationship in your domain:

### Generic Relations
```elixir
entity_type / entity_id  # When the relationship is generic/multipurpose
```

### Hierarchical Relations
```elixir
parent_type / parent_id  # For parent-child hierarchies
child_type / child_id    # For inverse relationships
```

### Ownership Relations
```elixir
owner_type / owner_id    # For ownership (User, Organization, Team)
creator_type / creator_id  # For tracking who created something
```

### Content Relations
```elixir
commentable_type / commentable_id  # For comments
taggable_type / taggable_id        # For tags
likeable_type / likeable_id        # For likes
attachable_type / attachable_id    # For attachments
```

### Activity/Event Relations
```elixir
subject_type / subject_id  # For activity feeds (who did it)
object_type / object_id    # For activity feeds (what was affected)
```

### Guidelines:
- Use `_type` suffix for the type field
- Use `_id` suffix for the ID field
- Match both fields to the same root word
- Choose names that read naturally: "comment.commentable_id" = "the thing this comment is on"
- Keep names consistent across your codebase

### This Guide's Examples

This guide uses `entity_type`/`entity_id` because that's what Maestro's Task model uses. When implementing your own polymorphic relations, substitute these names with whatever fits your domain (e.g., replace all instances of `entity_type` with `parent_type` and `entity_id` with `parent_id`).
