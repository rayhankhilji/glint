# Glint — Design System

> Version: 1.0 · Updated: 2026-11-03 · Applies to GlintUI (overlay, menu bar, onboarding, calibration, settings, HUD). Tokens live in `Packages/GlintKit/Sources/GlintUI/DesignSystem/`.

## 1. Design Direction

**Personality:** luminous, calm, precise, quietly delightful. **Not** gamer-neon, not sci-fi HUD, not clinical, not cute.

Glint should feel like Apple built it and then added a little magic. The product *is* a light: a warm glint that knows what you mean. Everything else (windows, settings, menu) is restrained Apple-native glass, so the glint is the only thing that glows.

| Reference | What we take | What we leave |
|---|---|---|
| visionOS eye-tracking hover effect | A target lights up softly when looked at; the highlight hugs the element's real shape; no cursor | Its 3D depth cues |
| iPhone Dynamic Island | Fluid spring morphing between states; one living object that changes shape instead of separate popups | Black pill aesthetic |
| macOS 26 Liquid Glass + Control Center | Translucent glass surfaces, specular edge highlights, system typography, density | Overly busy refraction on small elements |
| A camera lens glint / sun on water | The click "flare": a brief warm star-burst | Literal lens-flare streaks across the screen |

**Principles**

1. **One light.** Only the glint (and its relatives: aura, edge glow, line marker) is warm and luminous. Chrome is neutral glass. *Implication:* the accent gold appears in chrome only for primary actions and selected states, never as decoration.
2. **Hug, don't point.** Feedback wraps the real element's shape. *Implication:* there's no cursor dot in production (the debug dot is Advanced-only), and the glint ring's corner radius matches the target.
3. **Anticipate, then act.** Every action has a visible build-up (armed brightening, dwell edge glow) so the user can abort by looking away. *Implication:* no action fires without a preceding visible state for ≥ 120 ms.
4. **Calm when uncertain.** Uncertainty is shown by softening (two faint rings, a wider aura), never by flicker. *Implication:* hysteresis and the uncertain state are part of the visual spec, not just the logic.
5. **Disappear when not needed.** When nothing is targeted, nothing renders. *Implication:* zero idle overlay pixels; the menu bar glyph is the only persistent presence.

## 2. Color Tokens

Two token groups: **Light tokens** for the overlay, which are appearance-independent because they sit on arbitrary content, and **Chrome tokens** for Glint's own windows, which have light and dark values. Components use semantic tokens only (`GlintColor.*`). Raw hex values appear only in `GlintColor.swift` and the asset catalog.

### 2.1 Light tokens (overlay)

The glint must read on both pure white and pure black. It is built from two layers: a warm **core** (reads on dark) and a thin dark **edge** hairline outside it (reads on light). Each layer clears 3:1 against the background it's designed for.

| Token | Value | Use | Verified contrast |
|---|---|---|---|
| `glint.core` | `#FFD98A` | 1.5 pt ring stroke, line marker | 15.5:1 on `#000000` |
| `glint.edge` | `#6B4300` @ 55% | 0.75 pt hairline outside the core | 8.65:1 (opaque) on `#FFFFFF` |
| `glint.halo` | `#FFC45C` @ 35% → 0% | Outer bloom, 10 pt radial falloff | decorative |
| `glint.armed` | `#FFE7B3` | Core when armed (brighter) | 16.9:1 on `#000000` |
| `glint.flare` | `#FFF6E0` | Flare shader peak color | decorative |
| `glint.uncertain` | `#FFD98A` @ 45% | Two faint rings | intentional low emphasis |
| `glint.aura` | `#FFC45C` @ 18% → 0% | No-AX gaze aura, radial | decorative |
| `glint.edgeGlow` | `#FFC45C` @ 0–40% | Scroll-zone dwell glow (alpha = progress × 0.4) | decorative |
| `glint.windowFlash` | `#FFD98A` @ 70% | Focus-switch window outline | 3:1+ via edge |
| `glint.ring.highContrast` | core `#FFB800`, edge `#000000` 1 pt, inner `#FFFFFF` 1 pt | Increase Contrast mode | 12.1:1 on black; 4.18:1 for `#B36B00` variant on white |
| `glint.debugDot` | `#FF3B6B` @ 80% | Debug gaze dot (Advanced only) | — |

