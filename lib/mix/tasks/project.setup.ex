defmodule Mix.Tasks.Project.Setup.Docs do
  @moduledoc false
  def short_doc, do: "Complete project setup with environment variables"
  def example, do: "mix project.setup"
end

if Code.ensure_loaded?(Igniter) do
  defmodule Mix.Tasks.Project.Setup do
    @shortdoc "#{__MODULE__.Docs.short_doc()}"
    use Igniter.Mix.Task

    def info(_argv, _composing_task), do: %Igniter.Mix.Task.Info{group: :project}

    def igniter(igniter) do
      cldr_module = Igniter.Project.Module.module_name(igniter, "Cldr")

      igniter
      |> Igniter.Project.Module.find_and_update_or_create_module(
        cldr_module,
        """
        use Cldr,
          locales: ["en"],
          default_locale: "en"
        """,
        fn zipper -> {:ok, zipper} end
      )
      |> Igniter.Project.Config.configure_new(
        "config.exs",
        :ex_cldr,
        [:default_backend],
        cldr_module
      )
    end
  end
end
