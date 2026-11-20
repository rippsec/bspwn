#!/usr/bin/env python3
"""Check the terminal palette (kitty/cockpit.conf) for legibility and colour separation.

    python3 scripts/palette_check.py [path/to/kitty-colors.conf]

Reports, with these targets:
  * text contrast vs background (WCAG ratio; hue colours >= 6:1, main text >= ~11:1)
  * pairwise CIEDE2000 difference between all hue colours + foreground (>= 20 is easy to tell apart)
  * same, with chroma cut to 60% (a washed-out panel): should stay >= ~14
  * normal vs bright twin difference (>= 10 so bold/bright output stands out)
Exit status is 1 if any target is missed. Pure python, no dependencies.
"""
import itertools, math, re, sys
from pathlib import Path

import math

def hex2rgb(h):
    h = h.lstrip('#'); return tuple(int(h[i:i+2], 16) for i in (0, 2, 4))

def rgb2hex(rgb):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(c))) for c in rgb)

def _lin(c):
    c /= 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4

def _delin(v):
    v = 12.92 * v if v <= 0.0031308 else 1.055 * v ** (1 / 2.4) - 0.055
    return v * 255.0

def rgb2xyz(rgb):
    r, g, b = (_lin(c) for c in rgb)
    return (0.4124564*r + 0.3575761*g + 0.1804375*b,
            0.2126729*r + 0.7151522*g + 0.0721750*b,
            0.0193339*r + 0.1191920*g + 0.9503041*b)

WP = (0.95047, 1.0, 1.08883)

def xyz2lab(xyz):
    def f(t): return t ** (1/3) if t > 216/24389 else (24389/27 * t + 16) / 116
    fx, fy, fz = (f(xyz[i] / WP[i]) for i in range(3))
    return (116*fy - 16, 500*(fx - fy), 200*(fy - fz))

def lab2xyz(lab):
    L, a, b = lab
    fy = (L + 16) / 116; fx = fy + a / 500; fz = fy - b / 200
    def finv(t): return t ** 3 if t ** 3 > 216/24389 else (116*t - 16) / (24389/27)
    return (finv(fx) * WP[0], (L / (24389/27) if L <= 8 else fy ** 3) * WP[1], finv(fz) * WP[2])

def xyz2rgb(xyz):
    x, y, z = xyz
    r = 3.2404542*x - 1.5371385*y - 0.4985314*z
    g = -0.9692660*x + 1.8760108*y + 0.0415560*z
    b = 0.0556434*x - 0.2040259*y + 1.0572252*z
    return tuple(_delin(max(0.0, min(1.0, v)) if -1e-9 <= v <= 1 + 1e-9 else v) for v in (r, g, b))

def hex2lab(h): return xyz2lab(rgb2xyz(hex2rgb(h)))

def lch2lab(L, C, h):
    return (L, C * math.cos(math.radians(h)), C * math.sin(math.radians(h)))

def lab2lch(lab):
    L, a, b = lab
    return (L, math.hypot(a, b), math.degrees(math.atan2(b, a)) % 360)

def lab_in_gamut(lab):
    x, y, z = lab2xyz(lab)
    r = 3.2404542*x - 1.5371385*y - 0.4985314*z
    g = -0.9692660*x + 1.8760108*y + 0.0415560*z
    b = 0.0556434*x - 0.2040259*y + 1.0572252*z
    return all(-0.0005 <= v <= 1.0005 for v in (r, g, b))

def lab2hex(lab):
    return rgb2hex(xyz2rgb(lab2xyz(lab)))

def luminance(h):
    return rgb2xyz(hex2rgb(h))[1]

def contrast(h1, h2):
    a, b = luminance(h1), luminance(h2)
    if a < b: a, b = b, a
    return (a + 0.05) / (b + 0.05)

