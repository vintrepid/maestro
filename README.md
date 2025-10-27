# Maestro

Phoenix/LiveView/Ash application.

## Development Setup

### Prerequisites

- PostgreSQL running locally
- Elixir 1.18+ and Erlang/OTP 27+
- Node.js for asset compilation

### Getting Started

```bash
# Install dependencies
mix deps.get

# Setup database
mix ecto.setup

# Start the server
source .env
mix phx.server
```

### Access Points

- **Web App**: http://localhost:4004
- **Live Debugger**: http://localhost:4012
- **Ash Admin**: http://localhost:4004/admin

## Project Structure

This project uses our standard stack:
- Phoenix 1.8+ with LiveView
- Ash Framework for resources
- Ash Authentication (magic link)
- Ash Admin for management UI
- Ash Oban for background jobs
- LiveDebugger for development

## Common Tasks

```bash
# Run tests
mix test

# Run precommit checks (format, credo, tests)
mix precommit

# Database tasks
mix ecto.create      # Create database
mix ecto.migrate     # Run migrations
mix ecto.reset       # Drop, create, migrate, seed

# Start interactive console
iex -S mix phx.server
```

## Documentation

See `agents/` directory (symlinked to ~/dev/agents) for:
- Development guidelines
- Phoenix/LiveView patterns
- DaisyUI integration guide
- Project setup instructions
