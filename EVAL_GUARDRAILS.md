# Saccade — Evaluation & Guardrails

> Version: 1.0 · Updated: 2026-11-03 · Non-negotiables. Every guardrail has an ID, a rule, a reason, and how it's verified. Check §1 before marking any task done.

## 1. Definition of Done

### Task-level DoD (every task)

- [ ] Every acceptance criterion the task references (`F-xx.ACn`) has a passing test with the matching ID (`T-Fxx-ACn`, TESTING_GUIDE §6), listed in TASK_LOG.
- [ ] `swiftformat --lint .` and `swiftlint --strict` are clean; no new compiler warnings (warnings are errors in CI).
- [ ] `swift test --package-path Packages/SaccadeCore` passes. If SaccadeCore changed, it also passes on Linux (CI `core-linux` job, or a local Docker `swift:6` image).
- [ ] The affected SaccadeKit/app tests pass (`swift test --package-path Packages/SaccadeKit`, and `xcodebuild … test` if App/UITests are touched).
- [ ] If perception, mapping, filters, or intent changed: `saccade-eval --dataset Evals/datasets/ci --check` passes, and the report diff vs `Evals/reports/baseline.json` is pasted in the PR.
- [ ] UI: all states from PRD (`States:`) and DESIGN_SYSTEM §9 are implemented, with snapshot tests in light and dark plus a reduced-motion variant; tokens only; VoiceOver labels present.
- [ ] Contracts match ARCHITECTURE §4–§5 exactly (names, fields, error codes). If a contract changed, ARCHITECTURE is updated in the same PR.
- [ ] `scripts/check-architecture.sh` passes (module import rules, network allowlist, no keyboard event posting, no pixel-buffer persistence APIs).
- [ ] No `print`, no `TODO` without a blocker ID, no commented-out code, no force unwraps outside tests.
- [ ] TASK_LOG.md updated (status, tests, notes, next action).

### Phase-level DoD

- [ ] All phase exit criteria in ROADMAP pass, with evidence (command output or CI link) recorded in TASK_LOG → Completed Phases.
- [ ] The full CI pipeline is green on the phase's final commit.
- [ ] From Phase 3 on: a manual QA pass (TESTING_GUIDE §10) on a real Mac for the phase's journeys, with results recorded.
- [ ] Performance budgets (§6) are re-measured if the phase touched the pipeline; no regression > 10%.

### Release DoD

- [ ] Every P0 acceptance criterion passes; every P1 that's shipping passes.
- [ ] `saccade-eval` on `Evals/datasets/v1` meets every **blocking** threshold in §7.3.
- [ ] Security checklist §2 is reviewed item by item with evidence.
- [ ] Notarized build passes `spctl --assess` on a clean macOS 14 VM and the current macOS release; the Sparkle update from the previous version works (F-14.AC2).
- [ ] UX rubric (§7.2) ≥ 4.0 average on every hero flow, no item < 3.
- [ ] Rollback rehearsed once (ARCHITECTURE §13).

## 2. Security & Privacy Guardrails

