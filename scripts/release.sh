#!/usr/bin/env bash
# Builds a Developer ID–signed, notarized, stapled Glint.app and DMG (ARCHITECTURE §13, F-14).
#
# Usage:
#   scripts/release.sh --dry-run            # everything except publishing (P0.T11)
#   scripts/release.sh --version 1.0.0      # full release build; publishing is done by .github/workflows/release.yml
#
# Requires (human-provided, PRD Q2): a "Developer ID Application" certificate in the keychain, and a notarytool
# keychain profile created once with:
#   xcrun notarytool store-credentials glint-notary --apple-id <id> --team-id <team> --password <app-password>
# Environment: GLINT_DEVELOPMENT_TEAM (required), NOTARY_PROFILE (default glint-notary).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
DRY_RUN=0
VERSION=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run) DRY_RUN=1 ;;
    --version) VERSION="$2"; shift ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
  shift
done

NOTARY_PROFILE="${NOTARY_PROFILE:-glint-notary}"
BUILD="$ROOT/build/release"
ARCHIVE="$BUILD/Glint.xcarchive"
EXPORT="$BUILD/export"
APP="$EXPORT/Glint.app"

step() { printf '\n▶ %s\n' "$1"; }
die() { echo "✗ $1" >&2; exit 1; }

step "Preflight"
[[ "$(uname -s)" == "Darwin" ]] || die "release builds need macOS"
[[ -n "${GLINT_DEVELOPMENT_TEAM:-}" ]] || die "set GLINT_DEVELOPMENT_TEAM (PRD Q2)"
security find-identity -v -p codesigning | grep -q "Developer ID Application" \
  || die "no 'Developer ID Application' certificate in the keychain"
command -v create-dmg >/dev/null || die "create-dmg missing (brew install create-dmg)"
xcrun notarytool history --keychain-profile "$NOTARY_PROFILE" >/dev/null 2>&1 \
  || die "notarytool profile '$NOTARY_PROFILE' missing (see header)"
FEED="$(grep -E '^GLINT_SPARKLE_FEED_URL' Config/Secrets.xcconfig 2>/dev/null | sed 's/.*= *//; s#:/$()/#://#')"
if [[ $DRY_RUN -eq 0 ]]; then
  [[ "$FEED" == https://* ]] || die "G-SEC-09: GLINT_SPARKLE_FEED_URL must be https:// for releases (got '${FEED:-unset}')"
fi
scripts/check-architecture.sh

step "Generate project"
export PATH="$ROOT/.tools/bin:$PATH"
xcodegen generate
rm -rf "$BUILD" && mkdir -p "$BUILD"

VERSION_ARGS=()
[[ -n "$VERSION" ]] && VERSION_ARGS+=("MARKETING_VERSION=$VERSION")
[[ -n "${GITHUB_RUN_NUMBER:-}" ]] && VERSION_ARGS+=("CURRENT_PROJECT_VERSION=$GITHUB_RUN_NUMBER")

step "Archive (Release)"
xcodebuild -project Glint.xcodeproj -scheme Glint -configuration Release \
  -destination 'generic/platform=macOS' -archivePath "$ARCHIVE" \
  DEVELOPMENT_TEAM="$GLINT_DEVELOPMENT_TEAM" "${VERSION_ARGS[@]+"${VERSION_ARGS[@]}"}" archive

step "Export (Developer ID)"
xcodebuild -exportArchive -archivePath "$ARCHIVE" -exportPath "$EXPORT" \
  -exportOptionsPlist Config/ExportOptions.plist

step "Verify signature and entitlements (G-SEC-07)"
codesign --verify --deep --strict --verbose=2 "$APP"
codesign -d --entitlements :- "$APP" 2>/dev/null > "$BUILD/entitlements.plist"
python3 -I - "$BUILD/entitlements.plist" Config/Glint.entitlements.expected <<'PY'
import plistlib, sys
actual, expected = (plistlib.load(open(p, "rb")) for p in sys.argv[1:3])
if actual != expected:
    sys.exit(f"entitlements differ: {actual} != {expected}")
PY

notarize() { # path
  local zip="$BUILD/notarize.zip" target="$1"
  if [[ "$target" == *.app ]]; then ditto -c -k --keepParent "$target" "$zip"; target="$zip"; fi
  xcrun notarytool submit "$target" --keychain-profile "$NOTARY_PROFILE" --wait
}

step "Notarize + staple app"
notarize "$APP"
xcrun stapler staple "$APP"

SHORT="$(defaults read "$APP/Contents/Info" CFBundleShortVersionString)"
DMG="$BUILD/Glint-$SHORT.dmg"
step "DMG"
create-dmg --volname "Glint" --window-size 540 380 --icon-size 128 \
  --icon "Glint.app" 140 190 --app-drop-link 400 190 --hide-extension "Glint.app" \
  "$DMG" "$APP"

step "Notarize + staple DMG"
notarize "$DMG"
xcrun stapler staple "$DMG"

step "Gatekeeper assessment (T-F14-AC1)"
spctl --assess --type execute -vv "$APP"
spctl --assess --type open --context context:primary-signature -vv "$DMG"

step "Sparkle archive"
ditto -c -k --keepParent "$APP" "$BUILD/Glint-$SHORT.zip"

if [[ $DRY_RUN -eq 1 ]]; then
  printf '\n✓ Dry run complete: %s\n  Not published (no appcast, release or tap update).\n' "$DMG"
else
  printf '\n✓ Release artifacts in %s. Publishing runs in .github/workflows/release.yml.\n' "$BUILD"
fi
