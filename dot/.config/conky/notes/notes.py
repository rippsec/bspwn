#!/usr/bin/env python3
"""Desktop notes: render a markdown file as conky markup, plus add/toggle/edit helpers.

  notes.py render [--cols N] [--size PT] [--max-lines N] [--hide-done]
  notes.py add       quick-add a todo through rofi
  notes.py toggle    tick / untick a task through rofi
  notes.py edit      open the file in mousepad (floating)
  notes.py scroll N  scroll the widget by N lines (negative = up)
  notes.py watch     daemon: click the widget to edit, wheel over it to scroll

Notes file: $DESKNOTES, default ~/notes/desktop.md
"""
import argparse
import datetime as dt
import os
import re
import subprocess
import sys
import time

NOTES = os.environ.get("DESKNOTES", os.path.expanduser("~/notes/desktop.md"))
FONT = "BlexMono Nerd Font"
STATE = os.path.expanduser("~/.cache/desknotes.offset")
ROFI_THEME = os.path.expanduser("~/.config/rofi/notes.rasi")

C_TEXT, C_DIM, C_ACC = "#c9d1e0", "#667085", "#ff6b6b"
C_H2, C_H3 = "#e8b4b8", "#b7c2d7"
C_CODE, C_TAG, C_LINK = "#8fd1a5", "#7fb2ff", "#7fb2ff"
C_DATE, C_SOON, C_LATE = "#e6c07b", "#ffb454", "#ff5f5f"

GLYPH_OPEN, GLYPH_DONE = "", ""  # nf-fa-square_o / nf-fa-check_square_o
TASK = re.compile(r"^(\s*)[-*+] \[([ xX])\] ?(.*)$")
BULLET = re.compile(r"^(\s*)[-*+] (.*)$")
NUMBER = re.compile(r"^(\s*)(\d+)[.)] (.*)$")
INLINE = re.compile(
    r"(\*\*.+?\*\*|__.+?__|~~.+?~~|`[^`]+`|\*[^*\s][^*]*?\*|\[\[.+?\]\]"
    r"|\[[^\]]+\]\([^)]+\)|@\d{4}-\d{2}-\d{2}|(?<![\w&])#[A-Za-z][\w/-]*)"
)

TEMPLATE = """# Today
- [ ] first thing to remember @{today}
- [ ] second thing

## Notes
- jot anything here, **markdown** works: `code`, ~~strike~~, #tags, [[links]]

> Super+n edit  ·  Super+Shift+n add todo  ·  Super+Ctrl+n tick a task
"""


def ensure_file():
    if not os.path.exists(NOTES):
        os.makedirs(os.path.dirname(NOTES), exist_ok=True)
        with open(NOTES, "w") as f:
            f.write(TEMPLATE.replace("{today}", dt.date.today().isoformat()))


def read_lines():
    ensure_file()
    with open(NOTES) as f:
        return f.read().split("\n")


def write_lines(lines):
    tmp = NOTES + ".tmp"
    with open(tmp, "w") as f:
        f.write("\n".join(lines))
    os.replace(tmp, NOTES)


# ---------------------------------------------------------------- rendering
def runs_for(text, base):
    """Split inline markdown into (text, style) runs. style = (bold, italic, color)."""
    bold, italic, color = base
    out, pos = [], 0
    for m in INLINE.finditer(text):
        if m.start() > pos:
            out.append((text[pos:m.start()], base))
        t = m.group(0)
        if t.startswith(("**", "__")):
            out.append((t[2:-2], (True, italic, color)))
        elif t.startswith("~~"):
            out.append((t[2:-2], (bold, italic, C_DIM)))
        elif t.startswith("`"):
            out.append((t[1:-1], (bold, italic, C_CODE)))
        elif t.startswith("[["):
            out.append((t[2:-2], (bold, italic, C_LINK)))
        elif t.startswith("["):
            out.append((t[1:t.index("]")], (bold, italic, C_LINK)))
        elif t.startswith("@"):
            try:
                d = dt.date.fromisoformat(t[1:])
                today = dt.date.today()
                c = C_LATE if d < today else C_SOON if d == today else C_DATE
                out.append((" " + t[1:], (d <= today, italic, c)))
            except ValueError:
                out.append((t, base))
        elif t.startswith("#"):
            out.append((t, (bold, italic, C_TAG)))
        else:  # *italic*
            out.append((t[1:-1], (bold, True, color)))
        pos = m.end()
    if pos < len(text):
        out.append((text[pos:], base))
    return out


