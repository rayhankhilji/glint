# Saccade — Design System

> Version: 2.0 · Updated: 2026-11-03 · Applies to SaccadeUI (overlay, menu bar, onboarding, calibration, settings, HUD). Tokens live in `Packages/SaccadeKit/Sources/SaccadeUI/DesignSystem/`.

## 1. Design Direction

**Personality:** precise, quiet, fast. Pure monochrome: ink on paper, paper on ink. The bar is Linear, Notion and Vercel: modern product software where nothing is decorative and every pixel is deliberate. **Not** gamer-neon, not sci-fi HUD, not a dashboard, no glows, no sparkles, no brand color.

| Reference | What we take |
|---|---|
| Linear | Density (13 pt rows, 28 pt controls), hairline section dividers, status dots, keyboard shortcuts in faint text |
| Notion / Vercel | Black and white only, calm neutral pages, plain words over badges |
| macOS | SF Pro and SF Symbols, native grouped forms, the hover highlight that hugs a target's real shape |

**Principles**

1. **No color.** The interface is black, white and greys. Primary buttons and switches are ink (light) or paper (dark). Semantic colors (success, warning, danger) appear only in status dots and callout symbols, always next to words.
2. **No decoration.** No gradients, glows, blur halos or sparkles. `check-architecture.sh` bans gradient and blur APIs in SaccadeUI and App. Emphasis comes from weight, opacity and position.
3. **System-native.** SF Pro for type, SF Symbols for every UI icon. Only the brand mark and menu bar glyphs are custom.
4. **Hug, don't point.** The overlay outlines the real element 3 pt outside its frame. A 7 pt dot shows the gaze only when nothing is under it.
5. **Dual-tone marks.** Every overlay mark is an ink core over a paper halo, so it reads on white pages, dark mode and photos without any color.
6. **Anticipate, then act.** Every action has a visible build-up (armed highlight, dwell progress bar) so the user can abort by looking away (G-ML-03).
7. **Calm when uncertain.** Two close candidates show as two faint dashed outlines; nothing is clickable until one wins.

## 2. Color Tokens

All colors live in `Design/tokens.json`, the single source of truth. `scripts/design/build_tokens.py` compiles them to `SaccadeUI/DesignSystem/SaccadeColorTokens.swift` (appearance-aware `NSColor` providers, so the Swift package has no asset catalog), and `scripts/contrast.py` checks every documented pair (22/22 pass). Components use `SaccadeColor.*` only.

### 2.1 Chrome (Saccade's windows)

| Token | Light | Dark | Use |
|---|---|---|---|
| `background` | `#FFFFFF` | `#0A0A0A` | Window background |
| `surface` | `#FFFFFF` | `#141414` | Raised surfaces |
| `subtle` | `#F4F4F5` | `#1C1C1E` | Row hover, inline callouts, onboarding rows |
| `border` | `#0A0A0A` @ 8% | `#FFFFFF` @ 9% | Hairlines |
| `text` | `#0A0A0A` | `#FAFAFA` | Primary text, the mark |
| `textMuted` | `#636366` | `#8E8E93` | Secondary text, row icons |
| `textFaint` | `#A1A1A6` | `#5A5A5F` | Shortcuts, placeholders (non-essential) |
| `accent` | `#0A0A0A` | `#FAFAFA` | Primary buttons, switches, sliders (ink / paper) |
| `onAccent` | `#FFFFFF` | `#0A0A0A` | Text on accent |
| `accentSoft` | `#0A0A0A` @ 6% | `#FAFAFA` @ 8% | Selected rows |
| `success` | `#1F7A45` | `#5BC98A` | Status dot: tracking, good accuracy |
| `warning` | `#94600A` | `#E9A949` | Status dot: paused, fair accuracy, low light |
| `danger` | `#C0362C` | `#FF6F61` | Status dot / callout: blocked, poor accuracy |
| `focusRing` | `#0A0A0A` | `#FAFAFA` | Keyboard focus |
| `scrim` | `#000000` @ 35% | `#000000` @ 55% | Calibration backdrop |

