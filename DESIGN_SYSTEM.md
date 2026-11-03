# Glint — Design System

> Version: 2.0 · Updated: 2026-11-03 · Applies to GlintUI (overlay, menu bar, onboarding, calibration, settings, HUD). Tokens live in `Packages/GlintKit/Sources/GlintUI/DesignSystem/`.

## 1. Design Direction

**Personality:** clean, precise, quiet, fast. The bar is Linear and Notion: modern product software where nothing is decorative and every pixel is deliberate. **Not** gamer-neon, not sci-fi HUD, not a dashboard, no sparkles.

| Reference | What we take |
|---|---|
| Linear | Density (13 pt rows, 28 pt controls), hairline section dividers, a single indigo accent, status dots, keyboard shortcuts in faint text |
| Notion | Calm neutral pages, soft highlight for "where you are", plain words over badges |
| macOS / visionOS | SF Pro and SF Symbols, system materials, the hover highlight that hugs a target's real shape |

**Principles**

1. **One accent.** Indigo marks what matters: the primary action, the switch, selection, focus, the mark's catchlight and the overlay highlight. Everything else is neutral.
2. **No decoration.** No gradients, glows, blur halos or sparkles. `check-architecture.sh` bans gradient and blur APIs in GlintUI and App. Emphasis comes from weight, opacity and position.
3. **System-native.** SF Pro for type, SF Symbols for every UI icon. Only the brand mark and menu bar glyphs are custom.
4. **Hug, don't point.** The overlay highlights the real element's shape; there is no cursor dot in production.
5. **Anticipate, then act.** Every action has a visible build-up (armed highlight, dwell progress bar) so the user can abort by looking away (G-ML-03).
6. **Calm when uncertain.** Uncertainty shows as two faint rings, never flicker.

## 2. Color Tokens

All colors live in `Design/tokens.json`, the single source of truth. `scripts/design/build_tokens.py` compiles them to `GlintUI/DesignSystem/GlintColorTokens.swift` (appearance-aware `NSColor` providers, so the Swift package has no asset catalog), and `scripts/contrast.py` checks every documented pair (28/28 pass). Components use `GlintColor.*` only.

### 2.1 Chrome (Glint's windows)

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#FBFBFC` | `#0B0C0D` | Window background |
| `surface` | `#FFFFFF` | `#141516` | Raised surfaces |
| `subtle` | `#F3F4F6` | `#1B1C1E` | Row hover, inline callouts |
| `border` | `#0F1011` @ 6% | `#FFFFFF` @ 8% | Hairlines |
| `text` | `#0F1011` | `#EDEEF0` | Primary text |
| `textMuted` | `#6B6F76` | `#8A8F98` | Secondary text, row icons |
| `textFaint` | `#9A9DA3` | `#5E636B` | Shortcuts, placeholders (non-essential) |
| `accent` | `#5753D9` | `#8B8DF8` | Primary actions, switch, links, catchlight |
| `onAccent` | `#FFFFFF` | `#0B0C0D` | Text on accent |
| `accentSoft` | `#5753D9` @ 10% | `#8B8DF8` @ 12% | Selected rows |
| `success` | `#16794A` | `#4CC38A` | Tracking, good accuracy |
| `warning` | `#9A5B00` | `#F1A33C` | Paused, fair accuracy, low light |
| `danger` | `#C42B1C` | `#FF6B5E` | Blocked, poor accuracy |
| `focusRing` | `#5753D9` | `#8B8DF8` | Keyboard focus |
| `scrim` | `#000000` @ 35% | `#000000` @ 55% | Calibration backdrop |

### 2.2 Overlay (drawn over other apps)

Appearance-independent, because the overlay sits on arbitrary content. The ring color `#6366F1` clears 4.5:1 on pure white and 4.7:1 on pure black.

