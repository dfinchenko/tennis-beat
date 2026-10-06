#!/usr/bin/env bash
# Gate: the Xcode project must stay openable by the Xcode 26.x on the CI runner.
# Xcode 27 writes the root key `validationLevel`, which forces objectVersion 110 (unreadable
# by Xcode 26: "future Xcode project file format"). Format 100 = Xcode 26.3 compatibility.
# Usage: scripts/gates/check-project-format.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
pbx="TennisBeat/TennisBeat.xcodeproj/project.pbxproj"
max=100
fail=0
version="$(sed -nE 's/^[[:space:]]*objectVersion = ([0-9]+);/\1/p' "$pbx")"
if [[ -z "$version" || "$version" -gt "$max" ]]; then
  echo "GATE FAIL: $pbx objectVersion is '${version:-missing}', must be <= $max (Xcode 26.3 format)" >&2
  fail=1
fi
if grep -Eq '^[[:space:]]*validationLevel = ' "$pbx"; then
  echo "GATE FAIL: $pbx contains 'validationLevel' (Xcode 27-only; forces objectVersion 110). Remove the line and set objectVersion = $max." >&2
  fail=1
fi
[[ $fail -eq 0 ]] && echo "GATE PASS: $pbx objectVersion $version"
exit $fail
