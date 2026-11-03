# Glint — Design System

> Version: 1.1 · Updated: 2026-11-03 · Applies to GlintUI (overlay, menu bar, onboarding, calibration, settings, HUD). Tokens live in `Packages/GlintKit/Sources/GlintUI/DesignSystem/`.

## 1. Design Direction

**Personality:** precise, calm, luminous, quietly delightful. **Not** gamer-neon, not sci-fi HUD, not a dashboard, not cute.

Glint is an optical instrument for your attention. Its chrome is ink on paper (and paper on ink): a cool, near-monochrome neutral with system typography and hairlines. Against that restraint there is exactly **one light**, the warm glint, which appears only where Glint is actually pointing at something or is itself the subject (the mark, the catchlight in the app icon). Light is drawn as crisp vector geometry, never as glows, blooms or gradients.

| Reference | What we take | What we leave |
|---|---|---|
| visionOS eye-tracking hover | The target lights up when looked at, hugging the element's real shape; no cursor | Depth cues, soft blooms |
| Precision instruments (camera viewfinders, rangefinder focus marks) | Corner brackets, thin rules, exact geometry that reads as measurement | Skeuomorphic texture |
| iPhone Dynamic Island | One living object that morphs between states with springs | The black pill |
| A catchlight in a portrait | The glint as a four-point star of light, crisp edged | Lens-flare streaks |

**Principles**

1. **One light.** Gold (`glint.*`, `glintMark`) is reserved for light: the overlay glint, the brand mark's sparkle, the app icon's catchlight and the focus ring (focus is attention). Everything else is ink and paper. *Implication:* primary buttons and switches are ink (light mode) or paper (dark mode), never gold.
2. **Light is geometry.** No decorative gradients, radial glows, blur halos or "AI shimmer". *Implication:* `LinearGradient`, `RadialGradient`, `AngularGradient`, `NSGradient`, `CAGradientLayer` and `.blur(radius:)` are banned in GlintUI and App by `scripts/check-architecture.sh`. Emphasis comes from stroke weight, opacity and motion.
3. **Hug, don't point.** Feedback wraps the real element's shape; there's no cursor dot in production.
4. **Anticipate, then act.** Every action has a visible build-up (armed brightening, dwell progress line) so the user can abort by looking away; no action fires without ≥ 80 ms of anticipation (G-ML-03).
5. **Calm when uncertain.** Uncertainty is shown by softening (two faint rings, a dashed aura), never by flicker.
6. **Own the details.** Brand-defining glyphs are custom (§7): menu bar, popover, Settings tabs, states. SF Symbols appear only inside system-provided controls.
7. **Disappear when not needed.** When nothing is targeted, nothing renders.

## 2. Color Tokens

Two token groups: **Light tokens** for the overlay, which are appearance-independent because they sit on arbitrary content, and **Chrome tokens** for Glint's own windows, which have light and dark values. Components use semantic tokens only (`GlintColor.*`). Raw hex values appear only in `GlintColor.swift` and the asset catalog. All colors are solid (principle 2).

### 2.1 Light tokens (overlay)

The glint must read on both pure white and pure black. It is built from two solid layers: a warm **core** stroke (reads on dark) and a thin dark **edge** hairline outside it (reads on light). Each layer clears 3:1 against the background it's designed for.

| Token | Value | Use | Verified contrast |
|---|---|---|---|
| `glint.core` | `#FFD98A` | 1.75 pt ring stroke, line marker, dwell progress line | 15.5:1 on `#000000` |
| `glint.edge` | `#6B4300` @ 55% | 3.5 pt hairline under the core (0.875 pt shows on each side) | 8.65:1 (opaque) on `#FFFFFF` |
| `glint.armed` | `#FFE7B3` | Core when armed (stroke 1.75 → 2.25 pt) | 16.9:1 on `#000000` |
| `glint.flare` | `#FFF6E0` | Flare star fill (vector, 260 ms) | decorative |
| `glint.uncertain` | `#FFD98A` @ 45% | Two faint rings | intentional low emphasis |
| `glint.aura` | `#FFD98A` @ 70% | No-AX aura: 1.5 pt **dashed** ring (3/4 pt), radius = sigma | decorative |
| `glint.progress` | `#FFD98A` | 2 pt scroll-dwell progress line along the zone edge | 15.5:1 on `#000000` |
| `glint.windowFlash` | `#FFD98A` @ 70% | Focus-switch window outline | 3:1+ via edge |
| `glint.ring.highContrast` | core `#FFB800`, edge `#000000` 1 pt, inner `#FFFFFF` 1 pt | Increase Contrast mode | 12.1:1 on black; 4.18:1 for `#B36B00` variant on white |
| `glint.debugDot` | `#FF3B6B` @ 80% | Debug gaze dot (Advanced only) | — |