### 2.2 Chrome tokens (Glint windows)

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F7F5F1` | `#161513` | Window background behind glass (fallback when Reduce Transparency is on) |
| `surface` | glass (`GlassSurface`) tint `#FFFFFF` @ 55% | glass tint `#2A2825` @ 55% | Cards, popover, HUD |
| `surfaceRaised` | `#FFFFFF` | `#22201D` | Sheets, inner cards |
| `border` | `#000000` @ 8% | `#FFFFFF` @ 10% | Hairlines (use sparingly) |
| `text` | `#1D1B18` | `#F4F1EA` | Primary text |
| `textMuted` | `#5E5A53` | `#A8A296` | Secondary text |
| `accent` | `#F2B544` | `#FFC85C` | Primary button fill, selected states, switch on |
| `onAccent` | `#241703` | `#241703` | Text/icon on accent |
| `accentText` | `#8A5A0B` | `#FFC85C` | Links, accent-colored text |
| `success` | `#1E7A3E` | `#6FD08C` | "Excellent/Good" accuracy, granted |
| `warning` | `#8A5A0B` | `#FFB454` | "Fair", low light |
| `danger` | `#B3261E` | `#FF8A80` | Denied, "Poor", destructive |
| `info` | `#1F5FAF` | `#8AB8FF` | Neutral notices |
| `focusRing` | `#B87503` | `#FFC85C` | Focus rings (3 pt, offset 2 pt); 3.45:1 / 11.9:1 |
| `overlayScrim` | `#000000` @ 35% | `#000000` @ 55% | Calibration backdrop under glass |

**Verified pairs (WCAG):** text/background 15.8 (L) / 16.2 (D); textMuted/background 6.3 / 7.2; accentText/background 5.4 / 11.9; onAccent/accent 9.6 / 11.4; danger 6.0 / 8.0; success 4.9 / 9.6; warning 5.4 / 10.4. All text pairs ≥ 4.5:1; UI and focus ≥ 3:1. Re-verify with `scripts/contrast.py` when changing a token.

## 3. Typography

System fonts only, loaded by the OS with no bundling: **SF Pro** (text and display, automatic optical sizes), **SF Pro Rounded** for numerals in accuracy/calibration readouts, and **SF Mono** for diagnostics. Fallback: the system handles it.

| Token | Size / line height | Weight | Tracking | Usage |
|---|---|---|---|---|
| `display` | 34 / 40 | semibold | -0.4 | Onboarding hero title |
| `title1` | 26 / 32 | semibold | -0.2 | Calibration result, step titles |
| `title2` | 20 / 26 | semibold | -0.1 | Settings section headers, popover state |
| `headline` | 15 / 20 | semibold | 0 | Card titles, row titles |
| `body` | 13 / 18 | regular | 0 | Default macOS body |
| `bodyEmphasis` | 13 / 18 | medium | 0 | Values, inline emphasis |
| `callout` | 12 / 16 | regular | 0 | Helper text under controls |
| `caption` | 11 / 14 | medium | +0.1 | Chips, metadata |
| `hud` | 13 / 16 | semibold | 0 | HUD capsule text |
| `numeric` | 28 / 32 | semibold rounded, tabular | -0.2 | Accuracy "1.4°", countdown |
| `mono` | 11 / 14 | regular SF Mono | 0 | Diagnostics |

Rules: use sentence case everywhere; tabular numerals for any changing number; max line length 60 ch in onboarding copy; support Dynamic Type equivalents via `.font(GlintFont.body)` mapping onto relative text styles so macOS accessibility text size changes apply.

