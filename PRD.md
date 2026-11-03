# Glint — Product Requirements

> Profile: Consumer desktop app (+ on-device ML / perception product) · Scope tier: MVP · Version: 1.0 · Updated: 2026-11-03

## 1. Summary

Glint is a native macOS menu-bar app that turns any Mac webcam into an intent-reading input device. It watches where you look and how you blink. It responds to your natural reading rhythm: it glides the page down when your eyes reach the bottom of what you're reading, and clicks the button you're looking at when you blink twice. It does not drive a jittery gaze cursor. A soft "glint" of light snaps to the real button or link you're looking at, using macOS Accessibility, so even a modest webcam feels precise. Everything runs on-device. Camera frames never leave the Mac, and there are no accounts. It is for anyone with a Mac: prosumers, heavy readers, the tech-Twitter crowd who want something that feels like magic, and people for whom hands-free input matters. The timing is right because Apple Silicon's Neural Engine can now run face-landmark models at camera frame rate for a few percent of one core, which makes always-on gaze input practical on a laptop.

## 2. Problem & Opportunity

- **Pain:** Reading long content means constant small hand movements (trackpad flicks, space bar, arrow keys) that break flow. They're also impossible when your hands are busy (eating, holding a coffee, taking paper notes, cooking with a recipe open) or limited (RSI, motor impairments).
- **Current workarounds and why they fail:**
  | Workaround | Why it fails |
  |---|---|
  | Dedicated IR eye trackers (Tobii etc.) | $150–$300+ extra hardware, Windows-first, poor macOS support, and they map gaze to a cursor, which is jittery and tiring. |
  | macOS Head Pointer / Eye Tracking accessibility features | Drive a pointer with dwell-click. Precise but slow and effortful, designed as a full mouse replacement rather than a reading companion. |
  | Webcam gaze libraries (WebGazer-style) | Browser-only, 4–6° error, map gaze straight to coordinates, so clicks miss. |
  | Auto-scroll extensions / teleprompter modes | Scroll at a fixed speed that doesn't follow the reader. |
- **Opportunity:** Combine (a) on-device face/iris landmarks, (b) per-user calibration that keeps improving silently, and (c) the Accessibility tree, which tells us where the real targets are. The result reads *intent* instead of raw coordinates. Raw webcam accuracy (~1.5–3°) can't match an IR tracker (~0.5°), but *effective* target-selection accuracy on real UI can feel equal or better because we snap to semantically real targets. That "it knew what I meant" moment is the product.

## 3. Target Users

| Persona | Context | Goals | Frustrations | Tech level | Primary device |
|---|---|---|---|---|---|
| **Maya — Power Reader (primary)** | Reads articles, docs, PDFs and threads 2–4 h/day; often reads while eating or note-taking | Read hands-free; never lose her place | Reaching for the trackpad mid-paragraph; losing her line after looking away | Medium–high | MacBook Air/Pro, built-in camera |
| **Dev — Tech Enthusiast** | Tries every new Mac utility; posts demos on X | A "how is this possible" experience worth sharing; tight polish | Gimmicks that break after day one; janky UI | High | MacBook Pro + Studio Display |
| **Sam — Hands-limited User** | RSI or limited fine motor control; uses Voice Control sometimes | Fewer hand movements for reading and basic clicking | Head-pointer setups are tiring; dwell-click is slow | Medium | MacBook / iMac |
| **Priya — Multitasker** | Several windows side by side (docs + editor + chat) | Keystrokes go to the window she's looking at | Typing into the wrong window | High | MacBook Pro, single display |

Primary persona: **Maya**. Design decisions favor calm, reliable reading assistance over a full mouse replacement.

## 4. Core User Journeys

1. **First run (time-to-magic < 90 s from first launch to first hands-free click)** — F-01, F-03, F-11
   1. Download the DMG, drag it to Applications, launch. The menu bar glint icon appears and the Welcome window opens.
   2. Welcome hero animation → "Let Glint see you": grant Camera → "Let Glint act for you": grant Accessibility (deep link to System Settings, auto-detects the grant).
   3. Calibration game (~20 s): double-blink to start, follow the drifting glint across 9 anchors, then a 5-point check shows the accuracy result.
   4. Playground: a practice article and three buttons. Reach the bottom and it glides; look at a button and double-blink and it clicks with a flare.
   5. Done: "Glint is on." Menu bar icon glows.
2. **Hands-free reading** — F-02, F-05, F-07, F-09
   1. Maya opens a long article in Safari and reads.
   2. When her gaze settles in the bottom 15% of the scroll area, a soft edge glow builds, and the page glides up 40% of the visible height.
   3. She looks away to her coffee for 10 s and comes back. Her last-read line glows briefly ("where was I").
3. **Clicking by intent** — F-02, F-05, F-06
   1. Maya finishes the article and looks at "Next chapter →". The glint wraps the link.
   2. She double-blinks. The glint flares, and the link activates via Accessibility press.
   3. She looks at a toolbar button and does blink + long blink. A context menu opens (right-click).
4. **Focus follows gaze** — F-08
   1. Priya has Notes on the left and Slack on the right. She stops typing and looks at Slack for ~0.9 s.
   2. The Slack window outline glints and Slack becomes key. She types her reply, and it lands in Slack.
5. **Staying in control** — F-10, F-11
   1. Dev presses ⌃⌥G and Glint turns off (camera off, icon hollow). He presses it again and Glint is back on.
   2. In 1Password, Glint is auto-paused by the default exclusion list.
   3. Sam pauses hands-free by looking at the menu bar icon and double-blinking.
6. **Silent improvement** — F-04
   1. Over the first day, every normal mouse click quietly adds a calibration sample.
   2. The accuracy chip in the menu bar popover moves from "Good" to "Excellent".

