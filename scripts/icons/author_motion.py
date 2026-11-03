#!/usr/bin/env python3
"""Authors Glint's animated SVG motion studies (Design/Motion/*.svg), the motion spec for DESIGN_SYSTEM §6.2.

Timings mirror the GlintMotion tokens and the SwiftUI keyframes in GlintUI/Icons/AnimatedIcons.swift; change both
together. SMIL rules: keySplines control values must stay within 0...1 (express overshoot with extra values).
Usage: python3 scripts/icons/author_motion.py   (writes Design/Motion/)
"""
import pathlib
import sys
OUT = pathlib.Path(sys.argv[1]) if len(sys.argv) > 1 else pathlib.Path(__file__).resolve().parents[2] / "Design/Motion"
SCREEN, CONTENT, MUTED = "#17181B", "#2C2E33", "#3A3D43"
CORE, ARMED, EDGE = "#FFD98A", "#FFE7B3", "#6B4300"
GLIDE = "0.22 0.61 0.36 1"; STD = "0.2 0 0 1"; ENTER = "0 0 0 1"; EXIT = "0.3 0 1 1"

def f(v): return f"{v:.2f}".rstrip("0").rstrip(".")
def sparkle(cx, cy, r, k=0.22):
    i = r * k; p = lambda x, y: f"{f(cx+x)} {f(cy+y)}"
    return (f"M{p(0,-r)} C{p(i*0.6,-i*2.6)} {p(i*2.6,-i*0.6)} {p(r,0)} C{p(i*2.6,i*0.6)} {p(i*0.6,i*2.6)} {p(0,r)} "
            f"C{p(-i*0.6,i*2.6)} {p(-i*2.6,i*0.6)} {p(-r,0)} C{p(-i*2.6,-i*0.6)} {p(-i*0.6,-i*2.6)} {p(0,-r)} Z")
def almond(x0, x1, cy, h):
    w = x1 - x0
    return (f"M{f(x0)} {f(cy)} C{f(x0+w*0.22)} {f(cy-h)} {f(x1-w*0.22)} {f(cy-h)} {f(x1)} {f(cy)} "
            f"C{f(x1-w*0.22)} {f(cy+h)} {f(x0+w*0.22)} {f(cy+h)} {f(x0)} {f(cy)} Z")
def kt(times, total): return ";".join(f(t/total) for t in times)

def wrap(name, title, desc, w, h, body):
    (OUT / f"{name}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" width="{w}" height="{h}" role="img">\n'
        f'  <title>{title}</title>\n  <desc>{desc}</desc>\n'
        f'  <rect width="{w}" height="{h}" rx="14" fill="{SCREEN}"/>\n{body}\n</svg>\n')

def scale_about(cx, cy, inner, values, times, total, splines=None):
    spl = f' calcMode="spline" keySplines="{splines}"' if splines else ""
    return (f'<g transform="translate({f(cx)} {f(cy)})"><g>'
            f'<animateTransform attributeName="transform" type="scale" values="{values}" keyTimes="{times}" dur="{f(total)}s" repeatCount="indefinite"{spl}/>'
            f'<g transform="translate({f(-cx)} {f(-cy)})">{inner}</g></g></g>')

# 1. Acquire → armed → click flare (3.2 s loop) --------------------------------------------------------
T = 3.2
btn = (130, 92, 140, 36)
x, y, w, h = btn
ring_r = min(max(h * 0.28, 6), 14) + 4
ring = (f'<rect x="{x-4}" y="{y-4}" width="{w+8}" height="{h+8}" rx="{f(ring_r)}" fill="none" stroke="{EDGE}" stroke-opacity="0.55" stroke-width="3.5"/>'
        f'<rect x="{x-4}" y="{y-4}" width="{w+8}" height="{h+8}" rx="{f(ring_r)}" fill="none" stroke="{CORE}" stroke-width="1.75">'
        f'<animate attributeName="stroke" values="{CORE};{CORE};{ARMED};{ARMED};{CORE}" keyTimes="{kt([0,1.2,1.28,1.5,T],T)}" dur="{T}s" repeatCount="indefinite"/>'
        f'<animate attributeName="stroke-width" values="1.75;1.75;2.25;2.25;1.75" keyTimes="{kt([0,1.2,1.28,1.5,T],T)}" dur="{T}s" repeatCount="indefinite"/></rect>')
