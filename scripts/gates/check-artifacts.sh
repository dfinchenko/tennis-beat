#!/usr/bin/env bash
# Gate: a feature may be implemented only if its Spec Kit artifacts exist, are non-empty
# and the spec is approved by Denys.
# Usage: scripts/gates/check-artifacts.sh specs/001-scoring-engine
set -euo pipefail
dir="${1:?usage: check-artifacts.sh specs/NNN-feature}"
fail=0
for f in spec.md plan.md tasks.md; do
  if [[ ! -s "$dir/$f" ]]; then
    echo "GATE FAIL: $dir/$f is missing or empty" >&2
    fail=1
  fi
done
if [[ -s "$dir/spec.md" ]] && ! grep -Eq '^\**Status:?\**:? *Approved' "$dir/spec.md"; then
  echo "GATE FAIL: $dir/spec.md is not 'Status: Approved' (set by Denys)" >&2
  fail=1
fi
[[ $fail -eq 0 ]] && echo "GATE PASS: $dir"
exit $fail
