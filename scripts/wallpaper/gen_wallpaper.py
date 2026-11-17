#!/usr/bin/env python3
"""Generate the 'cockpit' wallpaper: glowing topographic ridge lines (radar terrain)
in the low-halation palette, with HUD reticle + telemetry labels.

Composition keeps the right ~22% calm/dark: that is where the conky cockpit HUD sits.

usage: gen_wallpaper.py [out.png] [WIDTHxHEIGHT]   (default 3200x1800 = 2x 1600x900)
"""
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parents[2] / "assets/wallpaper/cockpit.jpg"
W, H = (int(v) for v in (sys.argv[2] if len(sys.argv) > 2 else "3200x1800").split("x"))
S = W / 3200  # scale factor for all pixel sizes
rng = np.random.default_rng(7780)

FONT = Path(__file__).resolve().parents[2] / "assets/fonts/AtkinsonHyperlegibleMono/AtkinsonHyperlegibleMono-Medium.ttf"


def hexrgb(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float32)


BG_TOP, BG_BOT = hexrgb("#0a0d12"), hexrgb("#11151c")
AMBER, TEAL, FG, MUTED = hexrgb("#e8b04b"), hexrgb("#56c8b9"), hexrgb("#d8d4c7"), hexrgb("#3a4250")

# ---------------------------------------------------------------- background
yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
t = (yy / H)[..., None]
img = BG_TOP * (1 - t) + BG_BOT * t
# warm horizon glow behind the peak
gx, gy = 0.36 * W, 0.50 * H
d = np.sqrt(((xx - gx) / (0.55 * W)) ** 2 + ((yy - gy) / (0.30 * H)) ** 2)
img += (np.exp(-d ** 2 * 2.2)[..., None] * AMBER * 0.10)
# cool counter-glow top-right (very faint, sits behind the HUD)
d2 = np.sqrt(((xx - 0.92 * W) / (0.35 * W)) ** 2 + ((yy - 0.10 * H) / (0.35 * H)) ** 2)
img += (np.exp(-d2 ** 2 * 2.5)[..., None] * TEAL * 0.035)

