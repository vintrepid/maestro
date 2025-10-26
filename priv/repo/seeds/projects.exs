alias Maestro.Ops.Project

projects = [
  %{
    name: "Ready",
    slug: "ready",
    description: "Chat app for Vince & Mia",
    web_port: 4000,
    debugger_port: 4007,
    github_url: "https://github.com/vintrepid/ready"
  },
  %{
    name: "Calvin",
    slug: "calvin",
    description: "Calvin project",
    web_port: 4001,
    debugger_port: 4008,
    github_url: "https://github.com/vintrepid/calvin"
  },
  %{
    name: "SanJuan",
    slug: "sanjuan",
    description: "SanJuan project",
    web_port: 4002,
    debugger_port: 4009,
    github_url: "https://github.com/vintrepid/sanjuan"
  },
  %{
    name: "new_project",
    slug: "new_project",
    description: "Phoenix/LiveView/Ash template project",
    web_port: 4003,
    debugger_port: 4011,
    github_url: "https://github.com/vintrepid/new_project"
  },
  %{
    name: "Maestro",
    slug: "maestro",
    description: "Project orchestration hub",
    web_port: 4004,
    debugger_port: 4012,
    github_url: "https://github.com/vintrepid/maestro"
  },
  %{
    name: "np",
    slug: "np",
    description: "Test project for setup workflow",
    web_port: 4005,
    debugger_port: 4013,
    github_url: "https://github.com/vintrepid/np"
  }
]

Enum.each(projects, fn project_data ->
  Project
  |> Ash.Changeset.for_create(:create, project_data)
  |> Ash.create!()
  |> IO.inspect(label: "Created project")
end)

IO.puts("\n✅ Seeded #{length(projects)} projects")