def de2000(l1, l2):
    L1, a1, b1 = l1; L2, a2, b2 = l2
    C1, C2 = math.hypot(a1, b1), math.hypot(a2, b2)
    Cb = (C1 + C2) / 2
    G = 0.5 * (1 - math.sqrt(Cb**7 / (Cb**7 + 25**7)))
    a1p, a2p = (1 + G) * a1, (1 + G) * a2
    C1p, C2p = math.hypot(a1p, b1), math.hypot(a2p, b2)
    h1p = math.degrees(math.atan2(b1, a1p)) % 360 if C1p else 0
    h2p = math.degrees(math.atan2(b2, a2p)) % 360 if C2p else 0
    dLp, dCp = L2 - L1, C2p - C1p
    if C1p * C2p == 0: dhp = 0
    else:
        d = h2p - h1p
        dhp = d - 360 if d > 180 else d + 360 if d < -180 else d
    dHp = 2 * math.sqrt(C1p * C2p) * math.sin(math.radians(dhp / 2))
    Lbp, Cbp = (L1 + L2) / 2, (C1p + C2p) / 2
    if C1p * C2p == 0: hbp = h1p + h2p
    else:
        s = h1p + h2p
        hbp = s / 2 if abs(h1p - h2p) <= 180 else (s + 360) / 2 if s < 360 else (s - 360) / 2
    T = (1 - 0.17*math.cos(math.radians(hbp - 30)) + 0.24*math.cos(math.radians(2*hbp))
         + 0.32*math.cos(math.radians(3*hbp + 6)) - 0.20*math.cos(math.radians(4*hbp - 63)))
    dth = 30 * math.exp(-(((hbp - 275) / 25) ** 2))
    Rc = 2 * math.sqrt(Cbp**7 / (Cbp**7 + 25**7))
    Sl = 1 + 0.015 * (Lbp - 50)**2 / math.sqrt(20 + (Lbp - 50)**2)
    Sc, Sh = 1 + 0.045 * Cbp, 1 + 0.015 * Cbp * T
    Rt = -math.sin(math.radians(2 * dth)) * Rc
    return math.sqrt((dLp/Sl)**2 + (dCp/Sc)**2 + (dHp/Sh)**2 + Rt * (dCp/Sc) * (dHp/Sh))

def de_hex(a, b): return de2000(hex2lab(a), hex2lab(b))

# ---------------------------------------------------------------- report
HUES = {1: "red", 2: "green", 3: "yellow", 4: "blue", 5: "magenta", 6: "cyan"}

def load(path):
    cfg = {}
    for line in Path(path).read_text().splitlines():
        m = re.match(r"\s*(background|foreground|color\d+)\s+(#[0-9a-fA-F]{6})", line)
        if m: cfg[m[1]] = m[2].lower()
    return cfg

def washed(h, k=0.6):
    L, C, hh = lab2lch(hex2lab(h)); lab = lch2lab(L, C * k, hh)
    return lab2hex(lab) if lab_in_gamut(lab) else h

def main():
    default = Path(__file__).resolve().parent.parent / "dot/.config/kitty/cockpit.conf"
    c = load(sys.argv[1] if len(sys.argv) > 1 else default)
    bg, fg = c["background"], c["foreground"]
    fails = []
    def check(ok, msg):
        print(("  ok   " if ok else "  FAIL ") + msg)
        if not ok: fails.append(msg)
    print(f"background {bg} (L* {hex2lab(bg)[0]:.1f}), foreground {fg} (L* {hex2lab(fg)[0]:.1f})")
    print("\ncontrast vs background")
    check(contrast(fg, bg) >= 10.5, f"foreground {contrast(fg, bg):.1f}:1")
    for i, n in HUES.items():
        check(contrast(c[f"color{i}"], bg) >= 6.0, f"{n:8s} {c[f'color{i}']}  {contrast(c[f'color{i}'], bg):.1f}:1")
    check(contrast(c["color8"], bg) >= 4.5, f"bright black (dim text) {contrast(c['color8'], bg):.1f}:1")
    for label, fn, floor in (("pairwise dE2000", lambda h: h, 20.0), ("pairwise dE2000, washed panel (chroma x0.6)", washed, 14.0)):
        items = {n: fn(c[f"color{i}"]) for i, n in HUES.items()}; items["foreground"] = fn(fg)
        pairs = sorted((de_hex(items[a], items[b]), a, b) for a, b in itertools.combinations(items, 2))
        print(f"\n{label}: worst 4 -> " + "; ".join(f"{a}-{b} {d:.1f}" for d, a, b in pairs[:4]))
        check(pairs[0][0] >= floor, f"minimum {pairs[0][0]:.1f} (target >= {floor:.0f})")
    print("\nnormal vs bright twin")
    for i, n in HUES.items():
        d = de_hex(c[f"color{i}"], c[f"color{i+8}"])
        check(d >= 10.0, f"{n:8s} {d:.1f}")
    print("\nblue vs cyan (symlink vs directory): normal %.1f, bright %.1f" % (de_hex(c["color4"], c["color6"]), de_hex(c["color12"], c["color14"])))
    print("\n" + ("all targets met" if not fails else f"{len(fails)} target(s) missed"))
    return 1 if fails else 0

if __name__ == "__main__":
    sys.exit(main())
