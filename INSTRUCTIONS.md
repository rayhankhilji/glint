# Agent Instructions — Glint

> Version: 1.0 · Updated: 2026-11-03. You are building Glint, a native macOS app. Read this whole file at the start of every session.

## 0. Read Order

1. This file.
2. `TASK_LOG.md`: current state, current task, blockers.
3. `ROADMAP.md`: the current phase, its tasks and exit criteria.
4. `PRD.md` and `ARCHITECTURE.md`: only the sections your task references (feature IDs `F-xx`, sections `§n`).
5. `DESIGN_SYSTEM.md` before touching anything in `GlintUI` or any visible behavior (glint, motion, copy).
6. `EVAL_GUARDRAILS.md` before marking anything done (Definition of Done, G-* rules, thresholds).
7. `TESTING_GUIDE.md` when writing or running tests.

## 1. Mission

Build Glint, a menu-bar app that reads intent from a webcam: a glint snaps to what you're looking at, a double blink clicks it, and the page glides when you reach the bottom. Everything runs on-device. The bar is "it feels like magic and never does something I didn't mean". **When unsure, do nothing.** A missed action is a small annoyance; an unintended click destroys trust.

## 2. Operating Loop

For every task:

1. Open `TASK_LOG.md`, pick the next unchecked task in the current phase, and mark it `[~]` with today's date.
2. Restate the task, the acceptance criteria it covers (`F-xx.ACn`), and the test IDs (`T-Fxx-ACn`) it must make green.
3. Plan briefly: files to touch, protocols/models affected (ARCHITECTURE §4–§5), and the module boundaries involved (§3).
4. Write the test first when the logic is in GlintCore (pure). For UI or system code, write the test alongside.
5. Implement in small commits (one logical change each).
6. Run the fast loop (TESTING_GUIDE §8): format → lint → `GlintCore` tests → affected package tests → affected app tests → `glint-eval --check` if you touched perception or intent.
7. Check the task-level Definition of Done (EVAL_GUARDRAILS §1).
8. Update `TASK_LOG.md`: mark `[x]`, list the tests, add notes and the next action. Commit.

Never start the next phase until the current phase's exit criteria in `ROADMAP.md` pass and are recorded in `TASK_LOG.md` → Completed Phases.

## 3. Tech Stack (locked)

| Layer | Choice |
|---|---|
| Language | Swift 6.4 toolchain, Swift 6 language mode, strict concurrency complete |
| Toolchain | Xcode 27.1+, macOS 14.0 deployment target, arm64 only |
| UI | SwiftUI (+ AppKit only for `NSPanel`, `NSStatusItem` geometry, window levels) |
| Camera | AVFoundation |
| Landmarks | MediaPipe Face Landmarker models via ONNX Runtime 1.24.2 (Core ML EP); Apple Vision fallback |
| Global hotkey | KeyboardShortcuts 3.1.0 |
| Updates | Sparkle 2.10.0 |
| Opt-in metrics / crashes | TelemetryDeck SwiftSDK 2.14.2 / Sentry Cocoa 9.30.2 |
| Tests | Swift Testing, XCTest/XCUITest, swift-snapshot-testing 1.19.6 |
| Lint/format | SwiftLint 0.65.1 (strict), SwiftFormat 0.63.1 |
| Project | XcodeGen 2.46.0 (`project.yml`), local SwiftPM packages |
| Scripts | bash (`set -euo pipefail`), Python 3.12 via `uv` for model conversion only |

Do not introduce new frameworks, libraries, SPM packages, or services without recording an ADR in `ARCHITECTURE.md` §16 and noting it in `TASK_LOG.md` → Decisions. Versions are in ARCHITECTURE §2.

## 4. Repository Structure