### 2.2 Overlay (drawn over other apps)

Appearance-independent, because the overlay sits on arbitrary content. Every stroke is drawn twice: a paper halo (core + 2 pt) under an ink core, so the mark clears 3:1 on pure white (ink, 21:1) and on pure black (paper, 21:1).

| Token | Value | Use |
|---|---|---|
| `overlayInk` | `#000000` | Core stroke: 1.5 pt locked, 2 pt armed; scroll bar; gaze-dot ring |
| `overlayPaper` | `#FFFFFF` | Halo stroke under every core; gaze-dot fill |
| `overlayInkFill` / `overlayInkFillArmed` | `#000000` @ 7% / 13% | Target fill: locked / armed |
| `overlayPaperFlash` | `#FFFFFF` @ 45% | Click flash over the target |
| `overlayUncertain` | `#000000` @ 45% | Dashed (3/3) candidate outlines when two targets tie |
| `overlayLineHighlight` | `#000000` @ 10% | "Where was I" line band |
| `overlayDebugDot` | `#FF3B6B` @ 80% | Reserved for diagnostics builds |

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

Rules: use sentence case everywhere; tabular numerals for any changing number; max line length 60 ch in onboarding copy; support Dynamic Type equivalents via `.font(SaccadeFont.body)` mapping onto relative text styles so macOS accessibility text size changes apply.

## 4. Spacing, Layout & Grid

- **Base unit 4 pt.** Tokens: `xxs 2 · xs 4 · s 8 · m 12 · l 16 · xl 24 · xxl 32 · x3l 48 · hero 64`.
- **Windows:** Onboarding 720×520 fixed (content inset `xxl`). Settings 640×480 min, tab content inset `xl`, form rows 44 pt min height, label column 180 pt. Popover width 320, inset `l`, row gap `s`. HUD capsule height 36, horizontal padding `l`, max width 420.
- **Calibration:** full screen on the gaze display; anchors at 10%/50%/90% in both axes; the instruction card is centered at 50%/18%, max width 440.
- **Overlay geometry:** highlight ring outset = 4 pt beyond the element frame; corner radius `= clamp(frame.height × 0.28, 6, 14) + 4`; minimum ring size 28×28 (small elements are padded symmetrically).
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

### 6.1 Tokens (`SaccadeMotion`)

| Token | Value | Use |
|---|---|---|
| `instant` | 80 ms | Armed brightening |
| `fast` | 140 ms | Saccade acquire fade, chip changes |
| `base` | 220 ms | Popover rows, toggles |
| `slow` | 320 ms | Onboarding step content |
| `deliberate` | 520 ms | Glide scroll, hero transitions |
| `ease.standard` | cubic-bezier(0.2, 0, 0, 1) | Most UI transitions |
| `ease.enter` | cubic-bezier(0, 0, 0, 1) | Appearing elements |
| `ease.exit` | cubic-bezier(0.3, 0, 1, 1) | Leaving elements |
| `ease.glide` | cubic-bezier(0.22, 0.61, 0.36, 1) | Scroll glide (gentle start, long soft landing) |
| `spring.follow` | `.spring(response: 0.22, dampingFraction: 0.86)` | Saccade moving between targets |
| `spring.acquire` | `.spring(response: 0.28, dampingFraction: 0.78)` | Saccade scale-in 1.06 → 1.0 |
| `spring.snappy` | `.spring(response: 0.25, dampingFraction: 0.9)` | Toggles, tab indicator |
| `spring.gentle` | `.spring(response: 0.45, dampingFraction: 0.85)` | Onboarding layout, HUD entrance |
| `spring.calibration` | `.spring(response: 0.9, dampingFraction: 1.0)` | Calibration saccade drifting between anchors (critically damped, smooth-pursuit friendly) |

### 6.2 Pattern catalogue

Each overlay pattern has an animated SVG study in `Design/Motion/` (written by `scripts/icons/author_motion.py`); the studies are the motion spec.

