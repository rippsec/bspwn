#!/usr/bin/env python3
"""Monochrome 'hackerish' emblem wallpaper: the glyph 四 as the main emblem,
surrounded by abstract geometry (segmented rings, rotated squares, triangles,
reticle, tick scales, node graph, hex/binary fragments).

The right ~22% stays calm for the conky HUD. Builds an SVG and renders it with
rsvg-convert, then adds film grain + vignette with PIL.

usage: gen_emblem.py [out.jpg] [WIDTHxHEIGHT] [--svg]   (default 3200x1800)
"""
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/emblem.jpg"
W, H = (int(v) for v in (sys.argv[2] if len(sys.argv) > 2 else "3200x1800").split("x"))
S = W / 3200
rng = np.random.default_rng(4)          # 四

WHITE, LIGHT, MID, DIM, FAINT = "#f2efe9", "#c9c6c0", "#8e9099", "#4b4d55", "#26272b"
BG0, BG1 = "#0a0a0c", "#141417"
MONO = "Atkinson Hyperlegible Mono"
CX, CY = 1240 * S, 900 * S              # emblem centre (left of the HUD column)

svg = []
add = svg.append


def f(v):
    return f"{v:.1f}"


def polar(r, deg, cx=CX, cy=CY):
    a = math.radians(deg)
    return cx + r * math.cos(a), cy + r * math.sin(a)


def arc(r, a0, a1, stroke, width, op=1.0, dash=None, cx=CX, cy=CY):
    x0, y0 = polar(r, a0, cx, cy)
    x1, y1 = polar(r, a1, cx, cy)
    large = 1 if (a1 - a0) % 360 > 180 else 0
    d = f' stroke-dasharray="{dash}"' if dash else ""
    add(f'<path d="M{f(x0)},{f(y0)} A{f(r)},{f(r)} 0 {large} 1 {f(x1)},{f(y1)}" fill="none" '
        f'stroke="{stroke}" stroke-width="{f(width)}" opacity="{op}"{d}/>')


def line(x0, y0, x1, y1, stroke, width, op=1.0, dash=None):
    d = f' stroke-dasharray="{dash}"' if dash else ""
    add(f'<line x1="{f(x0)}" y1="{f(y0)}" x2="{f(x1)}" y2="{f(y1)}" stroke="{stroke}" '
        f'stroke-width="{f(width)}" opacity="{op}"{d}/>')


def text(x, y, s, size, fill, op=1.0, anchor="start", ls=0, weight=400, family=MONO):
    add(f'<text x="{f(x)}" y="{f(y)}" font-family="{family}" font-size="{f(size)}" font-weight="{weight}" '
        f'fill="{fill}" opacity="{op}" text-anchor="{anchor}" letter-spacing="{f(ls)}">{s}</text>')


def rsquare(cx, cy, size, deg, stroke, width, op=1.0, fill="none", dash=None):
    pts = [polar(size / math.sqrt(2), deg + 45 + 90 * k, cx, cy) for k in range(4)]
    d = f' stroke-dasharray="{dash}"' if dash else ""
    add(f'<polygon points="{" ".join(f"{f(a)},{f(b)}" for a, b in pts)}" fill="{fill}" stroke="{stroke}" '
        f'stroke-width="{f(width)}" opacity="{op}"{d}/>')


def tri(cx, cy, r, deg, stroke, width, op=1.0, fill="none"):
    pts = [polar(r, deg + 120 * k, cx, cy) for k in range(3)]
    add(f'<polygon points="{" ".join(f"{f(a)},{f(b)}" for a, b in pts)}" fill="{fill}" stroke="{stroke}" '
        f'stroke-width="{f(width)}" opacity="{op}"/>')