## 5. Features

### F-01 · Onboarding & permissions — Priority: P0
- **User story:** As a new user, I want a short, beautiful setup that explains why Glint needs my camera and Accessibility, so that I trust it and get to the magic fast.
- **Details:** Welcome window with 5 steps: Welcome → Camera → Accessibility → Calibrate (F-03) → Playground. Permission state is polled every 500 ms on the permission steps (`AVCaptureDevice.authorizationStatus`, `AXIsProcessTrusted`). The Accessibility step deep-links to `x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility`. Onboarding is resumable: quitting mid-way resumes at the first incomplete step. A completed onboarding never shows again unless the user picks "Run setup again" in Settings → Advanced.
- **States:** not-determined (primary CTA "Allow camera") · requesting · granted (check animates, auto-advance after 600 ms) · denied (explanation + "Open System Settings" + "I've changed it" re-check) · restricted (MDM: "Your organization blocks camera access", no CTA except Quit) · no camera found ("Connect a camera or enable Continuity Camera") · relaunch required (Accessibility on some macOS versions needs relaunch: "Restart Glint" button).
- **Acceptance criteria:**
  - F-01.AC1 — Given a fresh install, When the app launches, Then the Welcome window appears within 1 s and the menu bar icon is present.
  - F-01.AC2 — Given camera permission is denied, When the user is on the Camera step, Then the denied state is shown with "Open System Settings", and Continue stays disabled.
  - F-01.AC3 — Given the user grants Accessibility in System Settings while Glint is on the Accessibility step, When the next poll runs, Then the step shows granted within 1 s without a click.
  - F-01.AC4 — Given the user quits during the Calibrate step, When they relaunch, Then onboarding resumes at Calibrate.
  - F-01.AC5 — Given no camera device is available, When the Camera step is shown, Then the no-camera state is shown and the app does not crash or loop.
  - F-01.AC6 — Given onboarding completed, When the app launches again, Then no onboarding window is shown and tracking starts in the last persisted on/off state.
- **Dependencies:** F-03, F-11

### F-02 · Gaze engine — Priority: P0
- **User story:** As a user, I want Glint to know where I'm looking and when I blink, accurately and with low latency, so that every other feature feels instant and trustworthy.
- **Details:** Captures front camera frames (prefer 60 fps, accept 30 fps, 1280×720 preferred; any `AVCaptureDevice` of type built-in, external, or Continuity Camera). Runs face + iris landmarks on-device (ARCHITECTURE §10), extracts gaze features, maps them to a screen point in global display points using the active calibration (F-03/F-04), filters, and classifies events: `fixation`, `saccade`, `blink`, `faceLost`, `offScreen`. Every estimate carries an uncertainty radius `sigmaPt`. Works on one "gaze display" (default: the display containing the camera, i.e. the built-in display; user-selectable). Frames live only in memory and are dropped after landmark inference.
- **States:** off (camera off) · starting (≤ 1.5 s) · tracking · low confidence (dim light / occlusion: confidence < 0.6 for > 1 s) · face lost (no face > 1 s) · off-screen (gaze outside gaze display) · camera interrupted (device unplugged / used exclusively by another app) · model failed (fatal, shown in menu).
- **Acceptance criteria:**
  - F-02.AC1 — Given tracking at 30 fps on an M1 MacBook Air, When measured over 5 min, Then p95 frame-to-estimate latency ≤ 45 ms and app CPU ≤ 15% of one core on average.
  - F-02.AC2 — Given the replay dataset `Evals/datasets/v1` and a 20 s calibration, When `glint-eval` runs, Then median angular error ≤ 2.0° and p90 ≤ 3.5°.
  - F-02.AC3 — Given the user closes both eyes for 150 ms, When the frames are processed, Then exactly one `blink` event is emitted and no fixation or position jump is emitted during the closure.
  - F-02.AC4 — Given no face is visible for > 1 s, When the state updates, Then `faceLost` is emitted, no actions can fire, and the menu bar icon shows the face-lost state.
  - F-02.AC5 — Given the camera is unplugged while tracking, When the session is interrupted, Then the engine moves to camera-interrupted, shows the HUD message, and recovers automatically within 2 s of the camera reappearing.
  - F-02.AC6 — Given any run of the app, When the process's file writes and network requests are audited, Then no image or pixel-buffer data is written to disk or sent over the network (G-SEC-01).
- **Dependencies:** none (foundation)

### F-03 · Calibration game & validation — Priority: P0
- **User story:** As a new user, I want a quick, playful calibration so that Glint is accurate for my face, my glasses, and my desk.
- **Details:** Full-screen glass overlay on the gaze display. Steps: (1) "Double-blink to begin" captures the user's open/closed eye baseline and deliberate double-blink signature (durations, depths) used by F-06. (2) A glint drifts along a smooth path that pauses 1.2 s at each of 9 anchors (3×3 grid at 10%/50%/90%), collecting ≥ 20 samples per anchor during the pause, after the first 300 ms settle. (3) Validation: 5 new points (center + 4 at 25%/75%) shown for 1 s each. (4) Result card with accuracy level: Excellent (≤ 1.5°), Good (≤ 2.5°), Fair (≤ 3.5°), Poor (> 3.5° → "Let's try again" recommended; the user can still continue). Total ≤ 25 s. Esc or "Skip" exits at any point; skipping leaves the previous profile active (or none, in which case F-05/F-06/F-07 remain disabled with a "Calibrate to start" prompt). One profile per (camera uniqueID, display UUID) pair.
- **States:** intro · waiting-for-double-blink · collecting (progress ring around glint) · face lost mid-run (pause the path, "Look back at the screen", resume) · validating · result (4 levels) · failed (fewer than 6 anchors with enough samples → "Couldn't see your eyes clearly. Try more light.").
- **Acceptance criteria:**
  - F-03.AC1 — Given a visible face, When the user completes calibration without interruption, Then the total duration from double-blink to result card is ≤ 25 s.
  - F-03.AC2 — Given calibration completes, When the result is shown, Then the accuracy level shown equals the bucket of the validation median error, and the profile is persisted to disk within 1 s.
  - F-03.AC3 — Given the face is lost during collection, When the face returns, Then the path resumes at the interrupted anchor and no samples were collected while the face was lost.
  - F-03.AC4 — Given fewer than 6 anchors collected ≥ 20 valid samples, When collection ends, Then the failed state is shown and no profile is overwritten.
  - F-03.AC5 — Given the user presses Esc, When calibration is in any step, Then the overlay closes within 300 ms and the previously active profile is still active.
  - F-03.AC6 — Given VoiceOver is running, When calibration starts, Then each step's instruction is announced.
