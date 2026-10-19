#!/usr/bin/env bash
# Dry-run checks of scripts/flaky-retries.sh (#34 R3-3): the exact-title lookup, the new and the
# existing tracking issue, the 7-day window at its edge, the more-than-2 threshold, an
# investigation already open, and an old last comment. A stub `gh` answers `issue list` and
# `api` from JSON with the script's own jq filters, so the lookups run as on GitHub; DRY_RUN=1
# prints every write instead. Run under the macOS bash 3.2 too (CI runs it with /bin/bash).
# Usage: scripts/tests/flaky-retries-test.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
# FLAKY_SCRIPT: another copy of the script, for checking that a mutation is caught.
script="${FLAKY_SCRIPT:-$PWD/scripts/flaky-retries.sh}"

stub="$(mktemp -d)"
trap 'rm -rf "$stub"' EXIT
cat > "$stub/gh" <<'STUB'
#!/usr/bin/env bash
# `gh issue list ... --jq <filter>` and `gh api ... --jq <filter>`, answered from
# $ISSUES_JSON and $COMMENTS_JSON.
filter=""
while [ $# -gt 0 ]; do
  if [ "$1" = "--jq" ]; then filter="$2"; fi
  case "$1" in issue|api) kind="${kind:-$1}" ;; esac
  shift
done
case "$kind" in
  issue) echo "${ISSUES_JSON:-[]}" | jq -r "$filter" ;;
  api) echo "${COMMENTS_JSON:-[]}" | jq -r "$filter" ;;
  *) echo "stub gh: unexpected call" >&2; exit 1 ;;
esac
STUB
chmod +x "$stub/gh"

# 2026-10-18T20:00:00Z
now=1792353600
day=86400
iso() { date -u -r "$1" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d "@$1" +%Y-%m-%dT%H:%M:%SZ; }
marker="<!-- flaky-retry -->"
comment() { printf '{"body":"%s\\nRetried: `x`","created_at":"%s"}' "$marker" "$(iso "$1")"; }

failures=0
check() {  # check <name> <expected text> <output>
  if grep -qF -- "$2" <<<"$3"; then echo "ok: $1"; else
    echo "FAIL: $1: expected '$2' in:"; echo "$3"; failures=$((failures + 1))
  fi
}
check_not() {
  if grep -qF -- "$2" <<<"$3"; then
    echo "FAIL: $1: unexpected '$2' in:"; echo "$3"; failures=$((failures + 1))
  else echo "ok: $1"; fi
}
run() {  # run <issues json> <comments json> <test>...; a failing run prints its exit status
  ISSUES_JSON="$1" COMMENTS_JSON="$2" PATH="$stub:$PATH" DRY_RUN=1 NOW="$now" \
    bash "$script" https://run/1 "${@:3}" || echo "script exited $?"
}

tracking='[{"number":40,"title":"Flaky test retries"}]'
similar='[{"number":41,"title":"Flaky test retries (old)"}]'
investigating='[{"number":40,"title":"Flaky test retries"},{"number":50,"title":"Investigate flaky test retries"}]'

out="$(run "$similar" '[]' testA)"
check "no exact title: creates the tracking issue" "issue create --title Flaky\ test\ retries" "$out"
check "a new issue counts this run's retries" "Retries in the last 7 days: 1" "$out"

out="$(run "$tracking" '[]' testA)"
check "existing issue: comments on it" "issue comment 40" "$out"
check_not "existing issue: no new tracking issue" "--title Flaky\ test\ retries" "$out"

# One comment inside the window (6 days 23 h ago), one just outside it (7 days 1 s ago).
two="[$(comment $((now - 7 * day + 3600))),$(comment $((now - 7 * day - 1)))]"
out="$(run "$tracking" "$two" testA)"
check "the window counts only the last 7 days" "Retries in the last 7 days: 2" "$out"
check_not "2 retries: no investigation" "Investigate" "$out"

three="[$(comment $((now - day))),$(comment $((now - 2 * day)))]"
out="$(run "$tracking" "$three" testA)"
check "3 retries in the week" "Retries in the last 7 days: 3" "$out"
check "more than 2: opens the investigation and mentions Denys" "issue create --title Investigate\ flaky\ test\ retries --body \$'@dfinchenko 3 " "$out"

out="$(run "$investigating" "$three" testA)"
check "an open investigation gets a comment" "issue comment 50" "$out"
check_not "an open investigation: no second one" "--title Investigate" "$out"

out="$(run "$tracking" "[$(comment $((now - 30 * day)))]" testA)"
check "an old last comment does not fail the run (#34 R2-2)" "Retries in the last 7 days: 1" "$out"
check_not "an old last comment: the script exits 0" "script exited" "$out"

out="$(run "$tracking" '[]' testA testB)"
check "one comment per retried test" "Retried: \`testB\`" "$out"
check "two tests count twice" "Retries in the last 7 days: 2" "$out"

if [ "$failures" -gt 0 ]; then echo "$failures check(s) failed"; exit 1; fi
echo "all flaky-retries checks passed"