ring_group = (f'<g opacity="0"><animate attributeName="opacity" values="0;0;1;1;0;0" keyTimes="{kt([0,0.4,0.54,1.5,1.76,T],T)}" dur="{T}s" repeatCount="indefinite"/>'
              + scale_about(x+w/2, y+h/2, ring, "1.06;1.06;1;1;1.12;1.12", kt([0,0.4,0.68,1.5,1.76,T],T), T,
                            f"0 0 1 1;{ENTER};0 0 1 1;{EXIT};0 0 1 1") + '</g>')
flare = (f'<g opacity="0"><animate attributeName="opacity" values="0;0;1;0;0" keyTimes="{kt([0,1.5,1.62,1.76,T],T)}" dur="{T}s" repeatCount="indefinite"/>'
         + scale_about(x+w, y, f'<path d="{sparkle(x+w, y, 16)}" fill="{CORE}"/>', "0.2;0.2;1.3;0.6;0.6", kt([0,1.5,1.62,1.76,T],T), T,
                       f"0 0 1 1;{ENTER};{EXIT};0 0 1 1") + '</g>')
button = (f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="9" fill="{CONTENT}">'
          f'<animate attributeName="fill" values="{CONTENT};{CONTENT};{MUTED};{CONTENT};{CONTENT}" keyTimes="{kt([0,1.5,1.56,1.8,T],T)}" dur="{T}s" repeatCount="indefinite"/></rect>'
          f'<rect x="{x+34}" y="{y+15}" width="{w-68}" height="6" rx="3" fill="#8C9099"/>')
context = "".join(f'<rect x="{bx}" y="104" width="64" height="12" rx="6" fill="{CONTENT}"/>' for bx in (40, 306))
wrap("glint-acquire-click", "Glint: acquire, arm, click",
     "Gaze fixates on a button: the glint ring scales 1.06 to 1 in 140 ms, brightens when armed by the first blink, "
     "then flares (260 ms) on the second blink while the button registers the press.",
     400, 220, context + button + ring_group + flare)

# 2. Double blink teaching loop (2.8 s) — same keyframes as GlintMark.doubleBlink -------------------------
T = 2.8; cx, cy = 200, 118
lidT = [0, 0.6, 0.68, 0.8, 0.98, 1.06, 1.18, T]
lidV = "1;1;0.08;1;1;0.08;1;1"
eye = (f'<path d="{almond(110, 290, cy, 62)}" fill="none" stroke="#ECEDEF" stroke-width="7" stroke-linejoin="round"/>'
       f'<circle cx="{cx}" cy="{cy}" r="27" fill="none" stroke="#ECEDEF" stroke-width="7"/>')
eye_anim = (f'<g transform="translate({cx} {cy})"><g><animateTransform attributeName="transform" type="scale" '
            f'values="{";".join("1 " + v for v in lidV.split(";"))}" keyTimes="{kt(lidT,T)}" dur="{T}s" repeatCount="indefinite"/>'
            f'<g transform="translate({-cx} {-cy})">{eye}</g></g></g>')
sp = scale_about(286, 46, f'<path d="{sparkle(286, 46, 30)}" fill="{CORE}"/>', "1;1;1.45;0.94;1;1",
                 kt([0, 1.18, 1.3, 1.55, 1.8, T], T), T, f"0 0 1 1;{STD};{STD};{STD};0 0 1 1")
sp_op = f'<g opacity="0.55"><animate attributeName="opacity" values="0.55;0.55;1;1;0.55" keyTimes="{kt([0,0.8,1.3,2.2,T],T)}" dur="{T}s" repeatCount="indefinite"/>{sp}</g>'
wrap("double-blink", "Double blink to click",
     "Two deliberate blinks (80 ms close, 120 ms open, 180 ms gap) and the glint flares: the onboarding teaching loop.",
     400, 220, eye_anim + sp_op)

# 3. Glide scroll (4.0 s) -----------------------------------------------------------------------------
T = 4.0; win = (60, 24, 280, 172); wx, wy, ww, wh = win
zone_top = wy + wh * 0.85
lines = "".join(f'<rect x="{wx+24}" y="{wy+18+i*22}" width="{ww-48-(i%3)*38}" height="7" rx="3.5" fill="{CONTENT}"/>' for i in range(16))
content = (f'<g><animateTransform attributeName="transform" type="translate" values="0 0;0 0;0 {-wh*0.4:.1f};0 {-wh*0.4:.1f}" '
           f'keyTimes="{kt([0,2.0,2.52,T],T)}" dur="{T}s" repeatCount="indefinite" calcMode="spline" keySplines="0 0 1 1;{GLIDE};0 0 1 1"/>{lines}</g>')
