#!/usr/bin/env python3
"""Compiles Saccade's brand artwork into native Swift vector data (DESIGN_SYSTEM §7). UI icons are SF Symbols.

Sources:  Design/Icons/*.svg (the mark, 24 grid) and Design/MenuBar/menubar-<state>.svg (18 grid)
Output:   Packages/SaccadeKit/Sources/SaccadeUI/Icons/SaccadeIconData.swift (generated, never edit by hand)

Supported SVG: <path> (all commands, absolute and relative, arcs converted to cubics), <circle>, <rect> (rx),
<line>. Each element is one named part (`data-part`), drawn as a stroke unless it has fill="currentColor".
Usage: python3 scripts/icons/build_icons.py [--check] [--emit-svg DIR]
  --check     exit 1 if the generated Swift file is out of date (CI)
  --emit-svg  write SVGs rebuilt from the parsed commands (fidelity check)
"""
import math
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

ROOT = pathlib.Path(__file__).resolve().parents[2]
ICONS = ROOT / "Design/Icons"
MENUBAR = ROOT / "Design/MenuBar"
OUTPUT = ROOT / "Packages/SaccadeKit/Sources/SaccadeUI/Icons/SaccadeIconData.swift"
NS = "{http://www.w3.org/2000/svg}"
KAPPA = 0.5522847498307936

# --- path parsing ---------------------------------------------------------------------------------------

TOKEN = re.compile(r"[MmLlHhVvCcSsQqTtAaZz]|[-+]?(?:\d*\.\d+|\d+\.?)(?:[eE][-+]?\d+)?")
ARITY = {"M": 2, "L": 2, "H": 1, "V": 1, "C": 6, "S": 4, "Q": 4, "T": 2, "A": 7, "Z": 0}


def tokenize(d):
    return TOKEN.findall(d)


def arc_to_cubics(x1, y1, rx, ry, phi, large, sweep, x2, y2):
    """SVG elliptical arc → list of cubic segments (W3C SVG implementation notes F.6)."""
    if rx == 0 or ry == 0 or (x1, y1) == (x2, y2):
        return [(x1, y1, x2, y2, x2, y2)]
    rx, ry = abs(rx), abs(ry)
    cp, sp = math.cos(math.radians(phi)), math.sin(math.radians(phi))
    dx, dy = (x1 - x2) / 2, (y1 - y2) / 2
    x1p, y1p = cp * dx + sp * dy, -sp * dx + cp * dy
    lam = x1p**2 / rx**2 + y1p**2 / ry**2
    if lam > 1:
        rx, ry = rx * math.sqrt(lam), ry * math.sqrt(lam)
    num = rx**2 * ry**2 - rx**2 * y1p**2 - ry**2 * x1p**2
    den = rx**2 * y1p**2 + ry**2 * x1p**2
    coef = math.sqrt(max(0, num / den)) * (-1 if large == sweep else 1)
    cxp, cyp = coef * rx * y1p / ry, -coef * ry * x1p / rx
    cx, cy = cp * cxp - sp * cyp + (x1 + x2) / 2, sp * cxp + cp * cyp + (y1 + y2) / 2

    def angle(u, v):
        a = math.atan2(u[0] * v[1] - u[1] * v[0], u[0] * v[0] + u[1] * v[1])
        return a

    t1 = angle((1, 0), ((x1p - cxp) / rx, (y1p - cyp) / ry))
    dt = angle(((x1p - cxp) / rx, (y1p - cyp) / ry), ((-x1p - cxp) / rx, (-y1p - cyp) / ry))
    if not sweep and dt > 0:
        dt -= 2 * math.pi
    elif sweep and dt < 0:
        dt += 2 * math.pi
    n = max(1, math.ceil(abs(dt) / (math.pi / 2) - 1e-9))
    step = dt / n
    k = 4 / 3 * math.tan(step / 4)
    out = []
    for i in range(n):
        a1, a2 = t1 + i * step, t1 + (i + 1) * step

        def pt(a, dxs=0.0, dys=0.0):
            ex, ey = rx * math.cos(a) + dxs, ry * math.sin(a) + dys
            return cp * ex - sp * ey + cx, sp * ex + cp * ey + cy

        p1 = pt(a1, -k * rx * math.sin(a1), k * ry * math.cos(a1))
        p2 = pt(a2, k * rx * math.sin(a2), -k * ry * math.cos(a2))
        p3 = pt(a2)
        out.append((*p1, *p2, *p3))
    return out


