#!/usr/bin/env python3
"""Authors Saccade's animated SVG motion studies (Design/Motion/*.svg), the motion spec for DESIGN_SYSTEM §6.2.

Overlay language: a precise indigo ring with a soft fill (target), a 2 px progress bar (scroll), a soft line
highlight (where was I), a shrinking target (calibration). No glows, gradients or sparkles. Timings mirror the
SaccadeMotion tokens and the SwiftUI keyframes in SaccadeUI/Icons/AnimatedIcons.swift; change both together.
SMIL rule: keySplines control values stay within 0...1 (express overshoot with extra values).
Usage: python3 scripts/icons/author_motion.py   (writes Design/Motion/)
"""
import pathlib
import sys

OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[2] / "Design/Motion"
PAGE, CHROME, INK, BAR, BAR2 = "#FFFFFF", "#F3F4F6", "#0F1011", "#E4E5E8", "#D5D7DB"
ACCENT = "#6366F1"
STD, ENTER, EXIT, GLIDE, LIN = "0.2 0 0 1", "0 0 0 1", "0.3 0 1 1", "0.22 0.61 0.36 1", "0 0 1 1"


def f(v):
    s = f"{v:.2f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def kt(times, total):
    return ";".join(f(t / total) for t in times)


def anim(attr, values, times, total, splines=None):
    spl = f' calcMode="spline" keySplines="{";".join(splines)}"' if splines else ""
    return (f'<animate attributeName="{attr}" values="{values}" keyTimes="{kt(times, total)}" '
            f'dur="{f(total)}s" repeatCount="indefinite"{spl}/>')


def scale_about(cx, cy, inner, values, times, total, splines=None):
    spl = f' calcMode="spline" keySplines="{";".join(splines)}"' if splines else ""
    return (f'<g transform="translate({f(cx)} {f(cy)})"><g><animateTransform attributeName="transform" type="scale" '
            f'values="{values}" keyTimes="{kt(times, total)}" dur="{f(total)}s" repeatCount="indefinite"{spl}/>'
            f'<g transform="translate({f(-cx)} {f(-cy)})">{inner}</g></g></g>')


def window(body, w=400, h=220):
    """A light app window: hairline frame, title bar with traffic lights, white page."""
    lights = "".join(f'<circle cx="{18 + i * 14}" cy="15" r="4.5" fill="{BAR2}"/>' for i in range(3))
    return (f'<rect x="0.5" y="0.5" width="{w - 1}" height="{h - 1}" rx="12" fill="{PAGE}" stroke="#0F101114"/>'
            f'<path d="M0.5 30 H{w - 0.5}" stroke="#0F101114"/>{lights}{body}')


def wrap(name, title, desc, body, w=400, h=220):
    (OUT / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img">\n'
        f"  <title>{title}</title>\n  <desc>{desc}</desc>\n  {body}\n</svg>\n")


def text_lines(x, y, widths, gap=20, h=7):
    return "".join(f'<rect x="{x}" y="{y + i * gap}" width="{w}" height="{h}" rx="3.5" fill="{BAR}"/>'
                   for i, w in enumerate(widths))


# 1. Target: acquire → armed → click (3.2 s) -------------------------------------------------------------
T = 3.2
bx, by, bw, bh = 150, 112, 100, 30
pad, rad = 4, 10
hl = (f'<rect x="{bx - pad}" y="{by - pad}" width="{bw + 2 * pad}" height="{bh + 2 * pad}" rx="{rad}" fill="{ACCENT}">'
      + anim("fill-opacity", "0.08;0.08;0.14;0.14;0.24;0.24", [0, 1.2, 1.28, 1.5, 1.56, T], T)
      + f'</rect><rect x="{bx - pad}" y="{by - pad}" width="{bw + 2 * pad}" height="{bh + 2 * pad}" rx="{rad}" '
      f'fill="none" stroke="{ACCENT}" stroke-width="1.5">'
      + anim("stroke-width", "1.5;1.5;2;2", [0, 1.2, 1.28, T], T) + "</rect>")
hl_group = ('<g opacity="0">' + anim("opacity", "0;0;1;1;0;0", [0, 0.4, 0.54, 1.56, 1.74, T], T)
            + scale_about(bx + bw / 2, by + bh / 2, hl, "1.04;1.04;1;1;0.97;0.97", [0, 0.4, 0.54, 1.56, 1.74, T], T,
                          [LIN, ENTER, LIN, EXIT, LIN]) + "</g>")
button = (f'<rect x="{bx}" y="{by}" width="{bw}" height="{bh}" rx="6" fill="{INK}">'
          + anim("fill-opacity", "1;1;0.82;1;1", [0, 1.5, 1.56, 1.8, T], T)
          + f'</rect><rect x="{bx + 30}" y="{by + 12}" width="{bw - 60}" height="6" rx="3" fill="#FFFFFF" fill-opacity="0.85"/>')