- **Dependencies:** F-02

### F-04 · Silent learning — Priority: P0
- **User story:** As a user, I want Glint to get more accurate on its own as I use my Mac normally, so that I never have to think about recalibrating.
- **Details:** While tracking, each physical left mouse-down (global monitor; posted events from Glint itself are ignored) becomes a candidate sample. The label is the click location. The features are the mean of the fixation ending 50 ms before the click. Accept only if: a fixation ≥ 150 ms was active, dispersion ≤ 1.0°, `|predicted − click| ≤ max(3·sigma, 150 pt)`, and confidence ≥ 0.8. Keep up to 400 implicit samples (FIFO) plus all explicit calibration samples. Weights: explicit 1.0; implicit 0.5 × recency decay (half-life 3 days). Refit in the background after every 20 new accepted samples. Swap in the new model only if leave-one-out error does not worsen by > 5%. A user toggle (default on) is in Settings → Privacy. "Reset learning" removes implicit samples.
- **States:** learning on (default) · learning off · refit in progress (invisible) · model improved (the accuracy chip updates silently; no toast).
- **Acceptance criteria:**
  - F-04.AC1 — Given 100 synthetic implicit samples drawn from a known offset bias of 60 pt, When the refits complete, Then median error on the replay set improves by ≥ 25% versus the calibration-only model.
  - F-04.AC2 — Given a click where the user was looking elsewhere (prediction 600 pt away), When the sample is evaluated, Then it is rejected and does not affect the model.
  - F-04.AC3 — Given a refit that worsens LOO error by > 5%, When it finishes, Then the old model stays active.
  - F-04.AC4 — Given learning is toggled off, When the user clicks, Then no samples are recorded.
  - F-04.AC5 — Given Glint posts a synthetic click (F-06), When the global monitor sees it, Then it is not recorded as a sample.
- **Dependencies:** F-02, F-03

### F-05 · Magnetic target snap & glint highlight — Priority: P0
- **User story:** As a user, I want a soft glint to wrap the actual button or link I'm looking at, so that I know exactly what a blink will click, even though webcams are imprecise.
- **Details:** At each fixation update (≤ 30 Hz), query the Accessibility tree around the gaze point within a search radius `r = clamp(2.5·sigmaPt, 40, 220) pt`. Candidates are elements with actionable roles (`AXButton`, `AXLink`, `AXMenuItem`, `AXMenuBarItem`, `AXCheckBox`, `AXRadioButton`, `AXPopUpButton`, `AXTab` or `AXRadioButton` inside `AXTabGroup`, `AXDisclosureTriangle`, `AXCell` with `AXPress`, `AXTextField`/`AXTextArea` for focus, `AXImage` with `AXPress`) that expose `AXPress` or are focusable text inputs, are enabled, and have a frame ≥ 12×12 pt. Score = Gaussian likelihood of the gaze under the element (distance to nearest point of the frame / sigma) × size prior × dwell prior. Hysteresis: a new candidate must beat the current one by ≥ 25% for ≥ 120 ms to take over. If the top-2 score margin < 15%, show the *uncertain* glint (two faint rings) and disarm clicking. The glint renders as a rounded-rect ring hugging the element frame (corner radius matched to element height) in a click-through overlay window. Elements in excluded apps or secure text fields (`AXSecureTextField`) never glint. If no AX targets are found (canvas apps, games), show the soft "gaze aura" (blurred disc of radius sigma). Clicks there are disabled by default ("Precise targets only" setting, default on).
- **States:** no target (no glint) · acquiring (glint fades in 140 ms) · locked (steady) · armed (first blink seen: glint brightens) · uncertain (two faint rings, not armed) · no-AX region (aura) · paused (nothing rendered).
- **Acceptance criteria:**
  - F-05.AC1 — Given the Eval Arena "standard targets" scene (targets ≥ 44 pt, ≥ 8 pt spacing) and a "Good" calibration, When a scripted gaze replay fixates each target, Then the correct target is locked for ≥ 95% of fixations.
  - F-05.AC2 — Given the "dense toolbar" scene (24–32 pt targets, 8 pt spacing), When replayed, Then the correct target is locked for ≥ 85% of fixations, and the wrong target is locked (not uncertain) for ≤ 5%.
  - F-05.AC3 — Given the gaze moves between two adjacent buttons with jitter of 0.5·sigma, When measured, Then the lock changes ≤ 1 time per second (no flicker).
  - F-05.AC4 — Given an AX query exceeds 50 ms, When the timeout hits, Then the previous lock is kept, the overlay stays at 60 fps, and the timeout is counted in diagnostics.
  - F-05.AC5 — Given the gaze is on a password field (`AXSecureTextField`), When candidates are computed, Then no glint is shown on it.
  - F-05.AC6 — Given a Chromium or Electron app, When Glint first targets it, Then Glint sets `AXManualAccessibility = true` on the app element once, and web content links become candidates.
