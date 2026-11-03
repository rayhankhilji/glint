#!/usr/bin/env bash
# Self-test for check-architecture.sh: a clean tree passes, and each planted violation fails (P0.T5 verify).
set -uo pipefail
SCRIPT="$(cd "$(dirname "$0")/.." && pwd)/check-architecture.sh"
pass=0; failed=0

make_tree() {
  local t; t="$(mktemp -d)"
  mkdir -p "$t/Config" "$t/Packages/SaccadeCore/Sources/SaccadeCore" "$t/Packages/SaccadeKit/Sources/SaccadeUI" \
    "$t/Packages/SaccadeKit/Sources/SaccadeSystem/Actuation" "$t/Packages/SaccadeKit/Sources/SaccadeServices/Telemetry" \
    "$t/Packages/SaccadeKit/Sources/SaccadeRuntime" "$t/App"
  printf 'import Foundation\npublic struct Ok {}\n' > "$t/Packages/SaccadeCore/Sources/SaccadeCore/Ok.swift"
  printf 'import CoreGraphics\nlet e = CGEvent(source: nil)\n' > "$t/Packages/SaccadeKit/Sources/SaccadeSystem/Actuation/ActuationService.swift"
  printf 'import Foundation\nlet s = URLSession.shared\n' > "$t/Packages/SaccadeKit/Sources/SaccadeServices/Telemetry/TelemetryClient.swift"
  printf '<plist><dict><key>com.apple.security.device.camera</key><true/></dict></plist>\n' > "$t/Config/Saccade.entitlements"
  cp "$t/Config/Saccade.entitlements" "$t/Config/Saccade.entitlements.expected"
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

K=Packages/SaccadeKit/Sources
expect "clean tree passes" 0 "" ""
expect "comment mentioning CGEvent( is fine" 0 "$K/SaccadeUI/Doc.swift" "// never call CGEvent( here"
expect "AppKit import in SaccadeCore" 1 "Packages/SaccadeCore/Sources/SaccadeCore/Bad.swift" "import AppKit"
expect "SwiftUI import in SaccadeCore" 1 "Packages/SaccadeCore/Sources/SaccadeCore/Bad.swift" "import SwiftUI"
expect "Date() in SaccadeCore" 1 "Packages/SaccadeCore/Sources/SaccadeCore/Bad.swift" "let now = Date()"
expect "FileManager in SaccadeCore" 1 "Packages/SaccadeCore/Sources/SaccadeCore/Bad.swift" "let fm = FileManager.default"
expect "AXUIElement in SaccadeUI" 1 "$K/SaccadeUI/Bad.swift" "let e: AXUIElement? = nil"
expect "SwiftUI in SaccadeRuntime" 1 "$K/SaccadeRuntime/Bad.swift" "import SwiftUI"
expect "pixel base address outside preprocessor" 1 "$K/SaccadePerception/Bad.swift" "CVPixelBufferLockBaseAddress(b, [])"
expect "pixel base address in preprocessor is allowed" 0 "$K/SaccadePerception/Camera/FramePreprocessor.swift" "CVPixelBufferLockBaseAddress(b, [])"
expect "image encoding in perception" 1 "$K/SaccadePerception/Bad.swift" "let d = rep.representation(using: .png, properties: [:])"
expect "keyboard event posting" 1 "$K/SaccadeSystem/Actuation/Bad.swift" "CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)"
expect "keyDown global monitor" 1 "$K/SaccadeSystem/Bad.swift" "NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { _ in }"
expect "CGEvent outside Actuation" 1 "$K/SaccadeSystem/Bad.swift" "let e = CGEvent(source: nil)"
expect "URLSession outside allowlist" 1 "$K/SaccadeRuntime/Bad.swift" "let s = URLSession.shared"
expect "print in production" 1 "$K/SaccadeServices/Bad.swift" "    print(\"hi\")"
expect "bare TODO" 1 "$K/SaccadeServices/Bad.swift" "// TODO: later"
expect "TODO with blocker id is allowed" 0 "$K/SaccadeServices/Ok2.swift" "// TODO(BLK-3): waiting on Q2"
expect "raw color outside DesignSystem" 1 "$K/SaccadeUI/Bad.swift" "let c = Color(red: 1, green: 0, blue: 0)"
expect "raw color in DesignSystem is allowed" 0 "$K/SaccadeUI/DesignSystem/SaccadeColor.swift" "let c = Color(red: 1, green: 0, blue: 0)"
expect "gradient in SaccadeUI" 1 "$K/SaccadeUI/Bad.swift" "let g = LinearGradient(colors: [], startPoint: .top, endPoint: .bottom)"
expect "blur glow in SaccadeUI" 1 "$K/SaccadeUI/Bad.swift" "view.blur(radius: 10)"
expect "SF Symbol literal outside SaccadeSymbol" 1 "$K/SaccadeUI/Bad.swift" "Image(systemName: \"star\")"
expect "@_exported import" 1 "App/Bad.swift" "@_exported import Foundation"
expect "entitlement drift" 1 "Config/Saccade.entitlements" "<plist><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>"

echo "check-architecture self-test: $pass passed, $failed failed"
[[ $failed -eq 0 ]]