clip = f'<clipPath id="win"><rect x="{wx}" y="{wy}" width="{ww}" height="{wh}" rx="10"/></clipPath>'
frame = f'<rect x="{wx}" y="{wy}" width="{ww}" height="{wh}" rx="10" fill="none" stroke="{MUTED}" stroke-width="1"/>'
zone = f'<line x1="{wx}" x2="{wx+ww}" y1="{zone_top:.1f}" y2="{zone_top:.1f}" stroke="{MUTED}" stroke-dasharray="3 5"/>'
gaze = (f'<circle r="11" fill="none" stroke="{CORE}" stroke-opacity="0.7" stroke-width="1.5" stroke-dasharray="3 4">'
        f'<animate attributeName="cx" values="{wx+40};{wx+220};{wx+60};{wx+180};{wx+180};{wx+180}" keyTimes="{kt([0,0.6,0.9,1.6,2.0,T],T)}" dur="{T}s" repeatCount="indefinite"/>'
        f'<animate attributeName="cy" values="{wy+60};{wy+60};{zone_top+10:.1f};{zone_top+10:.1f};{zone_top+10:.1f};{wy+60}" keyTimes="{kt([0,0.6,0.9,1.6,2.6,T],T)}" dur="{T}s" repeatCount="indefinite"/></circle>')
progress = (f'<line x1="{wx}" y1="{wy+wh-1.5}" y2="{wy+wh-1.5}" stroke="{CORE}" stroke-width="2.5" stroke-linecap="round">'
            f'<animate attributeName="x2" values="{wx};{wx};{wx+ww};{wx+ww};{wx}" keyTimes="{kt([0,1.7,2.0,2.05,2.25],T)};1" dur="{T}s" repeatCount="indefinite"/>'
            f'<animate attributeName="opacity" values="0;0;1;1;0;0" keyTimes="{kt([0,1.68,1.7,2.0,2.2,T],T)}" dur="{T}s" repeatCount="indefinite"/></line>')
wrap("glide-scroll", "Glide scroll",
     "Gaze settles in the bottom 15% of the scroll area; a 2 pt progress line fills during the 300 ms dwell, then the page "
     "glides up 40% of its height over 520 ms on the glide curve.",
     400, 220, f'<defs>{clip}</defs><g clip-path="url(#win)">{content}</g>{frame}{zone}{gaze}{progress}')
# fix keyTimes count for progress x2 (5 values need 5 keyTimes)
p = OUT / "glide-scroll.svg"; s = p.read_text()
s = s.replace(f'keyTimes="{kt([0,1.7,2.0,2.05,2.25],T)};1"', f'keyTimes="{kt([0,1.7,2.0,2.2,T],T)}"'); p.write_text(s)

# 4. Where was I (4.4 s) ------------------------------------------------------------------------------
T = 4.4
lines = "".join(f'<rect x="64" y="{40+i*26}" width="{272-(i%3)*44}" height="8" rx="4" fill="{CONTENT}"/>' for i in range(6))
ly = 40 + 2*26 + 14
marker = (f'<line x1="64" y1="{ly}" y2="{ly}" stroke="{CORE}" stroke-width="2.5" stroke-linecap="round">'
          f'<animate attributeName="x2" values="64;64;{64+272-88};{64+272-88}" keyTimes="{kt([0,2.6,3.05,T],T)}" dur="{T}s" repeatCount="indefinite" calcMode="spline" keySplines="0 0 1 1;{STD};0 0 1 1"/>'
          f'<animate attributeName="opacity" values="0;0;1;1;0;0" keyTimes="{kt([0,2.58,2.6,3.65,4.25,T],T)}" dur="{T}s" repeatCount="indefinite"/></line>')
away = (f'<g opacity="1"><animate attributeName="opacity" values="1;1;0;0;1;1" keyTimes="{kt([0,0.9,1.0,2.5,2.6,T],T)}" dur="{T}s" repeatCount="indefinite"/>'
        f'<circle r="11" fill="none" stroke="{CORE}" stroke-opacity="0.7" stroke-width="1.5" stroke-dasharray="3 4" cy="{ly-10}">'
        f'<animate attributeName="cx" values="80;250;250;120;120" keyTimes="{kt([0,0.9,2.6,2.61,T],T)}" dur="{T}s" repeatCount="indefinite"/></circle></g>')
