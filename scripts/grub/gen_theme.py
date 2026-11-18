#!/usr/bin/env python3
"""Monochrome ASCII-terminal GRUB theme with the 四 sigil (same palette as
scripts/wallpaper/gen_emblem.py).

Writes everything GRUB needs into system/boot/grub/themes/bspwn/:
  background.png      1920x1080 desktop image (ASCII 四, frames, fake boot log)
  theme.txt           gfxmenu layout (menu sits inside the ASCII box)
  select_*.png        inverted selection bar (terminal "cursor line")
  terminal_box_*.png  thin frame for the GRUB shell (c) / editor (e)
  *.pf2               BlexMono bitmap fonts (grub-mkfont)

usage: gen_theme.py [OUT_DIR]
"""
import subprocess
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "system/boot/grub/themes/bspwn"
OUT.mkdir(parents=True, exist_ok=True)

W, H = 1920, 1080
rng = np.random.default_rng(4)          # 四

WHITE, LIGHT, MID, DIM, FAINT = "#f2efe9", "#c9c6c0", "#8e9099", "#4b4d55", "#202125"
BG = "#0a0a0c"
MONO = "/usr/share/fonts/nerd-fonts/BlexMono/BlexMonoNerdFontMono-Regular.ttf"
MONO_B = "/usr/share/fonts/nerd-fonts/BlexMono/BlexMonoNerdFontMono-Bold.ttf"
CJK = "/usr/share/fonts/opentype/noto/NotoSansCJK-Black.ttc"

# menu box (pixels at 1920x1080; theme.txt uses the same numbers as percentages)
BX0, BY0, BX1, BY1 = 900, 190, 1820, 850
MENU = dict(left=940, top=280, width=840, height=400)
TIMEOUT_Y = 770


def font(path, size):
    return ImageFont.truetype(path, size)


img = Image.new("RGB", (W, H), BG)
d = ImageDraw.Draw(img)
f14, f16, f18, f22 = font(MONO, 14), font(MONO, 16), font(MONO, 18), font(MONO, 22)
fb20, fb30 = font(MONO_B, 20), font(MONO_B, 30)

