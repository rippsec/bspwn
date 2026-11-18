#!/usr/bin/env python3
"""Monochrome ASCII-terminal GRUB theme, full-screen and centred: the boot menu
sits in the middle of the screen, flanked by thin ASCII line-art wings, with
small centred text and rules top/bottom (same palette as
scripts/wallpaper/gen_emblem.py).

Writes everything GRUB needs into system/boot/grub/themes/bspwn/:
  background.png      1920x1080 desktop image
  theme.txt           gfxmenu layout
  select_*.png        inverted selection bar (terminal "cursor line")
  terminal_box_*.png  thin frame for the GRUB shell (c) / editor (e)
  *.pf2               BlexMono bitmap fonts (grub-mkfont)

usage: gen_theme.py [OUT_DIR]       preview: scripts/grub/preview.sh
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "system/boot/grub/themes/bspwn"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1920, 1080
CX = W // 2
rng = np.random.default_rng(4)          # 四

WHITE, LIGHT, MID, DIM, FAINT = "#f2efe9", "#c9c6c0", "#8e9099", "#4b4d55", "#202125"
BG = "#0a0a0c"
MONO = "/usr/share/fonts/nerd-fonts/BlexMono/BlexMonoNerdFontMono-Regular.ttf"
MONO_B = "/usr/share/fonts/nerd-fonts/BlexMono/BlexMonoNerdFontMono-Bold.ttf"
CJK = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"

# boot menu, centred (pixels at 1920x1080; theme.txt converts to %)
MENU_W, MENU_H, MENU_Y = 480, 200, 480
MENU = dict(left=CX - MENU_W // 2, top=MENU_Y, width=MENU_W, height=MENU_H)
IH, ISP = 34, 6                          # item height / spacing
TIMEOUT_Y = 760

img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
f14, f16, f18 = (ImageFont.truetype(MONO, s) for s in (14, 16, 18))
fb16, fb18 = ImageFont.truetype(MONO_B, 16), ImageFont.truetype(MONO_B, 18)


def ctext(y, s, font, fill, x=CX):
    d.text((x, y), s, font=font, fill=fill, anchor="ma")


def rule(y, ch="─", col=DIM, font=f14):
    n = int((W - 80) / d.textlength(ch, font=font))
    ctext(y, ch * n, font, col)


# ------------------------------------------------------------------ rules / bars
rule(24, "═", DIM)
rule(H - 64, "═", DIM)
bar = "[0x56DB - bspwn boot]"
d.text((40, H - 40), bar, font=f16, fill=MID)
bx = 40 + d.textlength(bar + " ", font=f16)
d.text((bx, H - 40), "░" * int((W - 40 - bx) / d.textlength("░", font=f16)), font=f16, fill=FAINT)

# ------------------------------------------------------------------ header (centred)
d.text((CX, 132), "四", font=ImageFont.truetype(CJK, 44, index=0), fill=WHITE, anchor="ma")
ctext(198, "B S P W N  ::  B O O T L O A D E R", fb16, LIGHT)
ctext(232, "node 7780  ·  uefi x86_64  ·  luks2  ·  sys nominal", f14, DIM)
ctext(330, "select boot target", f16, MID)
ctext(358, "──────────  ·:·  ──────────", f16, DIM)

# ------------------------------------------------------------------ wings
# hand-drawn right wing; the left one is its mirror image
WING = r"""
 _
