#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rip (rippsec) and contributors. See LICENSE and NOTICE.md.
"""Build the bspwn documentation: manual (md + pdf), cheatsheet (md + pdf), keyboard map and diagrams, interactive page.

    python3 scripts/docs/build.py            # everything
    python3 scripts/docs/build.py --check    # only compare the docs' key list with sxhkdrc / tmux.conf
    python3 scripts/docs/build.py --no-pdf   # skip the (slow) PDF step

Needs: python3-markdown, weasyprint, graphviz (`dot`). Sources live in docs/src/, diagrams in docs/diagrams/*.dot,
shortcuts in scripts/docs/keys.py. Output goes to docs/ (committed, so people can read it without building).
"""
import json, re, subprocess, sys, html, datetime
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
DOCS = ROOT / "docs"
SRC = DOCS / "src"
sys.path.insert(0, str(HERE))
import keys as K

# ------------------------------------------------------------------ check
def check():
    ok = True
    real = {k.lower() for k in K.parse_sxhkd(ROOT / "dot/.config/sxhkd/sxhkdrc")}
    doc = {k.lower() for k in K.doc_sxhkd_keys() if "drag" not in k}
    for label, a, b in (("bound in sxhkdrc but missing from scripts/docs/keys.py", real - doc, None),
                        ("documented in keys.py but not bound in sxhkdrc", doc - real, None)):
        if a:
            ok = False
            print(f"sxhkd: {label}:"); [print("   ", x) for x in sorted(a)]
    treal = {k.lower() for k in K.parse_tmux(ROOT / "dot/.tmux.conf")}
    tdoc = set()
    for _, rows in K.TMUX:
        for k, _ in rows:
            if k.startswith("alt+") or k.startswith("prefix+"):
                tdoc.add(k.lower())
    tdoc = {x for x in tdoc if ".." not in x}
    for n in range(1, 10): tdoc.add(f"alt+{n}")
    tdoc -= {f"alt+1..9"}
    miss = treal - tdoc
    # a few tmux binds are intentionally undocumented (unbinds, mouse-mode helpers)
    if miss:
        print("tmux: bound in dot/.tmux.conf but missing from keys.py:"); [print("   ", x) for x in sorted(miss)]
        ok = False
    extra = tdoc - treal
    if extra:
        print("tmux: documented but not found in dot/.tmux.conf:"); [print("   ", x) for x in sorted(extra)]
        ok = False
    print("keys check:", "OK" if ok else "DRIFT")
    return ok

# ------------------------------------------------------------------ diagrams
def diagrams():
    style = (DOCS / "diagrams/_style.dot").read_text()
    for f in sorted((DOCS / "diagrams").glob("*.dot")):
        if f.name.startswith("_"):
            continue
        text = f.read_text().replace("//STYLE", style)
        out = f.with_suffix(".svg")
        subprocess.run(["dot", "-Tsvg", "-o", str(out)], input=text.encode(), check=True)
    print("diagrams: ok")

# ------------------------------------------------------------------ keyboard map
SHORT = {  # super+key and super+shift+key, a few letters each
 "1": ("desk 1", "to 1"), "2": ("desk 2", "to 2"), "3": ("desk 3", "to 3"), "4": ("desk 4", "to 4"), "5": ("desk 5", "to 5"),
 "6": ("desk 6", "to 6"), "7": ("desk 7", "to 7"), "8": ("desk 8", "to 8"), "9": ("desk 9", "to 9"), "0": ("desk 10", "to 10"),
 "q": ("close", ""), "w": ("", "screenshot"), "e": ("touchpad", "unfreeze"), "r": ("launcher", "rotate"), "t": ("tiled", "pseudo"),
 "y": ("pull leaf", ""), "u": ("", ""), "i": ("newer", ""), "o": ("older", "float all"), "p": ("focus fol.", ""),
 "a": ("", ""), "s": ("float", "screenshot"), "d": ("menu", ""), "f": ("fullscr", "firefox"), "g": ("swap big", "chromium"),
 "h": ("focus ◀", "move ◀"), "j": ("focus ▼", "move ▼"), "k": ("focus ▲", "move ▲"), "l": ("focus ▶", "move ▶"),
 "z": ("", ""), "x": ("lock", ""), "c": ("next win", "caido*"), "v": ("", ""), "b": ("sibling", "brave"), "n": ("notes", "add todo"),
 "m": ("monocle", ""),
 "Return": ("terminal", "plain term"), "Tab": ("overview", ""), "Esc": ("restart wm", "dbus+wm"),
}

