#!/usr/bin/env bash
# Builds Glint.app from source on your Mac, ad-hoc signed for local use (no Apple Developer account needed).
#
#   scripts/build-app.sh            # build → build/Glint.app
#   scripts/build-app.sh --install  # …and copy to /Applications (or ~/Applications)
#   scripts/build-app.sh --open     # …and launch it (look for the ring in the menu bar)
#   scripts/build-app.sh --dmg      # …and make build/Glint.dmg to share
#
# Requires a Mac (Apple Silicon or Intel) with Xcode 26 or newer. Signed + notarized releases use scripts/release.sh.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
INSTALL=0; OPEN=0; DMG=0
for arg in "$@"; do
  case "$arg" in
    --install) INSTALL=1 ;;
    --open) OPEN=1 ;;
    --dmg) DMG=1 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "unknown option: $arg (see --help)" >&2; exit 2 ;;
  esac
done

say() { printf '\033[1m▸ %s\033[0m\n' "$1"; }
fail() { printf '\033[31m✗ %s\033[0m\n' "$1" >&2; exit 1; }

say "Checking your Mac"
[[ "$(uname -s)" == "Darwin" ]] || fail "This builds a macOS app; run it on a Mac."
DEV_DIR="$(xcode-select -p 2>/dev/null || true)"
if [[ "$DEV_DIR" != *".app/Contents/Developer" ]]; then
  fail "Xcode isn't selected. Install Xcode from the App Store, then run: sudo xcode-select -s /Applications/Xcode.app"
fi
XCODE_MAJOR="$(xcodebuild -version | awk 'NR==1 {split($2, v, "."); print v[1]}')"
[[ "${XCODE_MAJOR:-0}" -ge 26 ]] || fail "Xcode 26 or newer is required (found $(xcodebuild -version | head -1))."
xcodebuild -checkFirstLaunchStatus >/dev/null 2>&1 || fail "Finish Xcode's first-launch setup: sudo xcodebuild -runFirstLaunch"
echo "  $(sw_vers -productName) $(sw_vers -productVersion) · $(xcodebuild -version | head -1)"

say "Installing pinned build tools into .tools/"
scripts/install-tools.sh >/dev/null
export PATH="$ROOT/.tools/bin:$PATH"

[[ -f Config/Secrets.xcconfig ]] || cp Config/Secrets.example.xcconfig Config/Secrets.xcconfig

say "Generating the Xcode project"
xcodegen generate --quiet

say "Building Glint (Release, ad-hoc signed) — the first build fetches Swift packages and takes a few minutes"
LOG="$ROOT/build/build.log"
mkdir -p build
if ! xcodebuild -project Glint.xcodeproj -scheme Glint -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath build/DerivedData \
    CODE_SIGN_IDENTITY=- CODE_SIGN_STYLE=Manual DEVELOPMENT_TEAM= OTHER_CODE_SIGN_FLAGS= \
    ENABLE_HARDENED_RUNTIME=NO build >"$LOG" 2>&1; then
  echo
  grep -E "error:|fatal error|BUILD FAILED" "$LOG" | head -20 || true
  fail "Build failed. The full log is $LOG — paste its last 40 lines (tail -40 \"$LOG\") to Claude."
fi

rm -rf build/Glint.app
ditto build/DerivedData/Build/Products/Release/Glint.app build/Glint.app
echo "  Built $ROOT/build/Glint.app"

APP="$ROOT/build/Glint.app"
if [[ $INSTALL -eq 1 ]]; then
  say "Installing"
  DEST="/Applications"
  [[ -w "$DEST" ]] || DEST="$HOME/Applications"
  mkdir -p "$DEST"
  osascript -e 'quit app "Glint"' >/dev/null 2>&1 || true
  rm -rf "$DEST/Glint.app"
  ditto "$APP" "$DEST/Glint.app"
  APP="$DEST/Glint.app"
  echo "  Installed $APP"
fi

if [[ $DMG -eq 1 ]]; then
  say "Making a disk image"
  STAGE="$(mktemp -d)"
  ditto "$ROOT/build/Glint.app" "$STAGE/Glint.app"
  ln -s /Applications "$STAGE/Applications"
  hdiutil create -volname Glint -srcfolder "$STAGE" -ov -format UDZO "$ROOT/build/Glint.dmg" >/dev/null
  rm -rf "$STAGE"
  echo "  Created $ROOT/build/Glint.dmg (unsigned: other Macs need right-click → Open the first time)"
fi

if [[ $OPEN -eq 1 ]]; then
  say "Launching"
  open "$APP"
  echo "  Glint runs in the menu bar (the ring icon, top right). It has no Dock icon."
fi
