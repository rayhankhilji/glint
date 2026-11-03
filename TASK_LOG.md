# Task Log — Glint

> Agents: update this file at the end of every task and every session. Keep the Status block current. Newest entries go at the top of the Session Log. Archive to `docs/archive/task-log-<phase>.md` when this file exceeds ~400 lines.

## Status

- **Current phase:** P0 — Foundation (exit criteria **not** met yet)
- **Current focus:** P0.T6 — get CI running (blocked: GitHub Actions jobs never get a runner, BLK-1)
- **Next action:** Human: check GitHub → Settings → Billing/Actions for `rayhankhilji/glint` (BLK-1). Then re-run CI and fix whatever the `app-macos` job reports for the macOS-only code (P0.T4, P0.T8, P0.T9).
- **Blocked:** BLK-1 (CI runners), BLK-2 (Developer ID / notary credentials, PRD Q2), BLK-3 (snapshot references must be recorded on a Mac)
- **Last updated:** 2026-11-03 by agent (session 2: design system v1.1)

## Current Phase Checklist

Legend: [ ] to do · [~] in progress · [x] done · [!] blocked

- [x] P0.T1 — Verify current stable versions and update ARCHITECTURE §2 / INSTRUCTIONS §3  (evidence: Decisions row 2026-11-03 "Version pins")
- [~] P0.T2 — Repo skeleton (`project.yml`, `Config/*`, Info.plist, entitlements + `.expected`, `.gitignore`, `.gitattributes`, `bootstrap.sh`, `install-tools.sh`)  (verified: plists/YAML parse, `install-tools.sh` works on Linux; pending: `scripts/bootstrap.sh && xcodegen generate` on a Mac)
- [x] P0.T3 — `Packages/GlintCore` (+ TestSupport, GlintEval lib, `glint-eval` CLI): geometry, Clock/ManualClock/SeededGenerator, GlintError catalogue  (tests: `swift test --package-path Packages/GlintCore` → 46 tests (44 GlintCore + 2 GlintEval) pass on Linux, Swift 6.4.2; coverage 94% ≥ 90%)
- [~] P0.T4 — `Packages/GlintKit` (6 modules incl. GlintPlatform, ADR-010) + `App/` (GlintApp, AppEnvironment, Updater) + launch UI test  (verified on Linux with an `os` stand-in: GlintPlatform/Services/Runtime compile and pass; pending: macOS build of GlintUI/App — BLK-1)
- [x] P0.T5 — `.swiftlint.yml` (custom rules), `.swiftformat`, `check-architecture.sh`, `check-licenses.sh`, `coverage.sh`, `contrast.py`  (tests: `scripts/tests/check-architecture.test.sh` 22/22, `scripts/tests/check-licenses.test.sh` 2/2, `swiftlint --strict` + `swiftformat --lint .` clean, contrast 22/22)
- [!] P0.T6 — `.github/workflows/ci.yml` (`core-linux`, `lint`, `app-macos`)  (workflow written; run 41621059219: all jobs failed in 3 s with no runner assigned — BLK-1)
- [x] P0.T7 — `Settings` + defaults + `validated()` + `SettingsMigrator` v1 + `SettingsStore`  (tests: SettingsDefaultsTests, SettingsValidationTests, SettingsMigratorTests on Linux; SettingsStoreTests 7/7 on Linux via `os` stand-in; T-F11-AC1 store part; macOS re-run pending BLK-1)
- [~] P0.T8 — Design tokens (asset catalog, GlintColor/Font/Spacing/Radius/Shadow/Motion), `GlassSurface`, snapshot infrastructure  (verified: `contrast.py` 22/22; pending: macOS compile + snapshot references — BLK-1, BLK-3)
- [~] P0.T9 — Menu bar glyph (5 states, drawn in code), popover bound to `AppModel` (10 states), Settings scene with 7 tabs  (snapshot + unit tests written; pending macOS — BLK-1, BLK-3)
- [x] P0.T10 — `GlintLog` categories, `GlintSignposts`, `Diagnostics` model  (tests: GlintPlatformTests log-text test on Linux; DiagnosticsTests incl. G-SEC-14 export check; arch check bans `print(`)
- [!] P0.T11 — `scripts/release.sh --dry-run` + Sparkle `Updater` wrapper  (script written, `bash -n` clean; needs a Developer ID certificate, notary profile and a Mac — BLK-2)

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
| BLK-1 | P0.T6 (and macOS verification of P0.T2/T4/T8/T9) | CI run 41621059219: all three jobs (`core-linux`, `lint`, `app-macos`) completed as failure 3 s after creation, `runner_id: 0`, no steps, logs 404, empty check-run output. | Read run, jobs, job logs and check run via the GitHub API. | Actions can't start jobs for this account/repo: billing problem or spending limit, Actions disabled for the repo, or no minutes for a private repo (macOS minutes are billed 10×). | Human: open the run page on GitHub and fix the Actions/billing setting it reports, then re-run. | 2026-11-03 |
| BLK-2 | P0.T11 | Notarized dry run needs a Developer ID Application certificate, team ID and a `notarytool` keychain profile. | — | PRD Q2 is still open. | Human: decide Q2; on a Mac run `xcrun notarytool store-credentials glint-notary …`, set `GLINT_DEVELOPMENT_TEAM`, then `scripts/release.sh --dry-run`. | 2026-11-03 |
| BLK-3 | P0.T8, P0.T9 | Snapshot reference PNGs can only be rendered on macOS. CI runs with `GLINT_SNAPSHOT_BOOTSTRAP=1` (records missing references, reports mismatches as known issues) and uploads them as the `snapshots` artifact. | — | — | Once CI runs: review the artifact PNGs, commit them under `Packages/GlintKit/Tests/GlintUITests/__Snapshots__/`, and delete `GLINT_SNAPSHOT_BOOTSTRAP` from `ci.yml`. | 2026-11-03 |

