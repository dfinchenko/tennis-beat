#!/usr/bin/env bash
# Records every whole-test retry in one tracking issue, "Flaky test retries", separate from
# "Nightly layout matrix failing" (Denys, relayed on #34:
# https://github.com/dfinchenko/tennis-beat/pull/34#issuecomment-6254956236). One comment per
# retried test, with the test name and the run link, from PRs and the nightly alike. More than 2
# retries in 7 days opens one investigation issue (or comments on the open one) and mentions
# Denys, so he is told.
# Usage: scripts/flaky-retries.sh <run-url> <test-name>...
# Needs GH_TOKEN with issues: write. DRY_RUN=1 prints the gh commands instead of running them.
# NOW (seconds since the epoch) overrides the clock, for checking the 7-day window.
set -euo pipefail
run_url="${1:?run url}"
shift
[[ $# -gt 0 ]] || { echo "usage: $0 <run-url> <test-name>..." >&2; exit 2; }
title="Flaky test retries"
investigation="Investigate flaky test retries"
marker="<!-- flaky-retry -->"
week_limit=2
now="${NOW:-$(date +%s)}"

gh_do() {
  if [[ "${DRY_RUN:-}" == 1 ]]; then printf 'would run: gh'; printf ' %q' "$@"; echo; else gh "$@"; fi
}

# The open issue with exactly this title, or nothing.
find_issue() {
  gh issue list --state open --search "in:title \"$1\"" --json number,title \
    --jq "map(select(.title == \"$1\")) | first | .number // empty"
}

tracking="$(find_issue "$title")"
if [[ -z "$tracking" ]]; then
  body="Every whole-test retry in CI gets a comment here: the test and the run (PRs and the nightly). Count them in the PR metrics rows. More than $week_limit retries in 7 days opens \"$investigation\" (docs/harness.md § CI time budget)."
  if [[ "${DRY_RUN:-}" == 1 ]]; then
    gh_do issue create --title "$title" --body "$body"
    tracking="NEW"
  else
    tracking="$(gh issue create --title "$title" --body "$body" | sed -E 's|.*/issues/([0-9]+)$|\1|')"
  fi
fi

for test_name in "$@"; do
  gh_do issue comment "$tracking" --body "$marker
Retried: \`$test_name\`
Run: $run_url"
done

# Retries in the last 7 days, the ones just added included.
week_ago=$((now - 7 * 24 * 3600))
earlier=0
if [[ "$tracking" != "NEW" ]]; then
  earlier="$(gh api "repos/{owner}/{repo}/issues/$tracking/comments" --paginate \
    --jq ".[] | select(.body | startswith(\"$marker\")) | .created_at" |
    while IFS= read -r created; do
      epoch="$(date -u -d "$created" +%s 2>/dev/null || date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$created" +%s)"
      [[ "$epoch" -ge "$week_ago" ]] && echo x
    done | wc -l | tr -d ' ')"
fi
# Comments made in this run are not listed yet in a dry run.
if [[ "${DRY_RUN:-}" == 1 || "$tracking" == "NEW" ]]; then
  week=$((earlier + $#))
else
  week="$earlier"
fi
echo "Retries in the last 7 days: $week"

if [[ "$week" -gt "$week_limit" ]]; then
  open_task="$(find_issue "$investigation")"
  note="$week whole-test retries in the last 7 days (more than $week_limit), latest: $run_url. Tracking: #$tracking."
  if [[ -n "$open_task" ]]; then
    gh_do issue comment "$open_task" --body "$note"
  else
    gh_do issue create --title "$investigation" --body "@dfinchenko $note

Find the root cause before adding any retry: start from the saved result bundle and tap log of the retried runs (docs/harness.md § CI time budget)."
  fi
fi
