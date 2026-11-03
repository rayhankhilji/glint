# Glint — Testing Guide

> Version: 1.0 · Updated: 2026-11-03 · Every command here is copy-pasteable from the repo root. If one stops working, fix the command or this doc in the same PR.

## 1. Strategy

Glint's risk is not CRUD bugs; it's **perception and intent quality** (accuracy, false clicks) and **system integration** (AX, events, permissions). The pyramid reflects that:

| Layer | Share | Runs on | What it's for |
|---|---|---|---|
| Unit (GlintCore) | ~55% | Linux + macOS | Every state machine transition, math (features, ridge, filters), blink grammar, snap scoring, settings migration, telemetry schema |
| Replay / eval (`glint-eval`) | ~15% | Linux + macOS | End-to-end pipeline quality on recorded landmark traces with ground truth: the gate for accuracy and false actions |
| Integration (GlintKit incl. GlintRuntime, with protocol fakes) | ~15% | macOS | Stores, IntentCoordinator/CalibrationCoordinator/TrackingController wiring, ActuationService decisions with a fake event poster, AXService filtering over fake trees, camera restart logic |
| Snapshot (GlintUI) | ~10% | macOS | Every component and screen state, light/dark, reduced motion |
| UI (XCUITest) | ~5% | macOS | Onboarding flow, popover, settings persistence, using a fake camera and fake permissions |
| Manual / hardware QA | checklist | Real Mac | Real camera, real TCC prompts, real AX in third-party apps, feel and motion |