## Decisions & Deviations

| Date | Decision | Reason | Docs updated |
|---|---|---|---|
| 2026-11-03 | Native macOS app instead of browser extension | User pivoted during planning: "works all across ur mac" | PRD §6, ADR-001 |
| 2026-11-03 | Webcam-only; target "effective accuracy" via AX snapping + calibration, not raw angular parity with IR trackers | Physical limits of RGB webcams; user chose effective-accuracy goal | PRD A1, EVAL_GUARDRAILS §7.3 |
| 2026-11-03 | Fully local; opt-in metrics via TelemetryDeck (+ Sentry crashes under same consent) | User choice: no BYOK/cloud features, opt-in anonymous metrics | ADR-008, G-SEC-05/06 |
| 2026-11-03 | Click = double blink only; right-click = blink + long blink | User chose double blink; right-click needed for accessibility foundations | PRD F-06, A5 |
| 2026-11-03 | Scroll = zone-triggered glide (bottom 15% / top 10%) | User choice | PRD F-07 |
| 2026-11-03 | Apple Silicon + macOS 14+, notarized DMG + Sparkle + Homebrew, free | User choices | PRD §8, F-14 |
| 2026-11-03 | Version pins (P0.T1): Xcode 27.1+, Swift 6.4 (CI `swift:6.4.1-noble`), ORT 1.24.2, Sparkle 2.10.0, TelemetryDeck 2.14.2, Sentry **9.30.2** (docs said 8.x), KeyboardShortcuts **3.1.0** (docs said 2.x), snapshot-testing 1.19.6, XcodeGen 2.46.0, SwiftLint 0.65.1, SwiftFormat 0.63.1 | Rule: newest release ≥ 14 days old (cutoff 2026-10-20); dates read from tag commits | ARCHITECTURE §2, INSTRUCTIONS §3, PRD §8, TESTING_GUIDE §2 |
| 2026-11-03 | Added `GlintPlatform` module (logging, signposts, `SystemClock`, `AppPaths`) | Every GlintKit module needs logging; GlintCore can't import `os`; GlintUI can't depend on GlintSystem | ADR-010, ARCHITECTURE §3, INSTRUCTIONS §4 |
| 2026-11-03 | `glint-eval` split into `GlintEval` library + thin executable; refuses `--check` until replay exists | Unit-testable; CI can't pass an empty gate | ARCHITECTURE §3 |
| 2026-11-03 | Build config variables are `GLINT_`-prefixed (`GLINT_TELEMETRYDECK_APP_ID`, `GLINT_SENTRY_DSN`, `GLINT_SPARKLE_FEED_URL`, `GLINT_SPARKLE_PUBLIC_ED_KEY`, `GLINT_DEVELOPMENT_TEAM`, `GLINT_BUNDLE_ID`) | Avoid clashing with Xcode build settings | ARCHITECTURE §12 |
| 2026-11-03 | The hotkey isn't mirrored in `Settings`; KeyboardShortcuts' UserDefaults entry is the single source | Avoid two sources of truth | ARCHITECTURE §4 |
| 2026-11-03 | "Pause until I resume" is persisted as `pausedUntil = .distantFuture` | No schema change needed; `GlintStatus.resolve` maps it to `.paused(until: nil)` | — (covered by StatusResolutionTests) |
| 2026-11-03 | Lint, architecture and license checks run on Linux CI; macOS runs only GlintKit tests and the app/UI tests; `xcodebuild test` covers UI tests, packages are tested with `swift test` | Saves macOS minutes (10× billing) | TESTING_GUIDE §3, §9; ARCHITECTURE §13; INSTRUCTIONS §5 |
| 2026-11-03 | `check-architecture.sh` requires GNU grep (`ggrep` on macOS via Homebrew) | Needs Perl regexes (lookahead for `TODO(BLK-n)`) and consistent `\b`/`\s` | INSTRUCTIONS §5, bootstrap.sh |
| 2026-11-03 | Temporary snapshot bootstrap mode in CI (`GLINT_SNAPSHOT_BOOTSTRAP=1`) | References can't be rendered on Linux; removed once BLK-3 closes | BLK-3 |
| 2026-11-03 | Design system v1.1 (user request: "higher quality, modern, no gradients, no slop, custom icons, SVG motion"): cool ink-and-paper chrome replaces warm cream; gold reserved for light (glint, mark, focus); ink/paper primary actions | The warm-cream + gold palette read as a generic AI look; one-light principle | DESIGN_SYSTEM §1, §2; asset catalog; contrast.py (28/28) |
| 2026-11-03 | No decorative gradients, glows or blur anywhere in GlintUI/App, enforced by `check-architecture.sh` (+ self-tests) | User request; light drawn as crisp vector geometry | DESIGN_SYSTEM §1 (principle 2), §2.1, §5, §6.2 |
| 2026-11-03 | Custom icon system: 28 SVG icons (24 pt grid) + 5 menu bar glyphs (18 pt) in `Design/`, compiled to Swift vector data by `scripts/icons/build_icons.py` (CI `--check`, 10 Python tests, Chromium round-trip fidelity check); SF Symbols removed from Glint-owned UI | Brand-defining glyphs must be ours; vector parts enable part-level motion | DESIGN_SYSTEM §7, §8; INSTRUCTIONS §5, §7 |
| 2026-11-03 | Motion spec as animated SVG studies (`Design/Motion/`, 6 studies, timings validated) mirrored by SwiftUI `KeyframeAnimator` views (`GlintMark` twinkle/double blink, `DrawOnIcon`); twinkle turns 90° (4-fold symmetric, seamless loop) | Motion reviewable without a Mac; one source of timing truth | DESIGN_SYSTEM §6.2 |
| 2026-11-03 | Popover redesigned: live mark + switch, plain-text accuracy (`AccuracyReadout` replaces the chip), flat banner, custom-icon action rows with flat hover | Remove chip/dashboard clutter | DESIGN_SYSTEM §9.1 |
| 2026-11-03 | App icon redrawn flat from `Design/AppIcon/glint-app-icon.svg` (ink tile, paper eye, gold catchlight), rasterized with `scripts/icons/render-app-icon.mjs` (dev-only Node + Playwright tool, not shipped) | Replaces the PIL gradient placeholder; macOS 26 Icon Composer variants remain P5.T8 | DESIGN_SYSTEM §7 |

