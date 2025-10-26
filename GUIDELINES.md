# Agent Guidelines - Project Initialization

## Initialization Protocol

**IMPORTANT: Every time the user says "Hi" or starts a conversation, you MUST:**

1. **Read this file first** (GUIDELINES.md in project root)
2. **Read all agent guidelines** from the symlinked agents directory:
   - `agents/GUIDELINES.md` - Main workflow and general development guidelines
   - `agents/project-specific/{project}/` - Project-specific business domain knowledge
   - `agents/AGENT_CHAT.md` - Read recent session logs from other agents
3. **Read project-specific guidelines**:
   - `AGENTS.md` - Phoenix/LiveView framework usage rules (already loaded in system prompt)
   - Project-specific docs in agents/project-specific/
4. **Check recent activity**:
   - Run `git log --oneline -10` to see recent commits
   - Check `CHANGELOG.md` for ongoing work
5. **Leave a check-in message** in `agents/AGENT_CHAT.md` with:
   - Project name and timestamp
   - What you plan to work on
   - Current branch (if working on features)
6. **Acknowledge** that you have read and will follow ALL these guidelines

### How to Read the Guidelines

Use shell commands to read the symlinked files:

```bash
cat agents/GUIDELINES.md
cat agents/project-specific/{project}/*.md
cat agents/AGENT_CHAT.md
```

## After Reading All Guidelines

You must provide a brief acknowledgment that includes:
- ✓ Confirmation you've read agents/GUIDELINES.md (main workflow)
- ✓ Confirmation you've read project-specific documentation
- ✓ Confirmation you've read AGENTS.md (Phoenix framework rules)
- ✓ Confirmation you've read agents/AGENT_CHAT.md (session logs)
- ✓ A summary of the key workflow requirements (git branches, commits, testing)
- ✓ A summary of project-specific patterns

## Why This Matters

These guidelines contain:
- **Workflow standards** - How to work with git, branches, commits
- **Framework patterns** - Phoenix, LiveView, Ash usage rules
- **Business logic** - Project-specific domain knowledge
- **Testing requirements** - When and how to run tests
- **Common pitfalls** - Lessons learned from previous work
- **Cross-session coordination** - What other agents have been working on

## Usage Rules Already Loaded

The following are already in your system prompt:
- Phoenix v1.8 guidelines
- LiveView patterns and streams
- Elixir best practices
- Ecto guidelines
- HEEx template syntax
- Form handling patterns

## DO NOT PROCEED WITHOUT READING

If you haven't read all the guidelines files listed above, **STOP** and read them now before responding to any request.
