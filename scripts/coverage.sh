#!/usr/bin/env bash
# Line-coverage gate per module (EVAL_GUARDRAILS §7.1). Run after `swift test --enable-code-coverage`.
# Usage: scripts/coverage.sh core|kit
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
case "${1:-}" in
  core) PKG="$ROOT/Packages/GlintCore"; GATES="GlintCore=90" ;;
  kit)  PKG="$ROOT/Packages/GlintKit";  GATES="GlintServices=80 GlintSystem=60 GlintPerception=60" ;;
  *) echo "usage: scripts/coverage.sh core|kit" >&2; exit 2 ;;
esac
JSON="$(swift test --package-path "$PKG" --show-codecov-path)"
[[ -f "$JSON" ]] || { echo "No coverage data at $JSON. Run: swift test --package-path $PKG --enable-code-coverage" >&2; exit 2; }
python3 -I - "$JSON" "$PKG" $GATES <<'PY'
import json, sys
data = json.load(open(sys.argv[1]))["data"][0]["files"]
pkg = sys.argv[2].rstrip("/") + "/Sources/"
failed = False
for gate in sys.argv[3:]:
    module, minimum = gate.split("=")
    prefix = pkg + module + "/"
    files = [f for f in data if f["filename"].startswith(prefix)]
    if not files:
        print(f"  {module}: no sources yet — gate skipped")
        continue
    count = sum(f["summary"]["lines"]["count"] for f in files)
    covered = sum(f["summary"]["lines"]["covered"] for f in files)
    pct = 100.0 * covered / count if count else 100.0
    status = "ok" if pct >= float(minimum) else "FAIL"
    failed |= status == "FAIL"
    print(f"  {module}: {pct:.1f}% lines ({covered}/{count}), gate {minimum}% — {status}")
sys.exit(1 if failed else 0)
PY