wrap("where-was-i", "Where was I",
     "You read line 3, look away for more than 2 s, and when you return a 2 pt underline sweeps the line left to right "
     "(450 ms), holds 600 ms, then fades over 600 ms.",
     400, 220, lines + away + marker)

# 5. Calibration pursuit (9 anchors, 1.2 s pause + 0.45 s move each) --------------------------------
anchors = [(0.1,0.1),(0.5,0.1),(0.9,0.1),(0.9,0.5),(0.5,0.5),(0.1,0.5),(0.1,0.9),(0.5,0.9),(0.9,0.9)]
W, H = 400, 220; P = 24
pts = [(P + ax*(W-2*P), P + ay*(H-2*P)) for ax, ay in anchors]
pause, move = 1.2, 0.45; T = len(pts)*(pause+move)
times, xs, ys = [], [], []
t = 0
for i, (px, py) in enumerate(pts):
    times += [t, t+pause]; xs += [px, px]; ys += [py, py]; t += pause + move
times.append(T); xs.append(pts[0][0]); ys.append(pts[0][1])
dots = "".join(f'<circle cx="{f(px)}" cy="{f(py)}" r="2.5" fill="{MUTED}"/>' for px, py in pts)
circ = 2*3.14159*13
ring_keys, ring_vals = [], []
t = 0
for _ in pts:
    ring_keys += [t, t+0.3, t+pause, t+pause+0.001]; ring_vals += [circ, circ, 0, circ]; t += pause + move
ring_keys.append(T); ring_vals.append(circ)
glint = (f'<g><animateTransform attributeName="transform" type="translate" '
         f'values="{";".join(f"{f(x)} {f(y)}" for x, y in zip(xs, ys))}" keyTimes="{kt(times,T)}" dur="{f(T)}s" repeatCount="indefinite" '
         f'calcMode="spline" keySplines="{";".join(["0 0 1 1" if i % 2 == 0 else "0.45 0 0.55 1" for i in range(len(times)-1)])}"/>'
         f'<circle r="13" fill="none" stroke="{CORE}" stroke-opacity="0.25" stroke-width="2"/>'
         f'<circle r="13" fill="none" stroke="{CORE}" stroke-width="2" stroke-linecap="round" transform="rotate(-90)" stroke-dasharray="{f(circ)}">'
         f'<animate attributeName="stroke-dashoffset" values="{";".join(f(v) for v in ring_vals)}" keyTimes="{kt(ring_keys,T)}" dur="{f(T)}s" repeatCount="indefinite"/></circle>'
         f'<path d="{sparkle(0, 0, 8)}" fill="{CORE}"/></g>')
wrap("calibration", "Calibration pursuit",
     "The glint drifts through 9 anchors (critically damped), pausing 1.2 s at each while a ring fills; samples are "
     "taken after the first 300 ms of each pause.", W, H, dots + glint)

# 6. Twinkle (production cadence 12 s; this study loops every 2.4 s) -----------------------------------
T = 2.4; cx, cy = 200, 110
sp = (f'<g transform="translate({cx} {cy})"><g>'
      f'<animateTransform attributeName="transform" type="scale" values="1;1;1.25;0.97;1" keyTimes="{kt([0,1.8,2.04,2.26,2.4],T)}" dur="{T}s" repeatCount="indefinite" calcMode="spline" keySplines="0 0 1 1;{STD};{STD};{STD}"/>'
      f'<g><animateTransform attributeName="transform" type="rotate" values="0;0;90;90" keyTimes="{kt([0,1.8,2.4,T],T)}" dur="{T}s" repeatCount="indefinite" calcMode="spline" keySplines="0 0 1 1;{STD};0 0 1 1"/>'
      f'<path d="{sparkle(0, 0, 56)}" fill="{CORE}"/></g></g></g>')
wrap("twinkle", "Glint twinkle",
     "While tracking, the mark's glint twinkles once every 12 s: scale 1 to 1.25 and a quarter turn over 600 ms (the glint is 4-fold symmetric, so the loop is seamless). "
     "This study compresses the rest period to 1.8 s.", 400, 220, sp)
print("motion studies written")