## 4. Spacing, Layout & Grid

- **Base unit 4 pt.** Tokens: `xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · x3l 48 · hero 64`.
- **Windows:** Onboarding 720×520 fixed (content inset `xxl`). Settings 640×480 min, tab content inset `xl`, form rows 44 pt min height, label column 180 pt. Popover width 320, inset `l`, row gap `s`. HUD capsule height 36, horizontal padding `l`, max width 420.
- **Calibration:** full screen on the gaze display; anchors at 10%/50%/90% in both axes; the instruction card is centered at 50%/18%, max width 440.
- **Overlay geometry:** glint ring outset = 4 pt beyond the element frame; corner radius `= clamp(frame.height × 0.28, 6, 14) + 4`; minimum ring size 28×28 (small elements are padded symmetrically).
- **Density:** one density (macOS standard). No compact mode.

## 5. Shape, Elevation & Effects

| Token | Value |
|---|---|
| `radius.s` | 6 (chips, keycaps) |
| `radius.m` | 10 (buttons, fields, rows) |
| `radius.l` | 16 (cards, popover content blocks) |
| `radius.xl` | 24 (onboarding card, calibration instruction card) |
| `radius.capsule` | height / 2 (HUD, accuracy chip) |
| `border.hairline` | 0.5 pt `border` |
| `shadow.card` | L: `0 1 2 rgba(0,0,0,.06), 0 8 24 rgba(0,0,0,.08)` · D: `0 1 2 rgba(0,0,0,.4), 0 8 24 rgba(0,0,0,.35)` |
| `shadow.hud` | L: `0 6 20 rgba(0,0,0,.16)` · D: `0 6 20 rgba(0,0,0,.5)` |
| `glint.bloom` | Gaussian blur 10 pt on `glint.halo` layer + additive (`.plusLighter`) blend |

**Glass rules:** use `GlassSurface(style: .regular | .clear)`. On macOS 26+ it uses `.glassEffect(.regular, in: shape)`; on 14–15 it uses `.background(.ultraThinMaterial, in: shape)` plus a 0.5 pt top specular hairline `#FFFFFF @ 35%`. With Reduce Transparency it's an opaque `surfaceRaised`. Glass is used only on the popover, HUD, onboarding card, calibration card, and Settings sidebar. Never nest glass in glass.

**Z / window levels:** overlay `.statusBar + 1` · HUD `.statusBar + 2` · calibration `.screenSaver` · onboarding/settings `.normal`.

## 6. Motion

Motion communicates cause → effect and lets users abort. Animate `opacity`, `scale`, `offset`, and shader uniforms only. The overlay renders at the display refresh rate (ProMotion 120 Hz).

### 6.1 Tokens (`GlintMotion`)

| Token | Value | Use |
|---|---|---|
| `instant` | 80 ms | Armed brightening |
| `fast` | 140 ms | Glint acquire fade, chip changes |
| `base` | 220 ms | Popover rows, toggles |
| `slow` | 320 ms | Onboarding step content |
| `deliberate` | 520 ms | Glide scroll, hero transitions |
| `ease.standard` | cubic-bezier(0.2, 0, 0, 1) | Most UI transitions |
| `ease.enter` | cubic-bezier(0, 0, 0, 1) | Appearing elements |
| `ease.exit` | cubic-bezier(0.3, 0, 1, 1) | Leaving elements |
| `ease.glide` | cubic-bezier(0.22, 0.61, 0.36, 1) | Scroll glide (gentle start, long soft landing) |
| `spring.follow` | `.spring(response: 0.22, dampingFraction: 0.86)` | Glint moving between targets |
| `spring.acquire` | `.spring(response: 0.28, dampingFraction: 0.78)` | Glint scale-in 1.06 → 1.0 |
| `spring.snappy` | `.spring(response: 0.25, dampingFraction: 0.9)` | Toggles, tab indicator |
| `spring.gentle` | `.spring(response: 0.45, dampingFraction: 0.85)` | Onboarding layout, HUD entrance |
| `spring.calibration` | `.spring(response: 0.9, dampingFraction: 1.0)` | Calibration glint drifting between anchors (critically damped, smooth-pursuit friendly) |

