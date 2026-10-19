#!/usr/bin/env bash
# Keeps one issue for a failing nightly (Denys:
# https://github.com/dfinchenko/tennis-beat/pull/32#issuecomment-6241234335). When the nightly
# fails it opens the issue "Nightly layout matrix failing", or comments on the open one, with a
# link to the run; when a nightly passes it closes the open issue. Other results (cancelled,
# skipped) change nothing.
# Usage: scripts/nightly-issue.sh <success|failure|cancelled|skipped> <run-url>
# Needs GH_TOKEN with issues: write. DRY_RUN=1 prints the gh commands instead of running them.
set -euo pipefail
result="${1:?result}"
run_url="${2:?run url}"
title="Nightly layout matrix failing"

gh_do() {
  if [[ "${DRY_RUN:-}" == 1 ]]; then printf 'would run: gh'; printf ' %q' "$@"; echo; else gh "$@"; fi
}

# The open issues are listed, not searched: the search index can lag (#34 R3-2).
open_issue="$(gh issue list --state open --limit 1000 --json number,title \
  --jq "map(select(.title == \"$title\")) | first | .number // empty")"

case "$result" in
  failure)
    if [[ -n "$open_issue" ]]; then
      gh_do issue comment "$open_issue" --body "The nightly failed again: $run_url"
    else
      gh_do issue create --title "$title" --body "The nightly workflow failed: $run_url

It runs the full layout matrix (EN, PL and UK; ♥ 205 and \"--\") with all the other watch tests, so the failure may be in any watch test, not only the layout test: check the failed job's log first. Fix it in the next PR, starting with a failing test (docs/harness.md § CI time budget). This issue closes when a nightly passes."
    fi
    ;;
  success)
    if [[ -n "$open_issue" ]]; then
      gh_do issue close "$open_issue" --comment "The nightly passed: $run_url"
    fi
    ;;
  *) echo "Nightly result '$result': the issue is left as it is." ;;
esac