def keymap_svg():
    rows = [list("1234567890"), list("qwertyuiop"), list("asdfghjkl"), list("zxcvbnm")]
    off = [0, 28, 44, 72]
    w, h, gap = 82, 74, 6
    parts = []
    y0 = 10
    def key(x, y, k, kw=w):
        main, sh = SHORT.get(k, ("", ""))
        label = k if len(k) == 1 else k
        parts.append(f'<rect x="{x}" y="{y}" width="{kw}" height="{h}" rx="7" fill="#e9e6df" stroke="#3a3c42"/>')
        parts.append(f'<text x="{x+8}" y="{y+16}" font-size="12" font-weight="700" fill="#111214">{html.escape(label.upper() if len(k)==1 else label)}</text>')
        if main:
            parts.append(f'<text x="{x+kw/2}" y="{y+42}" font-size="12" text-anchor="middle" fill="#111214">{html.escape(main)}</text>')
        if sh:
            parts.append(f'<text x="{x+kw/2}" y="{y+62}" font-size="10.5" text-anchor="middle" fill="#7a3d00">⇧ {html.escape(sh)}</text>')
    for r, row in enumerate(rows):
        for i, k in enumerate(row):
            key(10 + off[r] + i * (w + gap), y0 + r * (h + gap), k)
    # bottom row: Esc, Tab, Return
    yb = y0 + 4 * (h + gap)
    key(10, yb, "Esc", 100); key(10 + 106, yb, "Tab", 100); key(10 + 212, yb, "Return", 130)
    W = 10 + 10 * (w + gap) + 20
    H = yb + h + 40
    parts.append(f'<text x="10" y="{H-14}" font-size="11" fill="#33353b">Hold Super (the Windows key) and press the key. Black = Super+key, orange ⇧ = Super+Shift+key. * caido shares its keys with "previous window".</text>')
    svg = (f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {W} {H}" width="{W}" height="{H}" '
           f'font-family="DejaVu Sans, sans-serif">{"".join(parts)}</svg>')
    (DOCS / "diagrams/keymap.svg").write_text(svg)
    print("keymap: ok")

# ------------------------------------------------------------------ markdown helpers
def kbd(keys):
    return " ".join(f"`{k}`" for k in [keys])

def show(k):
    return k.replace("prefix+", "Ctrl+b, ").replace("C-", "Ctrl+") if k.startswith("prefix+") else k

def md_table(rows, head=("Keys", "Action")):
    out = [f"| {head[0]} | {head[1]} |", "| --- | --- |"]
    for k, d in rows:
        out.append(f"| `{show(k)}` | {d} |")
    return "\n".join(out)

def md_keys(kind):
    data = {"sxhkd": K.SXHKD, "tmux": K.TMUX}[kind]
    out = []
    for sec, rows in data:
        out.append(f"#### {sec}\n\n" + md_table(rows))
    return "\n\n".join(out)

def md_zsh():
    return md_table(K.ZSH)

def md_bar():
    out = ["| # | Symbol | What it is | Mouse |", "| --- | --- | --- | --- |"]
    for n, sym, what, mouse in K.BAR:
        out.append(f"| {n} | {sym} | {what} | {mouse} |")
    return "\n".join(out)

def slug(text):  # GitHub-style heading anchor
    s = re.sub(r"[`*_]", "", text.strip().lower())
    s = re.sub(r"[^\w\- ]", "", s, flags=re.U)
    return s.replace(" ", "-")