### 6.2 Pattern catalogue

| Pattern | Spec | Reduced motion |
|---|---|---|
| **Glint acquire** | Ring opacity 0→1 (`fast`, `ease.enter`) + scale 1.06→1 (`spring.acquire`); halo fades in 60 ms later; one specular sweep (shader uniform 0→1, 420 ms, left→right) on first lock only | Opacity 0→1, 120 ms; no sweep |
| **Glint follow** | Frame (origin + size + corner radius) animates with `spring.follow`; the ring never fades out between adjacent targets | Cross-fade old→new 100 ms |
| **Armed** | Core → `glint.armed`, halo alpha +35%, `instant` | Same (color only) |
| **Flare (click)** | t=0: flare shader star (4 soft rays, 0→1→0 over 260 ms) centered on the ring; ring scale 1→1.12 + opacity 1→0 (260 ms, `ease.exit`); optional "tink" | Ring opacity pulse 1→0.4→1 (150 ms) |
| **Right-click** | Same as flare, but the rays rotate 45° and the ring contracts 1→0.94 before fading | Same as click (reduced) |
| **Reject** | Horizontal shake ±2 pt, 2 cycles, 180 ms; core dims to 60% for 200 ms | Opacity dip 1→0.5→1 (150 ms) |
| **Uncertain** | Two rings at the top-2 candidates, `glint.uncertain`, slow breathing opacity 0.35↔0.55 (1.6 s period) | Static 0.45 |
| **Aura (no-AX)** | Radial disc radius = sigmaPt, follows filtered gaze with `spring.follow` | Static disc, repositions with 100 ms fade |
| **Scroll dwell glow** | Edge gradient band 24 pt tall at the zone's edge, alpha = progress × 0.4, width = scroll area width, eased with `ease.enter` | Same (it's progress, not decoration) |
| **Glide** | Content scroll with `ease.glide` over `deliberate` (520 ms); the glow fades out over 200 ms as the glide starts | Glide 300 ms `ease.standard` (functional motion kept) |
| **At end nudge** | Glow pulses once, 4 pt band offset up/down (rubber band), 240 ms | Glow opacity pulse only |
| **Line marker ("where was I")** | 2 pt `glint.core` underline + bloom along the line rect; sweep L→R 450 ms (`ease.standard`), hold 600 ms, fade 600 ms (`ease.exit`) | Fade in 150 ms, hold 900 ms, fade 150 ms |
| **Window focus flash** | Window outline ring (radius 12) at 70% → 0 over 300 ms (`ease.exit`) | 150 ms fade |
| **HUD** | Enter: y −8→0 + opacity (`spring.gentle`); exit: opacity + scale 0.98 (180 ms, `ease.exit`); auto-dismiss 2.4 s; morphs width when replaced (`spring.snappy`) | Opacity only, 150 ms |
| **Onboarding steps** | Content slides x 24→0 + fade (`slow`, `ease.enter`); the hero glint is a `matchedGeometryEffect` that travels between steps | Cross-fade 150 ms |
| **Permission granted** | Checkmark draws (trim 0→1, 280 ms) + success tint; auto-advance after 600 ms | Instant check + fade |
| **Calibration glint** | Drifts between anchors with `spring.calibration`; a progress ring fills around it during each 1.2 s pause; it pops (scale 1→1.25→1, 200 ms) on anchor complete | Glint jumps with a 120 ms fade; ring fills (functional) |
| **Menu bar glyph** | Cross-fades between state glyphs (140 ms); when tracking, the glint dot "twinkles" once every 12 s (opacity 0.7→1→0.7, 600 ms) | No twinkle |