| Pattern | Spec | Reduced motion |
|---|---|---|
| **Target acquire** | Rounded rect 3 pt outside the element (corner = min(half the short side, 8 pt)): ink 1.5 pt over a 3.5 pt paper halo, `overlayInkFill`. Moves between targets with `.snappy(0.16 s)`. Study: `target-click.svg` | Jumps, no spring |
| **Target follow** | Frame animates with the same snappy spring; the highlight never fades out between adjacent targets | Jumps |
| **Armed** | Core 1.5→2 pt, fill → `overlayInkFillArmed`, 80 ms | Same |
| **Click** | Fill flashes `overlayPaperFlash` and the mark presses to 0.96, recovering over 200 ms. Study: `target-click.svg` | Fill flash only |
| **Right-click** | Same as click | Same |
| **Uncertain** | Two dashed 1 pt `overlayUncertain` outlines (with halo) on the top two candidates, no fill | Same |
| **Gaze dot** | 7 pt paper dot with a 1.5 pt ink ring, following the gaze with `spring.follow`. Shown only when nothing is locked or uncertain and the mouse is idle | Jumps |
| **Scroll dwell** | 2 pt ink bar (1 pt paper halo) fills along the scroll area's bottom edge (top edge for scrolling up) during the dwell. Study: `glide-scroll.svg` | Same (functional) |
| **Glide** | Content scrolls 40% with `ease.glide` over 520 ms (pixel scroll events at 120 Hz) | Same |
| **Where was I** | `overlayLineHighlight` band behind the last-read line, 3 pt radius, holds 1.65 s, fades 140 ms. Study: `where-was-i.svg` | Same |
| **Window focus** | 2 pt ink outline with halo on the window frame for one frame, fading 140 ms | Same |
| **Calibration** | A white 9 pt dot inside a 1.25 pt ring that tightens from 40 to 12 pt as samples are collected; drifts between 13 anchors with `spring.calibration`. Study: `calibration.svg` | Dot moves with a short ease; ring still tightens |
| **Live mark** | `SaccadeMark(.live)`: every 8 s the jump retracts and redraws from the dot to the ring (360 ms) while the dot dips to 0.8 | Static |
| **Double blink** | `SaccadeMark(.doubleBlink)`: the ring squashes on its own center twice (80 ms close, 120 ms open, 180 ms apart), then the dot pulses to 1.35 | Static |
| **HUD** | Enter y −8→0 + opacity (`spring.gentle`); exit 180 ms; auto-dismiss 2.4 s | Opacity only |

**Choreography rules:** at most one overlay animation runs at a time (click beats progress bar beats acquire). The HUD never animates while a flare plays: it waits 260 ms. Staggers in lists use 30 ms per item, max 6 items.

**Performance:** the overlay draws vector paths only (no blur, no full-screen layers); the overlay must hold 120 fps on ProMotion with < 4 ms GPU per frame (check with the Metal HUD).

## 7. Iconography & Imagery

**UI icons are SF Symbols**, listed once in `SaccadeSymbol` (`SaccadeUI/Icons/SaccadeSymbol.swift`) and drawn with `SaccadeSymbolImage`: 12 pt medium in popover rows, 11 pt in callouts, 20 pt regular in empty states, system size in Settings tabs. Never use `Image(systemName:)` with a literal outside `SaccadeSymbol`.

| Use | Symbol |
|---|---|
| Pause / Resume | `pause` / `play` |
| Recalibrate | `scope` |
| Settings | `gearshape` |
| Quit | `power` |
| Callout | `exclamationmark.triangle.fill`, `info.circle.fill` |
| Settings tabs | `slider.horizontal.3`, `eye`, `arrow.down.to.line`, `square.grid.2x2`, `hand.raised`, `gauge.with.dots.needle.33percent`, `info.circle` |

**The mark** (`Design/Icons/mark.svg`): a saccade drawn literally. A filled fixation `dot` at lower left, a short `path` (the jump) and the `ring` it lands in at upper right, 1.75 pt strokes on a 24 pt grid. Every part takes `text`; there is no accent. The parts animate (§6.2).