### 2.2 Chrome tokens (Glint windows)

A cool optical neutral (slight blue bias, never warm cream). Actions are ink on paper; gold is reserved for light.

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#F6F7F8` | `#0E0F11` | Window background (fallback when Reduce Transparency is on) |
| `surfaceTint` | `#FFFFFF` @ 62% | `#1A1C1F` @ 62% | Glass tint |
| `surfaceRaised` | `#FFFFFF` | `#17181B` | Banners, sheets |
| `border` | `#0B0C0E` @ 9% | `#FFFFFF` @ 10% | Hairlines, row hover fill |
| `text` | `#111214` | `#ECEDEF` | Primary text and icons |
| `textMuted` | `#5B5F66` | `#9A9EA6` | Secondary text, row icons |
| `accent` | `#111214` | `#ECEDEF` | Primary button fill, switch on (ink / paper) |
| `onAccent` | `#FFFFFF` | `#0E0F11` | Text on accent |
| `accentText` | `#111214` | `#ECEDEF` | Text actions (always underlined or medium weight) |
| `success` | `#1B7A43` | `#5FD28A` | Excellent/Good accuracy, granted |
| `warning` | `#8C5800` | `#F5B04A` | Fair, low light |
| `danger` | `#BE2A20` | `#FF7A70` | Denied, Poor, destructive |
| `info` | `#2457C5` | `#8AB1FF` | Neutral notices |
| `focusRing` | `#A86A00` | `#FFC85C` | Focus rings (3 pt, offset 2 pt): attention is the glint's job |
| `glintMark` | `#A86A00` | `#FFC85C` | The mark's sparkle in chrome |
| `overlayScrim` | `#000000` @ 35% | `#000000` @ 55% | Calibration backdrop |

**Verified pairs (WCAG, `scripts/contrast.py`, 28/28 pass):** text/background 17.5 (L) / 16.4 (D); textMuted/background 6.0 / 7.1; onAccent/accent 18.7 / 16.4; danger 5.5 / 7.6; success 5.0 / 10.1; warning 5.6 / 10.2; info 6.0 / 9.0; focusRing and glintMark on background 4.1 / 12.5 and on surfaceRaised 4.4 / 11.6. Text pairs ≥ 4.5:1; UI, focus and graphics ≥ 3:1.

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

**Glass rules:** use `GlassSurface(style: .regular | .clear)`. On macOS 26+ it uses `.glassEffect(.regular, in: shape)`; on 14–15 it uses `.background(.ultraThinMaterial, in: shape)` plus a solid 0.5 pt edge hairline (`glassEdge`, `#FFFFFF` @ 22%). With Reduce Transparency it's an opaque `surfaceRaised`. Glass is used only on the HUD, onboarding card and calibration card (the popover is already system glass). Never nest glass in glass.

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

