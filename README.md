# Saccade

Saccade is a macOS menu-bar app that reads intent from your webcam. You look at a button and blink twice to click it; when your eyes reach the bottom of what you're reading, the page glides down. It all runs on your Mac: video never leaves it and is never saved.

## How it works

| Gesture | What happens |
|---|---|
| Look at a button, link or field | A thin outline locks onto it, 3 pt outside its edges |
| Blink twice | Clicks what's outlined |
| Blink, then hold the second blink | Right-clicks it |
| Rest your eyes near the bottom of a page | A progress line fills, then the page glides down 40% |
| Rest near the top | Glides back up |
| Look at another window for about a second | Brings it forward (paused while you type) |
| Look away for 2 s or more, then back | The line you were reading is briefly highlighted |
| ⌃⌥S | Turns Saccade on or off |

Precision comes from several layers working together:

- **Iris localization from camera pixels.** A gradient-voting locator finds the iris center to sub-pixel precision inside each eye patch, rather than using the face model's coarse pupil points.
- **Fixation stabilization.** Small eye tremor is averaged away while you hold your gaze, and real jumps are followed immediately.
- **Magnetic snapping to real UI elements.** Accessibility reports where buttons actually are. Saccade picks the most likely one, holds it against jitter, and refuses to click when two targets are too close to call.
- **Learning from your clicks.** Every mouse click you make, and every target you click by gaze, teaches Saccade the small offset it has at that spot on the screen. The calibration keeps improving after setup; nothing but those offsets is stored.

## Try it on your Mac

You need a Mac (Apple Silicon or Intel) with Xcode 26 or newer installed from the App Store, and a webcam (the built-in one is fine). You don't need Homebrew or an Apple Developer account.

1. Clone the repository and switch to the build branch:

   ```bash
   gh repo clone rayhankhilji/glint && cd glint
   ```

   ```bash
   git checkout claude/loving-darwin-nm6z3n
   ```

2. Build, install and launch:

   ```bash
   scripts/build-app.sh --install --open
   ```

   The first build downloads Swift packages and takes a few minutes. Saccade then appears in the menu bar (a dot and a ring, top right); it has no Dock icon.

3. Set it up. A welcome window walks you through it:
   - **Camera:** allow it when macOS asks. Frames are processed in memory and never saved.
   - **Accessibility:** click **Open System Settings** and turn on Saccade under Privacy & Security → Accessibility. The window notices by itself. Without this, Saccade can only show your gaze.
   - **Calibrate:** follow the white dot through 13 points for about 20 seconds.

   Then look at any button and blink twice. Tips: face the screen at about an arm's length, with light in front of you rather than behind. Click around normally with the mouse for a minute too; each click sharpens accuracy at that spot. Intel Macs run at a lower frame rate.

   Settings (menu bar icon → Settings…) has every control: gestures, scroll zones, per-app rules, and privacy.

If the build fails, it prints the errors and saves the full log to `build/build.log`. Send the end of that log to Claude:

```bash
tail -40 build/build.log
```

To make a disk image you can share, add `--dmg`; it's written to `build/Saccade.dmg`. To remove Saccade, quit it from its menu and delete `Saccade.app` from Applications. Its settings are in `~/Library/Application Support/Saccade`.

## Develop

Start with [INSTRUCTIONS.md](INSTRUCTIONS.md). It covers the reading order for the build docs, commands, coding standards and the design system ([DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)).
