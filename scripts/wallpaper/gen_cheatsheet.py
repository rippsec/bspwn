#!/usr/bin/env python3
"""Monochrome 'functional' wallpaper: a pentest quick-reference (ASCII, bases,
encodings, OWASP Top 10 web, OWASP Top 10 LLM, ports, HTTP codes) with the 四
emblem as a faint watermark.

Layout is authored for 1600x900 (polybar on top, conky HUD in the right column
x>=1270), drawn at 2x with Pillow and downsampled for clean anti-aliasing.
Needs only Pillow + numpy and the bundled Atkinson Hyperlegible Mono.

usage: gen_cheatsheet.py [out.jpg]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(sys.argv[1]) if len(sys.argv) > 1 else ROOT / "assets/wallpaper/cheatsheet.jpg"
W, H, K = 1600, 900, 2                      # logical size, supersample factor
FONTS = ROOT / "assets/fonts/AtkinsonHyperlegibleMono"
CJK = "/usr/share/fonts/opentype/noto/NotoSansCJK-Bold.ttc"

WHITE, LIGHT, MID, DIM, FAINT = (252, 250, 246), (232, 229, 223), (188, 190, 198), (128, 130, 138), (38, 39, 43)

img = Image.new("RGB", (W * K, H * K), (10, 10, 12))
d = ImageDraw.Draw(img)
_fc = {}


def font(size, weight="Regular"):
    key = (size, weight)
    if key not in _fc:
        _fc[key] = ImageFont.truetype(str(FONTS / f"AtkinsonHyperlegibleMono-{weight}.ttf"), round(size * K))
    return _fc[key]


TS = 1.1                                    # global text scale


def tx(x, y, s, size=11, fill=MID, weight="Regular", anchor="ls"):
    d.text((x * K, y * K), s, font=font(size * TS, weight), fill=fill, anchor=anchor)


def ln(x0, y0, x1, y1, fill=DIM, w=1):
    d.line((x0 * K, y0 * K, x1 * K, y1 * K), fill=fill, width=max(1, round(w * K)))


def title(x, y, w, s, tag=""):
    tx(x, y, s, 12, WHITE, "Bold")
    if tag:
        tx(x + w, y, tag, 10, DIM, anchor="rs")
    ln(x, y + 6, x + w, y + 6, MID, 1)
    ln(x, y + 6, x + 22, y + 6, WHITE, 2)


# ------------------------------------------------------------------ background
yy, xx = np.mgrid[0:H * K, 0:W * K].astype(np.float32)
v = np.sqrt(((xx - W * K * 0.55) / (W * K * 0.8)) ** 2 + ((yy - H * K / 2) / (H * K * 0.8)) ** 2)
bg = (20 - 12 * np.clip(v, 0, 1) ** 1.5)[..., None] * np.ones((1, 1, 3), np.float32)
img = Image.fromarray(bg.astype(np.uint8))
d = ImageDraw.Draw(img)
for gx in range(0, W, 40):                  # faint dot grid
    for gy in range(0, H, 40):
        d.rectangle((gx * K, gy * K, gx * K + 1, gy * K + 1), fill=FAINT)

# 四 watermark behind the HUD column
wm = Image.new("L", (W * K, H * K), 0)
ImageDraw.Draw(wm).text((1445 * K, 470 * K), "四", font=ImageFont.truetype(CJK, 430 * K, index=2), fill=255, anchor="mm")
wm = np.asarray(wm, np.float32) / 255
arr = np.asarray(img, np.float32)
arr += wm[..., None] * 18
img = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
d = ImageDraw.Draw(img)

# ================================================================== COLUMN 1
X1, CW = 40, 372
y = 70

# ---- ASCII (like `man ascii`, hex layout)
title(X1, y, CW, "ASCII", "man ascii")
y += 26
cell = 22
tx(X1 + 22, y, "", 10)
for c in range(16):
    tx(X1 + 30 + c * cell, y, f"{c:X}", 10, DIM, "Bold", "ms")
for r in range(2, 8):
    ry = y + 10 + (r - 1) * 26 - 6
    tx(X1 + 8, ry, f"{r}_", 10, DIM, "Bold", "ms")
    for c in range(16):
        n = r * 16 + c
        if n == 0x20:
            s, col, wt = "SP", DIM, "Regular"
        elif n == 0x7F:
            s, col, wt = "DL", DIM, "Regular"
        else:
            ch = chr(n)
            s = ch
            col, wt = (LIGHT, "Regular") if ch.isalnum() else (WHITE, "Bold")
        tx(X1 + 30 + c * cell, ry, s, 12.5 if len(s) == 1 else 9, col, wt, "ms")
y += 10 + 6 * 26 + 18
tx(X1, y, "00 NUL  07 BEL  08 BS  09 TAB  0A LF  0D CR", 10.5, MID)
y += 18
tx(X1, y, "1B ESC  20 SP  30 '0'  41 'A'  61 'a'  7F DEL", 10.5, MID)

# ---- bases
y += 46
title(X1, y, CW, "BASES", "hex · dec · bin · oct")
y += 24
for blk in range(2):
    bx = X1 + blk * 190
    tx(bx, y, "H  DC  BIN  OC", 10, DIM, "Bold")
    for i in range(8):
        n = blk * 8 + i
        tx(bx, y + 19 + i * 19, f"{n:X}  {n:>2}  {n:04b} {n:>2o}", 11.5, LIGHT if n % 2 == 0 else MID)
y += 19 + 8 * 19 + 14
for s in ("0x41 = 65 = 0b01000001 = 'A'     0xFF = 255",
          "2^8 256 · 2^10 1K · 2^16 64K · 2^32 4G",
          "rwx = 4 2 1 · 755 rwxr-xr-x · 4000 SUID · 2000 SGID",
          "/8 255.0.0.0 · /16 255.255.0.0 · /24 ...255.0 · /30 ..252"):
    tx(X1, y, s, 10, MID)
    y += 19

# ---- encodings
y += 24
title(X1, y, CW, "ENCODING", "url %hex")
y += 22
enc = [("sp", "%20"), ('"', "%22"), ("#", "%23"), ("%", "%25"), ("&", "%26"), ("'", "%27"),
       ("/", "%2F"), (";", "%3B"), ("<", "%3C"), (">", "%3E"), ("\\", "%5C"), ("NUL", "%00")]
for i, (a, b) in enumerate(enc):
    cx = X1 + (i % 4) * 94
    cy = y + (i // 4) * 20
    tx(cx, cy, a, 11, WHITE, "Bold")
    tx(cx + 30, cy, b, 11, MID)
y += 3 * 20 + 6
tx(X1, y, "CRLF %0d%0a · b64 pad = · html &lt; &gt; &#x27;", 10, MID)

# ================================================================== COLUMN 2
X2 = 440
y = 70
title(X2, y, CW, "OWASP TOP 10", "web · 2021")
y += 28
owasp = [
    ("A01", "Broken Access Control", "IDOR · forced browse · JWT/role tamper · CORS"),
    ("A02", "Cryptographic Failures", "no TLS · weak hash/cipher · keys in repo"),
    ("A03", "Injection", "' \" ; ` {{7*7}} ${} · SQLi XSS SSTI cmd LDAP"),
    ("A04", "Insecure Design", "logic flaws · no rate limit · trust boundary"),
    ("A05", "Security Misconfiguration", "defaults · verbose errors · XXE · open buckets"),
    ("A06", "Vulnerable Components", "version -> CVE · searchsploit · retire.js"),
    ("A07", "Identification/Auth Failures", "brute · default creds · fixation · MFA bypass"),
    ("A08", "Software/Data Integrity", "unsafe deserialization · unsigned updates · CI/CD"),
    ("A09", "Logging/Monitoring Failures", "no alerts · log injection · no audit trail"),
    ("A10", "SSRF", "169.254.169.254 · localhost · gopher:// · rebinding"),
]
for code, name, hint in owasp:
    tx(X2, y, code, 11.5, DIM, "Bold")
    tx(X2 + 38, y, name, 12, WHITE, "Bold")
    tx(X2 + 38, y + 17, hint, 10.5, MID)
    y += 53

# ---- ports (under OWASP)
y += 14
title(X2, y, CW, "PORTS", "tcp")
y += 24
ports = [("21", "ftp"), ("22", "ssh"), ("23", "telnet"), ("25", "smtp"), ("53", "dns"), ("80", "http"),
         ("88", "kerberos"), ("110", "pop3"), ("139", "netbios"), ("143", "imap"), ("389", "ldap"), ("443", "https"),
         ("445", "smb"), ("1433", "mssql"), ("3306", "mysql"), ("3389", "rdp"), ("5432", "pgsql"), ("5985", "winrm"),
         ("6379", "redis"), ("8080", "http-alt")]
for i, (p, n) in enumerate(ports):
    cx = X2 + (i % 3) * 126
    cy = y + (i // 3) * 20
    tx(cx, cy, p, 11, WHITE, "Bold")
    tx(cx + 40, cy, n, 10.5, MID)

# ================================================================== COLUMN 3
X3 = 860
CW3 = 380
y = 70
title(X3, y, CW3, "OWASP TOP 10 · LLM", "2025")
y += 28
llm = [
    ("LLM01", "Prompt Injection", "direct · indirect (docs, web, mail) · jailbreak"),
    ("LLM02", "Sensitive Info Disclosure", "PII · secrets in context · training leaks"),
    ("LLM03", "Supply Chain", "poisoned models/datasets · plugins · deps"),
    ("LLM04", "Data & Model Poisoning", "tainted fine-tune/RAG data · backdoor triggers"),
    ("LLM05", "Improper Output Handling", "model output -> XSS/SQLi/RCE downstream"),
    ("LLM06", "Excessive Agency", "tools w/ too much power · no human in loop"),
    ("LLM07", "System Prompt Leakage", "'repeat the above' · secrets in the prompt"),
    ("LLM08", "Vector/Embedding Weaknesses", "RAG poisoning · cross-tenant retrieval"),
    ("LLM09", "Misinformation", "hallucinated facts · fake packages (slopsquat)"),
    ("LLM10", "Unbounded Consumption", "token floods · DoS · wallet drain · model theft"),
]
for code, name, hint in llm:
    tx(X3, y, code, 11, DIM, "Bold")
    tx(X3 + 46, y, name, 12, WHITE, "Bold")
    tx(X3 + 46, y + 17, hint, 10.5, MID)
    y += 53

# ---- http status
y += 14
title(X3, y, CW3, "HTTP", "status")
y += 24
http = [("200", "ok"), ("201", "created"), ("204", "no content"), ("301", "moved"), ("302", "found"),
        ("304", "not modified"), ("400", "bad request"), ("401", "unauth"), ("403", "forbidden"),
        ("404", "not found"), ("405", "bad method"), ("429", "rate limit"), ("500", "server err"),
        ("502", "bad gateway"), ("503", "unavailable")]
for i, (c, n) in enumerate(http):
    cx = X3 + (i % 3) * 126
    cy = y + (i // 3) * 20
    tx(cx, cy, c, 11, WHITE, "Bold")
    tx(cx + 36, cy, n, 10.5, MID)

# ------------------------------------------------------------------ footer mark
d.text((40 * K, 880 * K), "四", font=ImageFont.truetype(CJK, 16 * K, index=2), fill=WHITE, anchor="ls")
tx(60, 880, "// REF", 11, WHITE, "Bold")
tx(122, 880, "bases · ascii · owasp web 2021 · owasp llm 2025", 10, DIM)

# ------------------------------------------------------------------ output
out = img.resize((W, H), Image.LANCZOS)
arr = np.asarray(out, np.float32)
arr += np.random.default_rng(4).normal(0, 1.6, (H, W, 1)).astype(np.float32)   # film grain
out = Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8))
OUT.parent.mkdir(parents=True, exist_ok=True)
out.save(OUT, quality=94, subsampling=0, optimize=True)
print(OUT, out.size)
