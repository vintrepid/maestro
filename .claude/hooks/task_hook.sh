#!/bin/bash
# Claude Code UserPromptSubmit hook — logs every user prompt as a Maestro task.
# Reads the prompt from stdin (JSON: {"prompt": "...", "session_id": "..."})
# Posts to the running Maestro app to create/update the current task.

MAESTRO_URL="${MAESTRO_URL:-http://localhost:4004}"
INPUT=$(cat)
PROMPT=$(echo "$INPUT" | jq -r '.prompt // empty' 2>/dev/null)

if [ -n "$PROMPT" ]; then
  curl -s -X POST "$MAESTRO_URL/api/tasks/hook" \
    -H "Content-Type: application/json" \
    -d "{\"prompt\": $(echo "$PROMPT" | jq -Rs .)}" \
    > /dev/null 2>&1 &
fi
