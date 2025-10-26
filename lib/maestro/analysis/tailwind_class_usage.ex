defmodule Maestro.Analysis.TailwindClassUsage do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "tailwind_class_usage" do
    field :class_name, :string
    field :category, :string
    field :file_path, :string
    field :line_number, :integer
    field :context, :string
    field :usage_count, :integer, default: 1
    field :analyzed_at, :utc_datetime
    field :description, :string
    field :project_name, :string

    timestamps()
  end

  def changeset(class_usage, attrs) do
    class_usage
    |> cast(attrs, [:class_name, :category, :file_path, :line_number, :context, :usage_count, :analyzed_at, :description, :project_name])
    |> validate_required([:class_name, :file_path, :line_number, :analyzed_at])
  end

  def available_projects(repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      where: not is_nil(c.project_name),
      select: c.project_name,
      distinct: true,
      order_by: c.project_name

    repo.all(query)
  end

  def summary_stats(analyzed_at \\ nil, project_name \\ nil, repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      group_by: c.class_name,
      select: %{
        class_name: c.class_name,
        category: fragment("array_agg(DISTINCT ?)", c.category),
        total_occurrences: count(c.id),
        file_count: fragment("COUNT(DISTINCT ?)", c.file_path)
      },
      order_by: [desc: count(c.id)]

    query = if analyzed_at, do: where(query, [c], c.analyzed_at == ^analyzed_at), else: query
    query = if project_name, do: where(query, [c], c.project_name == ^project_name), else: query
    repo.all(query)
  end

  def category_stats(analyzed_at \\ nil, project_name \\ nil, repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      where: not is_nil(c.category),
      group_by: c.category,
      select: %{
        category: c.category,
        unique_classes: fragment("COUNT(DISTINCT ?)", c.class_name),
        total_occurrences: count(c.id)
      },
      order_by: [desc: count(c.id)]

    query = if analyzed_at, do: where(query, [c], c.analyzed_at == ^analyzed_at), else: query
    query = if project_name, do: where(query, [c], c.project_name == ^project_name), else: query
    repo.all(query)
  end

  def file_stats(analyzed_at \\ nil, project_name \\ nil, repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      group_by: c.file_path,
      select: %{
        file_path: c.file_path,
        unique_classes: fragment("COUNT(DISTINCT ?)", c.class_name),
        total_occurrences: count(c.id)
      },
      order_by: [desc: count(c.id)]

    query = if analyzed_at, do: where(query, [c], c.analyzed_at == ^analyzed_at), else: query
    query = if project_name, do: where(query, [c], c.project_name == ^project_name), else: query
    repo.all(query)
  end

  def files_for_class(class_name, repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      where: c.class_name == ^class_name,
      select: %{
        file_path: c.file_path,
        line_number: c.line_number,
        context: c.context
      },
      order_by: [c.file_path, c.line_number]

    repo.all(query)
  end

  def available_timestamps(repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      select: c.analyzed_at,
      distinct: true,
      order_by: [desc: c.analyzed_at]

    repo.all(query)
  end

  def analysis_summary(repo \\ Maestro.Repo) do
    query = from c in __MODULE__,
      group_by: [c.analyzed_at, c.project_name],
      select: %{
        analyzed_at: c.analyzed_at,
        project_name: c.project_name,
        description: fragment("MAX(?)", c.description),
        unique_classes: fragment("COUNT(DISTINCT ?)", c.class_name),
        total_occurrences: count(c.id)
      },
      order_by: [desc: c.analyzed_at, asc: c.project_name]

    repo.all(query)
  end
end
