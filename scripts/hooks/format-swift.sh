#!/usr/bin/env bash
# PostToolUse hook: format the edited Swift file. Never blocks the agent.
input="$(cat)"
file="$(printf '%s' "$input" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
if [[ "$file" == *.swift && -f "$file" ]]; then
  swift format --in-place "$file" >/dev/null 2>&1 || true
fi
exit 0