| Pattern | Spec | Reduced motion |
|---|---|---|
| **Glint acquire** | Ring opacity 0→1 (`fast`, `ease.enter`) + scale 1.06→1 (`spring.acquire`); no halo, no sweep — the crisp ring is the event. Study: `Design/Motion/glint-acquire-click.svg` | Opacity 0→1, 120 ms |
| **Glint follow** | Frame (origin + size + corner radius) animates with `spring.follow`; the ring never fades out between adjacent targets | Cross-fade old→new 100 ms |
| **Armed** | Core → `glint.armed`, stroke 1.75 → 2.25 pt, `instant` | Same (color + weight) |
| **Flare (click)** | A vector four-point star (`glint.flare`) at the ring's top-right corner scales 0.2→1.3→0.6 and fades (260 ms); ring scales 1→1.12 + fades (`ease.exit`); optional "tink". Study: `glint-acquire-click.svg` | Ring opacity pulse 1→0.4→1 (150 ms) |
| **Right-click** | Same as flare, but the rays rotate 45° and the ring contracts 1→0.94 before fading | Same as click (reduced) |
| **Reject** | Horizontal shake ±2 pt, 2 cycles, 180 ms; core dims to 60% for 200 ms | Opacity dip 1→0.5→1 (150 ms) |
| **Uncertain** | Two rings at the top-2 candidates, `glint.uncertain`, slow breathing opacity 0.35↔0.55 (1.6 s period) | Static 0.45 |
| **Aura (no-AX)** | Dashed ring (1.5 pt, 3/4 dash) of radius = sigmaPt, follows filtered gaze with `spring.follow`; never a filled disc | Static ring, repositions with 100 ms fade |
| **Scroll dwell progress** | A 2 pt `glint.progress` line grows along the zone's bottom edge with dwell progress (0 → full width in 300 ms), then fades 200 ms as the glide starts. Study: `glide-scroll.svg` | Same (it's progress, not decoration) |
| **Glide** | Content scroll with `ease.glide` over `deliberate` (520 ms) | Glide 300 ms `ease.standard` (functional motion kept) |
| **At end nudge** | The progress line flashes once at full width and fades (240 ms); content doesn't move | Same |
| **Line marker ("where was I")** | 2 pt `glint.core` underline along the line rect; sweep L→R 450 ms (`ease.standard`), hold 600 ms, fade 600 ms (`ease.exit`). Study: `where-was-i.svg` | Fade in 150 ms, hold 900 ms, fade 150 ms |
| **Window focus flash** | Window outline ring (radius 12) at 70% → 0 over 300 ms (`ease.exit`) | 150 ms fade |
| **HUD** | Enter: y −8→0 + opacity (`spring.gentle`); exit: opacity + scale 0.98 (180 ms, `ease.exit`); auto-dismiss 2.4 s; morphs width when replaced (`spring.snappy`) | Opacity only, 150 ms |
| **Onboarding steps** | Content slides x 24→0 + fade (`slow`, `ease.enter`); the hero glint is a `matchedGeometryEffect` that travels between steps | Cross-fade 150 ms |
| **Permission granted** | Checkmark draws (trim 0→1, 280 ms) + success tint; auto-advance after 600 ms | Instant check + fade |
| **Calibration glint** | The glint star drifts between anchors with `spring.calibration`; a 2 pt ring fills around it during each 1.2 s pause; it pops (scale 1→1.25→1, 200 ms) on anchor complete. Study: `calibration.svg` | Glint jumps with a 120 ms fade; ring fills (functional) |
| **Menu bar glyph** | Swaps between state glyphs (§7) on status change; the menu bar itself doesn't animate | — |
| **Mark twinkle** | `GlintMark(.twinkle)`: every 12 s the sparkle scales 1→1.25→1 and turns 90° in 600 ms. The glint is 4-fold symmetric, so the loop is seamless (a 45° turn would snap). Study: `twinkle.svg` | Static mark |
| **Double-blink teaching loop** | `GlintMark(.doubleBlink)`: lids close 80 ms / open 120 ms, 180 ms gap, again, then the sparkle flares (1→1.45, overshoot 0.94, settle). Study: `double-blink.svg` | Static mark |
| **Draw-on** | `DrawOnIcon`: strokes trim 0→1 in 280 ms (`ease.standard`) on appear (granted, done) | Drawn immediately |

**Choreography rules:** at most one overlay animation family is "loud" at a time (flare beats progress line beats acquire). The HUD never animates while a flare plays: it waits 260 ms. Staggers in lists use 30 ms per item, max 6 items.

**Performance:** the overlay draws vector paths only (no blur, no full-screen layers); the overlay must hold 120 fps on ProMotion with < 4 ms GPU per frame (check with the Metal HUD).

## 7. Iconography & Imagery

**Custom icon system.** Glint draws its own icons. Sources are SVGs in `Design/Icons/` (24 pt grid) and `Design/MenuBar/` (18 pt grid); `scripts/icons/build_icons.py` compiles them into native Swift vector data (`GlintUI/Icons/GlintIconData.swift`, generated, checked in CI with `--check`). Nothing is rasterized, so icons are crisp at any size and individual parts can animate.

