#!/usr/bin/env python3
"""Recolour a black-and-white emblem into a muted dark-grey wallpaper.

Look: limited muted palette, low contrast, matte, flat lighting, no pure white,
low dynamic range (every pixel stays within 19..72). The emblem's three tones are
mapped like this: black body/outline -> INK, the white ring/eyes inside the emblem
-> RING, the white page outside -> BG.

usage: gen_batlogo.py [logo.png] [out.jpg]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[2]
SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/src/bat-emblem.png"
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else ROOT / "assets/wallpaper/batlogo.jpg"
W, H = 1600, 900
LOGO_W = 870                       # emblem width: keeps the right wing tip clear of the conky HUD (starts x~1258)

BG = np.array((31, 32, 36), np.float32)      # page
INK = np.array((19, 20, 23), np.float32)     # emblem body + outline
RING = np.array((70, 72, 78), np.float32)    # inner ring / eyes (the "white" inside the emblem)

# -- composite on white, grayscale
im = Image.open(SRC).convert("RGBA")
page = Image.new("RGBA", im.size, (255, 255, 255, 255))
page.alpha_composite(im)
g = np.asarray(page.convert("L"), np.float32) / 255.0          # 0 ink .. 1 white

# -- which white is the outside page? flood from the corner, then grow 2 px to cover anti-aliasing
white = g > 0.5
labels, _ = ndimage.label(white)
outside = labels == labels[0, 0]
outside = ndimage.binary_dilation(outside, iterations=2)

# -- colourise: ink -> white-colour blend, white-colour depends on inside/outside
whitecol = np.where(outside[..., None], BG, RING)
out = INK * (1 - g[..., None]) + whitecol * g[..., None]

# -- crop to the emblem, scale, centre on the canvas
ys, xs = np.where(~outside | (g < 0.5))
y0, y1, x0, x1 = ys.min(), ys.max() + 1, xs.min(), xs.max() + 1
emblem = Image.fromarray(np.clip(out[y0:y1, x0:x1], 0, 255).astype(np.uint8))
scale = LOGO_W / emblem.width
emblem = emblem.resize((LOGO_W, round(emblem.height * scale)), Image.LANCZOS)

canvas = Image.new("RGB", (W, H), tuple(int(v) for v in BG))
canvas.paste(emblem, ((W - emblem.width) // 2, (H - emblem.height) // 2))

# -- matte: a touch of grain only
arr = np.asarray(canvas, np.float32) + np.random.default_rng(4).normal(0, 0.8, (H, W, 1)).astype(np.float32)
res = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
res.save(OUT, quality=95, subsampling=0, optimize=True)
print(OUT, res.size)