**Menu bar glyphs** (`Design/MenuBar/menubar-<state>.svg`, 18 pt template images):

| State | Glyph |
|---|---|
| Tracking | the mark (dot, jump, ring) |
| Off | the mark at 50% opacity |
| Paused | ring + two bars |
| Away | ring + a closed-lid line |
| Needs attention | ring + `!` |

`scripts/icons/build_icons.py` compiles the mark and menu bar SVGs into Swift vector data (`SaccadeIconData.swift`, CI `--check`).

**App icon** (`Design/AppIcon/saccade-app-icon.svg`, rasterized by `scripts/icons/render-app-icon.mjs`): the white mark on a flat `#0A0A0A` tile. Light/dark/tinted variants for Icon Composer are P5.T8.

## 8. Components

All components live in `SaccadeUI/Components/`. Each has a snapshot test in light and dark and an accessibility label test.

| Component | Variants / sizes | States | Accessibility | Do / Don't |
|---|---|---|---|---|
| `GlassSurface` | `.regular`, `.clear`; any `Shape` | normal, reduce-transparency (opaque) | Container only | Do wrap whole cards. Don't nest. |
| `SaccadeButton` | `.primary` (accent fill), `.secondary` (glass), `.plain` (text), `.destructive`; sizes `regular` (32 h), `large` (40 h) | default, hover (+4% brightness), pressed (scale 0.98, `instant`), focus (focusRing), disabled (40% opacity), loading (inline `ProgressView` + label kept) | `.accessibilityLabel` = visible label; Return triggers `.primary` | One primary per view. Verbs: "Allow camera", not "OK". |
| `ToggleRow` | with/without subtitle | on, off, disabled (with reason subtitle) | Label + value "On/Off" | Don't use for actions. |
| `SliderRow` | continuous, stepped | default, dragging (live value label), disabled | Value announced with units ("300 milliseconds") | Always show the current value. |
| `PickerRow` | menu style | default, disabled | | Camera/display pickers show the device name and "(built-in)". |
| `ShortcutRow` | KeyboardShortcuts.Recorder wrapped | empty, recording, set, conflict (danger text) | Recorder is labeled | |
| `KeyCap` | s, m | — | Reads as "Control Option G" | Display only |
| `SettingsSection` | with header + footer text | — | Header is `.isHeader` | |
| `PermissionCard` | camera, accessibility | notDetermined, requesting, granted (check draw), denied, restricted, relaunchRequired | Status announced via `.accessibilityValue` | Explain *why* in one sentence before the button. |
| `AccuracyReadout` | excellent, good, fair, poor, notCalibrated | — | "Accuracy: Good, 2.1 degrees" | `StatusDot` + level word + degrees in tabular digits. No pill. |
| `StatusDot` | any semantic color | — | Hidden; always paired with text | 6 pt circle. |
| `SaccadeButtonStyle` | `.primary` (accent fill), `.secondary` (hairline), `.ghostAccent` (text) | default, pressed, disabled 40% | Visible label | 28 pt tall, 6 pt corners, no shadow. |
| `StepIndicator` | 5 steps | upcoming (`border`), current (`text` capsule 20 pt wide), done (`text`) | "Step 3 of 5, Calibrate" | |
| `ProgressRing` | 24, 64 | indeterminate, determinate | Value as percent | Calibration uses a white 1.25 pt ring (§6.2). |
| `HUDCapsule` | info, warning, success | entering, visible, replacing, exiting | Posted as an announcement (`NSAccessibility.post(… .announcementRequested)`) | ≤ 6 words + optional symbol. |
| `StatusBanner` | warning, danger, info | with action | Combined element | Inline callout on `subtle`, 6 pt corners, SF Symbol in the severity color, `.ghostAccent` action. One at a time. |
| `EmptyState` | any `SaccadeSymbol` | — | Title + description read | 20 pt symbol in `textFaint`, 13 pt title, one 12 pt sentence. |
| `SaccadeMark` | `.still`, `.live`, `.doubleBlink` | Reduce Motion → still | Hidden (decorative) | Popover header (live while tracking, 40% when off), About, onboarding. |
| `PopoverRow` | symbol + title + shortcut/chevron | default, hover (`subtle` fill), pressed, disabled (40%) | Button with identifier `saccade.popover.<id>` | 28 pt tall, 6 pt corners, no scaling. |
| `AppRuleRow` | off, scrollOnly | default, hover (shows remove), default-rule badge text "Default" | Row reads app name + mode | App icon 20 pt + name; mode `Picker`. |
| `PayloadViewer` | — | loading, empty ("Nothing sent yet"), list | Monospaced text selectable | JSON pretty-printed, SF Mono. |
| `HUDView` | mark, symbol | entering, visible, exiting | Announced (`announcementRequested`) | ≤ 60 characters, one line. Copy from `HUDMessage.make`. |
| **Overlay:** `GazeOverlayView` | lock (locked, armed, pressed), uncertain pair, gaze dot, scroll bar, line marker, window flash | per §6.2 | Hidden from AX | Renders `OverlayState` from the intent engine verbatim; draws nothing the engine didn't decide. |

