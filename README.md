# Glint

Glint is a macOS menu-bar app that reads intent from your webcam. You look at a button and blink twice to click it; when your eyes reach the bottom of what you're reading, the page glides down. It all runs on your Mac: video never leaves it and is never saved.

## Status

Glint is early. The build plan has seven phases ([ROADMAP.md](ROADMAP.md)); only the foundation exists today.

| Works now | Not built yet |
|---|---|
| Menu bar icon with on, off and pause states | Camera capture and eye tracking (Phase 1) |
| Popover: on/off switch, pause, accuracy, Settings, Quit | Calibration (Phase 2) |
| Settings window (tabs only) | Target highlight, double-blink click, glide scroll (Phase 3) |
| Settings saved across launches | Onboarding, focus follows gaze, "where was I" (Phase 4) |

## Try it on your Mac

You need an Apple Silicon Mac (M1 or later) with Xcode 26 or newer installed from the App Store. You don't need Homebrew or an Apple Developer account.

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

   The first build downloads Swift packages and takes a few minutes. Glint then appears in the menu bar as a ring icon, top right; it has no Dock icon.

If the build fails, it prints the errors and saves the full log to `build/build.log`. Send the end of that log to Claude:

```bash
tail -40 build/build.log
```

To make a disk image you can share, add `--dmg`; it's written to `build/Glint.dmg`. To remove Glint, quit it from its menu and delete `Glint.app` from Applications. Its settings are in `~/Library/Application Support/Glint`.

## Develop

Start with [INSTRUCTIONS.md](INSTRUCTIONS.md). It covers the reading order for the build docs, commands, coding standards and the design system ([DESIGN_SYSTEM.md](DESIGN_SYSTEM.md)).