# ------------------------------------------------------------------ ASCII 四
# render the glyph to a mask, sample it on a character grid, map coverage -> ramp
CW, CH = 10, 17                          # cell size (BlexMono 16px advance ~9.6)
COLS, ROWS = 58, 31
GX, GY = 110, 180
RAMP = " .:-=+*#%@"
mask = Image.new("L", (COLS * 8, ROWS * 8 * CH // CW), 0)
md = ImageDraw.Draw(mask)
cjk = ImageFont.truetype(CJK, int(mask.height * 0.95), index=0)
md.text((mask.width / 2, mask.height / 2), "四", font=cjk, fill=255, anchor="mm")
cov = np.asarray(mask.resize((COLS, ROWS), Image.BOX), dtype=float) / 255
edge = np.asarray(mask.filter(ImageFilter.FIND_EDGES).resize((COLS, ROWS), Image.BOX), dtype=float) / 255

for r in range(ROWS):
    for c in range(COLS):
        v = cov[r, c]
        x, y = GX + c * CW, GY + r * CH
        if v > 0.06:
            ch = RAMP[min(len(RAMP) - 1, int(v * (len(RAMP) - 1) + 0.5))]
            col = WHITE if v > 0.8 else LIGHT if v > 0.45 else MID
            if edge[r, c] > 0.25 and v < 0.8:
                col = MID
            d.text((x, y), ch, font=f16, fill=col)
        elif rng.random() < 0.10:
            d.text((x, y), str(int(rng.integers(0, 2))), font=f16, fill=FAINT)
        elif (r + c) % 4 == 0:
            d.text((x, y), ".", font=f16, fill=FAINT)

# bracket corners around the glyph field
gx1, gy1 = GX + COLS * CW, GY + ROWS * CH
for (x, y, sx, sy) in [(GX - 16, GY - 12, 1, 1), (gx1 + 6, GY - 12, -1, 1),
                       (GX - 16, gy1 + 6, 1, -1), (gx1 + 6, gy1 + 6, -1, -1)]:
    d.line([(x, y), (x + sx * 48, y)], fill=WHITE, width=3)
    d.line([(x, y), (x, y + sy * 48)], fill=WHITE, width=3)
cjk30 = ImageFont.truetype(CJK, 34, index=0)
d.text((GX - 10, gy1 + 34), "四", font=cjk30, fill=WHITE)
d.text((GX + 34, gy1 + 36), "// PRECISION", font=fb30, fill=WHITE)
d.text((GX - 10, gy1 + 82), "sigil.glyph  U+56DB  ·  render=ascii  ·  ramp[10]", font=f16, fill=MID)

# ------------------------------------------------------------------ top / bottom bars
d.text((60, 40), "四", font=ImageFont.truetype(CJK, 30, index=0), fill=WHITE)
d.text((104, 44), "BSPWN :: BOOTLOADER", font=fb20, fill=WHITE)
d.text((W - 60, 46), "UEFI · x86_64 · LUKS2 · NODE 7780", font=f18, fill=MID, anchor="ra")
RULE = "─" * int((W - 120) / d.textlength("─", font=f14))
d.text((60, 90), RULE, font=f14, fill=DIM)
d.text((60, H - 70), RULE, font=f14, fill=DIM)
d.text((60, H - 50), "root@precision:~# grub --menu --theme=bspwn", font=f16, fill=DIM)
d.text((W - 60, H - 50), "sys nominal  [ 0x56DB ]", font=f16, fill=DIM, anchor="ra")

# ------------------------------------------------------------------ ASCII menu box
cw = d.textlength("─", font=f18)


def hline(x0, x1, y, left, right, title=None):
    n = int((x1 - x0) / cw) - 1
    s = left + "─" * (n - 1) + right
    if title:
        t = f"┤ {title} ├"
        s = s[:3] + t + s[3 + len(t):]
    d.text((x0, y), s, font=f18, fill=MID)
    return x0 + n * cw


xr = hline(BX0, BX1, BY0, "┌", "┐", "SELECT BOOT TARGET")
hline(BX0, BX1, BY1, "└", "┘")
for y in range(BY0 + 19, BY1, 19):
    d.text((BX0, y), "│", font=f18, fill=MID)
    d.text((xr, y), "│", font=f18, fill=MID)
hline(BX0, BX1, 712, "├", "┤")
d.text((BX0 + 40, 238), "$ ls /boot/entries", font=f16, fill=DIM)
d.text((BX0 + 40, 806), "[↑↓] select   [enter] boot   [e] edit   [c] shell   [esc] back",
       font=f16, fill=DIM)
# cursor block next to the timeout label
d.rectangle([BX0 + 40, TIMEOUT_Y + 2, BX0 + 50, TIMEOUT_Y + 22], fill=LIGHT)

# ------------------------------------------------------------------ data fragments
log = ["[  OK  ] efi: loaded image \\EFI\\kali\\grubx64.efi",
       "[  OK  ] tpm: measured boot disabled",
       "[  OK  ] cryptdisk: nvme0n1p3_crypt  (luks2/aes-xts)",
       "[  OK  ] lvm: localhost-vg/root online",
       "[ WAIT ] handoff -> plymouth"]
for k, s in enumerate(log):
    d.text((GX - 10, 1000 - (len(log) - k) * 20), s, font=f14, fill=DIM if k < 4 else MID)
for k in range(7):
    hx = " ".join(f"{int(v):02X}" for v in rng.integers(0, 256, 8))
    d.text((BX0 + 40, 880 + k * 18), f"0x{0x7780 + k * 16:05X}  {hx}", font=f14, fill=FAINT)
for k in range(7):
    bits = " ".join(format(int(v), "08b") for v in rng.integers(0, 256, 3))
    d.text((W - 60, 880 + k * 18), bits, font=f14, fill=FAINT, anchor="ra")
for k in range(36):                      # left edge scale
    y = 180 + k * 18
    ln = 22 if k % 5 == 0 else 9
    d.line([(30, y), (30 + ln, y)], fill=MID if k % 5 == 0 else DIM, width=2)

# ------------------------------------------------------------------ CRT: scanlines, vignette, grain
a = np.asarray(img, dtype=float)
a[1::3] *= 0.78
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


IH = 34
solid("select_c.png", 1, IH, [(1, "#e6e3dd")])
solid("select_w.png", 10, IH, [(4, WHITE), (2, BG), (4, "#e6e3dd")])
solid("select_e.png", 4, IH, [(4, "#e6e3dd")])
for side, size in {"n": (1, 2), "s": (1, 2), "e": (2, 1), "w": (2, 1),
                   "ne": (2, 2), "nw": (2, 2), "se": (2, 2), "sw": (2, 2), "c": (1, 1)}.items():
    Image.new("RGB", size, BG if side == "c" else MID).save(OUT / f"terminal_box_{side}.png")

# ------------------------------------------------------------------ fonts
RANGE = "0x20-0x7E,0xA0-0x17F,0x2190-0x21FF,0x2500-0x259F"
for path, style, size in [(MONO, "Regular", 16), (MONO, "Regular", 20), (MONO_B, "Bold", 20)]:
    # -n is the family only; grub-mkfont appends style + size itself,
    # giving e.g. "bspwn Mono Bold 20", the name theme.txt refers to
    subprocess.run(["grub-mkfont", "-s", str(size), "-n", "bspwn Mono", "-r", RANGE,
                    "-o", str(OUT / f"mono-{style.lower()}-{size}.pf2"), path], check=True,
                   stderr=subprocess.DEVNULL)


# ------------------------------------------------------------------ theme.txt
def pct(v, total):
    """GRUB only parses integer percentages: whole % + pixel remainder."""
    p = int(100 * v / total)
    rest = round(v - p * total / 100)
    return f"{p}%+{rest}" if rest else f"{p}%"


(OUT / "theme.txt").write_text(f"""# bspwn GRUB theme: monochrome ASCII terminal, 四 sigil.
# Generated by scripts/grub/gen_theme.py; edit that, not this file.
title-text: ""
desktop-image: "background.png"
desktop-color: "{BG}"
terminal-font: "bspwn Mono Regular 16"
terminal-box: "terminal_box_*.png"
terminal-left: "{pct(BX0 + 20, W)}"
terminal-top: "{pct(BY0 + 30, H)}"
terminal-width: "{pct(BX1 - BX0 - 50, W)}"
terminal-height: "{pct(BY1 - BY0 - 50, H)}"
terminal-border: "0"

+ boot_menu {{
  left = {pct(MENU['left'], W)}
  top = {pct(MENU['top'], H)}
  width = {pct(MENU['width'], W)}
  height = {pct(MENU['height'], H)}
  item_font = "bspwn Mono Regular 20"
  selected_item_font = "bspwn Mono Bold 20"
  item_color = "{MID}"
  selected_item_color = "{BG}"
  icon_width = 0
  icon_height = 0
  item_icon_space = 14
  item_height = {IH}
  item_padding = 0
  item_spacing = 6
  selected_item_pixmap_style = "select_*.png"
  scrollbar = false
}}

+ label {{
  id = "__timeout__"
  left = {pct(BX0 + 62, W)}
  top = {pct(TIMEOUT_Y, H)}
  width = {pct(700, W)}
  height = {pct(26, H)}
  align = "left"
  font = "bspwn Mono Regular 20"
  color = "{LIGHT}"
  text = "autoboot in %d s"
}}
""")
print(f"theme written to {OUT}")