| ID | Rule | Reason | Verification |
|---|---|---|---|
| G-SEC-01 | Camera pixel data is never persisted, copied into `Data`/`CGImage`/`NSImage`/`CIImage` outside the landmark preprocessing function, logged, or transmitted. Pixel buffers are released after one inference. | The core privacy promise. | `check-architecture.sh` greps for `CVPixelBufferGetBaseAddress`, `CIImage(`, `CGImage`, `jpegData`, `pngData`, and `write(` outside the allowlisted `FramePreprocessor.swift`; unit test that `GazePipeline` holds no buffer references after `observe` returns; manual Instruments allocation check in P5. |
| G-SEC-02 | Never post keyboard events; never read keystroke contents; never request Input Monitoring. | Saccade must never be (or look like) a keylogger. | `check-architecture.sh` bans `keyboardEventSource`, `CGEvent(keyboardEventSource`, `kCGEventKeyDown` posting, and `addGlobalMonitorForEvents(matching: .keyDown`; Info.plist has no input-monitoring usage string. |
| G-SEC-03 | AX text content (titles, values, descriptions, URLs) is never stored, sent, or logged at `.public`. `AXSecureTextField` elements are skipped entirely. | Screen contents are highly sensitive. | Unit tests on `AXService` filters; a log-privacy lint (grep for `privacy: .public` on string interpolations in SaccadeSystem); telemetry schema has no string fields (G-SEC-06). |
| G-SEC-04 | Only these actuations exist: left/right mouse click, pixel scroll-wheel, `AXPress`, `AXShowMenu`, `AXRaise`, app activate. Every posted CGEvent carries `SACCADE_EVENT_TAG`. | Least privilege; our own monitors must ignore our own events. | `ActuationService` is the only file with `CGEvent(`/`.post(` (arch check); unit test of tag presence. |
| G-SEC-05 | Network egress only via Sparkle (the appcast host), TelemetryDeck, and Sentry, and the latter two only when opted in. | No silent phoning home. | `check-architecture.sh` (no `URLSession`/`Network` outside allowlisted files); `NetworkEgressTests` installs a `URLProtocol` spy and asserts zero non-Sparkle requests with consent off (T-F12-AC1); manual Little Snitch check before release. |
| G-SEC-06 | Telemetry payloads are built only from the closed `TelemetrySignal` enum; parameter values are enums or integers. No app bundle IDs, window titles, URLs, device names, or timestamps finer than a day. | Anonymous by construction. | Schema validation test on every signal (T-F12-AC2); PR review of any `TelemetrySignal` change requires human approval (§9). |
| G-SEC-07 | Hardened runtime on; the only entitlement is `com.apple.security.device.camera`. | Minimize attack surface of a highly privileged (Accessibility-trusted) app. | `codesign -d --entitlements :- Saccade.app` in the release job compared against `Config/Saccade.entitlements.expected`. |
| G-SEC-08 | ML models are loaded only if their SHA-256 matches `Models/checksums.sha256` (embedded at build time). | Prevent model tampering in a privileged process. | `ModelLoaderTests` with a corrupted model fixture → `MODEL_CHECKSUM_MISMATCH`. |
| G-SEC-09 | Updates are accepted only if the EdDSA signature and Developer ID signature verify; feed over HTTPS only. | Update channel is the biggest supply-chain risk. | F-14.AC3 test with a tampered archive; `SUFeedURL` must start with `https://` (build-time assert in `release.sh`). |
| G-SEC-10 | Camera stops within 1 s of: Off, screen lock, sleep, session resign. While paused, the camera may run (for the resume gesture), and the menu bar glyph shows paused. | Users expect the green light to mean "active". | T-F10-AC1, T-F10-AC5 + manual check of the green camera indicator. |
| G-SEC-11 | Default app rules (`off`) include password managers, Keychain Access, System Settings, the login window, and the screensaver; users can remove them, but "Reset to defaults" restores them. | Avoid acting in security-sensitive UIs by default. | T-F10-AC4; `SettingsDefaultsTests`. |
| G-SEC-12 | Dependencies are pinned via `Package.resolved`; licenses must be MIT/Apache-2.0/BSD; no new dependency without an ADR. | Supply chain + license hygiene for a closed-source app. | `scripts/check-licenses.sh` in CI reads `Package.resolved` and an allowlist. |
| G-SEC-13 | Eval recordings contain landmarks and labels only, with pseudonymous participant IDs and signed consent kept outside the repo. | Biometric-adjacent data. | `TraceSchemaTests` reject unknown fields (T-F15-AC2); consent checklist in TESTING_GUIDE §4. |
| G-SEC-14 | Diagnostics export contains only numeric/enum data and error codes. | Users share these publicly in issues. | `DiagnosticsExportTests` scan output for strings outside the enum allowlist. |

## 3. ML / Intent Guardrails

There is no LLM in Saccade. These rules govern the perception and intent models, where the "unsafe output" is an unintended action.

