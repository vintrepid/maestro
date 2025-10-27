# Agent Guidelines for This Project

## Session Initialization

**When you start a new session, read the startup instructions:**

1. Check which project you're working on
2. Read `agents/startup/STARTUP.md` for the startup checklist
3. Follow the instructions in that file

For Maestro: Read `agents/startup/STARTUP.md`

## Framework Guidelines

For Elixir, Phoenix, and LiveView technical patterns, see:
- **agents/LIVEVIEW.md** - Complete Elixir/Phoenix/LiveView guidelines

## Project-Specific Guidelines

- Use `mix precommit` when done with changes
- Use `:req` library for HTTP requests (avoid :httpoison, :tesla, :httpc)

### Phoenix v1.8

- Always begin LiveView templates with `<Layouts.app flash={@flash} ...>`
- Use `<.icon name="hero-x-mark">` for icons
- Use `<.input>` component for form inputs

### CSS & Styling

**Philosophy: DaisyUI for Components, Tailwind for Layout**

See `agents/DAISYUI.md` for complete patterns.

### UI/UX

- Produce world-class UI designs
- Implement subtle micro-interactions
- Focus on delightful details

---

*For complete technical guidelines, see agents/LIVEVIEW.md*
*For workflow and git patterns, see agents/GUIDELINES.md*