**Choreography rules:** at most one overlay animation family is "loud" at a time (flare beats sweep beats glow). The HUD never animates while a flare plays: it waits 260 ms. Staggers in lists use 30 ms per item, max 6 items.

**Performance:** shaders only on overlay layers ≤ the element ring bounds + 24 pt; no full-screen shader passes; the overlay must hold 120 fps on ProMotion with < 4 ms GPU per frame (check with the Metal HUD).

## 7. Iconography & Imagery

- **Icons:** SF Symbols, hierarchical rendering, `.medium` weight; sizes 13 (inline), 16 (rows), 20 (cards), 44 (onboarding permission hero).
- **App icon:** a rounded-square glass tile showing a stylized eye whose catchlight is a four-ray warm glint. Light and dark/tinted variants are required for macOS 26 icon styles (Icon Composer `.icon` file).
- **Menu bar glyph:** a custom template image (16×16 @1x/@2x): an eye outline with a small four-point sparkle at the upper right. States:
  | State | Glyph |
  |---|---|
  | Tracking | eye + filled sparkle (twinkles) |
  | Paused | eye + sparkle outline + small pause bars |
  | Off | eye outline only, 50% opacity |
  | Face lost / away | eye half-closed + sparkle outline |
  | Needs attention (permission/camera/calibration) | eye + small `!` badge (template, not colored) |
- **Illustration:** none beyond the glint itself. Empty states use a large SF Symbol in a soft glass circle plus the glint sparkle.
- **Imagery:** no stock photos. Onboarding visuals are live renders of the glint on sample UI (the Playground).

## 8. Components

All components live in `GlintUI/Components/`. Each has a snapshot test in light and dark and an accessibility label test.

| Component | Variants / sizes | States | Accessibility | Do / Don't |
|---|---|---|---|---|
| `GlassSurface` | `.regular`, `.clear`; any `Shape` | normal, reduce-transparency (opaque) | Container only | Do wrap whole cards. Don't nest. |
| `GlintButton` | `.primary` (accent fill), `.secondary` (glass), `.plain` (text), `.destructive`; sizes `regular` (32 h), `large` (40 h) | default, hover (+4% brightness), pressed (scale 0.98, `instant`), focus (focusRing), disabled (40% opacity), loading (inline `ProgressView` + label kept) | `.accessibilityLabel` = visible label; Return triggers `.primary` | One primary per view. Verbs: "Allow camera", not "OK". |
| `ToggleRow` | with/without subtitle | on, off, disabled (with reason subtitle) | Label + value "On/Off" | Don't use for actions. |
| `SliderRow` | continuous, stepped | default, dragging (live value label), disabled | Value announced with units ("300 milliseconds") | Always show the current value. |
| `PickerRow` | menu style | default, disabled | | Camera/display pickers show the device name and "(built-in)". |
| `ShortcutRow` | KeyboardShortcuts.Recorder wrapped | empty, recording, set, conflict (danger text) | Recorder is labeled | |
| `KeyCap` | s, m | — | Reads as "Control Option G" | Display only |
| `SettingsSection` | with header + footer text | — | Header is `.isHeader` | |
| `PermissionCard` | camera, accessibility | notDetermined, requesting, granted (check draw), denied, restricted, relaunchRequired | Status announced via `.accessibilityValue` | Explain *why* in one sentence before the button. |
| `AccuracyChip` | excellent, good, fair, poor, notCalibrated | — | "Accuracy: Good, 2.1 degrees" | Text + small dot; color is never the only signal (the text says the level). |
| `StepIndicator` | 5 steps | upcoming, current (accent capsule 20 pt wide), done | "Step 3 of 5, Calibrate" | |
| `ProgressRing` | 24, 64 | indeterminate, determinate | Value as percent | Calibration uses `glint.core` ring. |
| `HUDCapsule` | info, warning, success | entering, visible, replacing, exiting | Posted as an announcement (`NSAccessibility.post(… .announcementRequested)`) | ≤ 6 words + optional symbol. |
| `Banner` | warning, danger, info | with action, dismissible | Role alert | Popover top; one at a time, highest severity wins. |
| `EmptyState` | apps list empty, diagnostics empty | — | Title + description read | Symbol + one sentence + action. |
| `AppRuleRow` | off, scrollOnly | default, hover (shows remove), default-rule badge text "Default" | Row reads app name + mode | App icon 20 pt + name; mode `Picker`. |
| `PayloadViewer` | — | loading, empty ("Nothing sent yet"), list | Monospaced text selectable | JSON pretty-printed, SF Mono. |
| **Overlay:** `GlintRing` | locked, acquiring, armed, uncertain, flare, reject, highContrast | per §6 | Hidden from AX | Never draw a ring smaller than 28×28. |
| **Overlay:** `GazeAura`, `EdgeGlow`, `LineMarker`, `WindowFlash`, `DebugDot` | per §2.1 / §6 | per §6 | Hidden from AX | `DebugDot` is only available with Advanced → Debug gaze dot. |