| ID | Rule | Reason | Verification |
|---|---|---|---|
| G-ML-01 | **Fail safe:** no action fires when confidence < 0.6, the face is not visible, the user is off-screen, there's no calibration, permissions are missing, Saccade is paused, or the front app is excluded. | False positives destroy trust. | `IntentEngineGateTests` (table-driven, one row per condition). |
| G-ML-02 | Click requires: a lock stable ≥ 250 ms and not uncertain, a valid double-blink grammar, gaze return within `max(1.5σ, 40 pt)` within 300 ms, and no mouse button held. | Multi-signal gating against natural blinks. | T-F06-AC1…AC7. |
| G-ML-03 | Every action is preceded by a visible anticipatory overlay state for ≥ 80 ms (armed, dwell glow, or locked). | Users can abort by looking away. | `OverlaySequenceTests` assert the state order in replays. |
| G-ML-04 | The model swap from silent learning happens only if LOO error doesn't worsen by > 5%; implicit samples obey the acceptance rules in F-04. | Prevent self-reinforcing drift. | T-F04-AC2, T-F04-AC3. |
| G-ML-05 | Thresholds live only in `IntentConstants` / `Settings` defaults. Any change requires a `saccade-eval` before/after report in the PR. | Small numbers have big UX effects. | Arch check: numeric literals in `Intent/` machines other than 0/1 fail lint (custom SwiftLint rule `no_magic_thresholds`). |
| G-ML-06 | Replays are deterministic: same trace → bit-identical metrics. | Reliable gating in CI. | T-F15-AC1. |
| G-ML-07 | Max rates: ≤ 1 click per 500 ms, ≤ 1 glide per 700 ms, ≤ 1 focus switch per 1.5 s. | Bound the blast radius of a bug. | `RateLimitTests`. |
| G-ML-08 | Manual input always wins: physical pointer movement hides the highlight for 1.2 s; physical scroll suspends gaze scroll for 2 s; mouse button down blocks clicks. | User is in charge. | T-F07-AC3, `ManualPrecedenceTests`. |
| G-ML-09 | The eval dataset must include subgroups: glasses vs none, dim vs normal light, ≥ 3 skin-tone groups (Monk scale buckets), 2+ camera models. Release thresholds apply per subgroup with ≤ 5 pp disparity on target-lock rate. | Fairness and robustness. | `saccade-eval --by-subgroup` in the release gate. |

## 4. Cost & Resource Budgets

There are no per-call AI costs. The budgets are on-device compute/energy and small fixed infrastructure costs.

### 4.1 Compute & energy (G-COST)

| ID | Operation | Budget (M1, 30 fps unless noted) | Behavior when exceeded |
|---|---|---|---|
| G-COST-01 | Landmark inference p95 | ≤ 9 ms (hard ceiling 12 ms) | Auto-degrade ladder: drop blendshapes → 192 px crop → 30 fps cap; log `perf.degrade` |
| G-COST-02 | Total app CPU, tracking | ≤ 15% of one core average over 5 min | Same ladder; diagnostics warning |
| G-COST-03 | Away mode CPU | ≤ 3% | 5 fps capture, detector-only inference |
| G-COST-04 | Memory resident | ≤ 250 MB | Fail the perf test; investigate leaks |
| G-COST-05 | AX snapshot rate | ≤ 30 /s, and only on fixation start/update | Throttle |
| G-COST-06 | Energy Impact (Activity Monitor) | "Low" average while tracking | P5 energy task |
| G-COST-07 | Battery + Low Power Mode | ≤ 30 fps, blendshapes off | Automatic |

### 4.2 Infrastructure

| Item | Expected monthly cost at launch (≤ 5k users) | Alert / cap |
|---|---|---|
| Apple Developer Program | $99/year | — |
| GitHub (Releases bandwidth, Actions) | $0 (public releases repo; Actions minutes within free tier; macOS minutes are 10× multiplier → keep app-macos job ≤ 15 min) | Alert if Actions usage > 80% of plan |
| TelemetryDeck | Free tier (≤ 3 signals/opted-in user/day) | Alert at 80% of plan quota; reduce to the `dailySummary` signal only if exceeded |
| Sentry | Free/Developer tier | Rate limit 1 event/min/install in `beforeSend`; alert at 80% quota |

### 4.3 Agent-development budget

- Read files by section (ARCHITECTURE §n), not whole docs, once you know the layout.
- Don't re-read unchanged large files in a session; rely on TASK_LOG notes.
- Summarize long `xcodebuild` logs: grep for `error:` / `warning:` / `Test Case .* failed` and paste ≤ 30 lines into TASK_LOG blockers.
- Prefer `swift test --filter` on SaccadeCore while iterating; run the full app test suite only before committing.
- Don't run the full v1 eval (`Evals/datasets/v1`) on every change: the CI set is enough until phase end.

## 5. Error Handling Conventions