## Session Log

### 2026-11-03 — Session 2 (design system v1.1)

- Done: custom icon system (SVG → Swift), motion studies, palette and no-gradient rule, popover/banner/empty-state/Settings-tab redesign, flat app icon. Not a ROADMAP task: user-requested quality pass, pulled forward from P5.T2/P5.T8.
- Tests (Linux): GlintCore 46 pass; icon converter 10 pass; `build_icons.py --check` up to date; generated icon data compiles under Swift 6.4 against stub types (28 icons, 102 parts); check-architecture 24/24 self-tests; contrast 28/28; SwiftLint + SwiftFormat clean. Visual QA in Chromium: icon contact sheet (light/dark, 24/48 pt), round-trip render diff of compiled paths vs SVG sources (only sub-pixel arc antialiasing), app icon at 16–256 px, motion studies frame by frame (found and fixed a 45° twinkle snap and an invalid SMIL keyTimes set).
- Not verified: SwiftUI rendering of the new views (BLK-1); snapshot references (BLK-3).
- Next: unchanged (BLK-1 first).

### 2026-11-03 — Session 1 (Phase 0)

- Done: P0.T1, P0.T3, P0.T5, P0.T7, P0.T10; P0.T2, P0.T4, P0.T8, P0.T9 written but awaiting macOS verification; P0.T6 written but CI can't start (BLK-1); P0.T11 written, blocked on BLK-2.
- Tests (Linux, Swift 6.4.2):
  - `swift test --package-path Packages/GlintCore`: 46 tests pass (44 + 2); coverage 94% (`scripts/coverage.sh core`).
  - GlintPlatform/Services/Runtime tests compiled against a throwaway `os` stand-in in the scratchpad (not committed): SettingsStore 7/7, IntentCoordinator 1/1, Platform 4/5. The one failure, "Default storage is Application Support/Glint", is expected on Linux, where Foundation maps Application Support to `~/.local/share`.
  - `swiftformat --lint .`, `swiftlint --strict`, `scripts/check-architecture.sh` (+ 22 self-tests), `scripts/check-licenses.sh` (+ 2), `python3 -I scripts/contrast.py` (22/22): all clean.
- Not verified: anything importing SwiftUI/AppKit/Sparkle (GlintUI, App), snapshot tests, UI tests, `xcodegen generate`, signing.
- Next: resolve BLK-1, then fix whatever `app-macos` reports; commit snapshot references (BLK-3); P0.T11 once Q2 is decided.

### 2026-11-03 — Session 0 (planning)

- Done: Generated the build docs (PRD, ARCHITECTURE, INSTRUCTIONS, ROADMAP, TASK_LOG, TESTING_GUIDE, DESIGN_SYSTEM, EVAL_GUARDRAILS, CLAUDE.md, AGENTS.md) from the product interview.
- Tests: none yet (docs only).
- Notes: Open questions Q1–Q4 are in PRD §11. Q2 (Developer ID team) blocks P0.T11 signing; Q3 (eval participants) is needed by P2.T7.
- Next: P0.T1.

## Completed Phases

| Phase | Completed | Exit-criteria evidence |
|---|---|---|

None yet.
