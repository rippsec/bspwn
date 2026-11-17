#!/usr/bin/env python3
"""Minimal abstract dragon wallpaper (original design) — black / white / red.

A serpentine dragon coiled in a spiral: white line-art body with chevron scales,
red dorsal spikes, red eye, thin red enso ring, small red seal with 龍.
The right ~22% stays empty for the conky HUD.

Builds an SVG, renders it with rsvg-convert, then adds film grain with PIL.

usage: gen_dragon.py [out.jpg] [WIDTHxHEIGHT]   (default 3200x1800 = 2x 1600x900)
"""
import math
import subprocess
import sys
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/dragon.jpg"
W, H = (int(v) for v in (sys.argv[2] if len(sys.argv) > 2 else "3200x1800").split("x"))
S = W / 3200

RED, RED_HI, WHITE, BG0, BG1 = "#e5383b", "#ff5a5f", "#ece8e1", "#0a0a0c", "#121216"

# ------------------------------------------------------------------ spine
CX, CY = 1230 * S, 930 * S            # coil centre (left of the HUD column)
N = 1400
t = np.linspace(0, 1, N)
theta = -0.62 * math.pi + t * 1.92 * math.pi          # head at upper right, coils clockwise inward
radius = (660 - 350 * t ** 0.9) * S + 46 * S * np.sin(t * 7 * math.pi) * (1 - t) ** 1.2
x = CX + radius * np.cos(theta)
y = CY + radius * np.sin(theta)
# body half-width: thick neck, long whip tail
half = (68 * (1 - t) ** 0.75 + 2.5) * S
half[:40] *= np.linspace(0.82, 1, 40)                  # neck slightly narrower than chest

dx, dy = np.gradient(x), np.gradient(y)
ln = np.hypot(dx, dy)
tx, ty = dx / ln, dy / ln                              # tangent (head -> tail)
nx, ny = -ty, tx                                       # normal (points outward of the coil)
if np.mean(nx * (x - CX) + ny * (y - CY)) < 0:
    nx, ny = -nx, -ny

lx, ly = x + nx * half, y + ny * half                  # outer edge
rx, ry = x - nx * half, y - ny * half                  # inner edge


def pts(xs, ys):
    return " ".join(f"{a:.1f},{b:.1f}" for a, b in zip(xs, ys))