body = window(text_lines(40, 54, [220, 300, 260]) + button + hl_group)
wrap("target-click", "Target highlight: acquire, arm, click",
     "Gaze settles on a button: a 1.5 pt indigo ring with an 8% fill appears (scale 1.04 to 1, 140 ms). The first "
     "blink arms it (2 pt ring, 14% fill); the second clicks: a 24% flash, then the highlight contracts and fades (180 ms).",
     body)

# 2. Double blink teaching loop (2.6 s), same keyframes as SaccadeMark.doubleBlink ------------------------
T = 2.6
cx, cy, s = 200, 112, 6.4
ring_r, cl = 8.25 * s, (cx + 2.75 * s, cy - 2.75 * s, 2.25 * s)
lid_t = [0, 0.6, 0.68, 0.8, 0.98, 1.06, 1.18, T]
lid_v = ";".join("1 " + v for v in "1;1;0.06;1;1;0.06;1;1".split(";"))
catch = scale_about(cl[0], cl[1], f'<circle cx="{f(cl[0])}" cy="{f(cl[1])}" r="{f(cl[2])}" fill="{ACCENT}"/>',
                    "1;1;1.5;0.94;1;1", [0, 1.18, 1.32, 1.5, 1.72, T], T, [LIN, STD, STD, STD, LIN])
# Ring and catchlight squash together toward the eye's center, like a lid closing.
ring = (f'<g transform="translate({cx} {cy})"><g><animateTransform attributeName="transform" type="scale" values="{lid_v}" '
        f'keyTimes="{kt(lid_t, T)}" dur="{f(T)}s" repeatCount="indefinite"/><g transform="translate({-cx} {-cy})">'
        f'<circle cx="{cx}" cy="{cy}" r="{f(ring_r)}" fill="none" stroke="{INK}" stroke-width="{f(1.75 * s)}"/>{catch}</g></g></g>')
catch = ""
wrap("double-blink", "Double blink",
     "The mark teaches the gesture: two deliberate blinks (80 ms close, 120 ms open, 180 ms apart), then the catchlight "
     "pulses to show the click.", f'<rect width="400" height="220" rx="12" fill="{CHROME}"/>{ring}{catch}')

# 3. Glide scroll (4.0 s) -------------------------------------------------------------------------------
T = 4.0
view_top, view_h = 31, 189
zone_y = view_top + view_h * 0.85
content = (f'<g><animateTransform attributeName="transform" type="translate" values="0 0;0 0;0 {-view_h * 0.4:.1f};0 {-view_h * 0.4:.1f}" '
           f'keyTimes="{kt([0, 2.0, 2.52, T], T)}" dur="{f(T)}s" repeatCount="indefinite" calcMode="spline" '
           f'keySplines="{LIN};{GLIDE};{LIN}"/>{text_lines(40, 52, [320, 300, 250, 320, 280, 200, 320, 300, 260, 310, 240, 320], 22)}</g>')
clip = f'<clipPath id="view"><rect x="1" y="{view_top}" width="398" height="{view_h - 1}" rx="0"/></clipPath>'
gaze = (f'<circle r="7" fill="none" stroke="{ACCENT}" stroke-opacity="0.55" stroke-width="1.25">'
        + anim("cx", "70;300;90;250;250;250", [0, 0.6, 0.9, 1.6, 2.0, T], T)
        + anim("cy", f"70;70;{zone_y + 12:.1f};{zone_y + 12:.1f};{zone_y + 12:.1f};70", [0, 0.6, 0.9, 1.6, 2.6, T], T)
        + "</circle>")
progress = (f'<rect x="1" y="{view_top + view_h - 3}" height="2" rx="1" fill="{ACCENT}">'
            + anim("width", "0;0;398;398;398", [0, 1.7, 2.0, 2.2, T], T, [LIN, STD, LIN, LIN])
            + anim("opacity", "0;0;1;1;0;0", [0, 1.68, 1.7, 2.0, 2.2, T], T) + "</rect>")
zone = f'<path d="M1 {zone_y:.1f} H399" stroke="#0F10111A" stroke-dasharray="2 4"/>'
wrap("glide-scroll", "Glide scroll",
     "Gaze settles in the bottom 15% of the scroll area; a 2 pt progress bar fills along the bottom edge during the "
     "300 ms dwell, then the page glides up 40% of its height over 520 ms.",
     window(f'<defs>{clip}</defs><g clip-path="url(#view)">{content}</g>{zone}{gaze}{progress}'))

