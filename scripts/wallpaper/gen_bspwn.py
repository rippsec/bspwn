#!/usr/bin/env python3
"""Minimal dark wallpaper: the word BSPWN centred, framed by sharp-edged
tech patterns (corner brackets, ticks, hatch).
Flat design: only black and dark greys, no shadows, highlights or gradients. Pillow + numpy only; drawn at 2x and downsampled.

usage: gen_bspwn.py [out.jpg] [font.ttf]
"""
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/bspwn.jpg"
W, H, K = 1600, 900, 2
CX, CY = W / 2, H / 2
FONT = sys.argv[2] if len(sys.argv) > 2 else str(Path.home() / ".local/share/fonts/AtkinsonHyperlegibleMono/AtkinsonHyperlegibleMono-Bold.ttf")

# flat palette: everything stays dark grey on black
BG = (11, 11, 13)
WHITE, LIGHT, MID, DIM, FAINT = (86, 88, 96), (74, 76, 83), (62, 64, 71), (46, 47, 53), (30, 31, 35)
GLYPH = (56, 58, 65)

img = Image.new("RGB", (W * K, H * K), BG)
d = ImageDraw.Draw(img)


def P(x, y):
    return (x * K, y * K)


def ln(x0, y0, x1, y1, fill=DIM, w=1.0):
    d.line((P(x0, y0), P(x1, y1)), fill=fill, width=max(1, round(w * K)))


def poly(pts, fill=None, outline=None, w=1.0):
    pts = [P(*p) for p in pts]
    if fill:
        d.polygon(pts, fill=fill)
    if outline:
        d.line(pts + [pts[0]], fill=outline, width=max(1, round(w * K)), joint="miter")


def rot_square(cx, cy, half, deg):
    a = math.radians(deg)
    out = []
    for sx, sy in ((-1, -1), (1, -1), (1, 1), (-1, 1)):
        x, y = sx * half, sy * half
        out.append((cx + x * math.cos(a) - y * math.sin(a), cy + x * math.sin(a) + y * math.cos(a)))
    return out


def tri(cx, cy, r, deg, fill):
    poly([(cx + r * math.cos(math.radians(deg + 120 * k)), cy + r * math.sin(math.radians(deg + 120 * k)))
          for k in range(3)], fill=fill)


# ---- corner brackets
for sx, sy, x0, y0 in ((1, 1, 90, 90), (-1, 1, 1510, 90), (1, -1, 90, 810), (-1, -1, 1510, 810)):
    ln(x0, y0, x0 + sx * 60, y0, MID, 1.2)
    ln(x0, y0, x0, y0 + sy * 60, MID, 1.2)

# ---- tick scales on the left and bottom edges
for i in range(0, 41):
    y = 130 + i * 16
    ln(40, y, 40 + (22 if i % 5 == 0 else 10), y, MID if i % 5 == 0 else DIM, 1.2)
for i in range(0, 61):
    x = 320 + i * 16
    ln(x, 862, x, 862 - (16 if i % 5 == 0 else 8), MID if i % 5 == 0 else DIM, 1.2)

# ---- diagonal hatch in two opposite corners (sharp parallel lines)
for i in range(7):
    o = i * 14
    ln(1560 - o, 40, 1560, 40 + o, DIM if i % 3 else MID, 1.0)
    ln(40 + o, 860, 40, 860 - o, DIM if i % 3 else MID, 1.0)

# ---- the text
font = ImageFont.truetype(FONT, 120 * K)
d.text(P(CX, CY), "BSPWN", font=font, fill=GLYPH, anchor="mm")

# ---- output (flat: no grain, no vignette)
out = img.resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=95, subsampling=0, optimize=True)
print(OUT, out.size)
