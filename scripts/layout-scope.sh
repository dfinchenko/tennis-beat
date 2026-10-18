#!/usr/bin/env bash
# Which layout matrix the watch UI tests run (CI budget, Denys, relayed on #31:
# https://github.com/dfinchenko/tennis-beat/pull/31#issuecomment-6238799308).
# Prints "full" when the changed files touch the score header or layout, "worst" otherwise.
# Usage: scripts/layout-scope.sh <base-sha> <head-sha>
#        scripts/layout-scope.sh --files <path>...   (for checking a list of paths)
set -euo pipefail
cd "$(dirname "$0")/.."

# Header and layout files: what draws the score screen, its strings and fonts, what the layout
# test launches the app with (launch options, the fake workout, the test helpers, the engine
# that sets the phases), the layout test itself, and the CI files that choose the matrix.
patterns=(
  '^TennisBeat/TennisBeat Watch App/Score/'
  '^TennisBeat/TennisBeat Watch App/DesignSystem/'
  '^TennisBeat/TennisBeat Watch App/Match/ScoreScreenModel\.swift$'
  '^TennisBeat/TennisBeat Watch App/Health/HeartRateDisplay\.swift$'
  '^TennisBeat/TennisBeat Watch App/Localizable\.xcstrings$'
  '^TennisBeat/TennisBeat Watch App/Match/LaunchOptions\.swift$'
  '^TennisBeat/TennisBeat Watch App/Health/FakeWorkoutService\.swift$'
  '^TennisBeat/TennisBeat Watch AppUITests/Support/XCUIApplication\+Helpers\.swift$'
  '^Packages/TennisCore/'
  '^TennisBeat/TennisBeat Watch AppUITests/ScoreAccessibilityUITests\.swift$'
  '^\.github/workflows/(ci|watch-tests|nightly)\.yml$'
  '^scripts/layout-scope\.sh$'
)

if [[ "${1:-}" == "--files" ]]; then
  shift
  files="$(printf '%s\n' "$@")"
else
  [[ $# -eq 2 ]] || { echo "usage: $0 <base-sha> <head-sha> | --files <path>..." >&2; exit 2; }
  files="$(git diff --name-only "$1...$2")"
fi

for pattern in "${patterns[@]}"; do
  if grep -Eq "$pattern" <<<"$files"; then
    echo full
    exit 0
  fi
done
echo worst