## 9. Patterns & Screen Specs

### 9.1 Menu bar popover (F-10, F-11)

```text
┌──────────────────────────────── 320 ─┐
│ [Banner: Accessibility is off  Fix ] │  ← only if a problem exists
│ ✦ Glint                     [  ●  ]  │  ← title2 + main switch
│ Tracking · 30 fps                    │  ← textMuted status line
│ Accuracy  ● Good  2.1°   Recalibrate │  ← AccuracyChip + plain button
│ ──────────────────────────────────── │
│ Pause            15 min · 1 hr · ∞ ▸ │
│ Settings…                        ⌘,  │
│ Quit Glint                       ⌘Q  │
└──────────────────────────────────────┘
```

States: **on/tracking**; **off** (switch off, status "Off — camera is off"); **paused** (status "Paused · resumes 3:41 PM" + "Resume" button); **away** ("Waiting for you…"); **not calibrated** (chip "Not calibrated" + primary "Calibrate"); **permission missing** (danger banner + Fix; switch disabled); **camera missing** (warning banner "No camera found"); **low light** (warning status "Too dark to see your eyes"); **starting** (status "Starting…" with an inline spinner, ≤ 1.5 s). Keyboard: ⌘, settings, ⌘Q quit, Space toggles the switch when focused.

### 9.2 Onboarding window (F-01)

720×520 glass card on the desktop, StepIndicator at the top and the primary button bottom-right.