def font(size, style):
    bold, italic, _ = style
    return "${font %s:%s%s:size=%d}" % (FONT, "bold" if bold else "regular", ":italic" if italic else "", size)


def emit(runs, size):
    merged = []
    for text, style in runs:
        if merged and merged[-1][1] == style:
            merged[-1] = (merged[-1][0] + text, style)
        else:
            merged.append((text, style))
    s = ""
    for text, style in merged:
        s += "${color %s}%s%s" % (style[2], font(size, style), text.replace("$", "$$").replace("#", "\\#"))
    return s


def wrap(prefix, cont, runs, cols):
    """Greedy word wrap of runs; prefix is a ready-made [(text, style)] list, cont the hanging indent."""
    lines, cur, width = [], list(prefix), sum(len(t) for t, _ in prefix)
    limit = max(cols, 8)
    cstyle = (False, False, C_ACC if cont.strip() else C_TEXT)
    for text, style in runs:
        for word in re.findall(r"\s+|\S+", text):
            if word.isspace():
                if width + len(word) <= limit and width > len(cont) - 0:
                    cur.append((word, style))
                    width += len(word)
                continue
            while len(word) > limit - len(cont):  # hard-split very long tokens
                room = limit - width
                if room <= 0:
                    lines.append(cur)
                    cur, width = [(cont, cstyle)], len(cont)
                    continue
                cur.append((word[:room], style))
                lines.append(cur)
                word = word[room:]
                cur, width = [(cont, cstyle)], len(cont)
            if width + len(word) > limit and width > len(cont):
                lines.append(cur)
                cur, width = [(cont, cstyle)], len(cont)
            cur.append((word, style))
            width += len(word)
    lines.append(cur)
    return lines