| Token | Value | Use |
|---|---|---|
| `overlayRing` | `#6366F1` | Target highlight ring, 1.5 pt; 2 pt when armed |
| `overlayFill` / `overlayFillArmed` / `overlayFillPress` | `#6366F1` @ 8% / 14% / 24% | Highlight fill: resting / armed / click flash |
| `overlayHairline` | `#FFFFFF` @ 70% | 1 pt inner hairline, separates the ring from indigo UI |
| `overlayUncertain` | `#6366F1` @ 45% | Two candidate rings, 1 pt |
| `overlayProgress` | `#6366F1` | Scroll-dwell progress bar, 2 pt |
| `overlayLineHighlight` | `#6366F1` @ 18% | "Where was I" line highlight |
| `overlayDebugDot` | `#FF3B6B` @ 80% | Debug gaze dot (Advanced only) |

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

**Glass rules:** use `GlassSurface(style: .regular | .clear)`. On macOS 26+ it uses `.glassEffect(.regular, in: shape)`; on 14–15 it uses `.background(.ultraThinMaterial, in: shape)` plus a 0.5 pt `border` hairline. With Reduce Transparency it's an opaque `surfaceRaised`. Glass is used only on the HUD, onboarding card and calibration card (the popover is already system glass). Never nest glass in glass.

**Z / window levels:** overlay `.statusBar + 1` · HUD `.statusBar + 2` · calibration `.screenSaver` · onboarding/settings `.normal`.

## 6. Motion

Motion communicates cause → effect and lets users abort. Animate `opacity`, `scale`, `rotation`, `offset`, stroke trim and stroke weight only. Every pattern below has an animated SVG study in `Design/Motion/` whose timings match these tokens; the studies are the motion spec. The overlay renders at the display refresh rate (ProMotion 120 Hz).

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

Each overlay pattern has an animated SVG study in `Design/Motion/` (written by `scripts/icons/author_motion.py`); the studies are the motion spec.

| Pattern | Spec | Reduced motion |
|---|---|---|
| **Target acquire** | Rounded-rect highlight 4 pt outside the element: 1.5 pt `overlayRing` + `overlayFill`, opacity 0→1 and scale 1.04→1 (140 ms, `ease.enter`). Study: `target-click.svg` | Opacity only, 120 ms |
| **Target follow** | Frame and corner radius animate with `spring.follow`; the highlight never fades out between adjacent targets | Cross-fade 100 ms |
| **Armed** | Ring 1.5→2 pt, fill → `overlayFillArmed`, 80 ms | Same |
| **Click** | Fill flashes to `overlayFillPress` (60 ms), then the highlight contracts 1→0.97 and fades (180 ms, `ease.exit`). Study: `target-click.svg` | Fill flash only |
| **Right-click** | Same as click, plus a 1 pt second ring 3 pt outside that fades with it | Fill flash only |
| **Reject** | Horizontal shake ±2 pt, 2 cycles, 180 ms | Opacity dip 1→0.5→1 |
| **Uncertain** | Two 1 pt `overlayUncertain` rings on the top two candidates, no fill | Same |
| **No-AX aura** | 1 pt `overlayRing` circle at 50% opacity, radius = sigmaPt, following gaze with `spring.follow` | Static, repositions with a fade |
| **Scroll dwell** | 2 pt `overlayProgress` bar fills along the scroll area's bottom edge over the 300 ms dwell, then fades (200 ms). Study: `glide-scroll.svg` | Same (functional) |
| **Glide** | Content scrolls 40% with `ease.glide` over 520 ms | 300 ms `ease.standard` |
| **At end** | The progress bar flashes once at full width and fades (240 ms) | Same |
| **Where was I** | `overlayLineHighlight` band behind the line, 4 pt radius, sweeps in left to right (450 ms), holds 600 ms, fades 600 ms. Study: `where-was-i.svg` | Fade in 150 ms, hold 900 ms, fade 150 ms |
| **Window focus** | 1.5 pt `overlayRing` outline on the window frame, fades over 300 ms | 150 ms fade |
| **Calibration** | A white 9 pt dot inside a 1.25 pt ring that tightens from 20 to 6 pt as samples are collected; drifts between anchors with `spring.calibration`. Study: `calibration.svg` | Dot jumps with a fade; ring still tightens |
| **Live mark** | `GlintMark(.live)`: every 8 s the catchlight swells 1→1.3→1 (500 ms). Study: `live-mark.svg` | Static |
| **Double blink** | `GlintMark(.doubleBlink)`: ring and catchlight squash toward the center twice (80 ms close, 120 ms open, 180 ms apart), then the catchlight pulses. Study: `double-blink.svg` | Static |
| **HUD** | Enter y −8→0 + opacity (`spring.gentle`); exit 180 ms; auto-dismiss 2.4 s | Opacity only |