```text
glint/
├── CLAUDE.md, AGENTS.md            # pointers → this file
├── INSTRUCTIONS.md PRD.md ARCHITECTURE.md ROADMAP.md TASK_LOG.md
├── TESTING_GUIDE.md DESIGN_SYSTEM.md EVAL_GUARDRAILS.md
├── project.yml                     # XcodeGen source of truth (never commit *.xcodeproj)
├── Config/
│   ├── Base.xcconfig Debug.xcconfig Release.xcconfig
│   ├── Secrets.example.xcconfig    # committed fake values; copy to Secrets.xcconfig (gitignored)
│   ├── Info.plist                  # LSUIElement, usage strings, Sparkle keys via $(VARS)
│   ├── ExportOptions.plist         # Developer ID export
│   └── Glint.entitlements(.expected)  # camera only; .expected guards drift (G-SEC-07)
├── App/                            # app target = composition root ONLY
│   ├── GlintApp.swift              # @main, MenuBarExtra, Settings scene
│   ├── AppEnvironment.swift        # builds the object graph
│   ├── Updater.swift               # Sparkle wrapper
│   └── Resources/ Assets.xcassets Localizable.xcstrings Shaders/*.metal
├── Packages/
│   ├── GlintCore/                  # cross-platform (macOS + Linux), Foundation only
│   │   ├── Package.swift
│   │   ├── Sources/GlintCore/{Geometry,Features,Mapping,Filters,Events,Calibration,Intent,Settings,Telemetry,Trace,Errors}/
│   │   ├── Sources/GlintCoreTestSupport/   # fixtures, SyntheticEye, ManualClock helpers (test-only)
│   │   ├── Sources/GlintEval/ Sources/glint-eval/   # eval library + thin CLI
│   │   └── Tests/GlintCoreTests/ Tests/GlintEvalTests/
│   └── GlintKit/                   # macOS only
│       ├── Package.swift
│       ├── Sources/{GlintPlatform,GlintPerception,GlintSystem,GlintServices,GlintUI,GlintRuntime}/
│       └── Tests/{GlintPlatformTests,GlintServicesTests,GlintUITests,GlintRuntimeTests,…}/   # GlintUITests = snapshot tests
├── UITests/                        # XCUITest target (onboarding, settings) using GLINT_FAKE_CAMERA
├── Design/                         # tokens.json, Icons/mark.svg, MenuBar/, AppIcon/, Motion/ (animated SVG motion spec)
├── Models/                         # *.onnx via Git LFS + checksums.sha256
├── Evals/
│   ├── datasets/ci/                # small (≤ 20 MB) traces used in CI
│   ├── datasets/v1/                # full eval set (LFS)
│   └── reports/                    # generated; only `baseline.json` is committed
├── scripts/
│   ├── bootstrap.sh install-tools.sh check-architecture.sh check-licenses.sh licenses.allowlist coverage.sh
│   ├── contrast.py release.sh (perf.sh P1.T10, rollback.sh P6.T7)
│   ├── tests/                      # self-tests for the guard scripts
│   └── models/{manifest.json,fetch_and_convert.py}
├── .github/workflows/{ci.yml,release.yml}
└── docs/archive/                   # archived TASK_LOG sections
```

Rules:

- Files: `PascalCase.swift`, one primary type per file, named after the type. Tests: `<Type>Tests.swift`. Snapshot references live next to their tests in `__Snapshots__/`.
- Put logic in the lowest module that can hold it. Thresholds and state machines go in GlintCore; anything that calls Apple frameworks goes in GlintKit modules; orchestration actors go in GlintRuntime; the app target only wires.
- All thresholds go in `GlintCore/Intent/IntentConstants.swift` or the relevant `Settings` default, never as inline literals in logic.
- Design tokens live only in `GlintUI/DesignSystem/` (`GlintColor`, `GlintFont`, `GlintSpacing`, `GlintRadius`, `GlintMotion`, `GlintShadow`).
- No barrel files or `@_exported import`.
- Logging, signposts, the production clock and storage paths come from `GlintPlatform` (ADR-010).
- User-facing strings go in `Localizable.xcstrings` via `String(localized:)`, never as raw literals in views.

## 5. Commands

Run from the repo root. First-time setup:

```bash
scripts/bootstrap.sh
```

`bootstrap.sh` installs git-lfs, uv, create-dmg and GNU grep with Homebrew, pulls LFS files, installs the pinned XcodeGen/SwiftLint/SwiftFormat into `.tools/bin` (`scripts/install-tools.sh`; add it to `PATH`), copies `Config/Secrets.example.xcconfig` to `Config/Secrets.xcconfig` if it's missing, and runs `xcodegen generate`. On Linux, run `scripts/install-tools.sh` only (SwiftLint + SwiftFormat).

