#!/usr/bin/env bash
# Stop hook: before the agent finishes, run engine tests if the engine changed.
# Exit 2 blocks stopping and shows stderr to Claude. Runs once per stop cycle.
input="$(cat)"
if [[ "$(printf '%s' "$input" | jq -r '.stop_hook_active // false' 2>/dev/null)" == "true" ]]; then
  exit 0
fi
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
pkg="Packages/TennisCore"
[[ -f "$pkg/Package.swift" ]] || exit 0
if git diff --quiet HEAD -- "$pkg" && [[ -z "$(git ls-files --others --exclude-standard -- "$pkg")" ]]; then
  exit 0
fi
if ! out="$(swift test --package-path "$pkg" 2>&1)"; then
  echo "TennisCore tests are failing. Fix them before finishing:" >&2
  printf '%s\n' "$out" | tail -n 40 >&2
  exit 2
fi
exit 0
