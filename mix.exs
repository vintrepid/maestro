defmodule Maestro.MixProject do
  use Mix.Project

  def project do
    [
      app: :maestro,
      version: "0.1.0",
      elixir: "~> 1.15",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      aliases: aliases(),
      deps: deps(),
      compilers: [:phoenix_live_view] ++ Mix.compilers(),
      listeners: [Phoenix.CodeReloader],
      consolidate_protocols: Mix.env() != :dev,
      usage_rules: usage_rules()
    ]
  end

  defp usage_rules do
    [
      usage_rules: [
        {:usage_rules, link: :markdown},
        {:ash, link: :markdown},
        {~r/^ash_/, link: :markdown},
        {:phoenix, link: :markdown},
        {:igniter, link: :markdown}
      ],
      skills: [
        location: ".claude/skills",
        # Pick up pre-built SKILL.md files shipped by deps
        package_skills: [:ash, ~r/^ash_/, :phoenix, :igniter, :usage_rules],
        build: [
          "ash-framework": [
            description:
              "Use this skill when working with Ash Framework or any of its extensions. Always consult this when making domain changes, features or fixes.",
            usage_rules: [:ash, ~r/^ash_/]
          ],
          "phoenix-liveview": [
            description:
              "Use this skill when working with Phoenix LiveView, templates, components, or the web layer.",
            usage_rules: [:phoenix]
          ],
          "elixir-core": [
            description: "Use this skill for core Elixir patterns, OTP, and general conventions.",
            usage_rules: [:usage_rules, :igniter]
          ]
        ]
      ]
    ]
  end

  # Configuration for the OTP application.
  #
  # Type `mix help compile.app` for more information.
  def application do
    [
      mod: {Maestro.Application, []},
      extra_applications: [:logger, :runtime_tools]
    ]
  end

  def cli do
    [
      preferred_envs: [precommit: :test]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Specifies your project dependencies.
  #
  # Type `mix help deps` for examples and options.
  defp deps do
    [
      {:open_api_spex, "~> 3.0"},
      {:ash_json_api, "~> 1.0"},
      {:maestro_tool, path: "../forks/maestro_tool"},
      {:css_linter, path: "../forks/css_linter"},
      {:fun_with_flags, "~> 1.11"},
      {:fun_with_flags_ui, "~> 1.0"},
      {:cinder, path: "../forks/cinder", override: true},
      {:ex_money_sql, "~> 1.0"},
      {:ex_cldr, "~> 2.0"},
      {:picosat_elixir, "~> 0.2"},
      {:sourceror, "~> 1.8"},
      {:oban, "~> 2.0"},
      {:usage_rules, "~> 1.2", only: [:dev]},
      {:ash_cloak, "~> 0.1"},
      {:cloak, "~> 1.0"},
      {:ash_ai, "~> 0.5"},
      {:ash_paper_trail, "~> 0.5"},
      {:tidewave, "~> 0.5", only: [:dev]},
      {:live_debugger, "~> 0.4", only: [:dev]},
      {:ash_archival, "~> 2.0"},
      {:ash_money, "~> 0.2"},
      {:oban_web, "~> 2.0"},
      {:ash_oban, "~> 0.7"},
      {:ash_admin, "~> 0.13"},
      {:ash_authentication_phoenix, "~> 2.0"},
      {:ash_authentication, "~> 4.0"},
      {:ash_postgres, "~> 2.0"},
      {:ash_phoenix, "~> 2.0"},
      {:ash, "~> 3.0"},
      {:igniter, "~> 0.6"},
      {:phoenix, "~> 1.8"},
      {:phoenix_ecto, "~> 4.5"},
      {:ecto_sql, "~> 3.13"},
      {:postgrex, ">= 0.0.0"},
      {:phoenix_html, "~> 4.1"},
      {:phoenix_live_reload, "~> 1.2", only: :dev},
      {:phoenix_live_view, "~> 1.1"},
      {:lazy_html, ">= 0.1.0", only: :test},
      {:floki, "~> 0.37"},
      {:phoenix_live_dashboard, "~> 0.8"},
      {:esbuild, "~> 0.10", runtime: Mix.env() == :dev},
      {:tailwind, "~> 0.4", runtime: Mix.env() == :dev},
      {:heroicons,
       github: "tailwindlabs/heroicons",
       tag: "v2.2.0",
       sparse: "optimized",
       app: false,
       compile: false,
       depth: 1},
      {:swoosh, "~> 1.16"},
      {:earmark, "~> 1.4"},
      {:req, "~> 0.5"},
      {:telemetry_metrics, "~> 1.0"},
      {:telemetry_poller, "~> 1.0"},
      {:gettext, "~> 1.0"},
      {:jason, "~> 1.2"},
      {:dns_cluster, "~> 0.2.0"},
      {:bandit, "~> 1.5"},
      {:slugify, "~> 1.3"}
    ]
  end

  # Aliases are shortcuts or tasks specific to the current project.
  # For example, to install project dependencies and perform other setup tasks, run:
  #
  #     $ mix setup
  #
  # See the documentation for `Mix` for more info on aliases.
  defp aliases do
    [
      setup: ["deps.get", "ash.setup", "assets.setup", "assets.build", "run priv/repo/seeds.exs"],
      "ecto.setup": ["ecto.create", "ecto.migrate", "run priv/repo/seeds.exs"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ash.setup --quiet", "test"],
      "assets.setup": ["tailwind.install --if-missing", "esbuild.install --if-missing"],
      "assets.build": ["compile", "tailwind maestro", "esbuild maestro"],
      "assets.deploy": [
        "tailwind maestro --minify",
        "esbuild maestro --minify",
        "phx.digest"
      ],
      precommit: ["compile --warning-as-errors", "deps.unlock --unused", "format", "test"]
    ]
  end
end