**Choreography rules:** at most one overlay animation runs at a time (click beats progress bar beats acquire). The HUD never animates while a flare plays: it waits 260 ms. Staggers in lists use 30 ms per item, max 6 items.

**Performance:** the overlay draws vector paths only (no blur, no full-screen layers); the overlay must hold 120 fps on ProMotion with < 4 ms GPU per frame (check with the Metal HUD).

## 7. Iconography & Imagery

**UI icons are SF Symbols**, listed once in `GlintSymbol` (`GlintUI/Icons/GlintSymbol.swift`) and drawn with `GlintSymbolImage`: 12 pt medium in popover rows, 11 pt in callouts, 20 pt regular in empty states, system size in Settings tabs. Never use `Image(systemName:)` with a literal outside `GlintSymbol`.

| Use | Symbol |
|---|---|
| Pause / Resume | `pause` / `play` |
| Recalibrate | `scope` |
| Settings | `gearshape` |
| Quit | `power` |
| Callout | `exclamationmark.triangle.fill`, `info.circle.fill` |
| Settings tabs | `slider.horizontal.3`, `eye`, `arrow.down.to.line`, `square.grid.2x2`, `hand.raised`, `gauge.with.dots.needle.33percent`, `info.circle` |

**The mark** (`Design/Icons/mark.svg`): a ring (the eye) with a filled catchlight at its upper right. The ring takes `text`; the catchlight takes `accent`. Its parts (`ring`, `catchlight`) animate (§6.2).

**Menu bar glyphs** (`Design/MenuBar/menubar-<state>.svg`, 18 pt template images): the same ring with the state inside it.

| State | Glyph |
|---|---|
| Tracking | ring + catchlight |
| Paused | ring + two bars |
| Off | ring only, 50% opacity |
| Away | ring + a closed-lid line |
| Needs attention | ring + `!` |

`scripts/icons/build_icons.py` compiles the mark and menu bar SVGs into Swift vector data (`GlintIconData.swift`, CI `--check`).

**App icon** (`Design/AppIcon/glint-app-icon.svg`, rasterized by `scripts/icons/render-app-icon.mjs`): the mark at 30× on a flat near-black tile, with a 1.5 pt 9% white edge. Light/dark/tinted variants for Icon Composer are P5.T8.

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
| `AccuracyReadout` | excellent, good, fair, poor, notCalibrated | — | "Accuracy: Good, 2.1 degrees" | `StatusDot` + level word + degrees in tabular digits. No pill. |
| `StatusDot` | any semantic color | — | Hidden; always paired with text | 6 pt circle. |
| `GlintButtonStyle` | `.primary` (accent fill), `.secondary` (hairline), `.ghostAccent` (text) | default, pressed, disabled 40% | Visible label | 28 pt tall, 6 pt corners, no shadow. |
| `StepIndicator` | 5 steps | upcoming, current (accent capsule 20 pt wide), done | "Step 3 of 5, Calibrate" | |
| `ProgressRing` | 24, 64 | indeterminate, determinate | Value as percent | Calibration uses a white 1.25 pt ring (§6.2). |
| `HUDCapsule` | info, warning, success | entering, visible, replacing, exiting | Posted as an announcement (`NSAccessibility.post(… .announcementRequested)`) | ≤ 6 words + optional symbol. |
| `StatusBanner` | warning, danger, info | with action | Combined element | Inline callout on `subtle`, 6 pt corners, SF Symbol in the severity color, `.ghostAccent` action. One at a time. |
| `EmptyState` | any `GlintSymbol` | — | Title + description read | 20 pt symbol in `textFaint`, 13 pt title, one 12 pt sentence. |
| `GlintMark` | `.still`, `.live`, `.doubleBlink` | Reduce Motion → still | Hidden (decorative) | Popover header (live while tracking, 40% when off), About, onboarding. |
| `PopoverRow` | symbol + title + shortcut/chevron | default, hover (`subtle` fill), pressed, disabled (40%) | Button with identifier `glint.popover.<id>` | 28 pt tall, 6 pt corners, no scaling. |
| `AppRuleRow` | off, scrollOnly | default, hover (shows remove), default-rule badge text "Default" | Row reads app name + mode | App icon 20 pt + name; mode `Picker`. |
| `PayloadViewer` | — | loading, empty ("Nothing sent yet"), list | Monospaced text selectable | JSON pretty-printed, SF Mono. |
| **Overlay:** `GlintRing` | locked, acquiring, armed, uncertain, flare, reject, highContrast | per §6 | Hidden from AX | Never draw a ring smaller than 28×28. |
| **Overlay:** `GazeAura`, `EdgeGlow`, `LineMarker`, `WindowFlash`, `DebugDot` | per §2.1 / §6 | per §6 | Hidden from AX | `DebugDot` is only available with Advanced → Debug gaze dot. |

