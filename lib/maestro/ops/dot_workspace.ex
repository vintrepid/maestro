defmodule Maestro.Ops.DotWorkspace do
  @moduledoc "A reviewed development brief and explicitly selected work for the Maestro DOT."
  use Ash.Resource.Actions.Implementation

  alias Maestro.Ops.{DevServerProject, Project, Task}
  alias Maestro.Resources.Resource
  require Ash.Query

  @review "2026-11-12"
  @profile "Maestro DOT — operating process"
  @source "Vince's current development-orchestration conversation, 2026-11-12"

  @doc "Current intent, separate from the historical backlog and observed implementation state."
  @spec project_briefs() :: [map()]
  def project_briefs do
    [
      %{
        slug: "maestro",
        name: "Maestro",
        description:
          "Development orchestration: projects, tasks, resources and workflows form the functional core. A DOT runs work selected by that core. Historical records require review before reuse; UI and runners remain thin imperative shells."
      },
      %{
        slug: "calvin",
        name: "Calvin",
        description:
          "AO operations and travel publishing. Current direction: Best Time to Visit remains distinct; rafting and river information are activity layers. Website/domain portfolio uses one resource. Revalidate implementation and deployment evidence before planning further work."
      },
      %{
        slug: "dabhand",
        name: "Dab Hand",
        description:
          "Research crawlers and composable activity layers for travel planning, beginning with rafting and rivers and extensible to other interests. This is the user-confirmed direction; current code and backlog have not been revalidated by this brief."
      }
    ]
  end

  @doc "Only a separately activated, reviewed profile can authorize its selected tasks."
  @spec eligible_tasks(map(), [map()]) :: [map()]
  def eligible_tasks(metadata, tasks) do
    if (metadata["execution_enabled"] == true and metadata["reviewed_at"]) &&
         metadata["review_source"] do
      ids = MapSet.new(metadata["active_task_ids"] || [])
      projects = MapSet.new(metadata["project_ids"] || [])

      Enum.filter(tasks, fn task ->
        MapSet.member?(ids, task.id) and
          task.entity_type == "project" and
          MapSet.member?(projects, task.entity_id) and
          task.status in [:todo, :in_progress]
      end)
    else
      []
    end
  end

  @impl true
  def run(%{action: %{name: :dot_work_packet}}, _opts, _context) do
    case Maestro.Ops.get_project_by_slug("maestro") do
      nil ->
        {:error, "Prepare the reviewed Maestro DOT workspace first"}

      project ->
        resources =
          Resource
          |> Ash.Query.filter(owner_type == "Project" and owner_id == ^project.id)
          |> Ash.read!(authorize?: false)

        case Enum.find(resources, &(&1.title == @profile)) do
          nil ->
            {:error, "Prepare the reviewed Maestro DOT workspace first"}

          profile ->
            metadata = profile.metadata || %{}
            ids = metadata["active_task_ids"] || []
            project_ids = metadata["project_ids"] || []

            tasks =
              Task
              |> Ash.Query.filter(
                id in ^ids and entity_type == "project" and entity_id in ^project_ids
              )
              |> Ash.read!(authorize?: false)

            {:ok,
             %{
               profile_id: profile.id,
               reviewed_at: metadata["reviewed_at"],
               activation_state: metadata["activation_state"],
               execution_enabled: metadata["execution_enabled"] == true,
               reviewed_tasks:
                 Enum.map(tasks, &Map.take(&1, [:id, :title, :description, :status, :notes])),
               executable_task_ids: Enum.map(eligible_tasks(metadata, tasks), & &1.id),
               resources: Enum.map(resources, &Map.take(&1, [:id, :title, :url, :content]))
             }}
        end
    end
  end

  def run(input, _opts, _context) do
    projects = Project.read!(authorize?: false)
    configs = DevServerProject.read!(authorize?: false)
    ports = Map.new(configs, &{&1.slug, &1.app_port})
    briefs = project_briefs()

    missing = Enum.reject(briefs, &is_integer(ports[&1.slug]))

    if missing != [] do
      {:error,
       "Missing managed development configuration: #{Enum.map_join(missing, ", ", & &1.slug)}"}
    else
      if input.arguments.apply do
        case Ash.transact([Project, Task, Resource], fn -> refresh!(briefs, ports, projects) end) do
          {:ok, result} -> {:ok, result}
          {:error, reason} -> {:error, reason}
        end
      else
        {:ok,
         %{
           mode: "preview",
           reviewed_at: @review,
           projects: briefs,
           task_titles: Enum.map(task_specs(), & &1.title),
           execution_enabled: false
         }}
      end
    end
  end

  defp refresh!(briefs, ports, projects) do
    current =
      Enum.map(briefs, fn brief ->
        attributes =
          Map.delete(
            Map.merge(brief, %{web_port: ports[brief.slug], debugger_port: ports[brief.slug] + 1}),
            :slug
          )

        case Enum.find(projects, &(&1.slug == brief.slug)) do
          nil -> Project.create!(Map.put(attributes, :slug, brief.slug), authorize?: false)
          project -> Project.update!(project, attributes, authorize?: false)
        end
      end)

    maestro = Enum.find(current, &(&1.slug == "maestro"))

    existing_tasks =
      Task
      |> Ash.Query.filter(entity_type == "project" and entity_id == ^maestro.id)
      |> Ash.read!(authorize?: false)

    tasks =
      Enum.map(task_specs(), fn spec ->
        Enum.find(existing_tasks, &(&1.title == spec.title)) ||
          Task.create!(
            Map.merge(spec, %{
              entity_type: "project",
              entity_id: maestro.id,
              status: :todo,
              notes:
                "Reviewed source: #{@source}. Historical tasks are not authorized by this record."
            }),
            authorize?: false
          )
      end)

    resources =
      Resource
      |> Ash.Query.filter(owner_type == "Project" and owner_id == ^maestro.id)
      |> Ash.read!(authorize?: false)

    existing_profile = Enum.find(resources, &(&1.title == @profile))
    previous = if existing_profile, do: existing_profile.metadata || %{}, else: %{}

    metadata =
      Map.merge(previous, %{
        "reviewed_at" => @review,
        "review_source" => @source,
        "project_ids" => Enum.map(current, & &1.id),
        "active_task_ids" => Enum.map(tasks, & &1.id),
        "execution_enabled" => false,
        "activation_state" =>
          "prepared; ChatGPT DOT activation and scoped connection are unverified",
        "historical_project_briefs" =>
          Map.get(
            previous,
            "historical_project_briefs",
            Enum.map(
              projects,
              &Map.take(&1, [:slug, :name, :description, :web_port, :debugger_port])
            )
          ),
        "scope" =>
          "Maestro project, task and resource records. Repository work requires a task-specific grant."
      })

    specs = [
      %{title: @profile, resource_type: :other, content: process(), metadata: metadata},
      %{
        title: "Maestro DOT — current project brief",
        resource_type: :other,
        content: Enum.map_join(briefs, "\n\n", &(&1.name <> ": " <> &1.description)),
        metadata: %{"reviewed_at" => @review, "review_source" => @source}
      },
      %{
        title: "Maestro DOT — bootstrap instructions",
        resource_type: :other,
        content: prompt(),
        metadata: %{"reviewed_at" => @review, "activation_state" => "prepared"}
      },
      %{
        title: "OpenAI DOT setup and controls",
        resource_type: :website,
        url: "https://learn.chatgpt.com/docs/dots/getting-started",
        content:
          "Official references: https://learn.chatgpt.com/docs/dots/computers-and-apps and https://learn.chatgpt.com/docs/dots/controls. Instructions are not a filesystem sandbox; computer access and app permissions are separate grants.",
        metadata: %{"reviewed_at" => @review}
      }
    ]

    saved =
      Enum.map(specs, fn spec ->
        case Enum.find(resources, &(&1.title == spec.title)) do
          nil ->
            Resource.create!(Map.merge(spec, %{owner_type: "Project", owner_id: maestro.id}),
              authorize?: false
            )

          resource ->
            Resource.update!(resource, spec, authorize?: false)
        end
      end)

    %{
      mode: "refreshed",
      project_ids: Enum.map(current, & &1.id),
      task_ids: Enum.map(tasks, & &1.id),
      resource_ids: Enum.map(saved, & &1.id),
      execution_enabled: false,
      profile_id: hd(saved).id
    }
  end

  defp task_specs do
    [
      %{
        title: "[DOT #{@review}] Review Maestro's historical backlog",
        task_type: :curation,
        description:
          "Compare historical project tasks and resources with current user decisions. Propose retain, revise or archive classifications. Preserve history. Old todo/in-progress states and recent monitor timestamps do not authorize execution."
      },
      %{
        title: "[DOT #{@review}] Revalidate Calvin's current milestones",
        task_type: :plan,
        description:
          "Use Calvin's current task records and verified handoffs to summarize Website/domain consolidation, Best Time to Visit and rafting/river publishing. Separate implemented, verified, deployed and proposed work. Do not treat this planning item as a deployment grant."
      },
      %{
        title: "[DOT #{@review}] Confirm Dab Hand's next layer and crawler work",
        task_type: :plan,
        description:
          "Draft current priorities from the user-confirmed layer/crawler direction. Ask for missing task-specific repository scope and acceptance criteria before changing Dab Hand. Existing project membership grants no access to other repositories or files."
      },
      %{
        title: "[DOT #{@review}] Repair cross-project updater recovery",
        task_type: :bug,
        description:
          "Observed during this bootstrap: maestro.depup --target captured Maestro's server but recovered Calvin on port 4004 because restart ran in the caller's Mix project. Add an independent cross-project ownership regression and recover the target's own application. Coordinate shared Maestro Tool work through its existing work log."
      },
      %{
        title: "[DOT #{@review}] Activate the scoped ChatGPT DOT runner",
        task_type: :other,
        description:
          "Create/select the Maestro DOT in ChatGPT, provide its bootstrap resource, and verify a narrowly scoped connection to the reviewed Maestro work packet. Computer-use access to the setup screen was blocked in this session. Do not grant general Mac access, publish local Maestro, invent a schedule, or mark the runner active without verification."
      }
    ]
  end

  defp process do
    """
    Reviewed #{@review}. Source: #{@source}.

    Maestro projects, tasks and resources are authoritative. The DOT is an execution adapter. Application actions own task selection and transitions; the UI and runner call those actions.

    1. Read this current profile and the current project brief. Treat every older record as historical unless specifically revalidated.
    2. Review only the explicit task IDs in active_task_ids. A timestamp, old status or plausible title is insufficient authorization. Preserve old records and completion evidence.
    3. Before execution, verify execution_enabled and the selected task's scope, owning repository, dependencies, acceptance criteria and handoff contract. Current state is prepared, execution disabled.
    4. Read pending verification; start one bounded task through the owning project's workflow. Keep functional behavior in Ash resources and domain functions. Record the exact commit, focused checks, full-suite state and deployment state.
    5. Report progress and concrete blockers in Maestro. Respect the user's current steering. Do not send messages to others, buy services, change permissions, merge or deploy without the task's actual authorization.

    Access is opt-in. Maestro records are in scope; project membership is not blanket filesystem, browser, email or account access. Do not enable broad access to the Mac. Custom instructions are not an enforced sandbox. A local localhost URL is not reachable from the DOT's cloud computer without a separately verified connection. No recurring schedule has been created.
    """
  end

  defp prompt do
    """
    You are Maestro, Vince's development coordinator. Use Maestro's existing Ash projects, tasks and resources as the source of truth. Your role is a thin runner of that functional core.

    Read the resources titled 'Maestro DOT — operating process' and 'Maestro DOT — current project brief', reviewed #{@review}. Confirm which connection actually lets you read them. If unavailable, ask for that specific work packet rather than searching the Mac or other accounts.

    Maestro contains old data. Do not resume its historical backlog. Start by reviewing the explicit task IDs in the operating profile and preparing a concise proposed plan. Execution is disabled until Vince activates a verified, scoped connection. Do not change your own permission scope or set execution_enabled yourself. No Mac-wide access, messaging, merge, deployment or recurring schedule is granted by this prompt.

    For each authorized task, use its own repository workflow and acceptance criteria. Distinguish implemented, focused-verified, full-suite-verified and deployed. Persist results and current blockers in Maestro and keep Vince informed concisely.
    """
  end
end