- **Dependencies:** F-02, ARCHITECTURE AXService

### F-06 · Double-blink click & right-click gesture — Priority: P0
- **User story:** As a user, I want to click whatever the glint is on by blinking twice, so that I can act without touching anything, and never click by accident when I blink naturally.
- **Details:** A *blink* is both eyes' normalized closure ≥ the personal threshold (from F-03, default 0.6) for 2+ frames and 50–350 ms. A *double blink* is two blinks with a gap of 80–450 ms and a total pattern ≤ 900 ms. A *blink + long blink* (second closure 400–900 ms) is right-click. Gating, all required: (a) target locked (not uncertain) for ≥ 250 ms before blink 1; (b) the lock target is frozen at blink-1 onset; (c) after blink 2, gaze reopens within `max(1.5·sigma, 40 pt)` of the frozen target within 300 ms; (d) not paused, app not excluded; (e) no mouse button held. Action: `AXPress` on the element (`AXShowMenu` for right-click); if the element lacks the action, post a synthetic CGEvent click at the element's frame center, then restore the cursor. Feedback: the glint brightens at blink 1 (armed), flares at click (lens-flare pulse 260 ms). An optional soft "tink" sound is off by default. A cooldown of 500 ms follows every click.
- **States:** idle · armed (after blink 1 on a locked target) · fired · rejected (pattern broken, gaze moved, or uncertain lock → glint does a tiny 2 pt shake, no action) · cooldown.
- **Acceptance criteria:**
  - F-06.AC1 — Given a locked target and a deliberate double blink from the replay set, When processed, Then the target receives exactly one press within 120 ms of blink-2 end.
  - F-06.AC2 — Given 30 minutes of natural-reading replay (no intended clicks), When processed, Then ≤ 1 click fires.
  - F-06.AC3 — Given the intended double-blink replay set (≥ 300 samples across ≥ 10 people), When processed, Then ≥ 95% fire a click.
  - F-06.AC4 — Given the target is in the uncertain state, When the user double-blinks, Then no click fires and the rejected feedback plays.
  - F-06.AC5 — Given blink + long blink on a Finder file, When processed, Then the context menu opens (`AXShowMenu` or right-click fallback).
  - F-06.AC6 — Given an element without `AXPress`, When a double blink fires, Then a synthetic click lands at the frame center and the cursor returns to its prior position within 60 ms.
  - F-06.AC7 — Given a single long closure of 2 s (resting eyes), When processed, Then no click fires.
- **Dependencies:** F-02, F-03 (blink baseline), F-05

### F-07 · Zone-triggered glide scroll — Priority: P0
- **User story:** As a reader, I want the page to glide down when my eyes reach the bottom of what I'm reading, so that I can read continuously without touching anything.
- **Details:** The *scroll area* is the nearest `AXScrollArea` ancestor of the element at gaze; if there is none, the window content frame. **Down zone:** the bottom 15% of the scroll area's visible frame. **Up zone:** the top 10%. Trigger down: a fixation (not a passing saccade) inside the down zone accumulates dwell ≥ 300 ms. Trigger up: dwell ≥ 450 ms in the up zone, and only if the area is scrolled below its top. Glide: scroll by 40% of visible height (down) or 30% (up) over 520 ms with ease-out (DESIGN_SYSTEM motion `glide`), posted as a stream of continuous pixel scroll events at 120 Hz with scroll phases, located at the gaze point (cursor is not moved). Cooldown 700 ms. If the gaze is still in the zone after cooldown, glide again. Physical scroll, trackpad, or mouse movement suspends gaze scroll for 2 s. No scroll if the scroll area is at its end (AX scroll bar value ≥ 0.999). The dwell progress shows as an edge glow along the zone's edge.
- **States:** idle · dwelling (edge glow grows 0→100% over the dwell) · gliding · cooldown · at end (no glow; a subtle 4 pt rubber-band nudge animation once) · suspended (manual input) · unsupported area (no scroll bar found and no scroll response → falls back to no-op; diagnostics counter).
- **Acceptance criteria:**
  - F-07.AC1 — Given an article in Safari, When gaze fixates in the bottom 15% for 300 ms, Then the content scrolls by 40% ± 5% of the visible height within 600 ms.
  - F-07.AC2 — Given a saccade that crosses the bottom zone without a fixation ≥ 300 ms, When processed, Then no scroll occurs.
  - F-07.AC3 — Given the user scrolls with the trackpad, When gaze then enters the zone within 2 s, Then no gaze scroll fires.
  - F-07.AC4 — Given the scroll area is at its bottom, When gaze dwells in the down zone, Then no scroll events are posted.
  - F-07.AC5 — Given gaze dwells in the top 10% for 450 ms on a scrolled page, Then the content scrolls up by 30% ± 5%.
  - F-07.AC6 — Given scroll events are posted at the gaze location, When the mouse cursor is elsewhere, Then the cursor position is unchanged and the window under the gaze scrolls (compatibility matrix: Safari, Chrome, Arc, Notion, Slack, Mail, Preview PDF, VS Code, Finder).
- **Dependencies:** F-02, AXService, ActuationService