## 9. Patterns & Screen Specs

### 9.1 Menu bar popover (F-10, F-11)

```text
┌──────────────────────────── 300 ─┐
│ ◎  Saccade                  [ ●]  │  ← SaccadeMark 22 (live while tracking) · 15 pt title · small switch
│    ● Tracking · 30 fps          │  ← StatusDot + 12 pt status line
│ [⚠ Saccade can't act — …     Fix] │  ← StatusBanner, only for blocking problems
├──────────────────────────────────┤  ← 1 px hairline, full bleed
│ Accuracy           ● Good  2.1°  │  ← AccuracyReadout
├──────────────────────────────────┤
│  ⏸  Pause                     ›  │  ← 28 pt rows, 12 pt SF Symbols in textMuted
│  ◎  Recalibrate                  │
│  ⚙  Settings…               ⌘,   │  ← shortcuts in textFaint
├──────────────────────────────────┤
│  ⏻  Quit Saccade              ⌘Q   │
└──────────────────────────────────┘
```

Status dot: green tracking, ink starting, amber paused/away/low light/not calibrated, red blocked, faint off. The popover itself is the system menu-bar window (system material), so it has no custom background.

### 9.2 Onboarding window (F-01)

720×520 standard window with a transparent title bar. Left-aligned content with a 48 pt margin; a StepIndicator (5 capsules, the current one 20 pt wide, done ones in `text`) at the top; actions bottom-right with the primary on the right. The resume point persists in `settings.onboarding`; it shows at every launch until "Done".

1. **Welcome:** `SaccadeMark(.doubleBlink)` 36 pt. Title "Control your Mac with your eyes". Three plain rows (SF Symbol + sentence): click by blinking twice, scroll by resting at the bottom, focus by looking at another window. Primary "Get Started".
2. **Camera:** title "Let Saccade see your eyes", one sentence on what happens to frames, a permission row (`camera` symbol, "Allowed ✓" / "Not allowed"). Primary "Allow Camera" → system prompt; "Open System Settings" when denied; "Continue" once granted (auto-advances on grant).
3. **Accessibility:** permission row and instructions. The first "Open System Settings" shows the system prompt (which also adds Saccade to the list); later presses open the pane. The window polls every 1.5 s and flips to "Continue" by itself. "Skip for Now" is secondary.
4. **Calibrate:** one sentence ("about 20 seconds… light in front of you") + "Start Calibration". The window steps aside during calibration and returns with "Last result" (AccuracyReadout), "Calibrate Again" and "Continue".
5. **Done:** `SaccadeMark(.live)`, "You're set", and a 4-row gesture table on `subtle` (Blink twice → Click · Blink, then hold → Right-click · Rest at the bottom of a page → Scroll · ⌃⌥S → Turn Saccade on or off). Primary "Done".

### 9.3 Calibration (F-03)

Full-screen scrim (`overlayScrim` + glass blur of the desktop) on the gaze display. The instruction card is at the top center.