svg = []
add = svg.append
add(f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">')
add(f'''<defs>
  <radialGradient id="bg" cx="{CX / W:.3f}" cy="{CY / H:.3f}" r="0.85">
    <stop offset="0" stop-color="{BG1}"/><stop offset="1" stop-color="{BG0}"/>
  </radialGradient>
  <radialGradient id="halo" cx="0.5" cy="0.5" r="0.5">
    <stop offset="0" stop-color="{RED}" stop-opacity="0.16"/>
    <stop offset="0.6" stop-color="{RED}" stop-opacity="0.05"/>
    <stop offset="1" stop-color="{RED}" stop-opacity="0"/>
  </radialGradient>
  <filter id="glow" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="{9 * S:.1f}" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="softglow" x="-50%" y="-50%" width="200%" height="200%">
    <feGaussianBlur stdDeviation="{4 * S:.1f}" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
</defs>''')
add(f'<rect width="{W}" height="{H}" fill="url(#bg)"/>')
# red halo + enso ring (open circle, brush-like: thick to thin)
add(f'<circle cx="{CX:.0f}" cy="{CY:.0f}" r="{900 * S:.0f}" fill="url(#halo)"/>')
ring_r = 820 * S
for k in range(60):
    a0 = math.radians(150 + k * 5.0)
    a1 = math.radians(150 + (k + 1) * 5.0 + 0.6)
    wdt = (1.0 + 7.0 * math.sin(math.pi * k / 60) ** 1.5) * S
    add(f'<path d="M{CX + ring_r * math.cos(a0):.1f},{CY + ring_r * math.sin(a0):.1f} '
        f'A{ring_r:.1f},{ring_r:.1f} 0 0 1 {CX + ring_r * math.cos(a1):.1f},{CY + ring_r * math.sin(a1):.1f}" '
        f'stroke="{RED}" stroke-width="{wdt:.1f}" fill="none" stroke-linecap="round" opacity="0.85" filter="url(#softglow)"/>')

# ------------------------------------------------------------------ body
# black body fill so the coil occludes what is behind it, then white outline
body = pts(lx, ly) + " " + pts(rx[::-1], ry[::-1])
add(f'<polygon points="{body}" fill="{BG0}" stroke="none"/>')
add(f'<polyline points="{pts(lx, ly)}" fill="none" stroke="{WHITE}" stroke-width="{2.6 * S:.1f}" stroke-linejoin="round" opacity="0.92"/>')
add(f'<polyline points="{pts(rx, ry)}" fill="none" stroke="{WHITE}" stroke-width="{2.0 * S:.1f}" stroke-linejoin="round" opacity="0.7"/>')

# chevron scales pointing towards the tail
step = 14
for i in range(30, N - 60, step):
    k = i / N
    j = min(N - 1, i + int(step * 0.9))
    op = 0.75 * (1 - k) ** 0.5 + 0.08
    sw = max(0.8, 1.8 * (1 - k)) * S
    a = (x[i] + nx[i] * half[i] * 0.88, y[i] + ny[i] * half[i] * 0.88)
    b = (x[j], y[j])
    c = (x[i] - nx[i] * half[i] * 0.88, y[i] - ny[i] * half[i] * 0.88)
    add(f'<polyline points="{a[0]:.1f},{a[1]:.1f} {b[0]:.1f},{b[1]:.1f} {c[0]:.1f},{c[1]:.1f}" '
        f'fill="none" stroke="{WHITE}" stroke-width="{sw:.2f}" opacity="{op:.2f}" stroke-linejoin="round"/>')

# red dorsal spikes on the outer edge, swept back
spikes = []
for i in range(55, int(N * 0.86), 26):
    k = i / N
    h = (70 * (1 - k) ** 1.1 + 6) * S
    w2 = (16 * (1 - k) + 3) * S
    bx, by = lx[i], ly[i]
    tipx = bx + nx[i] * h + tx[i] * h * 0.55
    tipy = by + ny[i] * h + ty[i] * h * 0.55
    spikes.append(f'M{bx - tx[i] * w2:.1f},{by - ty[i] * w2:.1f} L{tipx:.1f},{tipy:.1f} '
                  f'L{bx + tx[i] * w2:.1f},{by + ty[i] * w2:.1f} Z')
add(f'<path d="{" ".join(spikes)}" fill="{RED}" opacity="0.95" filter="url(#glow)"/>')

# tail flourish: a thin red whip continuing the spiral
tt = np.linspace(0, 1, 200)
th2 = theta[-1] + tt * 0.9 * math.pi
r2 = radius[-1] * (1 - 0.55 * tt)
add(f'<polyline points="{pts(CX + r2 * np.cos(th2), CY + r2 * np.sin(th2))}" fill="none" stroke="{RED}" '
    f'stroke-width="{2.2 * S:.1f}" stroke-linecap="round" opacity="0.9" filter="url(#softglow)"/>')

# ------------------------------------------------------------------ legs (clawed)
def leg(i, side=-1, scale=1.0):
    """line-art foreleg on the inner side of the body at spine index i"""
    k = i / N
    sz = (120 * (1 - k) + 50) * S * scale
    bx, by = x[i] + side * nx[i] * half[i], y[i] + side * ny[i] * half[i]
    ox, oy = side * nx[i], side * ny[i]                    # away from the body
    ex, ey = bx + ox * sz * 0.9 + tx[i] * sz * 0.5, by + oy * sz * 0.9 + ty[i] * sz * 0.5   # elbow
    wx, wy = ex + ox * sz * 0.5 - tx[i] * sz * 0.6, ey + oy * sz * 0.5 - ty[i] * sz * 0.6   # wrist
    add(f'<polyline points="{bx:.1f},{by:.1f} {ex:.1f},{ey:.1f} {wx:.1f},{wy:.1f}" fill="none" stroke="{WHITE}" '
        f'stroke-width="{2.4 * S:.1f}" stroke-linejoin="round" stroke-linecap="round" opacity="0.9"/>')
    for ang in (-0.55, 0.0, 0.55):                          # three talons
        ca, sa = math.cos(ang), math.sin(ang)
        dxx, dyy = (-tx[i]) * ca - ox * sa * 0.0 + ox * 0.35, (-ty[i]) * ca + oy * 0.35
        dxx, dyy = dxx * math.cos(ang) - dyy * math.sin(ang), dxx * math.sin(ang) + dyy * math.cos(ang)
        cx2, cy2 = wx + dxx * sz * 0.42, wy + dyy * sz * 0.42
        add(f'<line x1="{wx:.1f}" y1="{wy:.1f}" x2="{cx2:.1f}" y2="{cy2:.1f}" stroke="{RED}" '
            f'stroke-width="{2.4 * S:.1f}" stroke-linecap="round" filter="url(#softglow)"/>')


# (legs left out on purpose: the coiled serpent reads cleaner without them)

# ------------------------------------------------------------------ head
# local frame at the neck: f = forward (away from the body), u = outward normal
fx, fy = -tx[0], -ty[0]
ux, uy = nx[0], ny[0]
hx0, hy0 = x[0], y[0]
L, Wd = 205 * S, half[0] * 1.25


def P(a, b):
    """local (forward a, lateral b) in head units -> screen"""
    return hx0 + fx * a * L + ux * b * Wd, hy0 + fy * a * L + uy * b * Wd


def poly(points):
    return " ".join(f"{px:.1f},{py:.1f}" for px, py in (P(a, b) for a, b in points))


def tapered(p0, c, p1, w0, w1, n=40):
    """filled tapered quadratic stroke (horns, mane flames)"""
    ts = np.linspace(0, 1, n)
    q = [((1 - u) ** 2 * p0[0] + 2 * (1 - u) * u * c[0] + u ** 2 * p1[0],
          (1 - u) ** 2 * p0[1] + 2 * (1 - u) * u * c[1] + u ** 2 * p1[1]) for u in ts]
    left, right = [], []
    for j, (qx, qy) in enumerate(q):
        a2, b2 = q[max(0, j - 1)], q[min(n - 1, j + 1)]
        ddx, ddy = b2[0] - a2[0], b2[1] - a2[1]
        l2 = math.hypot(ddx, ddy) or 1
        wv = w0 + (w1 - w0) * ts[j]
        left.append((qx - ddy / l2 * wv, qy + ddx / l2 * wv))
        right.append((qx + ddy / l2 * wv, qy - ddx / l2 * wv))
    return " ".join(f"{px:.1f},{py:.1f}" for px, py in left + right[::-1])


# horns first (behind the skull): long, swept back, tapered
for (a0, b0), (ac, bc), (a1, b1), w0, op in [((0.45, 1.15), (-0.3, 2.1), (-1.7, 1.75), 9, 0.95),
                                            ((0.7, 1.05), (0.1, 1.75), (-1.05, 1.6), 6, 0.6)]:
    add(f'<polygon points="{tapered(P(a0, b0), P(ac, bc), P(a1, b1), w0 * S, 0.6 * S)}" fill="{WHITE}" opacity="{op}"/>')

# mane: red flame strokes along the back of the neck
for k in range(6):
    a0 = 0.15 - 0.22 * k
    add(f'<polygon points="{tapered(P(a0, 1.0), P(a0 - 0.35, 1.8 + 0.15 * (k % 2)), P(a0 - 0.95, 1.9 + 0.3 * (k % 2)), (7 - k * 0.8) * S, 0.5 * S)}" '
        f'fill="{RED}" opacity="{0.95 - 0.1 * k:.2f}" filter="url(#softglow)"/>')

# skull with open jaws
skull = [(0, 1.0), (0.35, 1.25), (0.75, 1.15), (1.0, 0.88), (1.55, 0.58), (1.95, 0.4), (2.12, 0.14),
         (2.05, -0.02), (1.45, -0.08), (2.0, -0.42), (1.92, -0.58), (1.2, -0.8), (0.6, -1.08),
         (0.2, -1.15), (0, -1.0)]
add(f'<polygon points="{poly(skull)}" fill="{BG0}" stroke="none"/>')
# outline without the back edge, so the head flows into the neck
add(f'<polyline points="{poly(skull)}" fill="none" stroke="{WHITE}" stroke-width="{2.8 * S:.1f}" stroke-linejoin="round" stroke-linecap="round"/>')
# fangs (upper + lower)
fangs = []
for a in (1.62, 1.85):
    p1, p2, p3 = P(a, -0.04), P(a + 0.05, -0.3), P(a + 0.1, -0.05)
    fangs.append(f"M{p1[0]:.1f},{p1[1]:.1f} L{p2[0]:.1f},{p2[1]:.1f} L{p3[0]:.1f},{p3[1]:.1f} Z")
for a in (1.55, 1.78):
    p1, p2, p3 = P(a, -0.36), P(a + 0.05, -0.12), P(a + 0.1, -0.4)
    fangs.append(f"M{p1[0]:.1f},{p1[1]:.1f} L{p2[0]:.1f},{p2[1]:.1f} L{p3[0]:.1f},{p3[1]:.1f} Z")
add(f'<path d="{" ".join(fangs)}" fill="{WHITE}" opacity="0.95"/>')
# facial lines: brow ridge, cheek, nostril
add(f'<polyline points="{poly([(0.5, 0.82), (1.0, 0.7), (1.6, 0.42)])}" fill="none" stroke="{WHITE}" stroke-width="{1.6 * S:.1f}" opacity="0.65"/>')
add(f'<polyline points="{poly([(0.25, -0.55), (0.75, -0.45), (1.25, -0.5)])}" fill="none" stroke="{WHITE}" stroke-width="{1.4 * S:.1f}" opacity="0.5"/>')
add(f'<polyline points="{poly([(1.9, 0.27), (2.0, 0.2)])}" fill="none" stroke="{WHITE}" stroke-width="{2.6 * S:.1f}" stroke-linecap="round"/>')
# red brow spike + cheek frills
add(f'<polygon points="{poly([(0.75, 1.15), (0.55, 1.75), (0.98, 0.95)])}" fill="{RED}" filter="url(#softglow)"/>')
for k in range(3):
    a0 = 0.45 - 0.22 * k
    add(f'<polygon points="{poly([(a0, -1.05), (a0 - 0.45, -1.75 + 0.15 * k), (a0 - 0.15, -0.98)])}" fill="{RED}" opacity="{0.9 - 0.15 * k:.2f}"/>')
# eye: glowing red slit
add(f'<polygon points="{poly([(0.9, 0.52), (1.3, 0.66), (1.06, 0.36)])}" fill="{RED_HI}" filter="url(#glow)"/>')
# whiskers: two red S-curves streaming back from the snout
for k, sgn in enumerate((1, -1)):
    s0 = P(1.95, 0.25 - 0.5 * k)
    c1 = P(2.9, 0.8 * sgn + 0.3)
    c2 = P(1.6, 3.2 * sgn)
    e = P(-0.6, 2.4 * sgn + 0.4)
    add(f'<path d="M{s0[0]:.1f},{s0[1]:.1f} C{c1[0]:.1f},{c1[1]:.1f} {c2[0]:.1f},{c2[1]:.1f} {e[0]:.1f},{e[1]:.1f}" '
        f'fill="none" stroke="{RED}" stroke-width="{2.0 * S:.1f}" stroke-linecap="round" opacity="0.85" filter="url(#softglow)"/>')

# ------------------------------------------------------------------ seal + caption
sx, sy, ss = 205 * S, H - 330 * S, 118 * S
add(f'<rect x="{sx:.0f}" y="{sy:.0f}" width="{ss:.0f}" height="{ss:.0f}" rx="{8 * S:.0f}" fill="{RED}" opacity="0.92"/>')
add(f'<text x="{sx + ss / 2:.0f}" y="{sy + ss * 0.78:.0f}" font-family="Noto Serif CJK JP, Noto Sans CJK JP" '
    f'font-weight="700" font-size="{ss * 0.78:.0f}" fill="{BG0}" text-anchor="middle">龍</text>')
add(f'<text x="{sx + ss + 34 * S:.0f}" y="{sy + 48 * S:.0f}" font-family="Atkinson Hyperlegible Mono" '
    f'font-weight="600" font-size="{40 * S:.0f}" fill="{WHITE}" letter-spacing="{6 * S:.0f}">PRECISION</text>')
add(f'<text x="{sx + ss + 34 * S:.0f}" y="{sy + 98 * S:.0f}" font-family="Atkinson Hyperlegible Mono" '
    f'font-size="{24 * S:.0f}" fill="{RED}" letter-spacing="{4 * S:.0f}">// bspwm · 7780</text>')
add('</svg>')

with tempfile.TemporaryDirectory() as d:
    svgp, pngp = Path(d) / "dragon.svg", Path(d) / "dragon.png"
    svgp.write_text("\n".join(svg))
    if len(sys.argv) > 3 and sys.argv[3] == "--svg":
        (OUT.with_suffix(".svg")).write_text("\n".join(svg))
    subprocess.run(["rsvg-convert", "-w", str(W), "-h", str(H), "-o", str(pngp), str(svgp)], check=True)
    img = np.asarray(Image.open(pngp).convert("RGB"), np.float32)

# film grain + gentle vignette
rng = np.random.default_rng(7780)
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
v = np.sqrt(((xx - W * 0.45) / (W * 0.8)) ** 2 + ((yy - H / 2) / (H * 0.8)) ** 2)
img *= (1 - 0.35 * np.clip(v, 0, 1) ** 2)[..., None]
img += rng.normal(0, 2.0, (H, W, 1)).astype(np.float32)
out = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=93, subsampling=0, optimize=True)
print(OUT, out.size)