## 9. Patterns & Screen Specs

### 9.1 Menu bar popover (F-10, F-11)

```text
┌──────────────────────────── 300 ─┐
│ ◎  Glint                  [ ●]  │  ← GlintMark 22 (live while tracking) · 15 pt title · small switch
│    ● Tracking · 30 fps          │  ← StatusDot + 12 pt status line
│ [⚠ Glint can't act — …     Fix] │  ← StatusBanner, only for blocking problems
├──────────────────────────────────┤  ← 1 px hairline, full bleed
│ Accuracy           ● Good  2.1°  │  ← AccuracyReadout
├──────────────────────────────────┤
│  ⏸  Pause                     ›  │  ← 28 pt rows, 12 pt SF Symbols in textMuted
│  ◎  Recalibrate                  │
│  ⚙  Settings…               ⌘,   │  ← shortcuts in textFaint
├──────────────────────────────────┤
│  ⏻  Quit Glint              ⌘Q   │
└──────────────────────────────────┘
```

Status dot: green tracking, indigo starting, amber paused/away/low light/not calibrated, red blocked, faint off. The popover itself is the system menu-bar window (system material), so it has no custom background.

### 9.2 Onboarding window (F-01)

720×520 glass card on the desktop, StepIndicator at the top and the primary button bottom-right.

1. **Welcome:** a large hero glint drifting over a stylized paragraph that "glides". Title "Your Mac, at a glance." Body: "Glint follows your eyes to scroll and click — no hands needed. Everything stays on this Mac." Primary: "Get started".
2. **Camera:** PermissionCard (`camera` symbol; a `checkmark` replaces it when granted). Copy: "Glint uses your camera to see where you're looking. Video never leaves your Mac and is never saved." States per PermissionCard. No-camera state: "Connect a camera or turn on Continuity Camera."
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

Tabbed `Settings` scene with SF Symbol tabs (§7). About shows the live `GlintMark` (48 pt), the name and the version.

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

- Tokens live in `Packages/GlintKit/Sources/GlintUI/DesignSystem/`: `GlintColorTokens.swift` (generated) + `GlintColorSupport.swift`, `GlintFont.swift`, `GlintSpacing.swift`, `GlintRadius.swift`, `GlintShadow.swift`, `GlintMotion.swift`, `GlassSurface.swift`. Icons: `Design/Icons/*.svg` → `scripts/icons/build_icons.py` → `GlintUI/Icons/GlintIconData.swift` (generated) rendered by `GlintIcon`, `GlintMark`, `DrawOnIcon` and `GlintIconArtwork.templateImage` (menu bar, tabs). Motion studies: `Design/Motion/*.svg` (authored by `scripts/icons/author_motion.py`). The overlay draws vector paths in SwiftUI; no Metal shaders are needed for crisp light.
- **Adding a color:** add it to `Design/tokens.json` (and a contrast pair if it carries text), run `python3 scripts/design/build_tokens.py` and `python3 scripts/contrast.py`, add a row to §2, and update snapshots.
- **Visual testing:** swift-snapshot-testing for every component and screen state, in light and dark, with Reduce Motion on (static frames) at 1× and 2× scale. Overlay states are snapshotted from `GlintRing` previews with fixed frames.
- **Previews:** every view has `#Preview` blocks for each state, fed by fixture models in `GlintUI/PreviewFixtures/`.