| Step | Visual | Copy |
|---|---|---|
| Intro / waiting | Large saccade at center, breathing | "Double-blink when you're ready." Subtext: "Sit like you normally do. Esc to cancel." |
| Collecting | The highlight drifts to each anchor and its progress ring fills; completed anchors leave a faint dot | "Follow the highlight." (count "3 of 13" in `caption`) |
| Face lost | The highlight freezes and dims; the card shows a warning | "Look back at the screen to continue." |
| Validating | 5 quick saccades, no ring | "Almost there — just look at each saccade." |
| Result | `numeric` "1.8°" + AccuracyChip + one-line meaning ("Great for buttons and links.") + "Done" (primary) / "Try again" | Poor: "Let's try again with more light in front of you." with "Try again" as primary |
| Failed | Warning symbol | "Couldn't see your eyes clearly. Try more light in front of you." Buttons: "Try again", "Cancel" |

### 9.4 Settings (F-11, F-12)

Tabbed `Settings` scene with SF Symbol tabs (§7); every pane is a native `Form` with `.formStyle(.grouped)`, controls tinted `accent` (ink / paper). Each section has at most one plain-language footer. Every edit is saved immediately.

- **General:** Saccade is on · Open at login (`SMAppService`) · Turn on or off: `⌃⌥S` (mono) · Calibration and From your clicks (AccuracyReadout each; "After a few clicks" until live accuracy exists) + "Recalibrate…" · Accessibility: "Allowed" or "Allow…".
- **Gestures:** Double blink to click · Blink, then hold, to right-click · Click sound (system "Tink" at 35%) · Blink sensitivity (Firm ↔ Light) · Focus follows gaze + Look for (600–1500 ms) · Mark where I was reading.
- **Scrolling:** Scroll by looking · Bottom zone (10–25%) · Top zone (5–20%) · Glide distance (25–60%) · Rest for (200–600 ms). Values show in tabular digits beside each slider.
- **Apps:** one row per rule (app name, bundle ID in `caption`, mode picker Off / Scroll only, remove button) + "Add App…" (NSOpenPanel on /Applications) + "Restore Defaults".
- **Privacy:** Camera: "Processed on this Mac, never stored" · Learn from my clicks · Share anonymous usage metrics · Calibration data: "Delete…" (destructive, confirmation dialog).
- **Advanced:** Only click real controls · Show gaze point · Record sessions for tuning + "Show Recordings" · Live (tabular digits, "—" until tracking): frame rate, gaze uncertainty, face confidence, clicks learned, Accessibility lookup p50/p95 · Setup: "Show Welcome…".
- **About:** live `SaccadeMark` (48 pt), name, version, one line.

### 9.5 Overlay (F-05–F-09)

Render-only states per §6.2. The intent engine decides precedence: a lock and an uncertain pair are exclusive; the gaze dot shows only with neither (or always with Advanced → Show gaze point); the line marker and window flash can coexist with a lock. Moving the mouse hides everything gaze-related for 1.2 s.

### 9.6 Playground article

A 900-word explainer, "How Saccade reads intent", set in `body` at 15 pt with a 64 ch measure, so first-time users actually read and trigger glide naturally.

### 9.7 HUD message catalogue

An ink capsule (36 pt, 16 pt side padding, 1 pt paper hairline at 16%) with paper text in `hud` type, centered 8 pt below the menu bar on the primary display. Click-through, never takes focus, announced to VoiceOver. Enters with `spring.gentle` from the top (opacity only with Reduce Motion), dismisses after 2.4 s. `HUDPolicy` (SaccadeCore) decides what may show: confirmations always, advice at most once per 10 minutes per kind.

| Trigger | Leading | Copy |
|---|---|---|
| Turned on with ⌃⌥S | the mark | "Saccade on" |
| Turned off with ⌃⌥S | `eye.slash` | "Saccade off" |
| Live accuracy > 2.5° and > 1.8× calibration | `scope` | "Accuracy dipped · Recalibrate from the menu bar" |
| Live accuracy ≤ 1.5° and ≥ 0.5° better than calibration | `checkmark` | "Accuracy now 1.2° from your clicks" |

