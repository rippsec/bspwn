#!/usr/bin/env python3
"""Minimal dark wallpaper: the word BSPWN centred, framed by sharp-edged
tech patterns (corner brackets, ticks, hatch).
Flat design: only black and dark greys, no shadows, highlights or gradients. Pillow + numpy only; drawn at 2x and downsampled.

usage: gen_bspwn.py [out.jpg] [font.ttf] [--text WORD | --user]
  --text WORD  centre WORD instead of BSPWN (upper-cased)
  --user       centre the current user name (whoami) in capitals: a personal wallpaper
               (install.sh -wallpaper writes it to ~/.local/share/bspwn/wallpaper.jpg)
"""
import getpass
import math
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
_args, TEXT, _i = [], "BSPWN", 1
while _i < len(sys.argv):
    if sys.argv[_i] == "--user":
        TEXT = getpass.getuser().upper()
    elif sys.argv[_i] == "--text" and _i + 1 < len(sys.argv):
        _i += 1
        TEXT = sys.argv[_i].upper()
    else:
        _args.append(sys.argv[_i])
    _i += 1
OUT = Path(_args[0]) if _args else ROOT / "assets/wallpaper/bspwn.jpg"
W, H, K = 1600, 900, 2
CX, CY = W / 2, H / 2
_FONT_NAME = "AtkinsonHyperlegibleMono/AtkinsonHyperlegibleMono-Bold.ttf"
FONT = _args[1] if len(_args) > 1 else next(
    (str(c) for c in (Path.home() / ".local/share/fonts" / _FONT_NAME, ROOT / "assets/fonts" / _FONT_NAME) if c.is_file()),
    str(ROOT / "assets/fonts" / _FONT_NAME))

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
# long names shrink to fit between the frame (max 760 px wide, never above 120 px high)
size = 120
while size > 40:
    font = ImageFont.truetype(FONT, size * K)
    if d.textlength(TEXT, font=font) <= 760 * K:
        break
    size -= 4
d.text(P(CX, CY), TEXT, font=font, fill=GLYPH, anchor="mm")

# ---- output (flat: no grain, no vignette)
out = img.resize((W, H), Image.LANCZOS)
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=95, subsampling=0, optimize=True)
print(OUT, out.size)