def fill(md):
    rep = {"<!--KEYS:sxhkd-->": md_keys("sxhkd"), "<!--KEYS:tmux-->": md_keys("tmux"),
           "<!--KEYS:zsh-->": md_zsh(), "<!--BAR-->": md_bar(),
           "<!--KEYMAP-->": "![Super key map](diagrams/keymap.svg)",
           "<!--DATE-->": datetime.date.today().isoformat()}
    for k, v in rep.items():
        md = md.replace(k, v)
    return md

def headings(md):
    out, fence = [], False
    for line in md.splitlines():
        if line.startswith("```"): fence = not fence
        if fence: continue
        m = re.match(r"^(#{1,3}) (.+)$", line)
        if m and "<!--" not in line:
            out.append((len(m.group(1)), m.group(2).strip()))
    return out

def make_toc(md, maxlevel=2):
    lines = []
    for lvl, t in headings(md):
        if lvl == 1 and t.lower().startswith("bspwn user manual"):
            continue
        if lvl > maxlevel: continue
        lines.append(f"{'  ' * (lvl - 1)}- [{t}](#{slug(t)})")
    return "\n".join(lines)

# ------------------------------------------------------------------ manual
CSS = r"""
@page { size: A4; margin: 18mm 16mm 20mm 16mm;
  @bottom-center { content: counter(page); font: 9pt 'DejaVu Sans'; color: #666; }
  @top-right { content: string(chapter); font: 8.5pt 'DejaVu Sans'; color: #888; } }
@page :first { margin: 0; @bottom-center { content: none } @top-right { content: none } }
html { font: 10pt/1.5 'DejaVu Sans', sans-serif; color: #1b1c20; }
h1 { string-set: chapter content(); font-size: 21pt; margin: 0 0 6mm; padding-bottom: 2mm; border-bottom: 2px solid #3a3c42; page-break-before: always; }
h1.first { page-break-before: avoid; }
h2 { font-size: 14pt; margin: 8mm 0 3mm; color: #111214; break-after: avoid; }
h3 { font-size: 11.5pt; margin: 6mm 0 2mm; color: #2c2e34; break-after: avoid; }
h4 { font-size: 10pt; margin: 5mm 0 1.5mm; color: #555860; text-transform: uppercase; letter-spacing: .05em; break-after: avoid; }
p, li { orphans: 3; widows: 3; }
code { font: 8.6pt 'DejaVu Sans Mono', monospace; background: #ecebe6; padding: 0 2px; border-radius: 2px; }
pre { background: #1d2024; color: #dddad3; padding: 3mm 4mm; border-radius: 3px; font: 8.2pt/1.4 'DejaVu Sans Mono', monospace; white-space: pre-wrap; word-wrap: break-word; break-inside: avoid; }
pre code { background: none; padding: 0; color: inherit; font-size: inherit; }
table { border-collapse: collapse; width: 100%; margin: 3mm 0 5mm; font-size: 8.8pt; }
th { background: #d7d4cc; text-align: left; padding: 1.6mm 2mm; border: 1px solid #b9b6ad; }
td { padding: 1.4mm 2mm; border: 1px solid #d3d0c8; vertical-align: top; }
tr { break-inside: avoid; }
img { max-width: 100%; display: block; margin: 3mm auto; }
a { color: #1f4f8f; text-decoration: none; }
blockquote { margin: 3mm 0; padding: 2mm 4mm; border-left: 3px solid #8e9099; background: #f2f0ea; }
.cover { page: first; height: 297mm; padding: 60mm 22mm 0; background: #111214; color: #e6e3dd; box-sizing: border-box; page-break-after: always; }
.cover h1 { color: #f2efe9; border: 0; font-size: 44pt; page-break-before: avoid; string-set: none; margin: 0; }
.cover p { font-size: 13pt; color: #bdbab3; max-width: 130mm; }
.cover .small { font-size: 9.5pt; color: #8e9099; margin-top: 70mm; }
.toc { page-break-after: always; }
.toc h1 { page-break-before: avoid; }
.toc ul { list-style: none; padding-left: 0; margin: 0; }
.toc li { margin: 0.3mm 0; line-height: 1.3; }
.toc li.l1 { margin-top: 3mm; font-weight: 700; }
.toc li.l2 { padding-left: 6mm; font-size: 8.8pt; }
.toc a { color: #1b1c20; }
.toc a::after { content: leader('.') target-counter(attr(href), page); color: #666; }
"""

