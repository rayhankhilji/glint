#!/usr/bin/env bash
# Enforces module boundaries (ARCHITECTURE §3) and the grep-checkable guardrails in EVAL_GUARDRAILS §2:
# G-SEC-01 (no pixel persistence), G-SEC-02 (no keyboard events), G-SEC-04 (actuation in one place),
# G-SEC-05 (network allowlist), G-SEC-07 (entitlements). Usage: scripts/check-architecture.sh [repo-root]
set -uo pipefail

ROOT="${1:-$(cd "$(dirname "$0")/.." && pwd)}"
cd "$ROOT" || exit 2
# GNU grep is required (Perl regexes, consistent \b/\s). On macOS: brew install grep (provides ggrep).
if grep --version 2>/dev/null | grep -q GNU; then GREP=grep
elif command -v ggrep >/dev/null; then GREP=ggrep
else echo "check-architecture: GNU grep required (brew install grep)" >&2; exit 2; fi

CORE="Packages/GlintCore/Sources"
KIT="Packages/GlintKit/Sources"
failures=0

fail() {
  echo "✗ $1"
  echo "$2" | sed 's/^/    /'
  failures=$((failures + 1))
}

# Swift files under the given paths (missing paths are skipped), excluding build output.
swift_files() {
  local p
  for p in "$@"; do
    [[ -e "$p" ]] && find "$p" -name '*.swift' -not -path '*/.build/*'
  done
}

