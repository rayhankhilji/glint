# Task Log — Glint

> Agents: update this file at the end of every task and every session. Keep the Status block current. Newest entries go at the top of the Session Log. Archive to `docs/archive/task-log-<phase>.md` when this file exceeds ~400 lines.

## Status

- **Current phase:** P0 — Foundation
- **Current focus:** P0.T1 — Verify current stable versions and update ARCHITECTURE §2 / INSTRUCTIONS §3
- **Next action:** Check the latest stable Xcode, Swift, ONNX Runtime SPM, Sparkle, TelemetryDeck SwiftSDK, Sentry Cocoa, KeyboardShortcuts, swift-snapshot-testing, XcodeGen, SwiftLint, SwiftFormat; edit the version column of ARCHITECTURE §2; add a Decisions row.
- **Blocked:** none (Q2 Developer ID team is needed by P0.T11; ask the human early)
- **Last updated:** 2026-11-03 by build-docs generator

## Current Phase Checklist

Legend: [ ] to do · [~] in progress · [x] done · [!] blocked

- [ ] P0.T1 — Verify current stable versions of Xcode, Swift, ONNX Runtime SPM, Sparkle, TelemetryDeck SwiftSDK, Sentry Cocoa, KeyboardShortcuts, swift-snapshot-testing, XcodeGen, SwiftLint, SwiftFormat; update ARCHITECTURE §2 and INSTRUCTIONS §3 in place  (verify: doc diff reviewed; versions recorded in TASK_LOG Decisions)
- [ ] P0.T2 — Create the repo skeleton: `project.yml`, `Config/*.xcconfig` (+ `Secrets.example.xcconfig`), `Info.plist` (LSUIElement, camera usage string), `Glint.entitlements` (camera only) + `Glint.entitlements.expected`, `.gitignore` (xcodeproj, build, Secrets.xcconfig), `.gitattributes` (LFS for `Models/**`, `Evals/datasets/**`), `scripts/bootstrap.sh`  (verify: `scripts/bootstrap.sh && xcodegen generate` succeeds on a clean clone)
- [ ] P0.T3 — Create `Packages/GlintCore` (targets `GlintCore`, `GlintCoreTestSupport`, `glint-eval` stub, tests) with `Point/Size/Rect`, `Clock`/`ManualClock`/`SeededGenerator`, and the full `GlintError` catalogue  (verify: `swift test --package-path Packages/GlintCore` on macOS and in Docker `swift:6` (Linux))
- [ ] P0.T4 — Create `Packages/GlintKit` (GlintPerception, GlintSystem, GlintServices, GlintUI, GlintRuntime + test targets, with an empty `IntentCoordinator`) and the `App/` target with `GlintApp` (`MenuBarExtra`) and `AppEnvironment`  (verify: `xcodebuild … build` and the app shows a menu bar icon)
- [ ] P0.T5 — Add `.swiftlint.yml` (strict, complexity limits, custom `no_magic_thresholds` for `GlintCore/Intent`), `.swiftformat`, `scripts/check-architecture.sh` (import rules §3, network allowlist, banned APIs from G-SEC-01/02/04/05), `scripts/check-licenses.sh`, `scripts/coverage.sh`, `scripts/contrast.py`  (verify: scripts exit 0 on the skeleton and exit 1 on a planted violation (test fixtures in `scripts/tests/`))
- [ ] P0.T6 — Add `.github/workflows/ci.yml` with `core-linux`, `lint`, `app-macos` jobs  (verify: all three jobs green on the PR)
- [ ] P0.T7 — Implement `Settings` (+ nested types, defaults incl. default AppRules), `Settings.validated()`, `SettingsMigrator` v1, `SettingsStore` (atomic writes, corrupt-file backup + defaults, `changes` stream)  (verify: `SettingsStoreTests`, `SettingsDefaultsTests` (T-F11-AC1 store part))
- [ ] P0.T8 — Implement design tokens (`GlintColor` + asset catalog light/dark, `GlintFont`, `GlintSpacing`, `GlintRadius`, `GlintShadow`, `GlintMotion`), `GlassSurface` with macOS 26/14 branches and reduce-transparency, and the snapshot test infrastructure  (verify: `swift test --package-path Packages/GlintKit --filter GlintUITests` with token swatch snapshots; `scripts/contrast.py` passes)
- [ ] P0.T9 — Build the menu bar glyph (template images for 5 states) and popover skeleton bound to a static `AppModel`, plus a Settings scene with 7 empty tabs  (verify: snapshot tests for each popover state)
- [ ] P0.T10 — Add logging categories (`Logger`), an `OSSignposter` wrapper, and a `Diagnostics` model skeleton  (verify: unit test that `GlintError` logging uses `.public` codes only; arch check for `print(`)
- [ ] P0.T11 — Release pipeline skeleton: `scripts/release.sh --dry-run` (archive → export Developer ID → notarytool → staple → DMG) and Sparkle wired with `SPUStandardUpdaterController` against a local test appcast  (verify: (human-provided Developer ID) a notarized skeleton DMG passes `spctl --assess`; the local appcast update offer appears)