### F-08 · Gaze-to-focus windows — Priority: P1
- **User story:** As a multitasker, I want the window I look at to become the active one, so that my keystrokes go where I'm looking.
- **Details:** The window under gaze is found with `CGWindowListCopyWindowInfo` (on-screen, layer 0, topmost containing the point). If it differs from the focused window, and the gaze dwells on it ≥ 900 ms continuously, and no key was pressed for ≥ 1.5 s (`CGEventSource.secondsSinceLastEventType(.combinedSessionState, .keyDown)`), and no mouse button is down, and its app is not excluded, then raise and focus it (`AXRaise` + `NSRunningApplication.activate`). Feedback: the window outline glints for 300 ms. Never switches across Spaces or to minimized or hidden windows. Default **on**; toggle and dwell slider (600–1500 ms) are in Settings → Gestures.
- **States:** off · watching · dwelling (no visual until it fires) · switched (outline glint) · blocked (typing guard / excluded) silently.
- **Acceptance criteria:**
  - F-08.AC1 — Given two side-by-side windows and no typing for 2 s, When gaze dwells 900 ms on the unfocused window, Then it becomes the key window within 150 ms.
  - F-08.AC2 — Given the user typed 0.5 s ago, When gaze dwells on another window, Then focus does not change until 1.5 s after the last keystroke and a further 900 ms of dwell.
  - F-08.AC3 — Given the feature is off, When gaze dwells on another window, Then focus never changes.
  - F-08.AC4 — Given the target window belongs to an excluded app, When gaze dwells on it, Then focus does not change.
- **Dependencies:** F-02, F-10

### F-09 · "Where was I" reading marker — Priority: P1
- **User story:** As a reader, I want my last-read line to glow briefly when I look back, so that I never hunt for my place.
- **Details:** *Reading mode* is entered after ≥ 3 consecutive fixations progressing left-to-right within ±0.5 estimated line heights, followed by a return sweep. Glint tracks the current line rect: it uses AX text line bounds (`AXRangeForLine` + `AXBoundsForRange` parameterized attributes) when available; otherwise a band at gaze y with the estimated line height (default 22 pt). An *attention break* is face lost or off-screen for ≥ 2.0 s. On return within 10 min to the same window, with the content not scrolled (same AX element and frame, or the same window scroll position), show the marker: an underline glint sweeping left→right (450 ms), holding 600 ms, then fading over 600 ms. Text content is never stored; only rects.
- **States:** not reading · reading (no visual) · break detected · marker shown · marker skipped (content moved / > 10 min / different window).
- **Acceptance criteria:**
  - F-09.AC1 — Given reading mode on line N and a 5 s face-lost break, When the face returns to the same window, Then the marker renders on line N's rect within 200 ms.
  - F-09.AC2 — Given the page was scrolled during the break, When the user returns, Then no marker is shown.
  - F-09.AC3 — Given a break < 2 s (normal glance), When the user returns, Then no marker is shown.
  - F-09.AC4 — Given any reading session, When the persisted state is inspected, Then no AX text values were stored on disk or in logs.
- **Dependencies:** F-02, AXService

### F-10 · Activation & safety controls — Priority: P0
- **User story:** As a user, I want to turn Glint on and off instantly, have it step aside in sensitive apps, and pause it hands-free, so that I'm always in control.
- **Details:**
  - **On/Off:** menu bar popover toggle and global hotkey ⌃⌥G (rebindable via the KeyboardShortcuts library). Off = camera session stopped within 1 s.
  - **Pause actions (hands-free):** look at the Glint menu bar icon and double-blink → paused (camera stays on, only the resume gesture works); repeat to resume. Also available as "Pause for 15 min / 1 hour / until I resume" in the popover.
  - **Auto-pause:** no face for 5 s → camera drops to 5 fps "away" mode; it resumes automatically on face return. Screen lock, sleep, screensaver, or fast user switch → camera stops; it resumes on unlock if Glint was on.
  - **Per-app rules:** a list of bundle IDs with mode `off` (no gaze actions or glint at all in that app) or `scroll-only`. Defaults `off`: 1Password, Bitwarden, Keychain Access, `com.apple.loginwindow`, `com.apple.ScreenSaver.Engine`, `com.apple.systempreferences` Privacy pane (whole app). Users add apps via the "Add current app" button or an app picker.
  - **Manual input precedence:** any physical mouse/trackpad movement > 4 pt hides the glint for 1.2 s, and any physical scroll suspends gaze scroll for 2 s.
- **States:** on · off · paused (gesture/timer) · auto-paused (away) · suspended by secure context (lock/sleep) · excluded app (per-app rule active).
- **Acceptance criteria:**
  - F-10.AC1 — Given Glint is on, When the user presses ⌃⌥G, Then the camera session stops within 1 s and the icon shows off.
  - F-10.AC2 — Given Glint is on, When the user looks at the menu bar icon and double-blinks, Then Glint enters paused, and no click/scroll/focus action fires until the resume gesture or menu toggle.
  - F-10.AC3 — Given no face for 5 s, When auto-pause triggers, Then the capture rate drops to ≤ 5 fps, and Glint resumes to full rate within 1 s of the face returning.
  - F-10.AC4 — Given the frontmost app is 1Password, When gaze is on its window, Then no glint renders and no actions fire.
  - F-10.AC5 — Given the screen locks, When the lock event arrives, Then the camera session is stopped within 1 s.
  - F-10.AC6 — Given "Pause for 15 min" is chosen, When 15 min elapse, Then Glint resumes automatically.
- **Dependencies:** F-02, F-11

