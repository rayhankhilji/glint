#!/usr/bin/env bash
# Self-test for check-licenses.sh.
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-licenses.sh"
pass=0; failed=0
run() { # name want identity
  local t; t="$(mktemp -d)"; mkdir -p "$t/Pkg"
  printf '{"pins":[{"identity":"%s","kind":"remoteSourceControl","location":"x","state":{"version":"1.0.0"}}],"version":2}' "$3" > "$t/Pkg/Package.resolved"
  "$SCRIPT" "$t" >/dev/null 2>&1; local got=$?
  if [[ $got == "$2" ]]; then pass=$((pass+1)); else failed=$((failed+1)); echo "FAIL: $1 (exit $got)"; fi
  rm -rf "$t"
}
run "allowlisted MIT package passes" 0 Sparkle
run "unknown package fails" 1 some-gpl-thing
echo "check-licenses self-test: $pass passed, $failed failed"
[[ $failed -eq 0 ]]
