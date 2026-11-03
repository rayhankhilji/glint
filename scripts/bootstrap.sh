#!/usr/bin/env bash
# First-time setup on a dev Mac (INSTRUCTIONS §5). Idempotent.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "bootstrap.sh sets up the full macOS app. On Linux, run: swift test --package-path Packages/SaccadeCore" >&2
  exit 1
fi

if ! command -v brew >/dev/null; then
  echo "Homebrew is required: https://brew.sh" >&2
  exit 1
fi
brew list git-lfs >/dev/null 2>&1 || brew install git-lfs
brew list uv >/dev/null 2>&1 || brew install uv
brew list create-dmg >/dev/null 2>&1 || brew install create-dmg
brew list grep >/dev/null 2>&1 || brew install grep   # GNU grep for check-architecture.sh

git lfs install --local
git lfs pull

scripts/install-tools.sh
export PATH="$ROOT/.tools/bin:$PATH"

if [[ ! -f Config/Secrets.xcconfig ]]; then
  cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig
  echo "Created Config/Secrets.xcconfig from the example (fake values; fine for local Debug builds)."
fi

xcodegen generate
echo
echo "Done. Add the pinned tools to your shell: export PATH=\"$ROOT/.tools/bin:\$PATH\""
echo "Then: open Saccade.xcodeproj"