### F-11 · Menu bar app & settings — Priority: P0
- **User story:** As a user, I want a beautiful, minimal menu bar presence with clear settings, so that Glint stays out of my way but is easy to tune.
- **Details:** `LSUIElement` app (no Dock icon). Menu bar glyph with states (DESIGN_SYSTEM §8). The popover shows: on/off switch, status line, accuracy chip (Excellent/Good/Fair/Poor/Not calibrated), Recalibrate, Pause submenu, Settings…, Quit. The Settings window has tabs: General (launch at login via `SMAppService.mainApp`, hotkey, gaze display, camera picker), Gestures (click gesture info + sensitivity slider, right-click toggle, focus-follows-gaze toggle + dwell, precise-targets-only toggle), Scrolling (enable, zone sizes 10–25%, glide distance 25–60%, dwell 200–600 ms), Apps (per-app rules table), Privacy (silent learning toggle, reset learning, delete all data, metrics opt-in with "exactly what's sent" disclosure), Advanced (debug gaze dot for diagnostics, **Demo capture mode**: lets the overlay appear in screenshots/screen recordings for making demo videos, auto-resets to off on relaunch; run setup again, export diagnostics JSON (no images)), About (version, Check for Updates). All settings persist immediately (no Save button).
- **States per screen:** see DESIGN_SYSTEM §9; includes not-calibrated, permission-revoked (banner with fix CTA), and camera-missing states.
- **Acceptance criteria:**
  - F-11.AC1 — Given any setting is changed, When the app relaunches, Then the setting persists.
  - F-11.AC2 — Given Accessibility permission is revoked while running, When the popover opens, Then a "Glint can't act — Accessibility is off" banner with "Fix" is shown and all actions are disabled.
  - F-11.AC3 — Given "Delete all data" is confirmed, When it completes, Then profiles, samples, settings, and pending metrics are removed, and the app returns to onboarding.
  - F-11.AC4 — Given the Settings window, When navigated with the keyboard only, Then every control is reachable and operable, with a visible focus ring.
  - F-11.AC5 — Given launch at login is enabled, When the user logs in, Then Glint starts in its last on/off state.
  - F-11.AC6 — Given Demo capture mode is on, When a screen recording is made, Then the glint is visible in it; When Glint relaunches, Then Demo capture mode is off and the overlay is excluded from capture again.
- **Dependencies:** F-10, F-12, F-14

### F-12 · Opt-in anonymous metrics & crash reports — Priority: P1
- **User story:** As a privacy-conscious user, I want to optionally share anonymous accuracy and reliability numbers, so that Glint improves without ever seeing me.
- **Details:** Off by default. Asked once at the end of onboarding (a "Help improve Glint" card with "Share anonymous stats" and "No thanks" buttons; both have equal visual weight), and changeable in Settings → Privacy. When on: TelemetryDeck signals from the allowlisted schema only (ARCHITECTURE §8), batched as one `dailySummary` plus the funnel and calibration signals, and Sentry crash reports with no PII, no screenshots, no breadcrumbs containing AX labels or window titles. When off: no network calls except the Sparkle update check. "Show me exactly what's sent" opens a sheet with the last 7 payloads as JSON.
- **States:** never asked · opted out · opted in · sending (invisible) · send failed (silently retried next day; max 7 days of pending summaries, then dropped).
- **Acceptance criteria:**
  - F-12.AC1 — Given metrics are off, When the app runs for a day, Then zero requests are made to TelemetryDeck or Sentry hosts (verified by URLProtocol test + manual Little Snitch check).
  - F-12.AC2 — Given metrics are on, When a daily summary is built, Then the payload validates against the allowlisted schema and contains no strings except enum values.
  - F-12.AC3 — Given the user opts out after opting in, When the toggle changes, Then pending summaries are deleted and no further sends occur.
  - F-12.AC4 — Given metrics are on, When the "exactly what's sent" sheet opens, Then it shows the stored payloads byte-for-byte.
- **Dependencies:** F-11

### F-13 · Accessibility foundations — Priority: P0
- **User story:** As a user who relies on assistive tech, I want Glint to coexist with VoiceOver and Voice Control and respect my display preferences, so that it helps rather than conflicts.
- **Details:** All Glint windows are fully VoiceOver-labelled. The overlay window is excluded from the AX tree (`accessibilityElement = false`, hidden from VoiceOver). Glint never steals focus except via F-08. With Reduce Motion on, all motion follows the reduced spec (DESIGN_SYSTEM §6). Increase Contrast swaps the glint for a high-contrast ring token. Hit targets in Glint UI are ≥ 28 pt. Right-click gesture (F-06). An always-available pause (F-10). Dwell click, gaze typing, and drag are explicitly v2 (PRD §6).
- **States:** default · reduce motion · increase contrast · VoiceOver running (calibration instructions are spoken).
- **Acceptance criteria:**
  - F-13.AC1 — Given VoiceOver is on, When navigating onboarding, popover, and settings, Then every control has a meaningful label, role, and value (Accessibility Inspector audit has 0 issues).
  - F-13.AC2 — Given Reduce Motion is on, When the glint acquires, flares, or scrolls, Then only opacity fades ≤ 150 ms are used and no scale/sweep/flare motion plays.
  - F-13.AC3 — Given Increase Contrast is on, When the glint renders, Then it uses `glint.ring.highContrast` with ≥ 3:1 contrast against both white and black backgrounds.
  - F-13.AC4 — Given VoiceOver is running, When the overlay is present, Then VoiceOver never focuses or announces overlay elements.
- **Dependencies:** F-01, F-05, F-11

### F-14 · Distribution & updates — Priority: P0
- **User story:** As a user, I want to install Glint like a polished Mac app and get updates automatically, so that I trust it and stay current.
- **Details:** Developer ID-signed, hardened-runtime, notarized, stapled `.app` in a DMG with a custom background (drag-to-Applications). Sparkle 2 auto-updates with EdDSA-signed appcast over HTTPS; check daily; "Check for Updates…" is in About. Homebrew cask in a personal tap (`brew install --cask <tap>/glint`). The app moves itself to /Applications on first launch if run from the DMG or Downloads (prompt).
- **States:** up to date · update available (Sparkle standard UI, restyled copy) · downloading · ready to install · update failed (silent retry; the error is only shown on manual check).
- **Acceptance criteria:**
  - F-14.AC1 — Given a release build, When `spctl --assess --type execute -vv Glint.app` runs, Then it reports "accepted" with source "Notarized Developer ID".
  - F-14.AC2 — Given version N installed and N+1 published to the appcast, When the user chooses Check for Updates, Then Sparkle offers N+1 and installs it, preserving settings and permissions.
  - F-14.AC3 — Given a tampered update archive, When Sparkle validates it, Then installation is refused (EdDSA mismatch).
  - F-14.AC4 — Given the cask is published, When `brew install --cask` runs on a clean Mac, Then Glint installs and launches.
