#!/usr/bin/env python3
"""ASCII-art bat wallpaper: a wide text-mode bat in the centre of a 100x30
character grid (16x30 px cells = 1600x900) inside a full-screen text border.

The bat is built from `/ \\ _ , . ·` like the hand-drawn original: head and its
two flanking wing pyramids kept as they were, plus an outer pyramid per wing and
a scalloped bottom row. Everything is drawn as real characters (IBM Plex Mono
Nerd Font) one cell at a time, so the grid never drifts.

The border keeps clear of the polybar (top 34 px) and the right-hand conky HUD.

usage: gen_batascii.py [out.jpg] [--style double|block]
  double : ╔═╗ double-line frame + inner thin frame (default)
  block  : █ block frame + inner ▀▄ edge
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
args = [a for a in sys.argv[1:] if not a.startswith("--")]
STYLE = "block" if "--style" in sys.argv and sys.argv[sys.argv.index("--style") + 1] == "block" else "double"
if "--style" in sys.argv:
    args = [a for a in args if a != sys.argv[sys.argv.index("--style") + 1]]
OUT = Path(args[0]) if args else ROOT / f"assets/wallpaper/batascii{'-blocks' if STYLE == 'block' else ''}.jpg"

W, H, K = 1600, 900, 2
CW, CH = 16, 30                      # cell size -> 100 x 30 cells
COLS, ROWS = W // CW, H // CH
FONT = "/usr/share/fonts/nerd-fonts/ibmplexmono/BlexMonoNerdFontMono-Regular.ttf"
FONT_B = "/usr/share/fonts/nerd-fonts/ibmplexmono/BlexMonoNerdFontMono-Bold.ttf"
FS = 27 * K

BG0, BG1 = (10, 10, 12), (19, 20, 23)
RING = (27, 28, 32)                  # outer block ring (block style)
FRAME = (92, 94, 103)                # main border
INNER = (48, 49, 55)                 # inner thin frame
BAT_LINE, BAT_TEX, BAT_EYE = (236, 234, 229), (150, 152, 160), (255, 253, 248)

# ---------------------------------------------------------------- the bat art
def mirror(s):
    return s[::-1].translate(str.maketrans("/\\()[]<>", "\\/)(][><"))


def put(cv, r, c, s):
    for i, ch in enumerate(s):
        if ch != " ":
            cv[r][c + i] = ch


def build_bat(width=51, rows=5):
    """Wide bat: your head + flanking pyramids in the middle, then wing 'fingers' that step
    down toward the tips (like a fanned wing) on a continuous scalloped bottom row."""
    parts = [
        # head (ears, face, fangs) - right half is mirrored
        (1, 23, "/\\_"), (2, 23, "\\·_"), (3, 24, "'"),
        # inner pyramid, tight against the head like the original sketch
        (0, 20, "/\\"), (1, 19, "/  \\"), (2, 18, "/,.,."), (3, 17, "/,"),
        # middle and outer pyramids, each one row lower
        (1, 12, "/\\"), (2, 11, "/  \\"), (3, 10, "/,.,\\"),
        (2, 5, "/\\"), (3, 4, "/  \\"),
        # continuous scalloped bottom edge
        (4, 2, "/,.,\\/,.,.,\\/,.,.,.,\\/,.,.,.,"),
    ]
    cv = [[" "] * width for _ in range(rows)]
    for r, c, t in parts:
        put(cv, r, c, t)
    cx = width // 2
    for r in range(rows):
        left = "".join(cv[r][:cx])
        for i, ch_ in enumerate(mirror(left)):
            if ch_ != " ":
                cv[r][cx + 1 + i] = ch_
    # fill the valleys between the pyramids with membrane texture: any run of spaces enclosed by
    # a '\\' on its left and a '/' on its right becomes ",.,." -> each wing reads as one solid shape
    for r in range(1, rows):
        row = cv[r]
        k = 0
        while k < width:
            if row[k] == "\\":
                j = k + 1
                while j < width and row[j] == " ":
                    j += 1
                if j < width and row[j] == "/" and j > k + 1:
                    for m in range(k + 1, j):
                        row[m] = "," if (m + r) % 2 else "."
                k = j
            else:
                k += 1
    return ["".join(x) for x in cv]


BAT = build_bat()

# ---------------------------------------------------------------- canvas
yy, xx = np.mgrid[0:H * K, 0:W * K].astype(np.float32)
t = np.clip(((xx / (W * K)) - 0.5) ** 2 * 1.6 + ((yy / (H * K)) - 0.5) ** 2 * 1.6, 0, 1)
bg = np.zeros((H * K, W * K, 3), np.float32)
for i in range(3):
    bg[..., i] = BG1[i] - (BG1[i] - BG0[i]) * t ** 0.8
img = Image.fromarray(bg.astype(np.uint8))
d = ImageDraw.Draw(img)
font = ImageFont.truetype(FONT, FS)
font_b = ImageFont.truetype(FONT_B, FS)


def ch(c, r, s, fill, bold=False, dx=0.0):
    """draw one character centred in grid cell (c, r) (dx = sub-cell x shift in px)"""
    if s == " ":
        return
    d.text(((c * CW + CW / 2 + dx) * K, (r * CH + CH / 2) * K), s, font=font_b if bold else font,
           fill=fill, anchor="mm")


def box(c0, r0, c1, r1, tl, tr, bl, br, h, v, fill):
    for c in range(c0 + 1, c1):
        ch(c, r0, h, fill); ch(c, r1, h, fill)
    for r in range(r0 + 1, r1):
        ch(c0, r, v, fill); ch(c1, r, v, fill)
    ch(c0, r0, tl, fill); ch(c1, r0, tr, fill); ch(c0, r1, bl, fill); ch(c1, r1, br, fill)


# ---------------------------------------------------------------- border
# rows 0-1 sit behind the polybar, so the frame starts at row 1 (just below it)
TOP, BOT, LEFT, RIGHT = 1, ROWS - 2, 1, COLS - 2
if STYLE == "double":
    box(LEFT, TOP, RIGHT, BOT, "╔", "╗", "╚", "╝", "═", "║", FRAME)
    box(LEFT + 1, TOP + 1, RIGHT - 1, BOT - 1, "┌", "┐", "└", "┘", "─", "│", INNER)
    mid = (LEFT + RIGHT) // 2                   # small joints at the middle of every edge
    ch(mid, TOP, "╤", FRAME); ch(mid + 1, TOP, "╤", FRAME)
    ch(mid, BOT, "╧", FRAME); ch(mid + 1, BOT, "╧", FRAME)
    ch(LEFT, (TOP + BOT) // 2, "╟", FRAME); ch(RIGHT, (TOP + BOT) // 2, "╢", FRAME)
else:
    for c in range(LEFT, RIGHT + 1):
        ch(c, TOP, "█", RING); ch(c, BOT, "█", RING)
    for r in range(TOP, BOT + 1):
        ch(LEFT, r, "█", RING); ch(RIGHT, r, "█", RING)
    for c in range(LEFT + 1, RIGHT):            # inner half-block edge
        ch(c, TOP + 1, "▄", FRAME); ch(c, BOT - 1, "▀", FRAME)
    for r in range(TOP + 2, BOT - 1):
        ch(LEFT + 1, r, "█", FRAME); ch(RIGHT - 1, r, "█", FRAME)

# ---------------------------------------------------------------- the bat
BCW, BCH = 18, 34                                  # bat cell (a bit larger than the border grid)
bfont = ImageFont.truetype(FONT, round(30 * K))
bfont_b = ImageFont.truetype(FONT_B, round(30 * K))
bw = len(BAT[0])
x0 = (W - bw * BCW) / 2
y0 = (H - len(BAT) * BCH) / 2
for ri, line in enumerate(BAT):
    for ci, s_ in enumerate(line):
        if s_ == " ":
            continue
        if s_ in "/\\":
            col, fnt = BAT_LINE, bfont_b
        elif s_ == "·":
            col, fnt = BAT_EYE, bfont_b
        elif s_ in "'_":
            col, fnt = BAT_EYE, bfont
        else:
            col, fnt = BAT_TEX, bfont
        d.text(((x0 + ci * BCW + BCW / 2) * K, (y0 + ri * BCH + BCH / 2) * K), s_, font=fnt, fill=col, anchor="mm")

# ---------------------------------------------------------------- output
out = img.resize((W, H), Image.LANCZOS)
arr = np.asarray(out, np.float32) + np.random.default_rng(4).normal(0, 1.0, (H, W, 1)).astype(np.float32)
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=95, subsampling=0, optimize=True)
print(OUT, out.size)