# rule <description> <regex> <paths...> [-- <allowed-path-regex>]
rule() {
  local desc="$1" regex="$2"
  shift 2
  local paths=() allow=""
  while [[ $# -gt 0 ]]; do
    if [[ "$1" == "--" ]]; then allow="$2"; break; fi
    paths+=("$1")
    shift
  done
  local files hits
  files="$(swift_files "${paths[@]}")"
  [[ -z "$files" ]] && return 0
  # shellcheck disable=SC2086
  hits="$(echo "$files" | xargs "$GREP" -HnP "$regex" 2>/dev/null | "$GREP" -vP '^[^:]+:[0-9]+:\s*//' || true)"
  if [[ -n "$allow" && -n "$hits" ]]; then
    hits="$(echo "$hits" | "$GREP" -vP "^($allow)" || true)"
  fi
  [[ -n "$hits" ]] && fail "$desc" "$hits"
  return 0
}

# --- Module boundaries (ARCHITECTURE §3, ADR-004) ---------------------------------------------------------
APPLE_FRAMEWORKS='AppKit|AVFoundation|ApplicationServices|Vision|CoreML|CoreImage|CoreGraphics|CoreVideo|SwiftUI|Combine|os|OSLog|Accelerate|Network|Metal|UIKit|IOKit|ServiceManagement|Dispatch'
rule "GlintCore / GlintEval must import Foundation only (Linux-compatible, ADR-004)" \
  "^\s*(@testable\s+)?import\s+(${APPLE_FRAMEWORKS})\b" "$CORE"
rule "GlintCore must not read the wall clock (inject Clock)" \
  '\bDate\(\)|CACurrentMediaTime|ProcessInfo\.processInfo\.systemUptime|DispatchTime\.now' "$CORE/GlintCore"
rule "GlintCore must not do file or network I/O" \
  '\bFileManager\b|\.write\(to:|URLSession|contentsOf:' "$CORE/GlintCore"
rule "GlintUI must not call Accessibility, CGEvent or AVFoundation directly (views → models → services)" \
  '^\s*import\s+(ApplicationServices|AVFoundation)\b|AXUIElement|CGEvent\(|AVCapture' "$KIT/GlintUI"
rule "GlintRuntime must not import SwiftUI or AppKit (orchestration only)" \
  '^\s*import\s+(SwiftUI|AppKit)\b' "$KIT/GlintRuntime"
rule "The app target only wires: no AX or CGEvent calls" 'AXUIElement|CGEvent\(' App
rule "No @_exported imports" '@_exported\s+import' "$CORE" "$KIT" App

# --- G-SEC-01: camera pixels never leave the preprocessing function ---------------------------------------
rule "G-SEC-01: pixel-buffer access only in GlintPerception/FramePreprocessor.swift" \
  'CVPixelBufferGetBaseAddress|CVPixelBufferLockBaseAddress|CIImage\(|VTCreateCGImageFromCVPixelBuffer' \
  "$CORE" "$KIT" App -- "$KIT/GlintPerception/Camera/FramePreprocessor.swift"
rule "G-SEC-01: no image encoding or persistence outside UI rendering" \
  'jpegData|pngData|tiffRepresentation|representation\(using:|CGImageDestination|NSBitmapImageRep\(cgImage' \
  "$CORE" "$KIT/GlintPerception" "$KIT/GlintSystem" "$KIT/GlintServices" "$KIT/GlintRuntime" App

# --- G-SEC-02: never post keyboard events or read keystrokes ----------------------------------------------
rule "G-SEC-02: keyboard events are forbidden" \
  'keyboardEventSource|CGEvent\(keyboardEvent|matching:\s*\[?\s*\.keyDown|matching:\s*\[?\s*\.keyUp|kCGEventKeyDown|kCGEventKeyUp|\.flagsChanged' \
  "$CORE" "$KIT" App

# --- G-SEC-04: actuation in one place ---------------------------------------------------------------------
rule "G-SEC-04: only GlintSystem/Actuation may create or post CGEvents" \
  'CGEvent\(|\.post\(tap:|CGEventPost|\.postToPid' "$CORE" "$KIT" App -- "$KIT/GlintSystem/Actuation/"

# --- G-SEC-05: network allowlist --------------------------------------------------------------------------
rule "G-SEC-05: network APIs only in Telemetry, CrashReporter and the Sparkle updater" \
  'URLSession|URLRequest|NWConnection|^\s*import\s+Network\b|CFNetwork|NSURLConnection' \
  "$CORE" "$KIT" App -- "$KIT/GlintServices/Telemetry/|$KIT/GlintServices/CrashReporter/|App/Updater.swift"

# --- Hygiene ---------------------------------------------------------------------------------------------
rule "No print() in production code (use GlintLog)" '^\s*print\(' "$CORE" "$KIT" App \
  -- "$CORE/glint-eval/"
todo_files="$(swift_files "$CORE" "$KIT" App UITests Packages/GlintCore/Tests Packages/GlintKit/Tests)"
if [[ -n "$todo_files" ]]; then
  todo_hits="$(echo "$todo_files" | xargs "$GREP" -HnP '\b(TODO|FIXME)\b(?!\(BLK-[0-9]+\))' 2>/dev/null || true)"
  [[ -n "$todo_hits" ]] && fail "No TODO/FIXME without a blocker ID, e.g. TODO(BLK-3) (INSTRUCTIONS §6)" "$todo_hits"
fi
rule "Raw colors only in GlintUI/DesignSystem (use GlintColor tokens)" \
  'Color\(red:|Color\(hue:|Color\(white:|NSColor\(red:|NSColor\(srgbRed:|NSColor\(calibratedRed:|Color\(hex' \
  "$KIT/GlintUI" App -- "$KIT/GlintUI/DesignSystem/"

# --- G-SEC-07: entitlements -------------------------------------------------------------------------------
if [[ -f Config/Glint.entitlements && -f Config/Glint.entitlements.expected ]]; then
  if ! diff -q Config/Glint.entitlements Config/Glint.entitlements.expected >/dev/null; then
    fail "G-SEC-07: Config/Glint.entitlements differs from Glint.entitlements.expected (needs an ADR + human approval)" \
      "$(diff Config/Glint.entitlements.expected Config/Glint.entitlements)"
  fi
  if "$GREP" -q 'com.apple.security.app-sandbox\|disable-library-validation\|allow-jit\|allow-unsigned-executable-memory' Config/Glint.entitlements; then
    fail "G-SEC-07: forbidden entitlement present" "$("$GREP" -n 'com.apple.security' Config/Glint.entitlements)"
  fi
fi

if [[ $failures -gt 0 ]]; then
  echo
  echo "check-architecture: $failures rule(s) failed"
  exit 1
fi
echo "check-architecture: all rules passed"