- **Taxonomy:** permission (`CAMERA_PERMISSION_DENIED`, `CAMERA_RESTRICTED`, `AX_PERMISSION_MISSING`), device (`CAMERA_NOT_FOUND`, `CAMERA_INTERRUPTED`), model (`MODEL_LOAD_FAILED`, `MODEL_CHECKSUM_MISMATCH`), calibration (`NOT_CALIBRATED`, `CALIBRATION_INSUFFICIENT`, `MAPPER_SINGULAR`), system/AX (`AX_TIMEOUT`, `AX_ACTION_UNSUPPORTED`, `AX_ELEMENT_GONE`, `ACTUATION_FAILED`), storage (`SETTINGS_CORRUPT`, `PERSISTENCE_FAILED`). The catalogue is in ARCHITECTURE §5.3. Codes are `SCREAMING_SNAKE`, stable forever once shipped.
- **Mapping to UI:** permission and device errors → popover banner + HUD on transition. Calibration errors → calibration screen states. AX/actuation errors → overlay reject animation only (never a dialog). Storage errors → one-time HUD. Nothing is ever shown as a modal alert except "Delete all data" confirmation and Sparkle's own UI.
- **Message rule:** what happened + what to do (DESIGN_SYSTEM §10). Never show error codes to users except in diagnostics.
- **Retry policy:** camera restart backoff 0.5 s, 1 s, 2 s, then every 5 s (with ±10% jitter); AX calls are never retried within the same frame, since the next fixation update retries naturally; telemetry retries daily for ≤ 7 days; model load is not retried (fallback provider instead).
- **Circuit breaking:** if `AX_TIMEOUT` exceeds 5 within 2 s for one pid, mark that app `axDegraded` for 30 s (aura mode, clicks off when `preciseTargetsOnly`), then probe again.
- **Logging vs showing:** every `SaccadeError` is logged once at `.error` with its code (`.public`) and increments a diagnostics counter. Repeated identical errors are rate-limited to 1 log per 10 s.
- **Crash policy:** no `fatalError`/`preconditionFailure` reachable from user input or system state; they're allowed only for programmer errors in DEBUG (`assertionFailure`).

## 6. Reliability & Performance Budgets

| Metric | Target | How measured |
|---|---|---|
| Frame → overlay update latency | p50 ≤ 35 ms, p95 ≤ 50 ms | Signposts `frame`→`render`; `PerfHarness` in P1.T10 |
| Blink-2 end → AXPress dispatched | ≤ 120 ms | Replay with timestamps + signpost |
| Fixation in zone → glide start | dwell (300 ms) + ≤ 60 ms | Replay |
| Overlay frame time | ≤ 4 ms GPU; 0 dropped frames during flare at 120 Hz | Metal HUD / Instruments |
| Startup (launch → tracking) | ≤ 1.5 s warm, ≤ 3 s cold | Signpost `appLaunch`→`firstSample` |
| Camera recovery | ≤ 2 s after the device returns | T-F02-AC5 |
| AX snapshot | p95 ≤ 15 ms; hard timeout 50 ms | Signpost `axSnapshot` |
| Crash-free sessions | ≥ 99.5% | Sentry (opted-in) |
| Hang rate | no main-thread hang > 250 ms | `os_signpost` + Xcode hang detection in QA |

**Timeouts on every external call:** AX messaging 50 ms; window list (synchronous) only called ≤ 10 Hz; TelemetryDeck/Sentry use SDK defaults (no UI blocking); Sparkle is Sparkle-managed.

**Graceful degradation:** Vision fallback provider; aura mode when AX is unavailable; perf degrade ladder (G-COST-01); away mode; read-only "scroll-only" per-app mode.

## 7. Quality Evals

### 7.1 Code quality gates

| Layer | Coverage (line) | Notes |
|---|---|---|
| SaccadeCore | ≥ 90% | Pure logic; every state machine transition tested |
| SaccadeServices | ≥ 80% | Stores, migrations, schema |
| SaccadeSystem / SaccadePerception | ≥ 60% | Behind protocol fakes; real-system parts covered by manual QA |
| SaccadeUI | snapshot per component/state | Coverage not gated |

Plus: SwiftLint cyclomatic complexity ≤ 10 (warning) / 15 (error); function body ≤ 40 lines (warning) / 60 (error); file ≤ 300 (warning) / 500 (error).

### 7.2 UX quality rubric (1–5), hero flows

Hero flows: first run (Journey 1), hands-free reading (2), clicking by intent (3), staying in control (5). Scored by the human product owner in P5 and before release.

| Criterion | 5 means |
|---|---|
| Clarity | First-time user completes the flow without reading docs |
| Feedback | Every gaze/blink has an immediate, legible visual response |
| Trust | Zero unintended actions in a 10-minute session; easy off |
| Motion | Feels physical and calm; no jank at 120 Hz; reduced motion feels complete |
| Consistency | Tokens/components/copy match DESIGN_SYSTEM everywhere |
| Accessibility | VoiceOver and keyboard complete the flow; contrast verified |