def render_html(md_text, *, cover=True):
    import markdown
    class Slugger: pass
    def slugify(value, sep):  # python-markdown hook: same as GitHub
        return slug(value)
    body = markdown.markdown(md_text, extensions=["tables", "fenced_code", "sane_lists", "attr_list", "toc"],
                             extension_configs={"toc": {"slugify": slugify, "toc_depth": "2-3"}})
    return body

def build_manual(pdf=True):
    src = (SRC / "manual.md").read_text()
    md = fill(src)
    toc_md = make_toc(md, 2)
    md = md.replace("<!--TOC-->", toc_md)
    (DOCS / "BSPWN-manual.md").write_text(md)
    print("manual.md: ok")
    if not pdf:
        return
    from weasyprint import HTML
    body = render_html(md)
    # PDF: replace the md TOC list by one with page numbers, first h1 is the title
    tocs = []
    for lvl, t in headings(md):
        if lvl == 1 and t.lower().startswith("bspwn user manual"): continue
        if t == "Contents": continue
        if lvl <= 2: tocs.append(f'<li class="l{lvl}"><a href="#{slug(t)}">{html.escape(t)}</a></li>')
    toc_html = '<div class="toc"><h1>Contents</h1><ul>' + "".join(tocs) + "</ul></div>"
    body = re.sub(r"<h1 id=\"[^\"]*\">BSPWN user manual.*?</h1>\s*<p><em>.*?</p>", "", body, count=1, flags=re.S)
    # drop the markdown TOC list (first <ul> after the Contents heading inside the body)
    body = re.sub(r"<h2 id=\"contents\">.*?</h2>\s*<ul>.*?</ul>\s*(?=<h1|<h2)", "", body, count=1, flags=re.S)
    body = body.replace('<h1 id=', '<h1 id=', 1)
    cover = (f'<div class="cover"><h1>bspwn</h1><p>User manual for the bspwm desktop: using it, changing it, and making it yours.</p>'
             f'<p>bspwm · sxhkd · polybar · tmux · zsh · themes · lock screen · power tools</p>'
             f'<p class="small">Built {datetime.date.today().isoformat()} from the repository (rippsec/bspwn). Licensed GPL-2.0; documentation CC BY-SA 4.0. See the LICENSE and NOTICE files.</p></div>')
    doc = f"<html><head><meta charset='utf-8'><title>bspwn user manual</title><style>{CSS}</style></head><body>{cover}{toc_html}{body}</body></html>"
    HTML(string=doc, base_url=str(DOCS) + "/").write_pdf(str(DOCS / "BSPWN-manual.pdf"))
    print("manual.pdf: ok")

# ------------------------------------------------------------------ cheatsheet
CS_CSS = r"""
@page { size: A4 landscape; margin: 8mm; }
html { font: 7.6pt/1.28 'DejaVu Sans', sans-serif; color: #1b1c20; }
h1 { font-size: 14pt; margin: 0 0 1.5mm; } .sub { color: #555860; margin: 0 0 2.5mm; font-size: 7.6pt; }
.cols { column-count: 3; column-gap: 5mm; }
.sec { break-inside: avoid; margin: 0 0 2.6mm; }
.sec h2 { font-size: 8.6pt; margin: 0 0 .8mm; padding: .6mm 1.6mm; background: #1d2024; color: #f2efe9; border-radius: 2px; }
table { border-collapse: collapse; width: 100%; }
td { padding: .25mm 1mm; border-bottom: .3pt solid #d3d0c8; vertical-align: top; }
td.k { white-space: nowrap; font: 6.8pt 'DejaVu Sans Mono', monospace; background: #f1efe9; width: 1%; }
.foot { margin-top: 1.5mm; font-size: 6.6pt; color: #666; }
"""