def parse_path(d):
    """Returns commands: ('M',x,y) ('L',x,y) ('C',x1,y1,x2,y2,x,y) ('Q',x1,y1,x,y) ('Z',) — all absolute."""
    tokens = tokenize(d)
    cmds, i = [], 0
    cur = start = (0.0, 0.0)
    last_c2 = last_q = None
    op = None
    while i < len(tokens):
        if re.match(r"[A-Za-z]", tokens[i]):
            op = tokens[i]
            i += 1
        elif op is None:
            raise ValueError(f"path data must start with a command: {d[:40]}")
        up, rel = op.upper(), op.islower()
        if up == "Z":
            cmds.append(("Z",))
            cur = start
            last_c2 = last_q = None
            op = None
            continue
        args = [float(t) for t in tokens[i : i + ARITY[up]]]
        if len(args) < ARITY[up]:
            raise ValueError(f"not enough arguments for {op} in {d[:40]}")
        i += ARITY[up]
        ox, oy = cur if rel else (0.0, 0.0)
        if up == "M":
            cur = start = (args[0] + ox, args[1] + oy)
            cmds.append(("M", *cur))
            op = "l" if rel else "L"  # implicit lineto after moveto
            last_c2 = last_q = None
        elif up in "LHV":
            if up == "L":
                cur = (args[0] + ox, args[1] + oy)
            elif up == "H":
                cur = (args[0] + (cur[0] if rel else 0), cur[1])
            else:
                cur = (cur[0], args[0] + (cur[1] if rel else 0))
            cmds.append(("L", *cur))
            last_c2 = last_q = None
        elif up in "CS":
            if up == "C":
                c1 = (args[0] + ox, args[1] + oy)
                c2, end = (args[2] + ox, args[3] + oy), (args[4] + ox, args[5] + oy)
            else:
                c1 = (2 * cur[0] - last_c2[0], 2 * cur[1] - last_c2[1]) if last_c2 else cur
                c2, end = (args[0] + ox, args[1] + oy), (args[2] + ox, args[3] + oy)
            cmds.append(("C", *c1, *c2, *end))
            cur, last_c2, last_q = end, c2, None
        elif up in "QT":
            if up == "Q":
                c, end = (args[0] + ox, args[1] + oy), (args[2] + ox, args[3] + oy)
            else:
                c = (2 * cur[0] - last_q[0], 2 * cur[1] - last_q[1]) if last_q else cur
                end = (args[0] + ox, args[1] + oy)
            cmds.append(("Q", *c, *end))
            cur, last_q, last_c2 = end, c, None
        elif up == "A":
            end = (args[5] + ox, args[6] + oy)
            for seg in arc_to_cubics(*cur, args[0], args[1], args[2], int(args[3]), int(args[4]), *end):
                cmds.append(("C", *seg))
            cur, last_c2, last_q = end, None, None
    return cmds


def circle(cx, cy, r):
    k = KAPPA * r
    return [("M", cx + r, cy), ("C", cx + r, cy + k, cx + k, cy + r, cx, cy + r),
            ("C", cx - k, cy + r, cx - r, cy + k, cx - r, cy), ("C", cx - r, cy - k, cx - k, cy - r, cx, cy - r),
            ("C", cx + k, cy - r, cx + r, cy - k, cx + r, cy), ("Z",)]


def rounded_rect(x, y, w, h, r):
    r = min(r, w / 2, h / 2)
    if r <= 0:
        return [("M", x, y), ("L", x + w, y), ("L", x + w, y + h), ("L", x, y + h), ("Z",)]
    k = KAPPA * r
    return [("M", x + r, y), ("L", x + w - r, y), ("C", x + w - r + k, y, x + w, y + r - k, x + w, y + r),
            ("L", x + w, y + h - r), ("C", x + w, y + h - r + k, x + w - r + k, y + h, x + w - r, y + h),
            ("L", x + r, y + h), ("C", x + r - k, y + h, x, y + h - r + k, x, y + h - r),
            ("L", x, y + r), ("C", x, y + r - k, x + r - k, y, x + r, y), ("Z",)]


# --- SVG loading ----------------------------------------------------------------------------------------

def load(path):
    root = ET.parse(path).getroot()
    vb = [float(v) for v in root.get("viewBox").split()]
    if vb[0] != 0 or vb[1] != 0 or vb[2] != vb[3]:
        raise ValueError(f"{path.name}: viewBox must be square and start at 0 0")
    title = (root.findtext(f"{NS}title") or path.stem).strip()
    parts, seen = [], set()
    for el in root:
        tag = el.tag.replace(NS, "")
        if tag == "title":
            continue
        part = el.get("data-part")
        if not part:
            raise ValueError(f"{path.name}: <{tag}> needs a data-part name")
        if part in seen:
            raise ValueError(f"{path.name}: duplicate data-part '{part}'")
        seen.add(part)
        g = lambda k: float(el.get(k, 0))
        if tag == "path":
            cmds = parse_path(el.get("d"))
        elif tag == "circle":
            cmds = circle(g("cx"), g("cy"), g("r"))
        elif tag == "rect":
            cmds = rounded_rect(g("x"), g("y"), g("width"), g("height"), float(el.get("rx", el.get("ry", 0))))
        elif tag == "line":
            cmds = [("M", g("x1"), g("y1")), ("L", g("x2"), g("y2"))]
        else:
            raise ValueError(f"{path.name}: unsupported element <{tag}>")
        style = "fill" if el.get("fill") == "currentColor" else "stroke"
        parts.append({"id": part, "style": style, "cmds": cmds})
    return {"grid": vb[2], "stroke": float(root.get("stroke-width", 1.5)), "title": title, "parts": parts}