- **Dependencies:** none

### F-15 · Eval Arena & replay harness (internal) — Priority: P0
- **User story:** As the builder (human or agent), I want reproducible accuracy measurements from landmark-only recordings, so that every change to the gaze or intent pipeline is judged by numbers, not vibes.
- **Details:** A debug-only "Eval Arena" window shows scripted scenes (standard targets, dense toolbar, reading article, scroll page, blink drills). It records **landmark-only** JSONL traces (no images) together with ground-truth target and timing labels, after explicit consent from each recorded participant. `glint-eval` (SwiftPM executable) replays traces through the exact production pipeline and outputs metrics JSON + a Markdown report. CI runs it against `Evals/datasets/v1` and fails if thresholds in EVAL_GUARDRAILS §7 regress.
- **States:** arena idle · recording · saving · replay passing · replay failing (diff report).
- **Acceptance criteria:**
  - F-15.AC1 — Given a recorded trace, When replayed twice, Then metric outputs are bit-identical (deterministic).
  - F-15.AC2 — Given a trace file, When inspected, Then it contains only numeric landmark, feature, and label data and no image data (schema-validated).
  - F-15.AC3 — Given a pipeline change that lowers target-lock accuracy by > 2 percentage points, When CI runs `glint-eval`, Then the job fails with a diff report.
- **Dependencies:** F-02, F-05, F-06, F-07

## 6. Out of Scope

Agents must not build these in v1.

| Item | Reason |
|---|---|
| Browser extension, Windows, Linux, ChromeOS | v1 is a native macOS app (the user pivoted from extension to OS-wide Mac app). |
| Intel Macs, macOS < 14 | Neural Engine needed for latency and energy budgets; modern SwiftUI APIs. |
| Dedicated IR eye-tracker support (Tobii) | Webcam-only product; keep the `LandmarkProvider` seam but no implementation. |
| Multi-monitor gaze across displays | Needs per-display calibration and geometry; v2. Glint works on one chosen gaze display. |
| Gaze typing, on-screen keyboard, drag-and-drop, dwell click | Full hands-free mode is v2 (accessibility foundations only in v1). |
| Key-hold-to-click, wink, eyebrow gestures | Only double blink (+ blink-long-blink for right-click) in v1 for a single, learnable gesture. |
| Any LLM/AI cloud feature, BYOK keys | Fully local product. |
| Accounts, cloud sync, settings sync | No accounts; local only. |
| Storing or transmitting camera frames or video, even for debugging | Hard privacy rule G-SEC-01. |
| Mac App Store build | The sandbox forbids the system-wide event posting and AX control Glint needs. |
| Payments / licensing | Free for now; keep no licensing code. |
| iOS / iPadOS / visionOS | Different input model; not planned. |
| Custom-trained gaze neural network | Effective-accuracy approach chosen; research track deferred (backlog). |
| Marketing website beyond a GitHub Releases page + README | Launch uses GitHub Releases; a site is backlog. |

## 7. Success Metrics

Measured only for users who opted in (F-12) via TelemetryDeck, and in the internal eval harness (F-15).

