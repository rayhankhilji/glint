# Saccade

Saccade is a macOS menu-bar app that reads intent from your webcam. You look at a button and blink twice to click it; when your eyes reach the bottom of what you're reading, the page glides down. It all runs on your Mac: video never leaves it and is never saved.

## Status

Saccade is early. The build plan has seven phases ([ROADMAP.md](ROADMAP.md)).

| Works now | Not built yet |
|---|---|
| Eye tracking from your webcam (Apple Vision face landmarks) | Clicking and scrolling other apps (Phase 3, needs Accessibility) |
| 15-second calibration with an accuracy result, saved across launches | Target snapping to real buttons (Phase 3) |
| A ring that follows your gaze; it pulses when you double-blink | Onboarding, focus follows gaze, "where was I" (Phase 4) |
| Menu bar app: on/off, pause, live status, Recalibrate, Settings shell | Settings controls (Phase 4) |

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

   The first build downloads Swift packages and takes a few minutes. Saccade then appears in the menu bar as a ring icon, top right; it has no Dock icon.

3. Use it:
   - macOS asks for camera access the first time. Allow it (if you miss it: System Settings → Privacy & Security → Camera → Saccade).
   - Click the ring in the menu bar, then **Calibrate**. Follow the white dot with your eyes for about 15 seconds, keeping your head still.
   - After **Done**, an indigo ring follows your gaze. Blink twice quickly and it pulses. Turn Saccade off from the menu bar switch; the camera light goes off.

   Tips: face the screen, sit about an arm's length away, and have light in front of you rather than behind. Accuracy varies with camera and lighting; recalibrate if the ring drifts. Intel Macs run at a lower frame rate.

If the build fails, it prints the errors and saves the full log to `build/build.log`. Send the end of that log to Claude:

```bash
tail -40 build/build.log
```

To make a disk image you can share, add `--dmg`; it's written to `build/Saccade.dmg`. To remove Saccade, quit it from its menu and delete `Saccade.app` from Applications. Its settings are in `~/Library/Application Support/Saccade`.

## Develop

Start with [INSTRUCTIONS.md](INSTRUCTIONS.md). It covers the reading order for the build docs, commands, coding standards and the design system ([DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)).