**Deliberately not automated:** real TCC permission dialogs (macOS doesn't allow it in CI); real AX against third-party apps (they need an interactive session plus trust), which is covered by the compatibility harness run manually (§5.6); battery drain (manual Activity Monitor runs in P5).

## 2. Setup

Prerequisites: a dev Mac on macOS 26.6+ (Apple Silicon) with Xcode 27.1+ (`xcode-select -p` points to it), Homebrew, Git LFS. The app itself runs on macOS 14+. Linux (agents/CI) only needs the Swift 6.4 toolchain (`swift --version` ≥ 6.4) for GlintCore.

From a clean clone (macOS):

```bash
git clone <repo-url> glint && cd glint
scripts/bootstrap.sh
swift test --package-path Packages/GlintCore
swift test --package-path Packages/GlintKit
xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'platform=macOS,arch=arm64' test
```

From a clean clone (Linux, GlintCore only):

```bash
git lfs install && git lfs pull --include="Evals/datasets/ci/**"
swift test --package-path Packages/GlintCore
swift run --package-path Packages/GlintCore glint-eval --dataset Evals/datasets/ci --check
```

**Test configuration:** no `.env` is needed. Tests read only these environment variables:

```bash
# Optional overrides used by tests and DEBUG builds (fake values)
GLINT_FAKE_CAMERA=Evals/datasets/ci/onboarding-happy.jsonl   # UI tests: replay landmarks instead of the camera
GLINT_FAKE_PERMISSIONS=camera:granted,ax:granted             # UI tests: FakePermissionsService states
GLINT_PROVIDER=vision                                        # force fallback provider (DEBUG)
SNAPSHOT_RECORD=1                                            # re-record snapshots (never in CI)
GLINT_STORAGE_ROOT=/tmp/glint-test-<uuid>                    # stores write here in tests (set automatically by TestSupport)
```

**Test storage:** stores take a root URL. `TestSupport.makeTempRoot()` creates a unique temp directory per test and deletes it in teardown. Tests never touch the real Application Support.

## 3. Commands

| Command | Runs | Time | When |
|---|---|---|---|
| `swift test --package-path Packages/GlintCore` | All core unit + eval-lib tests | ~20 s | Every change |
| `swift test --package-path Packages/GlintCore --filter BlinkGrammarTests` | One suite | ~3 s | Iterating |
| `swift test --package-path Packages/GlintCore --filter "T-F06"` | Tests whose display name contains the ID (`@Test("T-F06-AC2 …")`) | ~5 s | Verifying an AC |
| `swift test --package-path Packages/GlintCore --enable-code-coverage` then `scripts/coverage.sh core` | Coverage report + gate (§7) | ~40 s | Before commit |
| `swift test --package-path Packages/GlintKit` | Integration + snapshot tests | ~60 s | When GlintKit changes |
| `SNAPSHOT_RECORD=1 swift test --package-path Packages/GlintKit --filter GlintUITests` | Re-record snapshots (review the PNG diffs!) | ~60 s | Intentional visual change |
| `xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'platform=macOS,arch=arm64' test` | Everything in the Glint test plan incl. XCUITest | ~5 min | Before PR / phase end |
| `xcodebuild … test -only-testing:GlintUITestsApp/OnboardingUITests` | One UI test class | ~90 s | Iterating UI flows |
| `swift run --package-path Packages/GlintCore glint-eval --dataset Evals/datasets/ci --check` | CI eval gate (thresholds + baseline diff) | ~30 s | Any perception/intent change |
| `swift run --package-path Packages/GlintCore -c release glint-eval --dataset Evals/datasets/v1 --report Evals/reports/latest.md --by-subgroup` | Full eval report | ~5 min | Phase end, release |
| `swift run --package-path Packages/GlintCore glint-eval --dataset Evals/datasets/ci --update-baseline` | Rewrite `baseline.json` | ~30 s | Only with human approval (EVAL_GUARDRAILS §9) |
| `scripts/check-architecture.sh` | Import rules, network allowlist, banned APIs | ~2 s | Every commit |
| `scripts/check-licenses.sh` | Dependency license allowlist | ~2 s | Dependency changes |
| `scripts/perf.sh` | Launches a Release build with `GLINT_FAKE_CAMERA` + signposts, records 60 s with `xctrace`, prints p50/p95 per stage | ~2 min | Pipeline changes, P1/P5 |

## 4. Mock Data & Fixtures

### 4.1 Factories (GlintCore `TestSupport` target)

| Factory | Location | Defaults |
|---|---|---|
| `Fixtures.settings(_:)` | `Packages/GlintCore/Sources/GlintCoreTestSupport/Fixtures+Settings.swift` | `Settings.defaults` with overrides via a closure |
| `Fixtures.profile(level:samples:)` | `…/Fixtures+Profile.swift` | Synthetic profile from `SyntheticEye` with a known ground-truth mapping |
| `Fixtures.fixation(at:duration:sigma:)` | `…/Fixtures+Gaze.swift` | 300 ms, sigma 60 pt |
| `Fixtures.blinkSequence(_ pattern: [BlinkSpec])` | `…/Fixtures+Blink.swift` | Generates per-frame closure values at 30 fps |
| `Fixtures.world(candidates:scrollArea:…)` | `…/Fixtures+World.swift` | One 80×32 button at (400,300), no scroll area, no typing |
| `SyntheticEye` | `…/SyntheticEye.swift` | Generates landmarks for a given gaze target + head pose + noise (seeded); the inverse model used to test FeatureExtractor + Mapper end to end |

### 4.2 Recorded traces (landmark-only)

- `Evals/datasets/ci/`: ≤ 20 MB, committed via LFS. Scenes: `calibration-*.jsonl` (6 sessions), `arena-standard-*.jsonl`, `arena-dense-*.jsonl`, `reading-natural-*.jsonl` (30 min total), `blink-intended-*.jsonl` (60 double blinks), `scroll-*.jsonl`, `onboarding-happy.jsonl` (for UI tests).
- `Evals/datasets/v1/`: the full set (≥ 10 participants, ≥ 3 h natural reading, ≥ 300 intended double blinks), subgroup-tagged in each trace header.
- **Recording protocol (Eval Arena, DEBUG build):**
  1. The participant reads and signs the consent form (stored offline, not in the repo). The form states that landmarks only are recorded, no video, the purpose, and that deletion is available on request.
  2. Assign a pseudonymous ID `P0xx`; record subgroup tags (glasses Y/N, lighting `normal|dim|backlit`, Monk skin-tone bucket `1-3|4-7|8-10`, camera model).
  3. Run the scenes in order: calibration → arena-standard → arena-dense → arena-jitter → blink-intended (prompted "double-blink now" ×30) → blink-long (×15) → scroll (prompted article) → reading-natural (≥ 15 min reading, no clicks expected) → reading-lines.
  4. The Arena writes `P0xx-<scene>-<n>.jsonl` and validates the schema on save.
- **Ground truth labels:** produced by the Arena (target shown, prompt times); `reading-natural` has the label `noIntent` for its whole duration.

### 4.3 External service strategy

| Integration | In tests |
|---|---|
| Camera | `TraceLandmarkProvider` replays traces (no AVFoundation). `CameraService` restart logic is tested with `FakeCaptureSession`. |
| ONNX Runtime | `ModelLoaderTests` load the real models on macOS only (tagged `.requiresModels`); everything else uses `TraceLandmarkProvider`. |
| AX | `FakeAXService` with scripted element trees (`AXTreeFixture` JSON: roles, frames, actions, secure flags) and injectable latency/timeouts. |
| Actuation | `RecordingEventPoster` captures posted CGEvent descriptors (type, location, deltas, tag) without posting. |
| Window list | `FakeWindowService` with scripted windows. |
| Input | `FakeInputMonitor` emits physical clicks/activity and returns a scripted `secondsSinceLastKeyDown`. |
| Permissions | `FakePermissionsService` driven by `GLINT_FAKE_PERMISSIONS`. |
| TelemetryDeck / Sentry | `SpyTelemetryClient`; a `URLProtocol` spy (`NetworkSpy`) asserts no requests leave in consent-off tests. |
| Sparkle | Local appcast served by `python3 -m http.server` from `Tests/Fixtures/appcast/` in the manual update test (§10); not in CI. |

### 4.4 Time and randomness

- GlintCore uses `ManualClock` in all tests (`clock.advance(by: 0.033)`).
- `SyntheticEye` and any noise use `SeededGenerator(seed:)` (SplitMix64); the seed is printed on failure.
- No `sleep` in tests. Async tests use `confirmation` (Swift Testing) with explicit expected counts.

## 5. Test Suites

### 5.1 Unit (GlintCore) — `Packages/GlintCore/Tests/GlintCoreTests/`

Naming: `<Type>Tests.swift`; each AC-mapped test's display name starts with its test ID.

```swift
// Packages/GlintCore/Tests/GlintCoreTests/ClickMachineTests.swift — T-F06-AC4
import Testing
@testable import GlintCore

@Test("T-F06-AC4 double blink on an uncertain lock does not click")
func uncertainLockDoesNotClick() {
  var engine = IntentEngine(settings: Fixtures.settings(), blink: .default, clock: ManualClock())
  let world = Fixtures.world(candidates: [.button(at: Point(x: 400, y: 300)), .button(at: Point(x: 430, y: 300))])
  let frames = Fixtures.fixation(at: Point(x: 415, y: 300), duration: 0.4, sigma: 60)
             + Fixtures.blinkSequence([.blink(ms: 120), .gap(ms: 200), .blink(ms: 120)])
  let actions = engine.replay(frames, world: world)
  #expect(!actions.contains { if case .press = $0 { true } else { false } })
  #expect(engine.lastOverlay.glint?.phase == .reject)
}
```

### 5.2 Replay / eval — `Packages/GlintCore/Sources/glint-eval/`, `Tests/GlintEvalTests/`

`glint-eval` loads traces, runs `FeatureExtractor → GazeMapper (fit from the trace's calibration segment) → filters → detectors → IntentEngine` with a `FakeWorld` built from the trace's labels (targets become AX candidates), and computes metrics (EVAL_GUARDRAILS §7.3). `--check` compares against thresholds and `baseline.json` and exits non-zero on failure with a Markdown diff. `GlintEvalTests` verify determinism (T-F15-AC1) and the regression detection (T-F15-AC3) on synthetic traces.

### 5.3 Integration (GlintKit) — `Packages/GlintKit/Tests/*`

Example targets: `SettingsStoreTests` (atomic write, corrupt-file recovery), `ProfileStoreTests`, `IntentCoordinatorTests`, `CalibrationCoordinatorTests`, `TrackingControllerTests` (GlintRuntimeTests: pipeline + fake AX + recording poster + fake system events), `ActuationServiceTests` (AXPress first, CGEvent fallback, tag, cursor restore), `AXServiceFilterTests` (secure fields, excluded apps, `AXManualAccessibility` once per pid), `CameraRestartTests`, `NetworkEgressTests`, `ModelLoaderTests` (`.requiresModels`).

### 5.4 Snapshot (GlintUI) — `Packages/GlintKit/Tests/GlintUITests/`

One test per component state (DESIGN_SYSTEM §8) and screen state (§9), named `test_<Component>_<state>_<appearance>`. Each runs light + dark at 2× and once with `\.accessibilityReduceMotion = true`. Perceptual precision is 0.98, so tiny anti-aliasing differences pass.

### 5.5 UI (XCUITest) — `UITests/`

Launches the app with `GLINT_FAKE_CAMERA`, `GLINT_FAKE_PERMISSIONS`, `GLINT_STORAGE_ROOT`, and `-GlintUITestMode YES` (disables the real overlay window and Sparkle). Classes: `OnboardingUITests`, `PopoverUITests`, `SettingsUITests`. Accessibility identifiers follow `glint.<surface>.<element>` (e.g. `glint.onboarding.camera.allow`).

### 5.6 Compatibility harness (manual, real AX)

DEBUG menu → "Run compatibility harness". With Accessibility granted, it opens test documents in each target app and, for each one: (1) snapshots AX around 5 known points, (2) posts a tagged glide at the gaze location while the cursor is parked in a corner, (3) checks the scroll value changed and the cursor didn't move, (4) presses a known button via AXPress. It writes `Evals/reports/compat-<date>.md`. Target apps: Safari, Chrome, Arc, Firefox, Notion, Slack, VS Code, Mail, Preview (PDF), Finder, Notes, Xcode, Figma (aura expected), System Settings (excluded expected).

### 5.7 Accessibility

`AccessibilityAuditTests` (XCUITest `performAccessibilityAudit()`) on onboarding, popover, and settings, with zero issues allowed (F-13.AC1). Manual VoiceOver pass in §10.

### 5.8 Performance

`scripts/perf.sh` (signposts + `xctrace`) and `PerfHarness` in DEBUG (live p50/p95 in Diagnostics). Budgets are in EVAL_GUARDRAILS §6. Results are recorded in TASK_LOG at P1 and P5 exit.

## 6. Acceptance Test Matrix

Status values: `planned`, `written`, `passing`. Layer key: U = unit (GlintCore), R = replay/eval, I = integration (GlintKit), S = snapshot, UI = XCUITest, M = manual QA.

| Test ID | AC | Layer | File | Status |
|---|---|---|---|---|
| T-F01-AC1 | F-01.AC1 | UI | UITests/OnboardingUITests.swift | planned |
| T-F01-AC2 | F-01.AC2 | UI + S | UITests/OnboardingUITests.swift; GlintUITests/PermissionCardSnapshotTests.swift | planned |
| T-F01-AC3 | F-01.AC3 | I | GlintKit/Tests/GlintUITests/OnboardingModelTests.swift | planned |
| T-F01-AC4 | F-01.AC4 | UI | UITests/OnboardingUITests.swift | planned |
| T-F01-AC5 | F-01.AC5 | UI + S | UITests/OnboardingUITests.swift | planned |
| T-F01-AC6 | F-01.AC6 | UI | UITests/OnboardingUITests.swift | planned |
| T-F02-AC1 | F-02.AC1 | M (perf.sh) | scripts/perf.sh → TASK_LOG evidence | planned |
| T-F02-AC2 | F-02.AC2 | R | glint-eval suite `gaze-accuracy` | planned |
| T-F02-AC3 | F-02.AC3 | U | GlintCoreTests/BlinkDetectorTests.swift | planned |
| T-F02-AC4 | F-02.AC4 | U + I | GlintCoreTests/GazeEstimatorTests.swift; IntentCoordinatorTests.swift | planned |
| T-F02-AC5 | F-02.AC5 | I + M | GlintPerceptionTests/CameraRestartTests.swift | planned |
| T-F02-AC6 | F-02.AC6 | I + arch | NetworkEgressTests.swift; scripts/check-architecture.sh; GazePipelineRetentionTests.swift | planned |
| T-F03-AC1 | F-03.AC1 | U | GlintCoreTests/CalibrationScriptTests.swift (scripted timing) | planned |
| T-F03-AC2 | F-03.AC2 | U + I | GlintCoreTests/CalibrationSessionTests.swift; GlintRuntimeTests/CalibrationCoordinatorTests.swift | planned |
| T-F03-AC3 | F-03.AC3 | U | GlintCoreTests/CalibrationSessionTests.swift | planned |
| T-F03-AC4 | F-03.AC4 | U + I | CalibrationSessionTests.swift; CalibrationCoordinatorTests.swift | planned |
| T-F03-AC5 | F-03.AC5 | UI | UITests/CalibrationUITests.swift | planned |
| T-F03-AC6 | F-03.AC6 | M | §10 VoiceOver checklist | planned |
| T-F04-AC1 | F-04.AC1 | U + R | GlintCoreTests/SilentLearnerTests.swift; glint-eval `implicit` | planned |
| T-F04-AC2 | F-04.AC2 | U | SilentLearnerTests.swift | planned |
| T-F04-AC3 | F-04.AC3 | U | SilentLearnerTests.swift | planned |
| T-F04-AC4 | F-04.AC4 | I | IntentCoordinatorTests.swift | planned |
| T-F04-AC5 | F-04.AC5 | I | InputMonitorTagTests.swift | planned |
| T-F05-AC1 | F-05.AC1 | R | glint-eval `arena-standard` | planned |
| T-F05-AC2 | F-05.AC2 | R | glint-eval `arena-dense` | planned |
| T-F05-AC3 | F-05.AC3 | U + R | GlintCoreTests/SnapMachineTests.swift; glint-eval `arena-jitter` | planned |
| T-F05-AC4 | F-05.AC4 | I | IntentCoordinatorTests.swift (FakeAXService latency 80 ms) | planned |
| T-F05-AC5 | F-05.AC5 | I | AXServiceFilterTests.swift | planned |
| T-F05-AC6 | F-05.AC6 | I + M | AXServiceFilterTests.swift; compat harness | planned |
| T-F06-AC1 | F-06.AC1 | U + R | ClickMachineTests.swift; glint-eval `blink-intended` latency | planned |
| T-F06-AC2 | F-06.AC2 | R | glint-eval `reading-natural` | planned |
| T-F06-AC3 | F-06.AC3 | R | glint-eval `blink-intended` | planned |
| T-F06-AC4 | F-06.AC4 | U | ClickMachineTests.swift | planned |
| T-F06-AC5 | F-06.AC5 | U + I + M | ClickMachineTests.swift; ActuationServiceTests.swift | planned |
| T-F06-AC6 | F-06.AC6 | I | ActuationServiceTests.swift | planned |
| T-F06-AC7 | F-06.AC7 | U | BlinkGrammarTests.swift | planned |
| T-F07-AC1 | F-07.AC1 | U + M | ScrollZoneMachineTests.swift; compat harness | planned |
| T-F07-AC2 | F-07.AC2 | U | ScrollZoneMachineTests.swift | planned |
| T-F07-AC3 | F-07.AC3 | U | ScrollZoneMachineTests.swift | planned |
| T-F07-AC4 | F-07.AC4 | U | ScrollZoneMachineTests.swift | planned |
| T-F07-AC5 | F-07.AC5 | U | ScrollZoneMachineTests.swift | planned |
| T-F07-AC6 | F-07.AC6 | I + M | ActuationServiceTests.swift; compat harness | planned |
| T-F08-AC1 | F-08.AC1 | U + M | FocusDwellMachineTests.swift | planned |
| T-F08-AC2 | F-08.AC2 | U | FocusDwellMachineTests.swift | planned |
| T-F08-AC3 | F-08.AC3 | U | FocusDwellMachineTests.swift | planned |
| T-F08-AC4 | F-08.AC4 | U | FocusDwellMachineTests.swift | planned |
| T-F09-AC1 | F-09.AC1 | U | ReadingTrackerTests.swift | planned |
| T-F09-AC2 | F-09.AC2 | U | ReadingTrackerTests.swift | planned |
| T-F09-AC3 | F-09.AC3 | U | ReadingTrackerTests.swift | planned |
| T-F09-AC4 | F-09.AC4 | I | AXServiceFilterTests.swift; log privacy lint | planned |
| T-F10-AC1 | F-10.AC1 | I + M | GlintRuntimeTests/TrackingControllerTests.swift | planned |
| T-F10-AC2 | F-10.AC2 | U | PauseMachineTests.swift | planned |
| T-F10-AC3 | F-10.AC3 | U + I | PauseMachineTests.swift; FrameRateControllerTests.swift | planned |
| T-F10-AC4 | F-10.AC4 | U | AppRuleGateTests.swift | planned |
| T-F10-AC5 | F-10.AC5 | I + M | GlintRuntimeTests/TrackingControllerTests.swift (fake SystemEvents) | planned |
| T-F10-AC6 | F-10.AC6 | U | PauseMachineTests.swift | planned |
| T-F11-AC1 | F-11.AC1 | I + UI | SettingsStoreTests.swift; SettingsUITests.swift | planned |
| T-F11-AC2 | F-11.AC2 | UI + S | PopoverUITests.swift; BannerSnapshotTests.swift | planned |
| T-F11-AC3 | F-11.AC3 | I + UI | DataDeletionTests.swift; SettingsUITests.swift | planned |
| T-F11-AC4 | F-11.AC4 | UI | SettingsUITests.swift (keyboard-only traversal) | planned |
| T-F11-AC5 | F-11.AC5 | M | §10 | planned |
| T-F11-AC6 | F-11.AC6 | I + M | OverlayWindowTests.swift (sharingType per mode, reset on launch); §10 | planned |
| T-F12-AC1 | F-12.AC1 | I + M | NetworkEgressTests.swift | planned |
| T-F12-AC2 | F-12.AC2 | U | TelemetrySchemaTests.swift | planned |
| T-F12-AC3 | F-12.AC3 | I | MetricsQueueTests.swift | planned |
| T-F12-AC4 | F-12.AC4 | S + UI | PayloadViewerSnapshotTests.swift | planned |
| T-F13-AC1 | F-13.AC1 | UI + M | AccessibilityAuditTests.swift | planned |
| T-F13-AC2 | F-13.AC2 | S | GlintRingSnapshotTests.swift (reduced motion) + OverlayMotionSpecTests.swift | planned |
| T-F13-AC3 | F-13.AC3 | S | GlintRingSnapshotTests.swift (high contrast) | planned |
| T-F13-AC4 | F-13.AC4 | I + M | OverlayWindowTests.swift (AX hidden, sharingType) | planned |
| T-F14-AC1 | F-14.AC1 | CI release job | .github/workflows/release.yml post-step | planned |
| T-F14-AC2 | F-14.AC2 | M | §10 update test | planned |
| T-F14-AC3 | F-14.AC3 | M | §10 tampered update test | planned |
| T-F14-AC4 | F-14.AC4 | M | §10 Homebrew test | planned |
| T-F15-AC1 | F-15.AC1 | U | GlintEvalTests/DeterminismTests.swift | planned |
| T-F15-AC2 | F-15.AC2 | U | GlintCoreTests/TraceSchemaTests.swift | planned |
| T-F15-AC3 | F-15.AC3 | U | GlintEvalTests/RegressionGateTests.swift | planned |

## 7. Expected Results

"Green" means:

- All Swift Testing and XCTest suites pass on macOS; the GlintCore suites also pass on Linux.
- Coverage: GlintCore ≥ 90%, GlintServices ≥ 80%, GlintSystem/GlintPerception ≥ 60% (`scripts/coverage.sh` gates).
- `glint-eval --check` passes all blocking thresholds (EVAL_GUARDRAILS §7.3) with no regression > 2 pp vs baseline.
- `performAccessibilityAudit()` reports zero issues on the audited screens.
- Snapshot tests: no unexpected diffs.
- `check-architecture.sh` and `check-licenses.sh`: exit 0.
- No warnings in the build (`SWIFT_TREAT_WARNINGS_AS_ERRORS = YES` in CI).

**Flaky tests:** fix them or quarantine them with the `.flaky` tag plus a TASK_LOG blocker within the same PR. Never add retries-until-green. Quarantined tests still run nightly, and the quarantine expires after 7 days. Typical flake sources: timing in UI tests (use `waitForExistence(timeout: 5)`, never sleeps) and snapshot font antialiasing (precision 0.98 is set).

## 8. Verification Loop for Agents

**Fast loop (after each change):**

```bash
swiftformat . && swiftlint --strict
swift test --package-path Packages/GlintCore --filter <AffectedSuite>
scripts/check-architecture.sh
```

Add, as needed:

```bash
swift run --package-path Packages/GlintCore glint-eval --dataset Evals/datasets/ci --check    # perception/intent touched
swift test --package-path Packages/GlintKit --filter <AffectedSuite>                          # GlintKit touched (macOS)
```

**Before commit:** the full `swift test` for each touched package.

**Phase-end loop:**

```bash
swift test --package-path Packages/GlintCore --enable-code-coverage && scripts/coverage.sh core
swift test --package-path Packages/GlintKit --enable-code-coverage && scripts/coverage.sh kit
xcodebuild -project Glint.xcodeproj -scheme Glint -destination 'platform=macOS,arch=arm64' test
swift run --package-path Packages/GlintCore -c release glint-eval --dataset Evals/datasets/v1 --report Evals/reports/latest.md --by-subgroup
scripts/perf.sh
```

Then do the manual QA items for the phase (§10).

**Reading failures:**

- Swift Testing prints `#expect` source locations; seeds from `SeededGenerator` are in the failure message.
- `glint-eval --check` writes `Evals/reports/check-<timestamp>.md` with per-metric diffs and the worst 10 traces.
- XCUITest artifacts land in `build/TestResults.xcresult`. Open it with `xcrun xcresulttool get --path build/TestResults.xcresult --format json` or in Xcode.
- Snapshot failures write `__Snapshots__/…_failure.png` next to the reference.
- Signpost traces from `perf.sh` go to `build/perf/*.trace`.

**If you're on Linux:** you can only run the GlintCore and glint-eval loops. Mark macOS-only verification as "pending macOS CI" in TASK_LOG and rely on the CI `app-macos` job before marking the task done.

## 9. CI Pipeline

`.github/workflows/ci.yml` on every push/PR:

| Job | Runner | Steps | Required for merge |
|---|---|---|---|
| `core-linux` | ubuntu-latest + Swift 6 | `swift test --package-path Packages/GlintCore`, coverage gate, `glint-eval --dataset Evals/datasets/ci --check` | yes |
| `lint` | macos-latest | `swiftformat --lint .`, `swiftlint --strict`, `check-architecture.sh`, `check-licenses.sh` | yes |
| `app-macos` | macos-latest | `xcodegen generate`, `swift test --package-path Packages/GlintKit`, `xcodebuild test` (unit + snapshot + UI, `CODE_SIGNING_ALLOWED=NO`), upload xcresult | yes |
| `nightly` (schedule 03:17 UTC) | both | full `v1` eval with `--by-subgroup`, quarantined tests, dependency audit (`swift package show-dependencies` vs advisories) | no (opens an issue on failure) |
| `release` (tag `v*`) | macos-latest | ARCHITECTURE §13 release pipeline + `spctl --assess` (T-F14-AC1) + entitlement diff (G-SEC-07) | — |

## 10. Manual QA Checklist

Run on a real Apple Silicon Mac with a real camera. Record results in TASK_LOG with the date, Mac model, macOS version, and camera.

- [ ] **First run on a clean user account:** real Camera and Accessibility prompts, deep link works, relaunch path works; time to first hands-free click < 90 s (Journey 1).
- [ ] **Lighting matrix:** normal office light, dim (lamp only), backlit (window behind) → correct HUD guidance, no actions while low-confidence.
- [ ] **Glasses:** regular and anti-reflective glasses → calibration level ≥ Fair.
- [ ] **Distance / posture:** 45 cm, 65 cm, 85 cm; leaning back; head turned 20° → glint still locks the right targets on the Playground.
- [ ] **Natural use, 15 min reading in Safari + Chrome:** zero unintended clicks; glide feels smooth; "where was I" appears after looking away ≥ 2 s.
- [ ] **Compatibility harness** (§5.6) report reviewed; failures logged in the Decisions or Blockers table.
- [ ] **Focus follows gaze:** typing in Notes while glancing at Slack doesn't switch focus; after stopping typing, it switches after ~0.9 s.
- [ ] **Controls:** ⌃⌥G toggles and the green camera light goes off within 1 s; pause gesture via the menu bar icon; lock the screen and the camera stops; 1Password gets no glint.
- [ ] **VoiceOver on:** complete onboarding, change a setting, run calibration (instructions announced).
- [ ] **Reduce Motion, Increase Contrast, Reduce Transparency:** all surfaces correct.
- [ ] **Light/Dark switch** while the popover is open.
- [ ] **Overlay not captured (T-F11-AC6):** take a screenshot with ⌘⇧4 and a screen recording; the glint must not appear. Turn on Demo capture mode: it appears. Relaunch: it's hidden again.
- [ ] **Energy:** Activity Monitor Energy Impact "Low" average over 10 min tracking on battery.
- [ ] **Updates (T-F14-AC2/AC3):** install vN, serve vN+1 from a local appcast, update, and confirm settings and permissions persist; a tampered zip is rejected.
- [ ] **Homebrew (T-F14-AC4):** `brew install --cask <tap>/glint` on a clean VM.
- [ ] **Launch at login (T-F11-AC5):** reboot and confirm Glint starts in its last state.
- [ ] **Motion feel review:** acquire, follow, flare, reject, glide, line marker at 60 Hz and 120 Hz; no jank.
- [ ] **Copy review** against DESIGN_SYSTEM §10.
