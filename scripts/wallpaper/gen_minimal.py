#!/usr/bin/env python3
"""Minimal dark wallpaper: the glyph 四 centred, framed by a few sharp-edged
geometric patterns (diamond, brackets, broken crosshair, ticks, triangles).
Monochrome. Pillow + numpy only; drawn at 2x and downsampled.

usage: gen_minimal.py [out.jpg]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/minimal.jpg"
W, H, K = 1600, 900, 2
CX, CY = W / 2, H / 2
CJK = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"

WHITE, LIGHT, MID, DIM, FAINT = (242, 239, 233), (201, 198, 192), (142, 144, 153), (75, 77, 85), (32, 33, 37)

# background: very dark, slight lift toward the centre
yy, xx = np.mgrid[0:H * K, 0:W * K].astype(np.float32)
v = np.sqrt(((xx - CX * K) / (W * K * 0.6)) ** 2 + ((yy - CY * K) / (H * K * 0.9)) ** 2)
bg = (22 - 15 * np.clip(v, 0, 1)) [..., None] * np.ones((1, 1, 3), np.float32)
img = Image.fromarray(bg.astype(np.uint8))
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


# ---- large diamond + inner square (sharp, thin)
poly(rot_square(CX, CY, 262, 45), outline=DIM, w=1.2)          # diamond, vertices ~ +-370
poly(rot_square(CX, CY, 205, 0), outline=FAINT if False else (58, 59, 65), w=1.0)
poly(rot_square(CX, CY, 150, 45), outline=(48, 49, 55), w=1.0)

# ---- broken crosshair along the axes (gap around the glyph)
for sx in (-1, 1):
    ln(CX + sx * 235, CY, CX + sx * 560, CY, MID, 1.2)
    ln(CX + sx * 580, CY, CX + sx * 640, CY, DIM, 1.2)
for sy in (-1, 1):
    ln(CX, CY + sy * 215, CX, CY + sy * 400, MID, 1.2)
    ln(CX, CY + sy * 415, CX, CY + sy * 440, DIM, 1.2)

# ---- corner brackets around the glyph
B, L = 205, 46
for sx, sy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
    x, y = CX + sx * B, CY + sy * B
    ln(x, y, x - sx * L, y, WHITE, 2.4)
    ln(x, y, x, y - sy * L, WHITE, 2.4)

# ---- triangles on the diamond vertices (solid, sharp)
vr = 262 * math.sqrt(2)
for k, deg in enumerate((0, 90, 180, 270)):
    x = CX + vr * math.cos(math.radians(deg))
    y = CY + vr * math.sin(math.radians(deg))
    tri(x, y, 9, deg + 180, WHITE if k % 2 == 0 else MID)

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

# ---- the glyph
font = ImageFont.truetype(CJK, 380 * K, index=2)
d.text(P(CX + 3, CY + 3 + 6), "四", font=font, fill=(6, 6, 8), anchor="mm")         # hard offset shadow
d.text(P(CX - 1.5, CY - 1.5 + 6), "四", font=font, fill=(214, 211, 205), anchor="mm")  # white highlight edge (top-left)
d.text(P(CX, CY + 6), "四", font=font, fill=(46, 47, 53), anchor="mm")              # dark grey body

# ---- output
out = img.resize((W, H), Image.LANCZOS)
arr = np.asarray(out, np.float32)
arr += np.random.default_rng(4).normal(0, 1.4, (H, W, 1)).astype(np.float32)
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=94, subsampling=0, optimize=True)
print(OUT, out.size)
