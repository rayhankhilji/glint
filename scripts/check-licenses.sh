#!/usr/bin/env bash
# Fails if any resolved SwiftPM dependency is missing from scripts/licenses.allowlist or has a license
# outside MIT / Apache-2.0 / BSD (G-SEC-12). Usage: scripts/check-licenses.sh [repo-root]
set -euo pipefail
ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
ALLOWLIST="${ALLOWLIST:-$(cd "$(dirname "$0")" && pwd)/licenses.allowlist}"
python3 -I - "$ROOT" "$ALLOWLIST" <<'PY'
import json, pathlib, sys
root, allowlist = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
ok_licenses = {"MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"}
allowed = {}
for line in allowlist.read_text().splitlines():
    line = line.split("#", 1)[0].strip()
    if line:
        identity, license_ = line.split()[:2]
        allowed[identity.lower()] = license_
resolved = [p for p in root.rglob("Package.resolved") if ".build" not in p.parts and ".tools" not in p.parts]
errors, seen = [], set()
for path in resolved:
    pins = json.loads(path.read_text()).get("pins", [])
    for pin in pins:
        identity = pin["identity"].lower()
        seen.add(identity)
        license_ = allowed.get(identity)
        if license_ is None:
            errors.append(f"{path.relative_to(root)}: '{identity}' is not in licenses.allowlist (needs an ADR)")
        elif license_ not in ok_licenses:
            errors.append(f"{path.relative_to(root)}: '{identity}' has disallowed license {license_}")
for e in errors:
    print("✗", e)
print(f"check-licenses: {len(seen)} dependencies in {len(resolved)} Package.resolved file(s), {len(errors)} problem(s)")
sys.exit(1 if errors else 0)
PY