# --- Swift emission ------------------------------------------------------------------------------------

def num(v):
    s = f"{v:.3f}".rstrip("0").rstrip(".")
    return "0" if s in ("-0", "") else s


def swift_cmd(c):
    op, a = c[0], [num(v) for v in c[1:]]
    if op == "Z":
        return ".close"
    name = {"M": "move", "L": "line", "C": "curve", "Q": "quad"}[op]
    return f".{name}({', '.join(a)})"


def case_name(stem):
    head, *rest = stem.split("-")
    return head + "".join(w[:1].upper() + w[1:] for w in rest)


def artwork(a, indent):
    pad = " " * indent
    lines = [f"SaccadeIconArtwork(grid: {num(a['grid'])}, strokeWidth: {num(a['stroke'])}, parts: ["]
    for p in a["parts"]:
        cmds = ", ".join(swift_cmd(c) for c in p["cmds"])
        lines.append(f'{pad}    SaccadeIconPart(id: "{p["id"]}", style: .{p["style"]}, commands: [{cmds}]),')
    lines.append(f"{pad}])")
    return "\n".join(lines)


def generate():
    icons = {p.stem: load(p) for p in sorted(ICONS.glob("*.svg"))}
    menubar = {p.stem.removeprefix("menubar-"): load(p) for p in sorted(MENUBAR.glob("menubar-*.svg"))}
    out = ["// Generated by scripts/icons/build_icons.py from Design/Icons and Design/MenuBar. Do not edit by hand.",
           "// swiftlint:disable file_length line_length type_body_length — generated vector data", "",
           "import SaccadeCore", "",
           "/// Brand artwork (DESIGN_SYSTEM §7). Source of truth: `Design/Icons/<rawValue>.svg`. UI icons use `SaccadeSymbol`.",
           "public enum SaccadeIconName: String, CaseIterable, Sendable {"]
    for stem in icons:
        name = case_name(stem)
        out.append(f"    case {name}" + (f' = "{stem}"' if name != stem else ""))
    out += ["", "    /// The icon's accessible name, from the SVG `<title>`.", "    public var title: String {",
            "        switch self {"]
    out += [f'        case .{case_name(s)}: "{a["title"]}"' for s, a in icons.items()]
    out += ["        }", "    }", "", "    public var artwork: SaccadeIconArtwork {", "        switch self {"]
    out += [f"        case .{case_name(s)}: SaccadeIconArtworks.{case_name(s)}" for s in icons]
    out += ["        }", "    }", "}", "",
            "extension MenuBarGlyphState {",
            "    /// Menu bar template artwork. Source of truth: `Design/MenuBar/menubar-<rawValue>.svg`.",
            "    public var artwork: SaccadeIconArtwork {", "        switch self {"]
    out += [f"        case .{s}: SaccadeIconArtworks.menuBar{s[0].upper() + s[1:]}" for s in menubar]
    out += ["        }", "    }", "}", "", "enum SaccadeIconArtworks {"]
    for s, a in icons.items():
        out.append(f"    static let {case_name(s)} = {artwork(a, 4)}")
    for s, a in menubar.items():
        out.append(f"    static let menuBar{s[0].upper() + s[1:]} = {artwork(a, 4)}")
    out += ["}", ""]
    return "\n".join(out), icons, menubar


def emit_svg(directory, items):
    directory.mkdir(parents=True, exist_ok=True)
    for stem, a in items.items():
        body = []
        for p in a["parts"]:
            d = " ".join(c[0] + " ".join(num(v) for v in c[1:]) for c in p["cmds"])
            fill = ' fill="currentColor" stroke="none"' if p["style"] == "fill" else ""
            body.append(f'<path d="{d}"{fill}/>')
        g = num(a["grid"])
        (directory / f"{stem}.svg").write_text(
            f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {g} {g}" fill="none" stroke="currentColor" '
            f'stroke-width="{num(a["stroke"])}" stroke-linecap="round" stroke-linejoin="round">{"".join(body)}</svg>\n')


def main(argv):
    swift, icons, menubar = generate()
    if "--emit-svg" in argv:
        emit_svg(pathlib.Path(argv[argv.index("--emit-svg") + 1]), {**icons, **{f"menubar-{k}": v for k, v in menubar.items()}})
    if "--check" in argv:
        if not OUTPUT.exists() or OUTPUT.read_text() != swift:
            print("SaccadeIconData.swift is out of date. Run: python3 scripts/icons/build_icons.py")
            return 1
        print(f"icons: {len(icons)} icons + {len(menubar)} menu bar glyphs up to date")
        return 0
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(swift)
    print(f"wrote {OUTPUT.relative_to(ROOT)}: {len(icons)} icons + {len(menubar)} menu bar glyphs")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
