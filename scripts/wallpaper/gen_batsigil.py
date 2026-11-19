#!/usr/bin/env python3
"""Original bat sigil wallpaper (not a Batman silhouette): a head-on, angular bat
built from sharp shards: tall blade ears, slit eyes, a kite-shaped head and wings
made of four bone-blades with notched membrane panels. Dark monochrome, flat.

All geometry is defined for the right half and mirrored. Pillow + numpy only,
drawn at 2x and downsampled.

usage: gen_batsigil.py [out.jpg]
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/batsigil.jpg"
W, H, K = 1600, 900, 2
CX, CY = W / 2, H / 2 + 12

# ---- palette (greys only)
BG0, BG1 = 12, 21
PANELS = [(30, 31, 36), (37, 38, 44), (30, 31, 36), (43, 44, 50)]   # wing membrane tones
BODY, BODY_HI = (50, 51, 58), (84, 86, 94)
BONE, EDGE = (86, 88, 97), (104, 106, 115)
EYE = (214, 212, 206)

# ---- background: dark vertical gradient with a faint light pool
yy, xx = np.mgrid[0:H * K, 0:W * K].astype(np.float32)
base = BG0 + (BG1 - BG0) * (yy / (H * K))
pool = np.exp(-(((xx - CX * K) / (520 * K)) ** 2 + ((yy - CY * K) / (330 * K)) ** 2)) * 9
img = Image.fromarray(np.clip(np.stack([base + pool] * 3, -1), 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)


def P(p):
    return ((CX + p[0]) * K, (CY + p[1]) * K)


def mir(p):
    return (-p[0], p[1])


def poly(pts, fill=None, edge=None, w=1.2):
    pts = [P(p) for p in pts]
    if fill:
        d.polygon(pts, fill=fill)
    if edge:
        d.line(pts + [pts[0]], fill=edge, width=max(1, round(w * K)), joint="curve")


def line(a, b, fill, w):
    d.line((P(a), P(b)), fill=fill, width=max(1, round(w * K)))


def both(pts):
    return pts, [mir(p) for p in pts]


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


# ---- frame: a big hexagon + inner triangle outline (sharp, very faint)
def regular(n, r, rot):
    return [(r * math.cos(math.radians(rot + 360 / n * i)), r * math.sin(math.radians(rot + 360 / n * i))) for i in range(n)]


poly(regular(6, 372, 0), edge=(40, 41, 47), w=1.2)
poly(regular(3, 410, -90), edge=(33, 34, 39), w=1.0)

# ---- wings (right side; mirrored)
S = (34, -4)                                        # shoulder
Wr = (200, -122)                                    # wrist
F = [(376, -218), (436, -52), (390, 94), (262, 178)]  # finger-blade tips, top -> bottom
B = (28, 100)                                       # lower body anchor
S2 = (42, 18)


def notch(a, b, pull=0.26):
    return lerp(lerp(a, b, 0.5), Wr, pull)           # trailing-edge V notch between two tips


panels = [
    [Wr, F[0], notch(F[0], F[1]), F[1]],
    [Wr, F[1], notch(F[1], F[2]), F[2]],
    [Wr, F[2], notch(F[2], F[3]), F[3]],
    [Wr, F[3], notch(F[3], B, 0.2), B, S2],
]
for i, pts in enumerate(panels):
    for side in both(pts):
        poly(side, fill=PANELS[i], edge=EDGE, w=1.1)
for tip in F:                                        # bone blades
    for a, b in (((Wr), tip), (mir(Wr), mir(tip))):
        line(a, b, BONE, 2.6)
for a, b in ((S, Wr), (mir(S), mir(Wr))):            # arm
    line(a, b, BONE, 4.6)
for p in (Wr, mir(Wr)):                              # wrist joint: small diamond
    poly([(p[0], p[1] - 9), (p[0] + 9, p[1]), (p[0], p[1] + 9), (p[0] - 9, p[1])], fill=BODY_HI)

# ---- body + head
torso = [(-27, 36), (27, 36), (20, 112), (0, 158), (-20, 112)]
poly(torso, fill=BODY, edge=BODY_HI, w=1.4)
line((0, 44), (0, 148), BODY_HI, 1.2)                # spine
for k in range(4):                                   # chest chevrons
    y = 56 + k * 20
    line((-14, y), (0, y + 10), BODY_HI, 1.1)
    line((0, y + 10), (14, y), BODY_HI, 1.1)

for ear in both([(14, -90), (66, -214), (50, -66)]):  # blade ears
    poly(ear, fill=BODY, edge=BODY_HI, w=1.4)
for inner in both([(22, -92), (56, -178), (44, -74)]):
    poly(inner, fill=(27, 28, 33))
head = [(0, -86), (46, -54), (36, 8), (0, 66), (-36, 8), (-46, -54)]
poly(head, fill=BODY, edge=BODY_HI, w=1.6)
for eye in both([(10, -30), (42, -42), (14, -20)]):   # slit eyes
    poly(eye, fill=EYE)
for fang in both([(5, 30), (13, 30), (9, 46)]):       # tiny fangs
    poly(fang, fill=EYE)
poly([(-9, -4), (9, -4), (0, 10)], fill=(28, 29, 34))  # nose

# ---- output (flat, tiny grain)
out = img.resize((W, H), Image.LANCZOS)
arr = np.asarray(out, np.float32) + np.random.default_rng(4).normal(0, 1.0, (H, W, 1)).astype(np.float32)
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=95, subsampling=0, optimize=True)
print(OUT, out.size)
