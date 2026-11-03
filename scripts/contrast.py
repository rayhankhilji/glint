#!/usr/bin/env python3
"""Verifies WCAG contrast of the color tokens in Design/tokens.json (DESIGN_SYSTEM §2).

Checks every pair in tokens.json "contrast" in light and dark, and the overlay ring against pure white and black.
Translucent tokens are composited over the pair's background first. Exit 1 on any failure.
"""
import json
import pathlib
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
TOKENS = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "Design/tokens.json"


def rgba(h):
    h = h.lstrip("#")
    r, g, b = (int(h[i : i + 2], 16) / 255 for i in (0, 2, 4))
    return r, g, b, (int(h[6:8], 16) / 255 if len(h) == 8 else 1.0)


def over(fg, bg):
    r, g, b, a = fg
    return tuple(c * a + bc * (1 - a) for c, bc in zip((r, g, b), bg[:3])) + (1.0,)


def luminance(c):
    f = lambda v: v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4
    r, g, b = (f(v) for v in c[:3])
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def ratio(a, b):
    la, lb = sorted((luminance(a), luminance(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def main():
    t = json.loads(TOKENS.read_text())
    chrome, failures, checks = t["chrome"], 0, 0
    for fg, bg, minimum in t["contrast"]:
        for mode in ("light", "dark"):
            b = rgba(chrome[bg][mode])
            f = over(rgba(chrome[fg][mode]), b)
            r = ratio(f, b)
            checks += 1
            ok = r >= minimum
            failures += not ok
            print(f"{'✓' if ok else '✗'} {fg:10s} on {bg:10s} {mode:5s} {r:5.2f}:1 (min {minimum})")
    # Overlay marks are dual-tone: the ink core must read on white, the paper halo on black.
    ink, paper = rgba(t["overlay"]["ink"]["value"]), rgba(t["overlay"]["paper"]["value"])
    for name, fg, bg in (("ink core on white", ink, (1, 1, 1, 1)), ("paper halo on black", paper, (0, 0, 0, 1))):
        r = ratio(fg, bg)
        checks += 1
        ok = r >= 3.0
        failures += not ok
        print(f"{'✓' if ok else '✗'} overlay {name:20s} {r:5.2f}:1 (min 3.0)")
    print(f"contrast: {checks - failures}/{checks} checks passed")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
