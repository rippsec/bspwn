#!/usr/bin/env python3
"""Dark monochrome 'layers' wallpaper with the Nerd Font bat glyph (U+F0B5F).

Same composition idea as kali-layers: soft translucent bands fan out from the
emblem towards the left and down, emblem near the centre-right, light falling
off to the top-right. Greys only. Pillow + numpy; drawn at 2x and downsampled.

usage: gen_bat.py [out.jpg]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/bat.jpg"
W, H, K = 1600, 900, 2
SW, SH = W * K, H * K
NF = "/usr/share/fonts/nerd-fonts/Symbols/SymbolsNerdFontMono-Regular.ttf"
BAT = "\U000f0b5f"
EMB_X, EMB_Y = 905, 452          # emblem centre (centre-right, like the dragon)

# ---- base: dark, lightest bottom-left, darkest top-right
yy, xx = np.mgrid[0:SH, 0:SW].astype(np.float32)
t = np.clip((xx / SW) * 0.55 + (1 - yy / SH) * 0.45, 0, 1)       # 0 top-right .. 1 bottom-left (inverted below)
t = 1 - np.clip(((xx / SW) * 0.45 + (1 - yy / SH) * 0.55), 0, 1)  # 1 at bottom-left
base = 16 + 26 * t ** 1.3
img = np.stack([base, base, base + 1.5 * t], axis=-1)

# ---- layered bands fanning from the emblem
def bez(p0, p1, p2, p3, n=60):
    s = np.linspace(0, 1, n)[:, None]
    return ((1 - s) ** 3) * p0 + 3 * ((1 - s) ** 2) * s * p1 + 3 * (1 - s) * s ** 2 * p2 + (s ** 3) * p3


def curve_to(end, bend):
    o = np.array([EMB_X * K, EMB_Y * K], np.float32)
    e = np.array(end, np.float32) * K
    mid = (o + e) / 2
    nrm = np.array([-(e - o)[1], (e - o)[0]]); nrm /= np.linalg.norm(nrm)
    return bez(o, o + (mid - o) * 0.6 + nrm * bend * K, mid + nrm * bend * K * 0.8, e)


def band(c1, c2, lift, blur=1.2):
    poly = [tuple(p) for p in np.vstack([c1, c2[::-1]])]
    m = Image.new("L", (SW, SH), 0)
    ImageDraw.Draw(m).polygon(poly, fill=255)
    m = m.filter(ImageFilter.GaussianBlur(blur * K))
    return np.asarray(m, np.float32)[..., None] / 255 * lift


# left wing fan: edges end along the left border (x=0) at increasing heights
left_ends = [(0, 330), (0, 470), (0, 620), (0, 790), (0, 905)]
left_curves = [curve_to(e, -26 * (i + 1) ** 0.6 * (1 if i % 2 else 1.4)) for i, e in enumerate(left_ends)]
for i in range(len(left_curves) - 1):
    img += band(left_curves[i], left_curves[i + 1], 5.5 + 2.2 * i)

# tail streaks: fan down from the emblem to the bottom edge
down_ends = [(960, 905), (1040, 905), (1150, 905), (1290, 905)]
down_curves = [curve_to(e, 40 + 14 * i) for i, e in enumerate(down_ends)]
for i in range(len(down_curves) - 1):
    img += band(down_curves[i], down_curves[i + 1], 4.0 + 1.6 * i)

# soft light pool behind the emblem
glow = np.exp(-(((xx - EMB_X * K) / (470 * K)) ** 2 + ((yy - (EMB_Y - 20) * K) / (360 * K)) ** 2))
img += (glow * 20)[..., None]

# ---- vignette toward the top-right
vig = np.clip(((xx / SW) - 0.62) * 1.2 + (0.25 - yy / SH) * 0.5, 0, 1)
img *= (1 - 0.30 * vig)[..., None]

canvas = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))

# ---- the bat glyph, flat near-black
d = ImageDraw.Draw(canvas)
font = ImageFont.truetype(NF, 520 * K)
d.text((EMB_X * K, EMB_Y * K), BAT, font=font, fill=(5, 5, 7), anchor="mm")

out = canvas.resize((W, H), Image.LANCZOS)
arr = np.asarray(out, np.float32) + np.random.default_rng(4).normal(0, 1.2, (H, W, 1)).astype(np.float32)
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=95, subsampling=0, optimize=True)
print(OUT, out.size)