| Purpose | Command |
|---|---|
| Generate Xcode project | `xcodegen generate` |
| Build core (macOS or Linux) | `swift build --package-path Packages/GlintCore` |
| Test core (macOS or Linux) | `swift test --package-path Packages/GlintCore` |
| Test one core suite | `swift test --package-path Packages/GlintCore --filter BlinkGrammarTests` |
| Test GlintKit (macOS, unit + snapshot) | `swift test --package-path Packages/GlintKit` |
| Build app | `xcodebuild -project Glint.xcodeproj -scheme Glint -configuration Debug -destination 'platform=macOS,arch=arm64' build` |
| Test app (build + UI tests) | `xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'platform=macOS,arch=arm64' test` |
| UI tests only | `xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'platform=macOS,arch=arm64' test -only-testing:GlintUITestsApp` |
| Record snapshots | `SNAPSHOT_RECORD=1 swift test --package-path Packages/GlintKit --filter GlintUITests` |
| Lint | `swiftlint --strict` |
| Format | `swiftformat .` |
| Format check | `swiftformat --lint .` |
| Architecture check (needs GNU grep) | `scripts/check-architecture.sh` (self-test: `scripts/tests/check-architecture.test.sh`) |
| License check | `scripts/check-licenses.sh` |
| Contrast check | `python3 -I scripts/contrast.py` |
| Coverage gate | `swift test --package-path Packages/GlintCore --enable-code-coverage && scripts/coverage.sh core` |
| Build + install the app locally (Mac) | `scripts/build-app.sh --install --open` |
| Compile color tokens | `python3 scripts/design/build_tokens.py` (CI: `--check`) |
| Compile brand artwork from SVG | `python3 scripts/icons/build_icons.py` (CI: `--check`) |
| Icon converter tests | `python3 -m unittest discover -s scripts/tests -p 'test_*.py'` |
| Regenerate motion studies | `python3 scripts/icons/author_motion.py` |
| Rasterize app icon | `node scripts/icons/render-app-icon.mjs` (dev-only; Node + Playwright) |
| Install pinned tools | `scripts/install-tools.sh` then `export PATH="$PWD/.tools/bin:$PATH"` |
| Eval gate (CI set) | `swift run --package-path Packages/GlintCore glint-eval --dataset Evals/datasets/ci --check` |
| Full eval report | `swift run --package-path Packages/GlintCore -c release glint-eval --dataset Evals/datasets/v1 --report Evals/reports/latest.md` |
| Fetch/convert models | `uv run scripts/models/fetch_and_convert.py` |
| Run app from CLI | `open build/Debug/Glint.app` after building with `-derivedDataPath build` |
| Release dry run | `scripts/release.sh --dry-run` |

Run `xcodegen generate` again after adding files to `App/` or changing `project.yml`. Packages pick up files automatically.

## 6. Coding Standards

- **Concurrency:** Swift 6 strict. Long-lived services are `actor`s; UI models are `@MainActor @Observable final class`. Data crossing actors is `Sendable`. No `@unchecked Sendable` without a comment explaining the invariant. No `DispatchQueue.main.async` in new code (use `@MainActor`). No `Task.detached` except in `GazePipeline` for inference.
- **No floating tasks:** every `Task {}` is stored and cancelled on teardown, or is structured (`async let`, task groups).
- **Typing:** no force unwraps (`!`) or `try!` outside tests. `as!` only for CF bridging, with a comment. No `Any`/`AnyObject` in public APIs.
- **Errors:** throw `GlintError` (typed throws `throws(GlintError)`) across module boundaries. Never swallow errors with an empty `catch {}`; at minimum, log the code at `.public` and count it in diagnostics.
- **Time:** GlintCore never calls `Date()` or `CACurrentMediaTime()`. Inject a `Clock`.
- **Purity:** GlintCore state machines are `struct`s with `mutating func step(...)`, explicit `enum State`, and no side effects. Side effects happen in GlintKit/App by executing returned `IntentAction`s.
- **Hot path:** no allocation per frame in feature extraction, mapping, or filters. Use pre-sized `ContiguousArray` buffers. No logging per frame above `.debug`.
- **Validation:** decoded JSON passes through `Settings.validated()` / `CalibrationProfile.validated()`, which clamp to the documented ranges.
- **Comments:** explain *why* (especially magic thresholds, with the PRD/ARCH reference). No commented-out code. No `TODO` without a TASK_LOG blocker ID.
- **Size:** files ≤ ~300 lines, functions ≤ ~40 lines; split by responsibility.
- **Access control:** `internal` by default; `public` only for cross-module API listed in ARCHITECTURE §5.