Minimum to ship: average ≥ 4.0 per flow, no criterion < 3.

### 7.3 Perception & intent eval suites (`saccade-eval`)

| Suite | Dataset | Metric | Threshold | Blocking in CI? |
|---|---|---|---|---|
| Gaze accuracy | `v1/calibration+validation` | Median / p90 angular error after 20 s calibration | ≤ 2.0° / ≤ 3.5° | CI set: yes (≤ 2.2° on `ci`); release: yes on `v1` |
| Silent learning gain | `v1/implicit` | Median error improvement after 100 implicit samples | ≥ 25% vs calibration-only | release |
| Target lock — standard | `v1/arena-standard` | Correct lock rate (targets ≥ 44 pt) | ≥ 95% | yes |
| Target lock — dense | `v1/arena-dense` | Correct ≥ 85%; wrong-locked (not uncertain) ≤ 5% | as stated | yes |
| Lock stability | `v1/arena-jitter` | Lock changes per second under 0.5σ jitter | ≤ 1.0 | yes |
| Double-blink recall | `v1/blink-intended` | Fired / intended | ≥ 95% | yes |
| False clicks | `v1/reading-natural` (≥ 3 h total) | Clicks per 30 min with no intent | ≤ 1.0 | yes |
| Right-click recall | `v1/blink-long` | Fired / intended | ≥ 90% | release |
| Scroll precision | `v1/scroll` | Intended glides fired ≥ 95%; false glides ≤ 1 per 10 min | as stated | yes |
| Reading line tracking | `v1/reading-lines` | Fixations assigned within ±1 line | ≥ 90% | release |
| Subgroup disparity | all, by subgroup | Max − min target-lock rate | ≤ 5 pp | release |
| Latency (replay) | all | Pipeline compute p95 (excluding camera) | ≤ 15 ms on CI hardware (Linux job reports, macOS job gates) | macOS job |

The baseline is stored in `Evals/reports/baseline.json`. A change that regresses any metric by > 2 pp (or > 0.1°), even while still above threshold, fails CI unless the PR includes a human-approved baseline update.

## 8. Privacy & Compliance

**Data inventory**

| Data | Where | Retention | Deletion |
|---|---|---|---|
| Camera frames | RAM only, one frame | < 50 ms | automatic |
| Landmarks/features (live) | RAM | rolling 2 s window | automatic |
| Calibration features + targets | `profiles/*.json` | until deleted; implicit FIFO 400 | Reset learning / Delete all data |
| Settings, app rules | `settings.json` | until deleted | Delete all data |
| Daily summary (opt-in) | `metrics/*.json` → TelemetryDeck | ≤ 7 days local; TelemetryDeck retention per their policy | Opt-out deletes local; TelemetryDeck data is anonymous |
| Crash reports (opt-in) | Sentry | Sentry default (90 days) | Opt-out stops sending |
| Eval recordings (internal) | `Evals/datasets` (LFS) | project lifetime | Delete on participant request; consent forms stored offline |

- **Biometric note:** facial landmarks can be considered biometric data in some jurisdictions (e.g. Illinois BIPA, GDPR Art. 9 when used for identification). Saccade never uses them for identification and never transmits them; eval recordings are the only stored landmark data. **Legal review is required** before publishing the eval dataset or adding any cloud feature.
- **Consent:** in-app metrics are opt-in (GDPR-friendly default). Eval participants sign written consent describing landmark-only recording, its purpose, and deletion rights.
- **Privacy policy:** a short `PRIVACY.md` (P6.T5) mirrors this inventory and is linked from About and the README.
- **App Store privacy labels:** N/A (not on the App Store).

## 9. Change Control

| Change | Requires |
|---|---|
| New dependency, SDK, entitlement, permission, or network host | ADR + human approval |
| Telemetry schema or consent defaults | Human approval + PRIVACY.md update |
| Eval thresholds, `IntentConstants`, gesture timings | `saccade-eval` before/after report + human approval |
| Persisted format change | New migration step + migration test + ADR if non-additive |
| Module boundary change (ARCHITECTURE §3) | ADR + `check-architecture.sh` update |
| Releasing, signing, tap updates | Human executes or approves |
| PRD scope change | Human; update PRD + ROADMAP + TASK_LOG Decisions |

Breaking contract changes inside the app are allowed (single binary), but they must be done atomically in one PR together with the doc updates.