| Rule | Value |
|---|---|
| Grid | 24 × 24 pt, 2 pt padding (live area 20 pt); menu bar 18 × 18 pt |
| Stroke | 1.5 pt (menu bar 1.4 pt), round caps and joins, scales with size |
| Geometry | circles, 45° angles, 1.75–3 pt corner radii; the four-point glint (concave sides, k = 0.22) is the only ornament |
| Fill | stroke by default; `fill="currentColor"` only for the glint, dots and pupils |
| Parts | every element has a `data-part` name; parts are what motion animates (`sparkle`, `outline`, `iris`, `lid`, `tick`, …) |
| Color | icons take the current foreground (`text` / `textMuted`); only a `sparkle` part may be recolored to `glintMark` |
| Sizes | 12 (chevrons), 16 (rows, banners), 20 (Settings tabs), 28 (empty states, popover mark), 56 (About) |
| Accessibility | decorative by default; `GlintIcon(_, label:)` when the icon is the only content of a control; each SVG `<title>` is the icon's name |

**Set (28):** camera, check, chevron-right, close, cursor-glint (act for you), display, eye, eye-closed, eye-glint (the mark), face-scan (waiting for you), focus-window, gauge (diagnostics), glint, grid (apps), info, keyboard (shortcut), low-light, pause, play, power, quit, reading (where was I), recalibrate, scroll-glide, shield (privacy), target (magnetic snap), tune (settings), warning.

**Adding an icon:** draw it on the grid in `Design/Icons/<name>.svg` using `<path>`, `<circle>`, `<rect>` or `<line>`, name every part, run `python3 scripts/icons/build_icons.py`, and add it to the snapshot sheet. The converter rejects unnamed or duplicate parts and non-square view boxes.

**Menu bar glyph** (template image, 18 pt). The eye is constant; the state lives in the glint's slot:

| State | Glyph (`Design/MenuBar/menubar-<state>.svg`) |
|---|---|
| Tracking | eye + filled glint |
| Paused | eye + two pause bars where the glint was |
| Off | eye, no glint, 50% opacity |
| Away | closed eye with lashes + outlined glint |
| Needs attention | eye + `!` where the glint was |

**App icon** (`Design/AppIcon/glint-app-icon.svg`, rasterized by Chromium to every size): flat ink tile, a paper eye centered on the tile, and the gold glint as its catchlight at the upper right. No gradients, no glass texture; a 2 pt 8% white inner edge separates the tile from dark docks. Light/dark/tinted variants for macOS 26 Icon Composer are P5.T8.

**Illustration:** none beyond the mark and the motion studies. **Imagery:** no stock photos; onboarding visuals are live renders of the glint on sample UI (the Playground).

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
| `AccuracyReadout` | excellent, good, fair, poor, notCalibrated | — | "Accuracy: Good, 2.1 degrees" | Plain text: the level word in its semantic color + degrees in tabular digits. No pill, no dot. |
| `StepIndicator` | 5 steps | upcoming, current (accent capsule 20 pt wide), done | "Step 3 of 5, Calibrate" | |
| `ProgressRing` | 24, 64 | indeterminate, determinate | Value as percent | Calibration uses `glint.core` ring. |
| `HUDCapsule` | info, warning, success | entering, visible, replacing, exiting | Posted as an announcement (`NSAccessibility.post(… .announcementRequested)`) | ≤ 6 words + optional symbol. |
| `StatusBanner` | warning, danger, info | with action | Combined element | Flat `surfaceRaised` + hairline; custom warning/info icon carries severity; underlined text action. One at a time. |
| `EmptyState` | any custom icon | — | Title + description read | 28 pt custom icon in `textMuted`, title, one sentence. No glass circle. |
| `GlintIcon` | any `GlintIconName`, any size | — | Decorative unless `label:` given | Use instead of SF Symbols everywhere Glint owns the visual. |
| `GlintMark` | `.still`, `.twinkle`, `.doubleBlink` | Reduce Motion → still | Hidden (decorative) | Popover header (twinkle while tracking, 45% when off), About, onboarding. |
| `DrawOnIcon` | any icon | draws once on appear | Hidden | Permission granted, calibration done. |
| `PopoverRow` | icon + title + shortcut/chevron | default, hover (flat `border` fill), pressed, disabled (40%) | Button with identifier `glint.popover.<id>` | No scaling, no color shift on hover. |
| `AppRuleRow` | off, scrollOnly | default, hover (shows remove), default-rule badge text "Default" | Row reads app name + mode | App icon 20 pt + name; mode `Picker`. |
| `PayloadViewer` | — | loading, empty ("Nothing sent yet"), list | Monospaced text selectable | JSON pretty-printed, SF Mono. |
| **Overlay:** `GlintRing` | locked, acquiring, armed, uncertain, flare, reject, highContrast | per §6 | Hidden from AX | Never draw a ring smaller than 28×28. |
| **Overlay:** `GazeAura`, `EdgeGlow`, `LineMarker`, `WindowFlash`, `DebugDot` | per §2.1 / §6 | per §6 | Hidden from AX | `DebugDot` is only available with Advanced → Debug gaze dot. |