## Up Next

Phase 1 — Gaze engine (do not start until the P0 exit criteria pass):

- [ ] P1.T1 — `CameraService`: device discovery (built-in, external, Continuity), 720p preference, 60→30 fps negotiation, `alwaysDiscardsLateVideoFrames`, interruption handling + restart backoff, `FakeCaptureSession`  (verify: T-F02-AC5 (`CameraRestartTests`))
- [ ] P1.T2 — Model toolchain: `scripts/models/manifest.json` (pinned URLs + SHA-256 of the MediaPipe sources), `fetch_and_convert.py` (uv, tf2onnx), outputs in `Models/` + `checksums.sha256` (LFS)  (verify: `uv run scripts/models/fetch_and_convert.py` is reproducible (same checksums twice))
- [ ] P1.T3 — **Spike:** implement minimal `MediaPipeORTProvider` and `VisionProvider`; measure p95 latency on M1 and landmark jitter on a 2-minute session; confirm no extra entitlements are needed; record the ADR-002 decision with numbers  (verify: spike report in `Evals/reports/spike-providers.md` + ADR updated + TASK_LOG Decisions row)
- [ ] P1.T4 — Production providers per ADR-002 + `ModelLoader` (checksum check, warm-up, fallback) + `TraceLandmarkProvider`  (verify: `ModelLoaderTests` (incl. corrupted model → `MODEL_CHECKSUM_MISMATCH`))
- [ ] P1.T5 — `FeatureExtractor` (eye-corner frames, iris, pose, faceScale, EAR, closure) + `SyntheticEye`  (verify: `FeatureExtractorTests` (synthetic round-trip, Linux))
- [ ] P1.T6 — `OneEuroFilter`, `FixationDetector` (I-DT), saccade detection  (verify: `OneEuroFilterTests`, `FixationDetectorTests`)
- [ ] P1.T7 — `BlinkDetector` + `BlinkGrammar` (double, blink+long, rest closure)  (verify: T-F02-AC3, T-F06-AC7)
- [ ] P1.T8 — `GazeEstimator` (Core) + `GazePipeline` actor (latest-wins, frame-rate controller, pixel-buffer release)  (verify: T-F02-AC4, T-F02-AC6 (`GazePipelineRetentionTests`, arch check))
- [ ] P1.T9 — Trace format `glint-trace/v1`, `TraceSchema` validation, `TraceRecorder` (DEBUG)  (verify: T-F15-AC2)
- [ ] P1.T10 — DEBUG gaze dot overlay (temporary 5-point quick mapping for development only), `PerfHarness`, `scripts/perf.sh`, `Glint.tracetemplate`  (verify: `scripts/perf.sh` prints per-stage p50/p95; record T-F02-AC1 baseline)
- [ ] P1.T11 — `glint-eval` v0: load traces, run the pipeline with `ManualClock`, report blink metrics, deterministic output  (verify: T-F15-AC1)

## Blockers

| ID | Task | Description | Tried | Hypotheses | Needs | Opened |
|---|---|---|---|---|---|---|

No blockers.

## Decisions & Deviations

| Date | Decision | Reason | Docs updated |
|---|---|---|---|
| 2026-11-03 | Native macOS app instead of browser extension | User pivoted during planning: "works all across ur mac" | PRD §6, ADR-001 |
| 2026-11-03 | Webcam-only; target "effective accuracy" via AX snapping + calibration, not raw angular parity with IR trackers | Physical limits of RGB webcams; user chose effective-accuracy goal | PRD A1, EVAL_GUARDRAILS §7.3 |
| 2026-11-03 | Fully local; opt-in metrics via TelemetryDeck (+ Sentry crashes under same consent) | User choice: no BYOK/cloud features, opt-in anonymous metrics | ADR-008, G-SEC-05/06 |
| 2026-11-03 | Click = double blink only; right-click = blink + long blink | User chose double blink; right-click needed for accessibility foundations | PRD F-06, A5 |
| 2026-11-03 | Scroll = zone-triggered glide (bottom 15% / top 10%) | User choice | PRD F-07 |
| 2026-11-03 | Apple Silicon + macOS 14+, notarized DMG + Sparkle + Homebrew, free | User choices | PRD §8, F-14 |

## Session Log

### 2026-11-03 — Session 0 (planning)

- Done: Generated the build docs (PRD, ARCHITECTURE, INSTRUCTIONS, ROADMAP, TASK_LOG, TESTING_GUIDE, DESIGN_SYSTEM, EVAL_GUARDRAILS, CLAUDE.md, AGENTS.md) from the product interview.
- Tests: none yet (docs only).
- Notes: Open questions Q1–Q4 are in PRD §11. Q2 (Developer ID team) blocks P0.T11 signing; Q3 (eval participants) is needed by P2.T7.
- Next: P0.T1.

## Completed Phases

| Phase | Completed | Exit-criteria evidence |
|---|---|---|

None yet.