Do — pure, injectable, testable:

```swift
public struct ScrollZoneMachine {
  public enum State: Equatable { case idle, dwelling(since: TimeInterval), cooldown(until: TimeInterval) }
  public private(set) var state: State = .idle
  public mutating func step(fixation: Fixation?, area: ScrollAreaInfo?, now: TimeInterval,
                            lastManualScroll: TimeInterval?, settings: ScrollSettings) -> IntentAction? { /* … */ }
}
```

Don't — side effects and wall clock inside logic:

```swift
func checkScroll() {
  if gaze.y > NSScreen.main!.frame.height * 0.85 {          // AppKit in logic, force unwrap, inline threshold
    CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1, wheel1: -40, wheel2: 0, wheel3: 0)!
      .post(tap: .cghidEventTap)                             // side effect inside the decision
  }
}
```

## 7. Frontend Rules (GlintUI)

- Use tokens from `GlintUI/DesignSystem` only: no raw `Color(red:…)`, hex, numeric font sizes, or ad-hoc animation durations. Add a token (DESIGN_SYSTEM §13) if one is missing.
- Icons: UI icons are SF Symbols, declared once in `GlintSymbol` and drawn with `GlintSymbolImage`. The brand mark and menu bar glyphs are SVGs in `Design/` compiled with `python3 scripts/icons/build_icons.py`; never edit generated `GlintIconData.swift` or `GlintColorTokens.swift` by hand.
- Colors: add or change them only in `Design/tokens.json`, then run `python3 scripts/design/build_tokens.py` and `python3 scripts/contrast.py`.
- No decorative gradients, glows or blur (`LinearGradient`, `RadialGradient`, `.blur(radius:)`, …): light is crisp geometry. `scripts/check-architecture.sh` enforces this.
- Glass: always use `GlassSurface` (wraps `glassEffect()` on macOS 26+, material fallback on 14–15). Never call `.glassEffect` directly in feature views.
- Every screen implements every state in DESIGN_SYSTEM §9 and PRD (`States:`), including permission-denied, not-calibrated, and camera-missing.
- Motion: use the `GlintMotion` presets. Respect `accessibilityReduceMotion`, `accessibilityDifferentiateWithoutColor`, `accessibilityReduceTransparency`, and Increase Contrast. Each animated view has a reduced-motion branch.
- The overlay is render-only: no gestures, no `onTapGesture`, never key, `sharingType = .none`, and excluded from the AX tree.
- Coordinates: convert with `ScreenGeometry` only (global top-left ↔ AppKit bottom-left). Hand-rolled `frame.height - y` math is a bug.
- Views talk only to their `@Observable` model. Models call services through protocols (ARCHITECTURE §5). Views never call AX, CGEvent, or AVFoundation.
- Every interactive control has an accessibility label, a visible focus ring, and a hit area ≥ 28 pt.

## 8. System & Perception Rules (GlintPerception, GlintSystem, GlintServices)

- **Camera frames:** never copy a `CVPixelBuffer` into `Data`/`CGImage`/`NSImage`, never write one to disk, never keep one beyond the current inference call (G-SEC-01). The Eval Arena records landmarks only.
- **AX:** call it only from `AXService` on its own executor. Set `AXUIElementSetMessagingTimeout(…, 0.05)` on every app element. Skip `AXSecureTextField` and elements in excluded apps. Never log AX strings above `.private`.
- **Actuation:** only `ActuationService` posts events. Allowed: left/right mouse click, pixel scroll-wheel, `AXPress`, `AXShowMenu`, `AXRaise`, `NSRunningApplication.activate`. Every posted CGEvent carries `GLINT_EVENT_TAG` in `eventSourceUserData`. **Never post keyboard events.**
- **Network:** only `TelemetryClient`, `CrashReporter`, and Sparkle may touch the network. `scripts/check-architecture.sh` fails on `URLSession`, `NWConnection`, or `Network` imports elsewhere.
- **Consent:** TelemetryDeck and Sentry are initialized only after `MetricsConsent.state == .optedIn` and are torn down on opt-out.
- **Fail safe:** if confidence < 0.6, permissions are missing, or the app is excluded, the IntentEngine emits no actions. Do not add "best effort" actions.
- **Persistence:** only through `SettingsStore`/`ProfileStore`/`MetricsQueue`, with atomic writes and schema versions. Never edit a shipped migration step; add a new one.