# 4. Where was I (4.4 s) --------------------------------------------------------------------------------
T = 4.4
widths = [300, 320, 260, 310, 240, 280]
line_y = 52 + 2 * 22
hl = (f'<rect x="34" y="{line_y - 6}" height="19" rx="4" fill="{ACCENT}" fill-opacity="0.18">'
      + anim("width", "0;0;272;272", [0, 2.6, 3.05, T], T, [LIN, STD, LIN])
      + anim("opacity", "0;0;1;1;0;0", [0, 2.58, 2.6, 3.65, 4.25, T], T) + "</rect>")
away = ('<g>' + anim("opacity", "1;1;0;0;1;1", [0, 0.9, 1.0, 2.5, 2.6, T], T)
        + f'<circle r="7" fill="none" stroke="{ACCENT}" stroke-opacity="0.55" stroke-width="1.25" cy="{line_y + 3}">'
        + anim("cx", "60;290;290;80;80", [0, 0.9, 2.6, 2.61, T], T) + "</circle></g>")
wrap("where-was-i", "Where was I",
     "You read line 3, look away for more than 2 s, and when you return the line gets a soft highlight that sweeps "
     "left to right (450 ms), holds 600 ms and fades over 600 ms.",
     window(hl + text_lines(40, 52, widths, 22) + away))

# 5. Calibration (9 anchors, 1.2 s pause + 0.45 s move each) -------------------------------------------
W, H, P = 400, 220, 26
anchors = [(0.1, 0.1), (0.5, 0.1), (0.9, 0.1), (0.9, 0.5), (0.5, 0.5), (0.1, 0.5), (0.1, 0.9), (0.5, 0.9), (0.9, 0.9)]
pts = [(P + ax * (W - 2 * P), P + ay * (H - 2 * P)) for ax, ay in anchors]
pause, move = 1.2, 0.45
T = len(pts) * (pause + move)
times, vals, t = [], [], 0.0
for px, py in pts:
    times += [t, t + pause]
    vals += [f"{f(px)} {f(py)}"] * 2
    t += pause + move
times.append(T)
vals.append(f"{f(pts[0][0])} {f(pts[0][1])}")
rk, rv, t = [], [], 0.0
for _ in pts:
    rk += [t, t + 0.3, t + pause, t + pause + 0.001]
    rv += ["20", "20", "6", "20"]
    t += pause + move
rk.append(T)
rv.append("20")
dots = "".join(f'<circle cx="{f(x)}" cy="{f(y)}" r="2" fill="#FFFFFF" fill-opacity="0.25"/>' for x, y in pts)
target = (f'<g><animateTransform attributeName="transform" type="translate" values="{";".join(vals)}" '
          f'keyTimes="{kt(times, T)}" dur="{f(T)}s" repeatCount="indefinite" calcMode="spline" '
          f'keySplines="{";".join([LIN if i % 2 == 0 else "0.45 0 0.55 1" for i in range(len(times) - 1)])}"/>'
          f'<circle r="20" fill="none" stroke="#FFFFFF" stroke-opacity="0.9" stroke-width="1.25">'
          f'<animate attributeName="r" values="{";".join(rv)}" keyTimes="{kt(rk, T)}" dur="{f(T)}s" repeatCount="indefinite"/></circle>'
          f'<circle r="4.5" fill="#FFFFFF"/></g>')
wrap("calibration", "Calibration",
     "A small target drifts through 9 anchors and pauses 1.2 s at each; its ring tightens from 20 to 6 pt as samples "
     "are collected (after the first 300 ms).",
     f'<rect width="{W}" height="{H}" rx="12" fill="#0B0C0D"/>{dots}{target}')

# 6. Live mark (production: every 8 s; this study loops every 2 s) -------------------------------------
T = 2.0
cx, cy, s = 200, 110, 6.4
cl = (cx + 2.75 * s, cy - 2.75 * s, 2.25 * s)
mark = (f'<circle cx="{cx}" cy="{cy}" r="{f(8.25 * s)}" fill="none" stroke="{INK}" stroke-width="{f(1.75 * s)}"/>'
        + scale_about(cl[0], cl[1], f'<circle cx="{f(cl[0])}" cy="{f(cl[1])}" r="{f(cl[2])}" fill="{ACCENT}"/>',
                      "1;1;1.3;0.97;1", [0, 1.5, 1.7, 1.88, T], T, [LIN, STD, STD, STD]))
wrap("live-mark", "Live mark",
     "While Saccade is tracking, the catchlight swells once every 8 s (scale 1 to 1.3, 500 ms). This study shortens "
     "the rest period to 1.5 s.", f'<rect width="400" height="220" rx="12" fill="{CHROME}"/>{mark}')
print("motion studies written")