| `-._                          ___..--''``
|     `-._           ___..--''``   __..--''
|  ,      `-.__..--''       __..--''   _.-'
|  |\            ___..--''``    __.--'`
|  | `.   __..--''       __..--''`
|__|  _.-'      __..--''   _..-'
   `-'.___..--''     _..-''
        ``--..__..--''
""".strip("\n").splitlines()
SWAP = str.maketrans("/\\()<>[]{}`'", "\\/)(><][}{'`")
width = max(map(len, WING))
right = [ln.ljust(width) for ln in WING]
left = [ln[::-1].translate(SWAP) for ln in right]
cw = d.textlength("_", font=f16)
lh = 22
wy = MENU_Y + 40 - len(WING) * lh // 2
gap = MENU_W // 2 + 50                   # distance from centre to the wing root
for k, (l, r) in enumerate(zip(left, right)):
    y = wy + k * lh
    d.text((CX - gap - width * cw, y), l, font=f16, fill=MID)
    d.text((CX + gap, y), r, font=f16, fill=MID)

# small captions under the wings, like annotations
ly = wy + len(WING) * lh + 30
ctext(ly, "efi: \\EFI\\kali\\grubx64.efi   ·   tpm: off", f14, DIM, x=CX - gap - width * cw / 2)
ctext(ly, "cryptdisk: nvme0n1p3_crypt   ·   lvm: online", f14, DIM, x=CX + gap + width * cw / 2)
ctext(ly + 24, "0x7780  4B 41 4C 49  0x56DB", f14, FAINT, x=CX - gap - width * cw / 2)
ctext(ly + 24, "handoff -> plymouth", f14, FAINT, x=CX + gap + width * cw / 2)

# ------------------------------------------------------------------ footer (centred)
ctext(TIMEOUT_Y + 50, "[↑↓] select   [enter] boot   [e] edit   [c] shell", f14, DIM)

# ------------------------------------------------------------------ CRT: scanlines, vignette, grain
a = np.asarray(img, dtype=float)
a[1::3] *= 0.80
yy, xx = np.mgrid[0:H, 0:W]
vig = 1 - 0.45 * (((xx - W / 2) / (W / 2)) ** 2 + ((yy - H / 2) / (H / 2)) ** 2) / 2
a *= vig[..., None]
a += rng.normal(0, 2.0, (H, W, 1))
Image.fromarray(a.clip(0, 255).astype(np.uint8)).save(OUT / "background.png", optimize=True)


# ------------------------------------------------------------------ pixmaps
def solid(name, w, h, cols):
    """cols: list of (width, colour) vertical stripes."""
    im = Image.new("RGB", (w, h), BG)
    x = 0
    for cw_, col in cols:
        ImageDraw.Draw(im).rectangle([x, 0, x + cw_ - 1, h - 1], fill=col)
        x += cw_
    im.save(OUT / name)


solid("select_c.png", 1, IH, [(1, "#e6e3dd")])
solid("select_w.png", 10, IH, [(4, WHITE), (2, BG), (4, "#e6e3dd")])
solid("select_e.png", 10, IH, [(4, "#e6e3dd"), (2, BG), (4, WHITE)])
for side, size in {"n": (1, 2), "s": (1, 2), "e": (2, 1), "w": (2, 1),
                   "ne": (2, 2), "nw": (2, 2), "se": (2, 2), "sw": (2, 2), "c": (1, 1)}.items():
    Image.new("RGB", size, BG if side == "c" else MID).save(OUT / f"terminal_box_{side}.png")

# ------------------------------------------------------------------ fonts
RANGE = "0x20-0x7E,0xA0-0x17F,0x2190-0x21FF,0x2500-0x259F"
for path, style, size in [(MONO, "Regular", 16), (MONO, "Regular", 18), (MONO_B, "Bold", 18)]:
    # -n is the family only; grub-mkfont appends style + size itself,
    # giving e.g. "bspwn Mono Bold 18", the name theme.txt refers to
    subprocess.run(["grub-mkfont", "-s", str(size), "-n", "bspwn Mono", "-r", RANGE,
                    "-o", str(OUT / f"mono-{style.lower()}-{size}.pf2"), path], check=True,
                   stderr=subprocess.DEVNULL)
for old in OUT.glob("mono-*-20.pf2"):
    old.unlink()


# ------------------------------------------------------------------ theme.txt
def pct(v, total):
    """GRUB only parses integer percentages: whole % + pixel remainder."""
    p = int(100 * v / total)
    rest = round(v - p * total / 100)
    return f"{p}%+{rest}" if rest else f"{p}%"


(OUT / "theme.txt").write_text(f"""# bspwn GRUB theme: monochrome ASCII terminal, centred, 四 sigil.
# Generated by scripts/grub/gen_theme.py; edit that, not this file.
title-text: ""
desktop-image: "background.png"
desktop-color: "{BG}"
terminal-font: "bspwn Mono Regular 16"
terminal-box: "terminal_box_*.png"
terminal-left: "{pct(240, W)}"
terminal-top: "{pct(230, H)}"
terminal-width: "{pct(W - 480, W)}"
terminal-height: "{pct(H - 400, H)}"
terminal-border: "0"

+ boot_menu {{
  left = {pct(MENU['left'], W)}
  top = {pct(MENU['top'], H)}
  width = {pct(MENU['width'], W)}
  height = {pct(MENU['height'], H)}
  item_font = "bspwn Mono Regular 18"
  selected_item_font = "bspwn Mono Bold 18"
  item_color = "{MID}"
  selected_item_color = "{BG}"
  icon_width = 0
  icon_height = 0
  item_icon_space = 18
  item_height = {IH}
  item_padding = 0
  item_spacing = {ISP}
  selected_item_pixmap_style = "select_*.png"
  scrollbar = false
}}

+ label {{
  id = "__timeout__"
  left = 0
  top = {pct(TIMEOUT_Y, H)}
  width = 100%
  height = {pct(26, H)}
  align = "center"
  font = "bspwn Mono Regular 18"
  color = "{LIGHT}"
  text = "autoboot in %d s _"
}}
""")
print(f"theme written to {OUT}")