## 10. Content & Voice

- **Tone:** warm, plain, confident; second person; short. Saccade speaks as "Saccade", not "we", in UI.
- **Capitalization:** sentence case for everything, including buttons and window titles.
- **Buttons:** verb first ("Allow camera", "Start calibration", "Try again"). Never "OK" or "Submit".
- **Error formula:** what happened + what to do, ≤ 2 short sentences ("Couldn't see your eyes clearly. Try more light in front of you.").
- **Privacy statements** are literal and checkable ("Video never leaves your Mac and is never saved"). Never vague ("we care about privacy").
- **Numbers:** accuracy as degrees with one decimal ("1.8°"); durations in ms in settings and in seconds in prose; times in the user's locale format.
- **No jargon** in user UI: "accuracy" not "angular error"; "targets" not "AX elements". Diagnostics may use technical terms.

## 11. Accessibility

- Saccade's UI meets WCAG 2.2 AA equivalents: contrast per §2 verified pairs; visible focus (3 pt `focusRing`, offset 2 pt) on every control; full keyboard operation of onboarding, popover, and settings (Tab/Shift-Tab, Space/Return, Esc closes sheets).
- VoiceOver: every control has a label, value, and hint where non-obvious; StepIndicator and PermissionCard expose status; HUD messages are posted as announcements; the calibration instructions are announced on each step change.
- Overlay windows are excluded from the AX tree and from screen capture (`sharingType = .none`), and never become key.
- Respect system settings: Reduce Motion (§6 reduced column), Reduce Transparency (opaque surfaces), Increase Contrast (`saccade.ring.highContrast`, borders at 20%), Differentiate Without Color (accuracy chip text always present; state never color-only).
- Hit targets ≥ 28×28 pt in Saccade UI.
- Coexistence: Saccade never moves VoiceOver focus; with Voice Control running, Saccade still works and announces nothing extra.

## 12. Responsive & Platform

- macOS only; pointer + keyboard + gaze. No touch.
- Windows are fixed-size or min-size; content reflows for larger accessibility text sizes (rows grow vertically, labels wrap, nothing truncates mid-word except file paths in diagnostics).
- Light/Dark follow the system appearance live; there's no in-app theme switch.
- Calibration and overlay adapt to any gaze display resolution and scale factor; geometry is computed in points.
- Full-screen apps and Spaces: the overlay joins all Spaces and full-screen spaces (`fullScreenAuxiliary`).

## 13. Implementation

- Tokens live in `Packages/SaccadeKit/Sources/SaccadeUI/DesignSystem/`: `SaccadeColorTokens.swift` (generated) + `SaccadeColorSupport.swift`, `SaccadeFont.swift`, `SaccadeSpacing.swift`, `SaccadeRadius.swift`, `SaccadeShadow.swift`, `SaccadeMotion.swift`, `GlassSurface.swift`. Icons: `Design/Icons/*.svg` → `scripts/icons/build_icons.py` → `SaccadeUI/Icons/SaccadeIconData.swift` (generated) rendered by `SaccadeIcon`, `SaccadeMark`, `DrawOnIcon` and `SaccadeIconArtwork.templateImage` (menu bar, tabs). Motion studies: `Design/Motion/*.svg` (authored by `scripts/icons/author_motion.py`). The overlay draws vector paths in SwiftUI; no Metal shaders are needed for crisp light.
- **Adding a color:** add it to `Design/tokens.json` (and a contrast pair if it carries text), run `python3 scripts/design/build_tokens.py` and `python3 scripts/contrast.py`, add a row to §2, and update snapshots.
- **Visual testing:** swift-snapshot-testing for every component and screen state, in light and dark, with Reduce Motion on (static frames) at 1× and 2× scale. Overlay states are snapshotted from `SaccadeRing` previews with fixed frames.
- **Previews:** every view has `#Preview` blocks for each state, fed by fixture models in `SaccadeUI/PreviewFixtures/`.