# ------------------------------------------------------------------ canvas
add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
add(f'''<defs>
  <radialGradient id="bg" cx="{CX / W:.3f}" cy="{CY / H:.3f}" r="0.9">
    <stop offset="0" stop-color="{BG1}"/><stop offset="1" stop-color="{BG0}"/>
  </radialGradient>
  <radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{WHITE}" stop-opacity="0.08"/>
    <stop offset="1" stop-color="{WHITE}" stop-opacity="0"/>
  </radialGradient>
  <filter id="glow" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="{f(10 * S)}" result="b"/>
    <feComponentTransfer in="b" result="bl"><feFuncA type="linear" slope="0.35"/></feComponentTransfer>
    <feMerge><feMergeNode in="bl"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="soft" x="-30%" y="-30%" width="160%" height="160%">
    <feGaussianBlur stdDeviation="{f(3 * S)}" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <pattern id="dots" width="{f(40 * S)}" height="{f(40 * S)}" patternUnits="userSpaceOnUse">
    <rect x="{f(19 * S)}" y="{f(19 * S)}" width="{f(2 * S)}" height="{f(2 * S)}" fill="{FAINT}"/>
  </pattern>
</defs>''')
add(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
add(f'<rect width="{W}" height="{H}" fill="url(#dots)" opacity="0.9"/>')
add(f'<circle cx="{f(CX)}" cy="{f(CY)}" r="{f(820 * S)}" fill="url(#halo)"/>')

# ------------------------------------------------------------------ rings
# outer segmented ring with tick scale
R1 = 640 * S
for k in range(12):
    a0 = k * 30 + 3
    arc(R1, a0, a0 + 22, LIGHT if k % 3 else WHITE, 3 * S, 0.55 if k % 3 else 0.85)
for deg in range(0, 360, 3):
    long_ = deg % 15 == 0
    r_in, r_out = R1 + 14 * S, R1 + (40 if long_ else 24) * S
    x0, y0 = polar(r_in, deg)
    x1, y1 = polar(r_out, deg)
    line(x0, y0, x1, y1, MID, (2.2 if long_ else 1.2) * S, 0.75 if long_ else 0.4)
for deg in range(0, 360, 45):
    x, y = polar(R1 + 74 * S, deg)
    text(x, y + 8 * S, f"{deg:03d}", 22 * S, MID, 0.7, "middle")
# dashed mid rings + rotating-looking partial arcs
arc(500 * S, 0, 359.9, DIM, 1.6 * S, 0.8, dash=f"{f(4 * S)} {f(14 * S)}")
arc(470 * S, 200, 330, WHITE, 6 * S, 0.9)
arc(470 * S, 20, 70, LIGHT, 6 * S, 0.6)
arc(430 * S, 95, 175, MID, 2 * S, 0.7)
arc(780 * S, 120, 160, MID, 1.6 * S, 0.5, dash=f"{f(20 * S)} {f(10 * S)}")
arc(780 * S, 290, 340, MID, 1.6 * S, 0.5, dash=f"{f(20 * S)} {f(10 * S)}")
arc(880 * S, 200, 250, DIM, 1.2 * S, 0.6)

# ------------------------------------------------------------------ squares / frame
rsquare(CX, CY, 760 * S, 45, DIM, 1.4 * S, 0.7)                     # big diamond
rsquare(CX, CY, 600 * S, 0, MID, 1.2 * S, 0.35, dash=f"{f(3 * S)} {f(9 * S)}")
# corner brackets framing the glyph
B, L = 330 * S, 70 * S
for sx, sy in [(-1, -1), (1, -1), (-1, 1), (1, 1)]:
    x, y = CX + sx * B, CY + sy * B
    line(x, y, x - sx * L, y, WHITE, 4 * S, 0.9)
    line(x, y, x, y - sy * L, WHITE, 4 * S, 0.9)
# crosshair ticks on the axes
for deg in (0, 90, 180, 270):
    x0, y0 = polar(360 * S, deg)
    x1, y1 = polar(420 * S, deg)
    line(x0, y0, x1, y1, WHITE, 3 * S, 0.9)

# ------------------------------------------------------------------ the emblem 四
# soft glow only
add(f'<text x="{f(CX)}" y="{f(CY + 165 * S)}" font-family="Noto Sans CJK JP" font-weight="900" '
    f'font-size="{f(440 * S)}" fill="#e6e3dd" text-anchor="middle" filter="url(#glow)">四</text>')
text(CX, CY + 300 * S, "S H I · 0 4", 26 * S, MID, 0.9, "middle", ls=6 * S)

# ------------------------------------------------------------------ satellites: triangles, squares, nodes
nodes = [(760, 170), (330, 640), (520, 1500), (1980, 380), (2130, 1180), (1040, 1730), (170, 1080)]
nodes = [(a * S, b * S) for a, b in nodes]
# dotted links only between neighbouring outer nodes (never across the emblem)
for a, b in [(1, 6), (6, 2), (0, 3), (3, 4)]:
    (x, y), (x2, y2) = nodes[a], nodes[b]
    line(x, y, x2, y2, FAINT, 1.4 * S, 0.9, dash=f"{f(2 * S)} {f(8 * S)}")
for k, (x, y) in enumerate(nodes):
    if k % 3 == 0:
        tri(x, y, 34 * S, -90 + 20 * k, LIGHT, 2 * S, 0.8)
    elif k % 3 == 1:
        rsquare(x, y, 40 * S, 15 * k, LIGHT, 2 * S, 0.8)
    else:
        add(f'<circle cx="{f(x)}" cy="{f(y)}" r="{f(18 * S)}" fill="none" stroke="{LIGHT}" stroke-width="{f(2 * S)}" opacity="0.8"/>')
    add(f'<rect x="{f(x - 3 * S)}" y="{f(y - 3 * S)}" width="{f(6 * S)}" height="{f(6 * S)}" fill="{WHITE}"/>')
    text(x + 46 * S, y + 6 * S, f"N{k:02d}·{rng.integers(0x1000, 0xffff):04X}", 20 * S, MID, 0.75)
# spokes from the ring to a few nodes
for k in (0, 3, 4):
    x, y = nodes[k]
    ang = math.degrees(math.atan2(y - CY, x - CX))
    x0, y0 = polar(R1 + 44 * S, ang)
    line(x0, y0, x, y, DIM, 1.4 * S, 0.8)

# big filled triangle accent (solid grey) + hollow twin
tri(2010 * S, 760 * S, 120 * S, 30, MID, 2 * S, 0.9)
tri(2010 * S, 760 * S, 70 * S, 30, WHITE, 0, 0.12, fill=WHITE)
rsquare(470 * S, 1290 * S, 150 * S, 20, LIGHT, 2 * S, 0.6)
rsquare(470 * S, 1290 * S, 90 * S, 20, WHITE, 0, 0.1, fill=WHITE)

# ------------------------------------------------------------------ data fragments
for k in range(9):
    bits = " ".join(format(int(v), "08b") for v in rng.integers(0, 256, 3))
    text(130 * S, (210 + k * 34) * S, bits, 20 * S, DIM, 0.85)
for k in range(7):
    hx = " ".join(f"{int(v):02X}" for v in rng.integers(0, 256, 8))
    text(1720 * S, (1540 + k * 32) * S, f"0x{0x7780 + k * 16:05X}  {hx}", 20 * S, DIM, 0.85)
# vertical scale on the left edge
for k in range(40):
    y = (420 + k * 26) * S
    ln = 34 if k % 5 == 0 else 14
    line(40 * S, y, (40 + ln) * S, y, MID, 1.6 * S, 0.7 if k % 5 == 0 else 0.35)
# caption bottom-left
text(130 * S, H - 140 * S, "四 // PRECISION", 44 * S, WHITE, 0.9, ls=8 * S, weight=600)
text(130 * S, H - 92 * S, "bspwm · node 7780 · sys nominal", 22 * S, MID, 0.9, ls=3 * S)
line(130 * S, H - 200 * S, 540 * S, H - 200 * S, WHITE, 3 * S, 0.8)
add('</svg>')

with tempfile.TemporaryDirectory() as d:
    svgp, pngp = Path(d) / "emblem.svg", Path(d) / "emblem.png"
    svgp.write_text("\n".join(svg))
    if "--svg" in sys.argv:
        OUT.with_suffix(".svg").write_text("\n".join(svg))
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(pngp), str(svgp)], check=True)
    img = np.asarray(Image.open(pngp).convert("RGB"), np.float32)

yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
v = np.sqrt(((xx - W * 0.45) / (W * 0.8)) ** 2 + ((yy - H / 2) / (H * 0.8)) ** 2)
img *= (1 - 0.35 * np.clip(v, 0, 1) ** 2)[..., None]
img += rng.normal(0, 2.0, (H, W, 1)).astype(np.float32)
out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=93, subsampling=0, optimize=True)
print(OUT, out.size)
