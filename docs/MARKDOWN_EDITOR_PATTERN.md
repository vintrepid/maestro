# Markdown Editor Pattern for LiveView + Ash

## The Right Way: Use AshAdmin's Built-in Support

**Don't build your own markdown editor component.** AshAdmin already has markdown editor support built-in.

## How to Use

### 1. Configure the Field in Your Ash Resource

In your resource module (e.g., `lib/maestro/ops/project.ex`):

```elixir
defmodule MyApp.MyResource do
  use Ash.Resource
  
  attributes do
    attribute :description, :string do
      allow_nil? true
      public? true
    end
  end
  
  # Configure for AshAdmin
  admin do
    field :description, :markdown
  end
end
```

### 2. For Custom LiveViews

If you need a markdown editor in a custom LiveView (not AshAdmin), use the EasyMDE JavaScript library that's already included:

**In your LiveView template:**

```heex
<div id="description-editor-wrapper" phx-update="ignore">
  <textarea 
    id="description-editor"
    name="description"
    phx-hook="MarkdownEditorHook"
    class="textarea textarea-bordered w-full"
  >{@value}</textarea>
</div>
```

**In your app.js (already configured):**

```javascript
const MarkdownEditorHook = {
  mounted() {
    const textarea = this.el;
    const easyMDE = new EasyMDE({
      element: textarea,
      spellChecker: false,
      toolbar: ["bold", "italic", "heading", "|", "quote", "unordered-list", "ordered-list", "|", "link", "image", "|", "preview", "side-by-side", "fullscreen"],
      status: false,
      initialValue: textarea.value || ""
    });
    
    easyMDE.codemirror.on("change", () => {
      textarea.value = easyMDE.value();
      textarea.dispatchEvent(new Event('input', { bubbles: true }));
    });
  }
};
```

### 3. Update Data with Ash (NOT SQL, NOT Browser Manipulation)

**✅ CORRECT:**

```elixir
def handle_event("save_description", %{"description" => description}, socket) do
  resource = socket.assigns.resource
  
  case MyResource.update(resource, %{description: description}) do
    {:ok, updated} ->
      {:noreply,
       socket
       |> assign(:resource, updated)
       |> put_flash(:info, "Description updated")}
    
    {:error, _} ->
      {:noreply, put_flash(socket, :error, "Failed to update")}
  end
end
```

**❌ WRONG - Don't use direct SQL:**

```elixir
execute_sql_query("UPDATE table SET description = $1", [description])
```

**❌ WRONG - Don't use browser manipulation:**

```javascript
document.querySelector('#editor').CodeMirror.setValue(text);
```

## Why Use Ash for Updates?

From DATA_MODIFICATION_PATTERNS guide:

- ✅ Validations enforced
- ✅ Business logic runs (hooks, callbacks)
- ✅ Policies checked (authorization)
- ✅ Calculations updated (computed fields)
- ✅ Consistent behavior (same as UI)
- ✅ Audit trails (if configured)
- ✅ Type safety

## Rendering Markdown

Use Earmark to convert markdown to HTML:

```elixir
case Earmark.as_html(markdown_text) do
  {:ok, html, _} -> raw(html)
  {:error, _, _} -> Phoenix.HTML.html_escape(markdown_text)
end
```

## Key Learnings

1. **Don't reinvent the wheel** - AshAdmin has this built-in
2. **Use Ash for all data updates** - Never bypass with SQL or browser manipulation
3. **Read documentation first** - Check deps for existing solutions
4. **EasyMDE is already available** - It's in the project, just use the hook

## References

- AshAdmin markdown field type: `deps/ash_admin/lib/ash_admin/resource/field.ex`
- Data modification patterns: Check project guides
- EasyMDE hook: `assets/js/app.js` (MarkdownEditorHook)