## 9. Patterns & Screen Specs

### 9.1 Menu bar popover (F-10, F-11)

```text
┌──────────────────────────────── 320 ─┐
│ ◉✦  Glint                   [  ●  ]  │  ← GlintMark 28 (twinkles while tracking) + title2 + switch
│     Tracking · 30 fps                │  ← status line, textMuted (warning for low light)
│ [⚠ Glint can't act — Accessibility…  Fix] │  ← StatusBanner, only for blocking problems
│ Accuracy                Good  2.1°   │  ← AccuracyReadout, plain text
│ ──────────────────────────────────── │  ← hairline
│ ⏸  Pause                          ›  │  ← PopoverRow (menu: 15 min · 1 hour · until I resume)
│ ⟳  Recalibrate                       │     ("Calibrate" when not calibrated)
│ ⚙  Settings…                     ⌘,  │
│ ⇥  Quit Glint                    ⌘Q  │
└──────────────────────────────────────┘
```

Row icons are custom (`pause`/`play`, `recalibrate`, `tune`, `quit`), 16 pt in `textMuted`. States: **tracking** (mark twinkles); **off** (switch off, mark at 45%, "Off — camera is off"); **paused** ("Paused · resumes 3:41 PM", the Pause row becomes Resume); **away** ("Waiting for you…"); **not calibrated** ("Calibrate to start", row reads "Calibrate"); **permission missing** (danger banner + Fix; switch disabled); **camera missing** (banner "No camera found" + Help); **low light** (status in `warning`: "Too dark to see your eyes"); **starting** ("Starting…", ≤ 1.5 s). Keyboard: ⌘, settings, ⌘Q quit, Space toggles the focused switch.

### 9.2 Onboarding window (F-01)

720×520 glass card on the desktop, StepIndicator at the top and the primary button bottom-right.

1. **Welcome:** a large hero glint drifting over a stylized paragraph that "glides". Title "Your Mac, at a glance." Body: "Glint follows your eyes to scroll and click — no hands needed. Everything stays on this Mac." Primary: "Get started".
2. **Camera:** PermissionCard (custom `camera` icon; `check` draws on when granted). Copy: "Glint uses your camera to see where you're looking. Video never leaves your Mac and is never saved." States per PermissionCard. No-camera state: "Connect a camera or turn on Continuity Camera."
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

Tabbed `Settings` scene with custom template tab icons (§7): General (`tune`), Gestures (`eye`), Scrolling (`scroll-glide`), Apps (`grid`), Privacy (`shield`), Advanced (`gauge`), About (`glint`). About shows the twinkling `GlintMark` (56 pt), the name and the version.

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

- Tokens live in `Packages/GlintKit/Sources/GlintUI/DesignSystem/`: `GlintColor.swift` (with named colors in `Assets.xcassets` for light/dark), `GlintFont.swift`, `GlintSpacing.swift`, `GlintRadius.swift`, `GlintShadow.swift`, `GlintMotion.swift`, `GlassSurface.swift`. Icons: `Design/Icons/*.svg` → `scripts/icons/build_icons.py` → `GlintUI/Icons/GlintIconData.swift` (generated) rendered by `GlintIcon`, `GlintMark`, `DrawOnIcon` and `GlintIconArtwork.templateImage` (menu bar, tabs). Motion studies: `Design/Motion/*.svg` (authored by `scripts/icons/author_motion.py`). The overlay draws vector paths in SwiftUI; no Metal shaders are needed for crisp light.
- **Adding a token:** add it to the Swift file + asset catalog, add a row to this doc's table in the same PR, verify contrast with `scripts/contrast.py` if it's a color, and update snapshots.
- **Visual testing:** swift-snapshot-testing for every component and screen state, in light and dark, with Reduce Motion on (static frames) at 1× and 2× scale. Overlay states are snapshotted from `GlintRing` previews with fixed frames.
- **Previews:** every view has `#Preview` blocks for each state, fed by fixture models in `GlintUI/PreviewFixtures/`.