## 9. Prohibited

| Don't use | Use instead | Why |
|---|---|---|
| Electron, Tauri, Catalyst, React Native | SwiftUI/AppKit | ADR-001 |
| RxSwift, Combine in new code | Swift Concurrency (`AsyncStream`, actors) | One concurrency model |
| Alamofire / any HTTP client | (none needed) SDKs only | Network allowlist |
| Realm, Core Data, SwiftData, GRDB | Codable JSON stores | ADR-007 |
| OpenCV, dlib, full MediaPipe C++ graph | ORT + MediaPipe models, Vision | Size, build complexity |
| Firebase, Mixpanel, Amplitude, PostHog | TelemetryDeck (opt-in) | Privacy promise |
| Third-party UI kits | SwiftUI + our tokens | Distinctive, native look |
| `Accelerate` in GlintCore | hand-written linear algebra | Linux compatibility (ADR-004) |

Prohibited practices:

- Storing, transmitting, or screenshotting camera frames, even "temporarily for debugging".
- Posting keyboard events, reading keystroke contents, requesting Input Monitoring.
- Logging window titles, AX labels/values, or URLs at `.public`.
- Editing `*.xcodeproj` by hand or committing it; editing shipped migration steps or `Models/checksums.sha256` without re-running the conversion script.
- Disabling SwiftLint rules inline without a `// swiftlint:disable:next <rule> — <reason>` comment.
- Lowering eval thresholds, skipping or deleting tests, or adding `.disabled` traits to make CI pass.
- Mocking the unit under test; mocks are only for protocols at module boundaries.
- Broad `catch {}` that swallows errors; `fatalError` outside truly impossible states.
- Shipping placeholder UI (lorem, gray boxes, unstyled system defaults) as done.
- Building anything in PRD §6 Out of Scope (multi-monitor, gaze typing, dwell click, browser extension, LLM features, accounts…).
- Adding entitlements beyond `com.apple.security.device.camera` without an ADR.

## 10. When Stuck

After **2 failed attempts** at the same problem:

1. Stop. Write a blocker row in `TASK_LOG.md` → Blockers: what you tried, exact error output (trimmed), hypotheses, what you need.
2. Mark the task `[!]` and move to the next unblocked task in the phase, or ask the human if none is unblocked.
3. Never silently change requirements, thresholds, architecture, or the stack to get unstuck.

Known traps:

- **TCC permission prompts in tests:** UI tests and unit tests must not require real Camera or Accessibility permissions. Use `GLINT_FAKE_CAMERA` and the `AXServicing` fakes. Real-permission checks are manual (TESTING_GUIDE §10).
- **Accessibility trust resets** after re-signing a debug build with a different identity. Use a stable "Apple Development" signing identity locally, or remove and re-add Glint in System Settings → Privacy & Security → Accessibility.
- **Linux builds:** if `swift test --package-path Packages/GlintCore` fails only on Linux, you've imported a Darwin-only API in GlintCore. Move that code to GlintKit.

## 11. Git & Commits

- Work on the branch the human specifies; otherwise use `feat/<phase>-<short-name>` (e.g. `feat/p1-blink-detector`).
- Conventional Commits: `feat(core): add BlinkGrammar double-blink detection (F-06)`, `fix(ax): honor 50ms messaging timeout`, `test(eval): …`, `docs: …`, `chore: …`.
- One task = one or more focused commits; reference the task ID in the body (`Refs: P1.T5`).
- PR description: Summary · Task IDs + AC/test IDs · What changed · Why · Testing performed (exact commands + results) · Screenshots/GIFs for UI (overlay recordings must use the Eval Arena, not real apps showing private content).

## 12. Human Escalation

Ask the human before:

- Adding a paid service, a new third-party SDK, or a new entitlement or permission.
- Changing a privacy guarantee (G-SEC-01…05), the telemetry schema, or the default of any consent-related setting.
- Changing a PRD acceptance threshold, an eval threshold, or a default gesture/timing that users will feel.
- Changing the persisted file formats in a way that requires a migration.
- Code signing, notarization, Apple Developer account actions, publishing a release, or pushing to the Homebrew tap.
- When acceptance criteria are ambiguous or contradict each other or the architecture.
- Recording eval data from anyone: participants must give explicit written consent (TESTING_GUIDE §4).
