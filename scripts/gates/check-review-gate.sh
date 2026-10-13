#!/usr/bin/env bash
# Review gate: the PR body's "Reviewed-SHA: <40-hex>" line must equal the PR head SHA.
# Inputs (env): PR_BODY, HEAD_SHA. Used by .github/workflows/review-gate.yml.
set -euo pipefail

: "${HEAD_SHA:?HEAD_SHA is not set}"
body="${PR_BODY:-}"

count="$(printf '%s\n' "$body" | tr -d '\r' | grep -Ec '^Reviewed-SHA:' || true)"
if [ "$count" -ne 1 ]; then
  echo "::error::The PR body must contain exactly one line starting with 'Reviewed-SHA:' (found $count)."
  exit 1
fi

reviewed="$(printf '%s\n' "$body" | tr -d '\r' | sed -nE 's/^Reviewed-SHA:[[:space:]]*([0-9a-f]{40})[[:space:]]*$/\1/p')"
if [ -z "$reviewed" ]; then
  echo "::error::'Reviewed-SHA:' must be followed by a full 40-character commit SHA and nothing else."
  exit 1
fi

if [ "$reviewed" != "$HEAD_SHA" ]; then
  echo "::error::Reviewed-SHA $reviewed does not match the PR head $HEAD_SHA. Re-run the reviewer on the head and update the PR body."
  exit 1
fi

echo "Review gate passed: Reviewed-SHA matches the PR head $HEAD_SHA."
