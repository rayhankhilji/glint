#!/usr/bin/env bash
# Self-test for check-architecture.sh: a clean tree passes, and each planted violation fails (P0.T5 verify).
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-architecture.sh"
pass=0; failed=0

make_tree() {
  local t; t="$(mktemp -d)"
  mkdir -p "$t/Config" "$t/Packages/GlintCore/Sources/GlintCore" "$t/Packages/GlintKit/Sources/GlintUI" \
    "$t/Packages/GlintKit/Sources/GlintSystem/Actuation" "$t/Packages/GlintKit/Sources/GlintServices/Telemetry" \
    "$t/Packages/GlintKit/Sources/GlintRuntime" "$t/App"
  printf 'import Foundation\npublic struct Ok {}\n' > "$t/Packages/GlintCore/Sources/GlintCore/Ok.swift"
  printf 'import CoreGraphics\nlet e = CGEvent(source: nil)\n' > "$t/Packages/GlintKit/Sources/GlintSystem/Actuation/ActuationService.swift"
  printf 'import Foundation\nlet s = URLSession.shared\n' > "$t/Packages/GlintKit/Sources/GlintServices/Telemetry/TelemetryClient.swift"
  printf '<plist><dict><key>com.apple.security.device.camera</key><true/></dict></plist>\n' > "$t/Config/Glint.entitlements"
  cp "$t/Config/Glint.entitlements" "$t/Config/Glint.entitlements.expected"
  echo "$t"
}

expect() { # expect <name> <expected-exit> <file-relative-path> <content>
  local name="$1" want="$2" rel="$3" content="$4" t got
  t="$(make_tree)"
  if [[ -n "$rel" ]]; then mkdir -p "$(dirname "$t/$rel")"; printf '%b\n' "$content" > "$t/$rel"; fi
  "$SCRIPT" "$t" >/dev/null 2>&1; got=$?
  if [[ "$got" == "$want" ]]; then pass=$((pass + 1)); else failed=$((failed + 1)); echo "FAIL: $name (exit $got, want $want)"; fi
  rm -rf "$t"
}

K=Packages/GlintKit/Sources
expect "clean tree passes" 0 "" ""
expect "comment mentioning CGEvent( is fine" 0 "$K/GlintUI/Doc.swift" "// never call CGEvent( here"
expect "AppKit import in GlintCore" 1 "Packages/GlintCore/Sources/GlintCore/Bad.swift" "import AppKit"
expect "SwiftUI import in GlintCore" 1 "Packages/GlintCore/Sources/GlintCore/Bad.swift" "import SwiftUI"
expect "Date() in GlintCore" 1 "Packages/GlintCore/Sources/GlintCore/Bad.swift" "let now = Date()"
expect "FileManager in GlintCore" 1 "Packages/GlintCore/Sources/GlintCore/Bad.swift" "let fm = FileManager.default"
expect "AXUIElement in GlintUI" 1 "$K/GlintUI/Bad.swift" "let e: AXUIElement? = nil"
expect "SwiftUI in GlintRuntime" 1 "$K/GlintRuntime/Bad.swift" "import SwiftUI"
expect "pixel base address outside preprocessor" 1 "$K/GlintPerception/Bad.swift" "CVPixelBufferLockBaseAddress(b, [])"
expect "pixel base address in preprocessor is allowed" 0 "$K/GlintPerception/Camera/FramePreprocessor.swift" "CVPixelBufferLockBaseAddress(b, [])"
expect "image encoding in perception" 1 "$K/GlintPerception/Bad.swift" "let d = rep.representation(using: .png, properties: [:])"
expect "keyboard event posting" 1 "$K/GlintSystem/Actuation/Bad.swift" "CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)"
expect "keyDown global monitor" 1 "$K/GlintSystem/Bad.swift" "NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }"
expect "CGEvent outside Actuation" 1 "$K/GlintSystem/Bad.swift" "let e = CGEvent(source: nil)"
expect "URLSession outside allowlist" 1 "$K/GlintRuntime/Bad.swift" "let s = URLSession.shared"
expect "print in production" 1 "$K/GlintServices/Bad.swift" "    print(\"hi\")"
expect "bare TODO" 1 "$K/GlintServices/Bad.swift" "// TODO: later"
expect "TODO with blocker id is allowed" 0 "$K/GlintServices/Ok2.swift" "// TODO(BLK-3): waiting on Q2"
expect "raw color outside DesignSystem" 1 "$K/GlintUI/Bad.swift" "let c = Color(red: 1, green: 0, blue: 0)"
expect "raw color in DesignSystem is allowed" 0 "$K/GlintUI/DesignSystem/GlintColor.swift" "let c = Color(red: 1, green: 0, blue: 0)"
expect "@_exported import" 1 "App/Bad.swift" "@_exported import Foundation"
expect "entitlement drift" 1 "Config/Glint.entitlements" "<plist><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>"

echo "check-architecture self-test: $pass passed, $failed failed"
[[ $failed -eq 0 ]]