def render(cols, size, max_lines, hide_done):
    raw = read_lines()
    body, i = [], 0
    if raw and raw[0].strip() == "---":  # skip YAML front matter
        for j in range(1, len(raw)):
            if raw[j].strip() == "---":
                i = j + 1
                break
    open_n = done_n = 0
    in_code = False
    plain = (False, False, C_TEXT)
    for line in raw[i:]:
        if line.strip().startswith("```"):
            in_code = not in_code
            continue
        if in_code:
            body += wrap([("  ", plain)], "  ", [(line, (False, False, C_CODE))], cols)
            continue
        if re.match(r"^\s*<!--.*-->\s*$", line):
            continue
        m = TASK.match(line)
        if m:
            ind, mark, txt = m.groups()
            done = mark in "xX"
            done_n += done
            open_n += not done
            if done and hide_done:
                continue
            pad = "  " * (len(ind.replace("\t", "  ")) // 2)
            glyph = (GLYPH_DONE if done else GLYPH_OPEN) + " "
            gstyle = (False, False, C_DIM if done else C_ACC)
            base = (False, False, C_DIM if done else C_TEXT)
            body += wrap([(pad, plain), (glyph, gstyle)], pad + "  ", runs_for(txt, base), cols)
            continue
        m = BULLET.match(line)
        if m:
            pad = "  " * (len(m.group(1).replace("\t", "  ")) // 2)
            body += wrap([(pad, plain), ("• ", (False, False, C_ACC))], pad + "  ",
                         runs_for(m.group(2), plain), cols)
            continue
        m = NUMBER.match(line)
        if m:
            pad = "  " * (len(m.group(1).replace("\t", "  ")) // 2)
            num = m.group(2) + ". "
            body += wrap([(pad, plain), (num, (False, False, C_ACC))], pad + " " * len(num),
                         runs_for(m.group(3), plain), cols)
            continue
        h = re.match(r"^(#{1,6})\s+(.*)$", line)
        if h:
            lvl = len(h.group(1))
            col = C_ACC if lvl == 1 else C_H2 if lvl == 2 else C_H3
            if body and body[-1]:
                body.append(None)  # spacer before headings
            body.append(("H%d" % min(lvl, 3), [(h.group(2), (True, False, col))]))
            continue
        if re.match(r"^\s*([-*_])\1{2,}\s*$", line):
            body.append(("HR", None))
            continue
        q = re.match(r"^>\s?(.*)$", line)
        if q:
            body += wrap([("▎ ", (False, False, C_ACC))], "▎ ",
                         runs_for(q.group(1), (False, True, C_DIM)), cols)
            continue
        if not line.strip():
            if body and body[-1] is not None:
                body.append(None)
            continue
        body += wrap([], "", runs_for(line.strip(), plain), cols)

    # flatten to markup lines
    out = []
    hsize = {"H1": size + 4, "H2": size + 2, "H3": size}
    for item in body:
        if item is None:
            out.append("")
        elif isinstance(item, tuple) and item[0] in hsize:
            out.append(emit(item[1], hsize[item[0]]))
        elif isinstance(item, tuple) and item[0] == "HR":
            out.append("${color %s}%s" % (C_DIM, "─" * cols))
        else:
            out.append(emit(item, size))
    while out and out[-1] == "":
        out.pop()

    head = "${color %s}${font %s:bold:size=%d}  NOTES${alignr}${font %s:regular:size=%d}%s%d open%s${color}" % (
        C_ACC, FONT, size + 1, FONT, size - 1, "${color %s}" % C_TEXT, open_n,
        ("  ·  %d done" % done_n) if done_n else "")
    avail = max_lines - 2
    off = 0
    if len(out) > avail:
        try:
            off = int(open(STATE).read())
        except (OSError, ValueError):
            pass
        off = max(0, min(off, len(out) - (avail - 1)))
        top = 1 if off > 0 else 0
        bottom = 1 if off + avail - top < len(out) else 0
        view = out[off:off + avail - top - bottom]
        note = "${color %s}${font %s:regular:size=%d}" % (C_DIM, FONT, size - 1)
        if top:
            view.insert(0, note + "\uf0d8  \u2026 %d more above \u2026" % off)
        if bottom:
            below = len(out) - (off + avail - top - bottom)
            view.append(note + "\uf0d7  \u2026 %d more below \u2026" % below)
        out = view
    elif os.path.exists(STATE):
        os.remove(STATE)
    sys.stdout.write(head + "\n${voffset 4}\n" + "\n".join(out) + "\n")


# ---------------------------------------------------------------- actions
def rofi(prompt, entries=None, extra=()):
    cmd = ["rofi", "-theme", ROFI_THEME, "-dmenu", "-i", "-p", prompt, *extra]
    r = subprocess.run(cmd, input="\n".join(entries or []), capture_output=True, text=True)
    return r.returncode, r.stdout.rstrip("\n")


def resolve_dates(text):
    today = dt.date.today()
    days = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]

    def sub(m):
        w = m.group(1).lower()
        if w == "today":
            d = today
        elif w in ("tomorrow", "tom"):
            d = today + dt.timedelta(days=1)
        else:
            idx = days.index(w[:3])
            d = today + dt.timedelta(days=(idx - today.weekday() - 1) % 7 + 1)
        return "@" + d.isoformat()

    pat = r"@(today|tomorrow|tom|mon|tue|wed|thu|fri|sat|sun)[a-z]*\b"
    return re.sub(pat, sub, text, flags=re.I)


def cmd_add():
    code, text = rofi("add", extra=["-lines", "0"])
    text = text.strip()
    if code != 0 or not text:
        return
    text = resolve_dates(text)
    if not text.startswith(("-", "#", ">", "*")):
        text = "- [ ] " + text
    lines = read_lines()
    while lines and not lines[-1].strip():
        lines.pop()
    lines += [text, ""]
    write_lines(lines)


def cmd_toggle():
    lines = read_lines()
    idx = [n for n, l in enumerate(lines) if TASK.match(l)]
    if not idx:
        return
    entries = []
    for n in idx:
        _, mark, txt = TASK.match(lines[n]).groups()
        entries.append(("%s  %s" % (GLYPH_DONE if mark in "xX" else GLYPH_OPEN, txt)))
    code, sel = rofi("tick", entries, extra=["-format", "i"])
    if code != 0 or not sel.isdigit():
        return
    n = idx[int(sel)]
    m = TASK.match(lines[n])
    new = " " if m.group(2) in "xX" else "x"
    lines[n] = re.sub(r"\[[ xX]\]", "[%s]" % new, lines[n], count=1)
    write_lines(lines)


def cmd_edit():
    ensure_file()
    os.execvp("mousepad", ["mousepad", NOTES])


def cmd_scroll(delta):
    try:
        cur = int(open(STATE).read())
    except (OSError, ValueError):
        cur = 0
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write(str(max(0, cur + delta)))  # render() clamps the upper end


def sh(*cmd):
    return subprocess.run(cmd, capture_output=True, text=True).stdout


def cmd_watch():
    """Click the widget (when nothing covers it) to edit; wheel over it to scroll."""
    geo, stamp = None, 0.0

    def widget():
        nonlocal geo, stamp
        if geo is None or time.time() - stamp > 5:
            wid = sh("xdotool", "search", "--class", "ConkyNotes").split()
            g = {}
            if wid:
                for line in sh("xdotool", "getwindowgeometry", "--shell", wid[0]).split():
                    k, _, v = line.partition("=")
                    g[k] = int(v) if v.lstrip("-").isdigit() else v
            geo = (int(wid[0]), g.get("X", 0), g.get("Y", 0), g.get("WIDTH", 0), g.get("HEIGHT", 0)) if g else (0, 0, 0, 0, 0)
            stamp = time.time()
        return geo

    def over_widget():
        wid, x0, y0, w, h = widget()
        if not wid:
            return False
        m = dict(l.split("=", 1) for l in sh("xdotool", "getmouselocation", "--shell").split())
        x, y = int(m.get("X", -1)), int(m.get("Y", -1))
        if not (x0 <= x < x0 + w and y0 <= y < y0 + h):
            return False
        # only react when the widget itself (not an app window on top of it) is under the pointer
        return int(m.get("WINDOW", 0)) == wid

    proc = subprocess.Popen(["xinput", "test-xi2", "--root"], stdout=subprocess.PIPE, text=True)
    kind, last = "", 0.0
    for line in proc.stdout:
        line = line.strip()
        if line.startswith("EVENT type"):
            kind = line
        elif line.startswith("detail:") and "RawButtonPress" in kind:
            btn = line.split()[1]
            if btn not in ("1", "4", "5") or time.time() - last < 0.04:
                continue
            last = time.time()
            if not over_widget():
                continue
            if btn == "1":
                subprocess.Popen([sys.argv[0], "edit"], start_new_session=True)
            else:
                cmd_scroll(-3 if btn == "4" else 3)


def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    r = sub.add_parser("render")
    r.add_argument("--cols", type=int, default=40)
    r.add_argument("--size", type=int, default=11)
    r.add_argument("--max-lines", type=int, default=24)
    r.add_argument("--hide-done", action="store_true")
    for name in ("add", "toggle", "edit", "watch"):
        sub.add_parser(name)
    sub.add_parser("scroll").add_argument("n", type=int)
    a = ap.parse_args()
    if a.cmd == "render":
        render(a.cols, a.size, a.max_lines, a.hide_done)
    else:
        if a.cmd == "scroll":
            cmd_scroll(a.n)
        else:
            {"add": cmd_add, "toggle": cmd_toggle, "edit": cmd_edit, "watch": cmd_watch}[a.cmd]()


if __name__ == "__main__":
    main()