1. **Welcome:** a large hero glint drifting over a stylized paragraph that "glides". Title "Your Mac, at a glance." Body: "Glint follows your eyes to scroll and click — no hands needed. Everything stays on this Mac." Primary: "Get started".
2. **Camera:** PermissionCard (camera symbol). Copy: "Glint uses your camera to see where you're looking. Video never leaves your Mac and is never saved." States per PermissionCard. No-camera state: "Connect a camera or turn on Continuity Camera."
3. **Accessibility:** PermissionCard. Copy: "To scroll and click for you, Glint needs Accessibility access. Turn on Glint in the list, then come back." Buttons: "Open System Settings" (primary) and "I've turned it on". The relaunch-required state shows "Restart Glint".
4. **Calibrate:** a preview card ("20 seconds. Follow the glint with your eyes.") + primary "Start calibration" → full-screen calibration (§9.3).
5. **Playground:** a scrollable practice article (lorem-free: a short real explainer of how Glint works) with 3 buttons ("Shuffle color", "Like", "Next tip"). Live checklist: ☐ Glide down ☐ Double-blink a button ☐ Right-click (blink + long blink). It completes when the first two are done, then shows the opt-in metrics card (F-12): "Help improve Glint?" with "Share anonymous stats" and "No thanks" given equal weight, plus a "What's shared" link → PayloadViewer sample.
- Global states: quit/resume (re-enters at the persisted step); VoiceOver (each step's title + body announced on appear).

### 9.3 Calibration (F-03)

Full-screen scrim (`overlayScrim` + glass blur of the desktop) on the gaze display. The instruction card is at the top center.

| Step | Visual | Copy |
|---|---|---|
| Intro / waiting | Large glint at center, breathing | "Double-blink when you're ready." Subtext: "Sit like you normally do. Esc to cancel." |
| Collecting | The glint drifts to each anchor and its progress ring fills; completed anchors leave a faint dot | "Follow the glint." (count "3 of 9" in `caption`) |
| Face lost | The glint freezes and dims; the card shows a warning | "Look back at the screen to continue." |
| Validating | 5 quick glints, no ring | "Almost there — just look at each glint." |
| Result | `numeric` "1.8°" + AccuracyChip + one-line meaning ("Great for buttons and links.") + "Done" (primary) / "Try again" | Poor: "Let's try again with more light in front of you." with "Try again" as primary |
| Failed | Warning symbol | "Couldn't see your eyes clearly. Try more light in front of you." Buttons: "Try again", "Cancel" |

### 9.4 Settings (F-11, F-12)

Tabbed `Settings` scene with SF Symbol tab icons: General (`gearshape`), Gestures (`eye`), Scrolling (`arrow.down.to.line`), Apps (`square.grid.2x2`), Privacy (`hand.raised`), Advanced (`wrench.and.screwdriver`), About (`info.circle`).

- **General:** Launch at login (Toggle) · Shortcut (ShortcutRow) · Gaze display (Picker) · Camera (Picker; "Recalibrate for this camera" hint when changed).
- **Gestures:** Double-blink click (Toggle) · Blink sensitivity (Slider: "Fewer accidental clicks" ↔ "More responsive") · Right-click with blink + long blink (Toggle) · Focus follows gaze (Toggle) + Dwell (Slider 600–1500 ms) · Precise targets only (Toggle; footer explains).
- **Scrolling:** Glide scroll (Toggle) · Bottom zone size (10–25%) · Top zone size (5–20%) · Glide distance (25–60%) · Dwell (200–600 ms) · Live mini-preview (a small article mock with the zones tinted).
- **Apps:** table of AppRuleRows + "Add current app" + "Add app…" (NSOpenPanel for /Applications) + "Reset to defaults". Empty state (if all removed): "Glint works in every app."
- **Privacy:** Silent learning (Toggle) + "Reset learning" · Anonymous stats (Toggle) + "Show me exactly what's sent" (PayloadViewer sheet) · "Delete all Glint data…" (destructive with confirm dialog: "This removes your calibration and settings. Glint will start fresh.").
- **Advanced:** Diagnostics (live table in `mono`: fps, provider, latency p50/p95, sigma, confidence, AX timeouts/min) · Debug gaze dot (Toggle) · Demo capture mode (Toggle; footer: "Shows the glint in screenshots and recordings until Glint restarts.") · Export diagnostics… · Run setup again.
- **About:** icon, version (build), "Check for Updates…", acknowledgements (licenses list).

States: not calibrated (Gestures/Scrolling show an info banner "Calibrate to use gestures" + button); permission revoked (banner on every tab); camera missing (General shows the warning in the picker row).

### 9.5 Overlay (F-05–F-09)

Render-only states per §6.2. Order of precedence when several apply: flare > reject > armed > locked > uncertain > aura; edge glow and line marker can coexist with a ring; window flash suppresses the ring for its 300 ms.

### 9.6 Playground article

A 900-word explainer, "How Glint reads intent", set in `body` at 15 pt with a 64 ch measure, so first-time users actually read and trigger glide naturally.

### 9.7 HUD message catalogue

| Trigger | Style | Copy |
|---|---|---|
| Turned on (hotkey) | success | "Glint on" |
| Turned off | info | "Glint off" |
| Paused by gesture | info | "Paused — double-blink the ✦ to resume" |
| Resumed | success | "Glint resumed" |
| Face lost > 3 s while on | info | "Waiting for you…" (only once per 10 min) |
| Low light > 3 s | warning | "Too dark to see your eyes" |
| Camera interrupted | warning | "Camera paused by macOS" |
| Camera back | success | "Camera back" |
| Settings reset (corrupt) | warning | "Settings were reset" |
| Accuracy dropped (residual rise) | info | "Accuracy dipped — recalibrate?" (clickable → calibration) |

## 10. Content & Voice

- **Tone:** warm, plain, confident; second person; short. Glint speaks as "Glint", not "we", in UI.
- **Capitalization:** sentence case for everything, including buttons and window titles.
- **Buttons:** verb first ("Allow camera", "Start calibration", "Try again"). Never "OK" or "Submit".
- **Error formula:** what happened + what to do, ≤ 2 short sentences ("Couldn't see your eyes clearly. Try more light in front of you.").
- **Privacy statements** are literal and checkable ("Video never leaves your Mac and is never saved"). Never vague ("we care about privacy").
- **Numbers:** accuracy as degrees with one decimal ("1.8°"); durations in ms in settings and in seconds in prose; times in the user's locale format.
- **No jargon** in user UI: "accuracy" not "angular error"; "targets" not "AX elements". Diagnostics may use technical terms.

## 11. Accessibility

- Glint's UI meets WCAG 2.2 AA equivalents: contrast per §2 verified pairs; visible focus (3 pt `focusRing`, offset 2 pt) on every control; full keyboard operation of onboarding, popover, and settings (Tab/Shift-Tab, Space/Return, Esc closes sheets).
- VoiceOver: every control has a label, value, and hint where non-obvious; StepIndicator and PermissionCard expose status; HUD messages are posted as announcements; the calibration instructions are announced on each step change.
- Overlay windows are excluded from the AX tree and from screen capture (`sharingType = .none`), and never become key.
- Respect system settings: Reduce Motion (§6 reduced column), Reduce Transparency (opaque surfaces), Increase Contrast (`glint.ring.highContrast`, borders at 20%), Differentiate Without Color (accuracy chip text always present; state never color-only).
- Hit targets ≥ 28×28 pt in Glint UI.
- Coexistence: Glint never moves VoiceOver focus; with Voice Control running, Glint still works and announces nothing extra.

## 12. Responsive & Platform

- macOS only; pointer + keyboard + gaze. No touch.
- Windows are fixed-size or min-size; content reflows for larger accessibility text sizes (rows grow vertically, labels wrap, nothing truncates mid-word except file paths in diagnostics).
- Light/Dark follow the system appearance live; there's no in-app theme switch.
- Calibration and overlay adapt to any gaze display resolution and scale factor; geometry is computed in points.
- Full-screen apps and Spaces: the overlay joins all Spaces and full-screen spaces (`fullScreenAuxiliary`).

## 13. Implementation

- Tokens live in `Packages/GlintKit/Sources/GlintUI/DesignSystem/`: `GlintColor.swift` (with named colors in `Assets.xcassets` for light/dark), `GlintFont.swift`, `GlintSpacing.swift`, `GlintRadius.swift`, `GlintShadow.swift`, `GlintMotion.swift`, `GlassSurface.swift`. Shaders are in `App/Resources/Shaders/Glint.metal` (`glintSweep`, `glintFlare`, `glintBloom`), exposed through `ShaderLibrary` wrappers in GlintUI.
- **Adding a token:** add it to the Swift file + asset catalog, add a row to this doc's table in the same PR, verify contrast with `scripts/contrast.py` if it's a color, and update snapshots.
- **Visual testing:** swift-snapshot-testing for every component and screen state, in light and dark, with Reduce Motion on (static frames) at 1× and 2× scale. Overlay states are snapshotted from `GlintRing` previews with fixed frames.
- **Previews:** every view has `#Preview` blocks for each state, fed by fixture models in `GlintUI/PreviewFixtures/`.