| Metric | Definition (exact signal / query) | Target | Tool |
|---|---|---|---|
| **North star: hands-free actions per active day** | Sum of `dailySummary.clicks + dailySummary.scrolls + dailySummary.focusSwitches` / count of `dailySummary` signals | ≥ 40 by week 4 | TelemetryDeck |
| Activation | % of `onboarding.completed` installs that emit `dailySummary` with `clicks ≥ 1` within 24 h | ≥ 60% | TelemetryDeck |
| Onboarding completion | `onboarding.completed` / `onboarding.started` | ≥ 75% | TelemetryDeck |
| D7 retention | % of installs with `dailySummary.trackingMinutes ≥ 10` on day 7 (±1) | ≥ 35% | TelemetryDeck |
| Calibration quality | Median `calibration.completed.errorBucket` | "good" or better for ≥ 70% | TelemetryDeck |
| False-click proxy (quality guardrail) | `dailySummary.clickRevertProxy / dailySummary.clicks` (revert = ⌘Z, Esc, or ⌘[ within 3 s after a gaze click) | ≤ 5% | TelemetryDeck |
| Latency guardrail | `dailySummary.p95LatencyMsBucket` | ≤ "50" bucket for ≥ 90% of days | TelemetryDeck |
| Crash-free sessions | Sentry crash-free session rate | ≥ 99.5% | Sentry |
| Offline accuracy (release gate) | `glint-eval` metrics on `Evals/datasets/v1` | Thresholds in EVAL_GUARDRAILS §7 | CI |

## 8. Non-Functional Requirements

- **Platform:** macOS 14.0+ on Apple Silicon (M1+) only. Built with the current stable Xcode (26.x or newer) in Swift 6 language mode.
- **Performance:** frame→overlay p95 ≤ 50 ms; blink-2 end → click ≤ 120 ms; overlay render at the display refresh rate (60/120 Hz) with no dropped frames during glint motion; average CPU ≤ 15% of one core at 30 fps (M1); memory ≤ 250 MB resident; Energy Impact "Low" in Activity Monitor while tracking; away mode ≤ 3% CPU.
- **Reliability:** crash-free sessions ≥ 99.5%; the camera pipeline self-heals from interruptions within 2 s; no action ever fires while confidence < 0.6 (fail safe: false negatives over false positives).
- **Privacy:** frames are processed in memory and dropped; only numeric calibration features are persisted; metrics are opt-in; no network except Sparkle (daily) and opted-in telemetry.
- **Accessibility:** Glint's own UI meets WCAG 2.2 AA equivalents on macOS (contrast, focus, labels, keyboard operability); respects Reduce Motion, Increase Contrast, and Reduce Transparency.
- **Localization:** English only in v1; all strings go in a String Catalog (`Localizable.xcstrings`) so localization is additive.
- **Environment:** works at 40–90 cm from the camera, head rotation within ±25° yaw / ±20° pitch, room light ≥ ~50 lux; works with most glasses (excluding strongly reflective coatings).
- **Data retention:** calibration profiles until deleted; implicit samples capped at 400 FIFO; pending metric payloads ≤ 7 days; diagnostics exports only on user action.

## 9. Assumptions

| # | Assumption | Reasoning | How to change |
|---|---|---|---|
| A1 | Raw webcam gaze accuracy will be ~1.5–3°; "better than a dedicated tracker" is pursued as *effective* target-selection accuracy, not raw angular error. | IR trackers measure the pupil with active illumination; RGB webcams can't match that physically. Snapping + calibration closes the gap for real UI. | If a research track is approved, add backlog item B-03 (custom model) to a phase. |
| A2 | Landmarks come from MediaPipe Face Landmarker (Apache-2.0) models run via ONNX Runtime with the Core ML execution provider; Apple Vision is the fallback provider. | Iris landmarks + blendshapes are best-in-class and permissively licensed; Vision has no iris landmarks. The P1 spike decides by numbers (ADR-002). | Change ADR-002 after the spike. |
| A3 | Glint is free and closed-source for now; distributed via GitHub Releases. | User chose free + notarized DMG; open-sourcing is undecided. | See Open Question Q1. |
| A4 | Focus-follows-gaze defaults **on** with a 900 ms dwell and typing guard. | User selected it for v1; conservative thresholds avoid surprise. | Flip `focusFollowsGaze.defaultEnabled` in `SettingsDefaults`. |
| A5 | Right-click gesture = blink + long blink (400–900 ms second closure). | Needs a hands-free right-click for accessibility foundations without a second facial gesture. | Update F-06 and `BlinkGrammar`. |
| A6 | Hotkey default ⌃⌥G. | Rarely bound by other apps; G for Glint; rebindable. | `SettingsDefaults.toggleShortcut`. |
| A7 | Opted-in metrics go to TelemetryDeck; crash reports to Sentry under the same consent. | User chose a privacy-first service; Sentry is the de facto Cocoa crash reporter and supports PII-off. | Remove Sentry by deleting the `CrashReporter` module (no other code depends on it). |
| A8 | One gaze display; other displays are "off-screen". | Multi-monitor deferred. | Backlog B-01. |
| A9 | English only. | MVP scope. | Add locales to the String Catalog. |

## 10. Risks & Mitigations

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| MediaPipe models fail to convert or run efficiently via ONNX Runtime | Medium | High | P1.T3 spike with a numeric decision rule (ADR-002); Apple Vision fallback provider; TFLite C API as a third option. |
| Natural blinks trigger false clicks | Medium | High | Personal blink signature, armed-target gating, gaze-return check, ≤ 1 false click / 30 min eval gate. |
| AX trees missing or slow in some apps (Electron, Chrome, canvas apps) | High | Medium | `AXManualAccessibility`, 50 ms timeouts, cached subtrees, aura fallback, compatibility matrix in P5. |
| Posted scroll events go to the window under the cursor, not under the gaze | Medium | High | P3.T7 spike; fallback to AX scroll-bar value stepping (ADR-005). |
| Low light, glasses glare, backlit users | High | Medium | Confidence gating, HUD guidance ("Add light in front of you"), eval subsets for glasses/dim light. |
| Battery drain perceived as high | Medium | Medium | 30 fps default on battery, away mode, ANE inference, energy tests in P5. |
| Users are uneasy about an always-on camera | Medium | High | Clear onboarding copy, the macOS green camera indicator, one-tap off, no frames stored, open telemetry payload viewer. |
| Calibration drifts as the user changes posture | High | Medium | Silent learning (F-04), head-pose-aware mapping, "accuracy dropped — quick recalibrate?" nudge when validation residuals rise. |

## 11. Open Questions

| ID | Question | Owner | Default if unanswered | Decide by |
|---|---|---|---|---|
| Q1 | Open-source the app (MIT) or keep the repo private? | Product owner | Private repo; releases published to a separate public repo `glint-releases` | P6 |
| Q2 | Final product name, domain, and Developer ID team? | Product owner | "Glint"; no domain; personal Developer ID | P0 (team ID needed for signing) |
| Q3 | Who records the v1 eval dataset (≥ 10 consenting participants, varied glasses/skin tones/lighting)? | Product owner | Founder + friends using the Eval Arena protocol in TESTING_GUIDE §4 | P2 |
| Q4 | Should the click "tink" sound default on for discoverability? | Design | Off | P5 |

## 12. Glossary

| Term | Meaning |
|---|---|
| Glint | The soft light highlight that wraps the current target; also the product. |
| Gaze display | The single display Glint tracks gaze on. |
| sigma (`sigmaPt`) | Current gaze uncertainty radius in points (1σ). |
| Fixation / saccade | A stable gaze period / a rapid eye movement between fixations. |
| Lock | The current snapped target element. |
| Armed | State after the first blink of a double blink on a locked target. |
| AX | macOS Accessibility API (`AXUIElement`). |
| Profile | Calibration model + samples for one camera × display pair. |
| Implicit sample | A calibration sample captured from a normal mouse click (F-04). |
| Pt | macOS points (logical pixels), global display coordinates with top-left origin. |