def cs_section(title, rows):
    body = "".join(f"<tr><td class='k'>{html.escape(k)}</td><td>{html.escape(d)}</td></tr>" for k, d in rows)
    return f"<div class='sec'><h2>{html.escape(title)}</h2><table>{body}</table></div>"

SHORT_DESC = lambda d: d.split(" (")[0]

def build_cheatsheet(pdf=True):
    secs = []
    for t, rows in K.SXHKD:
        secs.append((f"Desktop: {t}", [(k.replace("super", "Super"), SHORT_DESC(d)) for k, d in rows]))
    for t, rows in K.TMUX:
        secs.append((f"tmux: {t}", [(k.replace("alt+", "Alt+").replace("prefix+", "Ctrl+b ").replace("C-", "Ctrl+"), SHORT_DESC(d)) for k, d in rows]))
    secs.append(("zsh", [(k, SHORT_DESC(d)) for k, d in K.ZSH]))
    secs.append(("Polybar (mouse)", [(f"{n} {sym}", f"{what}: {mouse}") for n, sym, what, mouse in K.BAR if mouse != "display only"]))
    # markdown version
    md = ["# bspwn cheatsheet", "", "*Super = the Windows key. A capital letter in sxhkdrc means Shift. tmux prefix is `Ctrl+b`; the Alt keys need no prefix.*", ""]
    for t, rows in secs:
        md += [f"## {t}", "", md_table(rows), ""]
    md += ["![Super key map](diagrams/keymap.svg)", "", "Generated by `scripts/docs/build.py` from `scripts/docs/keys.py`."]
    (DOCS / "BSPWN-cheatsheet.md").write_text("\n".join(md))
    print("cheatsheet.md: ok")
    if not pdf:
        return
    from weasyprint import HTML
    desk = "".join(cs_section(t, r) for t, r in secs if t.startswith("Desktop"))
    rest = "".join(cs_section(t, r) for t, r in secs if not t.startswith("Desktop"))
    svg = re.sub(r' (width|height)="\d+"', "", (DOCS / "diagrams/keymap.svg").read_text(), count=2)
    doc = (f"<html><head><meta charset='utf-8'><style>{CS_CSS}</style></head><body>"
           f"<h1>bspwn cheatsheet</h1><p class='sub'>Super = the Windows key · a capital letter means Shift · tmux prefix = Ctrl+b (the Alt keys need none) · full docs: BSPWN-manual.pdf</p>"
           f"<div class='cols'>{desk}</div>"
           f"<div style='break-before:page'><h1>tmux, shell and bar</h1><div class='cols'>{rest}</div>"
           f"<h1 style='margin-top:4mm'>Super key map</h1><div style='width:100%;break-inside:avoid'>{svg}</div></div>"
           f"</body></html>")
    HTML(string=doc, base_url=str(DOCS) + "/").write_pdf(str(DOCS / "BSPWN-cheatsheet.pdf"))
    print("cheatsheet.pdf: ok")

# ------------------------------------------------------------------ interactive
def build_interactive():
    tpl = (SRC / "interactive.template.html").read_text()
    data = {"sxhkd": K.SXHKD, "tmux": K.TMUX, "zsh": K.ZSH, "bar": K.BAR,
            "built": datetime.date.today().isoformat()}
    out = tpl.replace("/*__DATA__*/null", json.dumps(data, ensure_ascii=False))
    (DOCS / "interactive.html").write_text(out)
    print("interactive.html: ok")

def main():
    args = sys.argv[1:]
    if "--check" in args:
        sys.exit(0 if check() else 1)
    pdf = "--no-pdf" not in args
    check()
    diagrams(); keymap_svg()
    build_manual(pdf); build_cheatsheet(pdf)
    if (SRC / "interactive.template.html").exists():
        build_interactive()

if __name__ == "__main__":
    main()
