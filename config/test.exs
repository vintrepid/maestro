import Config
config :maestro, Oban, testing: :manual
config :maestro, token_signing_secret: "SEi8texs9dK+TpBmvzyhKxOUotQq/LZb"
config :bcrypt_elixir, log_rounds: 1
config :ash, policies: [show_policy_breakdowns?: true], disable_async?: true

# Configure your database
#
# The MIX_TEST_PARTITION environment variable can be used
# to provide built-in test partitioning in CI environment.
# Run `mix help test` for more information.
config :maestro, Maestro.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "maestro_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: System.schedulers_online() * 2

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :maestro, MaestroWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "z5oc/B0LvUND6kJFN/fFvoi+rAST04EWn1Rc/+l17Z8C4iyRwIqMUzt2brlxxIPR",
  server: false

# In test we don't send emails
config :maestro, Maestro.Mailer, adapter: Swoosh.Adapters.Test

# Disable swoosh api client as it is only required for production adapters
config :swoosh, :api_client, false

# Print only warnings and errors during test
config :logger, level: :warning

# Initialize plugs at runtime for faster test compilation
config :phoenix, :plug_init_mode, :runtime

# Enable helpful, but potentially expensive runtime checks
config :phoenix_live_view,
  enable_expensive_runtime_checks: true
