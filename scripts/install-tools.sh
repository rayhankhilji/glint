#!/usr/bin/env bash
# Installs the pinned developer tools into .tools/bin (ARCHITECTURE §2). Works on macOS and Linux (x86_64).
# Usage: scripts/install-tools.sh            # then: export PATH="$PWD/.tools/bin:$PATH"
set -euo pipefail

XCODEGEN_VERSION="2.46.0"
SWIFTLINT_VERSION="0.65.1"
SWIFTFORMAT_VERSION="0.63.1"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TOOLS="$ROOT/.tools"
BIN="$TOOLS/bin"
mkdir -p "$BIN"
OS="$(uname -s)"

fetch() { # url dest-dir
  local url="$1" dest="$2" tmp
  tmp="$(mktemp -d)"
  curl -sSfL --retry 3 -o "$tmp/a.zip" "$url"
  mkdir -p "$dest"
  unzip -qo "$tmp/a.zip" -d "$dest"
  rm -rf "$tmp"
}

installed() { [[ -f "$TOOLS/$1.version" && "$(cat "$TOOLS/$1.version")" == "$2" ]]; }

if ! installed swiftlint "$SWIFTLINT_VERSION"; then
  if [[ "$OS" == "Darwin" ]]; then asset="portable_swiftlint.zip"; else asset="swiftlint_linux_amd64.zip"; fi
  fetch "https://github.com/realm/SwiftLint/releases/download/$SWIFTLINT_VERSION/$asset" "$TOOLS/swiftlint"
  ln -sf "$TOOLS/swiftlint/swiftlint" "$BIN/swiftlint"
  chmod +x "$TOOLS/swiftlint/swiftlint"
  echo "$SWIFTLINT_VERSION" > "$TOOLS/swiftlint.version"
fi

if ! installed swiftformat "$SWIFTFORMAT_VERSION"; then
  if [[ "$OS" == "Darwin" ]]; then asset="swiftformat.zip"; bin="swiftformat"; else asset="swiftformat_linux.zip"; bin="swiftformat_linux"; fi
  fetch "https://github.com/nicklockwood/SwiftFormat/releases/download/$SWIFTFORMAT_VERSION/$asset" "$TOOLS/swiftformat"
  chmod +x "$TOOLS/swiftformat/$bin"
  ln -sf "$TOOLS/swiftformat/$bin" "$BIN/swiftformat"
  echo "$SWIFTFORMAT_VERSION" > "$TOOLS/swiftformat.version"
fi

if [[ "$OS" == "Darwin" ]] && ! installed xcodegen "$XCODEGEN_VERSION"; then
  fetch "https://github.com/yonaskolb/XcodeGen/releases/download/$XCODEGEN_VERSION/xcodegen.zip" "$TOOLS"
  ln -sf "$TOOLS/xcodegen/bin/xcodegen" "$BIN/xcodegen"
  echo "$XCODEGEN_VERSION" > "$TOOLS/xcodegen.version"
fi

echo "Tools installed in $BIN:"
"$BIN/swiftlint" version
"$BIN/swiftformat" --version
[[ "$OS" == "Darwin" ]] && "$BIN/xcodegen" --version
exit 0