# dot grid
step = int(40 * S)
grid = np.zeros((H, W), np.float32)
grid[step // 2::step, step // 2::step] = 1.0
img += grid[..., None] * MUTED * 0.55


# ---------------------------------------------------------------- terrain
def value_noise_1d(n, freq, seed):
    r = np.random.default_rng(seed)
    pts = r.random(int(freq) + 3)
    x = np.linspace(0, freq, n)
    i = np.floor(x).astype(int)
    f = x - i
    f = f * f * (3 - 2 * f)
    return pts[i] * (1 - f) + pts[i + 1] * f


N = 64
xs = np.arange(0, W + 1, max(2, int(3 * S)), dtype=np.float32)
xn = xs / W
lines = Image.new("RGB", (W, H), (0, 0, 0))
ld = ImageDraw.Draw(lines)

# envelope: big massif centre-left, secondary peak, calm towards the HUD on the right
env = (1.00 * np.exp(-((xn - 0.34) / 0.075) ** 2)
       + 0.45 * np.exp(-((xn - 0.25) / 0.06) ** 2)
       + 0.55 * np.exp(-((xn - 0.52) / 0.06) ** 2)
       + 0.25 * np.exp(-((xn - 0.10) / 0.05) ** 2))
calm = 1 - 0.85 / (1 + np.exp(-(xn - 0.70) / 0.025))
summit = None
for i in range(N):
    k = i / (N - 1)                       # 0 = far, 1 = near
    y0 = H * (0.45 + 0.50 * k ** 1.25)
    # tallest ridges in the middle distance, so the massif rises above the plain
    amp = H * 0.30 * (0.25 + 0.75 * math.sin(math.pi * min(1.0, k * 1.35)) ** 0.8) * (1 - 0.35 * k)
    rough = sum(value_noise_1d(len(xs), f, 1000 * i + j) * w
                for j, (f, w) in enumerate([(9, 0.55), (23, 0.28), (61, 0.12)]))
    # terrain shifts slowly with depth so ridges look continuous
    drift = 0.02 * math.sin(k * 3.1)
    e = np.interp(xn - drift, xn, env)
    h = amp * (e * (0.55 + 0.45 * rough) + 0.035 * rough) * calm
    ys = y0 - h
    pts = list(zip(xs.tolist(), ys.tolist()))
    # occlusion: hide the lines behind this one
    ld.polygon(pts + [(W, H), (0, H)], fill=(0, 0, 0))
    # colour: far = dim teal, near = amber; brightness rises towards the viewer
    c = TEAL * (1 - k ** 1.6) + AMBER * k ** 1.6
    a = 0.18 + 0.72 * k ** 0.9
    width = max(1, int(round((1.0 + 1.6 * k) * S)))
    ld.line(pts, fill=tuple(int(v) for v in c * a), width=width, joint="curve")
    j = int(np.argmin(ys))
    if summit is None or ys[j] < summit[1]:
        summit = (float(xs[j]), float(ys[j]))

# dim the lines behind the HUD column on the right
fade = (1 - 0.65 / (1 + np.exp(-(np.arange(W) / W - 0.80) / 0.02))).astype(np.float32)
lines = Image.fromarray((np.asarray(lines, np.float32) * fade[None, :, None]).astype(np.uint8))
L = np.asarray(lines, np.float32)
glow = np.asarray(lines.filter(ImageFilter.GaussianBlur(10 * S)), np.float32)
glow2 = np.asarray(lines.filter(ImageFilter.GaussianBlur(40 * S)), np.float32)
img = img + L + glow * 1.4 + glow2 * 0.9

# ---------------------------------------------------------------- vignette + grain + scanlines
v = np.sqrt(((xx - W / 2) / (W * 0.75)) ** 2 + ((yy - H / 2) / (H * 0.75)) ** 2)
img *= (1 - 0.45 * np.clip(v, 0, 1) ** 2.2)[..., None]
img *= (1 - 0.035 * ((yy.astype(int) // max(1, int(2 * S))) % 2))[..., None]
img += rng.normal(0, 2.2, (H, W, 1)).astype(np.float32)
base = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8))

# ---------------------------------------------------------------- HUD overlay
hud = Image.new("RGBA", (W, H), (0, 0, 0, 0))
hd = ImageDraw.Draw(hud)


def col(c, a):
    return tuple(int(v) for v in c) + (int(255 * a),)


font_s = ImageFont.truetype(str(FONT), int(22 * S))
font_m = ImageFont.truetype(str(FONT), int(30 * S))
font_l = ImageFont.truetype(str(FONT), int(64 * S))

# reticle over the main peak
cx, cy = summit[0], summit[1] - 40 * S
for r, a in [(150, 0.55), (230, 0.22), (330, 0.10)]:
    r *= S
    hd.ellipse([cx - r, cy - r, cx + r, cy + r], outline=col(AMBER, a), width=max(1, int(2 * S)))
for ang in range(0, 360, 10):
    r1, r2 = 150 * S, (162 if ang % 30 else 176) * S
    ca, sa = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    hd.line([cx + r1 * ca, cy + r1 * sa, cx + r2 * ca, cy + r2 * sa], fill=col(AMBER, 0.45), width=max(1, int(2 * S)))
g = 24 * S
for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
    hd.line([cx + dx * g, cy + dy * g, cx + dx * g * 3, cy + dy * g * 3], fill=col(FG, 0.8), width=max(1, int(2 * S)))
hd.ellipse([cx - 5 * S, cy - 5 * S, cx + 5 * S, cy + 5 * S], fill=col(AMBER, 0.95))
# sweep arc
hd.arc([cx - 330 * S, cy - 330 * S, cx + 330 * S, cy + 330 * S], start=-160, end=-120, fill=col(TEAL, 0.55), width=int(4 * S))
# callout from reticle
lx, ly = cx + 260 * S, cy - 150 * S
hd.line([cx + 120 * S, cy - 90 * S, lx, ly, lx + 300 * S, ly], fill=col(FG, 0.55), width=max(1, int(2 * S)))
hd.text((lx + 8 * S, ly - 40 * S), "TGT  LOCK", font=font_m, fill=col(AMBER, 0.95))
hd.text((lx + 8 * S, ly + 10 * S), "ALT 2847m   HDG 312°", font=font_s, fill=col(FG, 0.65))
hd.text((lx + 8 * S, ly + 40 * S), "N 19°25'  W 99°08'", font=font_s, fill=col(FG, 0.45))

# title block (top-left, in the empty sky under the bar)
bx, by = 150 * S, 150 * S
hd.text((bx, by), "PRECISION//7780", font=font_l, fill=col(FG, 0.80))
hd.text((bx + 4 * S, by + 82 * S), "SYS NOMINAL  ·  LINK UP  ·  bspwm", font=font_s, fill=col(TEAL, 0.75))
hd.line([bx - 30 * S, by + 10 * S, bx - 30 * S, by + 120 * S], fill=col(AMBER, 0.85), width=int(4 * S))

# altitude tape along the left edge
for j in range(0, 21):
    y = H * 0.30 + j * 34 * S
    ln = 34 if j % 5 == 0 else 16
    hd.line([30 * S, y, (30 + ln) * S, y], fill=col(FG, 0.35 if j % 5 else 0.6), width=max(1, int(2 * S)))
    if j % 5 == 0:
        hd.text((74 * S, y - 13 * S), f"{(20 - j) * 100:04d}", font=font_s, fill=col(FG, 0.4))

out = Image.alpha_composite(base.convert("RGBA"), hud).convert("RGB")
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=93, subsampling=0, optimize=True) if OUT.suffix.lower() in ('.jpg', '.jpeg') else out.save(OUT, optimize=True)
print(OUT, out.size)
