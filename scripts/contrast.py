#!/usr/bin/env python3
"""Verifies WCAG contrast of the chrome color tokens straight from the asset catalog (DESIGN_SYSTEM §2.2).

Usage: python3 scripts/contrast.py [path/to/Colors.xcassets]
Exit 1 if any documented pair falls below its minimum in light or dark appearance.
"""
import json
import pathlib
import sys

DEFAULT = pathlib.Path(__file__).resolve().parent.parent / "Packages/GlintKit/Sources/GlintUI/Resources/Colors.xcassets"

# (foreground, background, minimum ratio). Text ≥ 4.5:1; UI and focus ≥ 3:1 (DESIGN_SYSTEM §2.2).
PAIRS = [
    ("text", "background", 4.5),
    ("textMuted", "background", 4.5),
    ("accentText", "background", 4.5),
    ("onAccent", "accent", 4.5),
    ("danger", "background", 4.5),
    ("success", "background", 4.5),
    ("warning", "background", 4.5),
    ("info", "background", 4.5),
    ("text", "surfaceRaised", 4.5),
    ("textMuted", "surfaceRaised", 4.5),
    ("focusRing", "background", 3.0),
]


def load(catalog: pathlib.Path) -> dict:
    colors = {}
    for colorset in catalog.glob("*.colorset"):
        data = json.loads((colorset / "Contents.json").read_text())
        values = {}
        for entry in data["colors"]:
            dark = any(a.get("value") == "dark" for a in entry.get("appearances", []))
            c = entry["color"]["components"]
            rgb = tuple(int(c[k], 16) / 255 if str(c[k]).startswith("0x") else float(c[k]) for k in ("red", "green", "blue"))
            values["dark" if dark else "light"] = (rgb, float(c["alpha"]))
        colors[colorset.stem] = values
    return colors


def luminance(rgb) -> float:
    def channel(v):
        return v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (channel(v) for v in rgb)
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b) -> float:
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main() -> int:
    catalog = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT
    if not catalog.exists():
        print(f"contrast: catalog not found: {catalog}")
        return 2
    colors = load(catalog)
    failures = 0
    for fg, bg, minimum in PAIRS:
        for mode in ("light", "dark"):
            (fg_rgb, fg_a), (bg_rgb, _) = colors[fg][mode], colors[bg][mode]
            if fg_a < 1:
                print(f"✗ {fg} is translucent in {mode}; contrast pairs must use opaque tokens")
                failures += 1
                continue
            r = ratio(fg_rgb, bg_rgb)
            ok = r >= minimum
            failures += not ok
            print(f"{'✓' if ok else '✗'} {fg:11s} on {bg:13s} {mode:5s} {r:5.2f}:1 (min {minimum})")
    print(f"contrast: {len(PAIRS) * 2 - failures}/{len(PAIRS) * 2} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
