# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
"""Single source of truth for the shortcuts shown in the manual, the cheatsheet and the interactive page.

`python3 scripts/docs/build.py --check` parses dot/.config/sxhkd/sxhkdrc and dot/.tmux.conf and reports every
hotkey that is bound there but missing here (or listed here but no longer bound), so the docs cannot silently drift.
Keys are written the way sxhkd reads them: Super is `super`, a capital letter in sxhkdrc means Shift+letter.
"""

# (section, [ (keys, what it does) ... ])  ---- sxhkd (the desktop). "super" = the Windows key.
SXHKD = [
 ("Apps and menus", [
  ("super+Return", "Terminal attached to the tmux session (created if missing)"),
  ("super+shift+Return", "Plain terminal, no tmux"),
  ("super+d", "App menu (jgmenu)"),
  ("super+r", "Full-screen launcher (rofi); press again to close"),
  ("super+shift+g", "Chromium"),
  ("super+shift+f", "Firefox"),
  ("super+shift+b", "Brave browser"),
  ("super+shift+c", "Caido"),
  ("super+n", "Desktop notes: edit"),
  ("super+shift+n", "Desktop notes: quick-add a todo"),
  ("super+ctrl+n", "Desktop notes: tick a task"),
  ("super+Tab", "Window overview (skippy-xd paging)"),
  ("alt+Tab", "Window switcher: hold Alt, Tab cycles, release to focus"),
  ("alt+shift+Tab", "Window switcher, backwards"),
 ]),
 ("Desktop, power and system", [
  ("super+x", "Lock the screen"),
  ("super+ctrl+u", "Switch mode live: cockpit <-> undercover"),
  ("super+ctrl+s", "Server mode on/off (keep running with the lid closed)"),
  ("super+Escape", "Restart bspwm (re-reads bspwmrc, applies the mode)"),
  ("alt+shift+Escape", "Reload sxhkd (this file)"),
  ("super+alt+Escape", "Quit bspwm (log out)"),
  ("super+shift+Escape", "Restart the D-Bus daemon and bspwm (last resort)"),
  ("super+p", "Toggle focus-follows-pointer"),
  ("super+e", "Toggle touchpad"),
  ("super+shift+e", "Un-freeze a stuck touchpad"),
  ("Print", "Screenshot, region (flameshot)"),
  ("super+shift+s", "Screenshot, region (flameshot)"),
  ("ctrl+Print", "Screenshot, region copied to the clipboard"),
  ("super+shift+w", "Screenshot, whole screen saved to ~/Pictures"),
  ("XF86AudioRaiseVolume", "Volume up"),
  ("XF86AudioLowerVolume", "Volume down"),
  ("XF86AudioMute", "Mute"),
  ("XF86AudioMicMute", "Microphone mute"),
  ("XF86MonBrightnessUp", "Brightness +3%"),
  ("XF86MonBrightnessDown", "Brightness -3%"),
 ]),
 ("Windows (bspwm)", [
  ("super+q", "Close the focused window"),
  ("super+m", "Toggle tiled / monocle layout (one window full size)"),
  ("super+t", "Tiled"),
  ("super+shift+t", "Pseudo-tiled"),
  ("super+f", "Fullscreen"),
  ("super+s", "Floating (toggle)"),
  ("super+shift+o", "Float / un-float all windows"),
  ("super+ctrl+x", "Lock the window against closing"),
  ("super+ctrl+y", "Sticky (follows you across desktops)"),
  ("super+ctrl+z", "Private"),
  ("super+g", "Swap with the biggest window"),
  ("super+y", "Send to the last manual window / pull the last leaf"),
  ("super+shift+r", "Rotate the whole layout 90 degrees"),
  ("super+h", "Focus window to the left"), ("super+j", "Focus window below"),
  ("super+k", "Focus window above"), ("super+l", "Focus window to the right"),
  ("super+shift+h", "Move window left (swap)"), ("super+shift+j", "Move window down (swap)"),
  ("super+shift+k", "Move window up (swap)"), ("super+shift+l", "Move window right (swap)"),
  ("super+b", "Focus the sibling (brother) node"),
  ("super+comma", "Focus the first child"), ("super+period", "Focus the second child"),
  ("super+c", "Focus next window on this desktop"),
  ("super+o", "Focus the older window in the focus history"),
  ("super+i", "Focus the newer window in the focus history"),
 ]),
 ("Desktops", [
  ("super+1..9,0", "Go to desktop 1-9 and 10 (the 0 key)"),
  ("super+shift+1..9,0", "Send the window there and follow it"),
  ("super+Left", "Previous desktop"), ("super+Right", "Next desktop"),
  ("super+alt+Left", "Send window to the previous desktop"), ("super+alt+Right", "Send window to the next desktop"),
  ("super+bracketleft", "Previous desktop (same monitor)"), ("super+bracketright", "Next desktop (same monitor)"),
 ]),
 ("Resize, preselect, mouse", [
  ("super+alt+h", "Grow the window to the left"), ("super+alt+j", "Grow it downwards"),
  ("super+alt+k", "Grow it upwards"), ("super+alt+l", "Grow it to the right"),
  ("super+alt+shift+h", "Shrink from the right"), ("super+alt+shift+j", "Shrink from the top"),
  ("super+alt+shift+k", "Shrink from the bottom"), ("super+alt+shift+l", "Shrink from the left"),
  ("super+shift+Left", "Move a floating window left"), ("super+shift+Down", "Move a floating window down"),
  ("super+shift+Up", "Move a floating window up"), ("super+shift+Right", "Move a floating window right"),
  ("super+ctrl+h", "Preselect: next window opens to the left"), ("super+ctrl+j", "Preselect: below"),
  ("super+ctrl+k", "Preselect: above"), ("super+ctrl+l", "Preselect: to the right"),
  ("super+ctrl+1..9", "Preselect the split ratio 0.1 .. 0.9"),
  ("super+ctrl+space", "Cancel the preselection of this window"),
  ("super+ctrl+shift+space", "Cancel all preselections on this desktop"),
  ("super+left-drag", "Move a window with the mouse"),
  ("super+right-drag", "Resize a window by the nearest corner"),
 ]),
]

# tmux. Prefix is the default Ctrl+b; "M-" = Alt (no prefix needed).
TMUX = [
 ("Without the prefix (Alt)", [
  ("alt+t", "New window (same folder)"), ("alt+1..9", "Go to window 1-9"),
  ("alt+Left", "Previous window"), ("alt+Right", "Next window"),
  ("alt+{", "Move the window left in the list"), ("alt+}", "Move the window right in the list"),
  ("alt+e", "Rename the window"), ("alt+q", "Kill the window (asks first)"),
  ("alt+|", "Split side by side"), ("alt+-", "Split top / bottom"),
  ("alt+h", "Pane left"), ("alt+j", "Pane down"), ("alt+k", "Pane up"), ("alt+l", "Pane right"),
  ("alt+shift+h", "Resize pane left (5)"), ("alt+shift+j", "Resize pane down"),
  ("alt+shift+k", "Resize pane up"), ("alt+shift+l", "Resize pane right"),
  ("alt+,", "Swap pane up"), ("alt+.", "Swap pane down"),
  ("alt+z", "Zoom / unzoom the pane"), ("alt+o", "Zoom / unzoom the pane"),
  ("alt+x", "Kill the pane (asks first)"), ("alt+w", "Kill the pane (asks first)"), ("alt+shift+w", "Kill the pane, no question"),
  ("alt+space", "Next pane layout"), ("alt+v", "Scroll / copy mode"),
  ("alt+m", "Mouse mode on/off (on by default)"), ("alt+r", "Reload ~/.tmux.conf"),
 ]),
 ("After the prefix (Ctrl+b, then the key)", [
  ("prefix+t", "New window"), ("prefix+w", "Pick a window from a tree (and kill with the confirm prompt)"),
  ("prefix+s", "Pick a session from a tree"), ("prefix+S", "New session (asks for a name)"),
  ("prefix+d", "Detach (the session keeps running)"),
  ("prefix+|", "Split side by side"), ("prefix+-", "Split top / bottom"), ("prefix+b", "Break the pane out into its own window"),
  ("prefix+Escape", "Scroll / copy mode"), ("prefix+p", "Paste buffer"), ("prefix+P", "Choose a paste buffer"),
  ("prefix+r", "Reload ~/.tmux.conf"), ("prefix+T", "Clock"), ("prefix+C-l", "Clear screen and history"),
  ("prefix+C-s", "Show / hide the status bar"), ("prefix+C-b", "Send Ctrl+b to the program inside"),
 ]),
 ("Scroll / copy mode (vim keys)", [
  ("v", "Start selecting"), ("y", "Copy to the clipboard (stay in copy mode)"), ("Y", "Copy and leave"),
  ("r", "Rectangle selection"), ("/", "Search forward"), ("?", "Search backward"),
  ("b / w / e", "Word back / forward / end"), ("q", "Leave copy mode"),
 ]),
]

ZSH = [
 ("Ctrl+F", "Fuzzy-find any file and paste its path (exact, case-insensitive; 'word' quotes whole words)"),
 ("Tab / Shift+Tab", "Cycle the completion menu forward / back"),
 ("Left / Right", "Move the text cursor (closes the menu)"),
 ("Ctrl+Left / Right", "Jump a word"), ("Ctrl+Delete", "Delete the next word"),
 ("PageUp / PageDown", "Start / end of history"),
]

# Mouse actions on the polybar (number = the symbol number in the manual).
BAR = [
 ("1", "Kali logo", "App launcher", "click: full-screen launcher; click again to close"),
 ("2", "Ten dots", "Desktops 1-9, 0", "click a dot to go there"),
 ("3", "Terminal", "Terminal", "left: terminal + tmux session; right: plain terminal"),
 ("4", "Globe", "Browser (Brave)", "left: open Brave"),
 ("5", "Folder", "File manager (Thunar)", "left: home; right: Downloads"),
 ("6", "Chip", "CPU load", "display only"),
 ("7", "Memory", "RAM in use", "display only"),
 ("8", "Disk", "Root disk fullness", "display only"),
 ("9", "Thermometer", "CPU temperature", "display only"),
 ("10", "Keyboard", "Modifier keys (shows Super/Ctrl/Alt/Shift while held)", "display only"),
 ("11", "Date and time", "Clock", "click: calendar dropdown"),
 ("12", "Link icon", "LHOST: your address for lab work", "left: pick an interface or type an IP; right/double click: copy"),
 ("13", "Crosshair", "RHOST: the target address", "left: set/edit; right/double click: copy"),
 ("-", "󰳓 / bell / 󱁣", "Claude Code status, shown only while a session is active (not in the picture)", "click: clear finished sessions"),
 ("14", "Server rack", "Server mode (lid closed = keep running)", "click: toggle"),
 ("15", "Mask", "Mode switch cockpit <-> undercover", "click: switch"),
 ("16", "Speaker", "Volume", "scroll: volume; red speaker = muted"),
 ("17", "Sun / gear", "Brightness", "scroll: brightness"),
 ("18", "Battery", "All batteries combined", "click: details notification"),
 ("19", "Microphone", "Mic mute", "click: mute/unmute (red lit = live)"),
 ("20", "Tray", "Network applet, clipboard manager, app icons", "per app"),
 ("21", "Power symbol", "Power menu", "click: Lock, Sleep, Hibernate, Logout, Restart, Shutdown"),
]

# ---- parsing for --check ---------------------------------------------------------------------------------
import re, itertools, os

def _expand_braces(s):
    m = re.search(r'\{([^{}]*)\}', s)
    if not m:
        return [s]
    out = []
    for alt in m.group(1).split(','):
        out += _expand_braces(s[:m.start()] + alt + s[m.end():])
    return out

def _alts(part):
    """expand one brace group's items, handling ranges like 1-9 and the '_' empty item"""
    items = []
    for a in part.split(','):
        a = a.strip()
        mm = re.fullmatch(r'(\d)-(\d)', a)
        if mm:
            items += [str(i) for i in range(int(mm.group(1)), int(mm.group(2)) + 1)]
        else:
            items.append('' if a == '_' else a)
    return items

def _expand(s):
    m = re.search(r'\{([^{}]*)\}', s)
    if not m:
        return [s]
    out = []
    for alt in _alts(m.group(1)):
        out += _expand(s[:m.start()] + alt + s[m.end():])
    return out

def _norm(combo):
    toks = [t.strip() for t in re.split(r'\s*\+\s*', combo.strip()) if t.strip() != '']
    mods = {'super', 'alt', 'ctrl', 'shift', 'mod4', 'mod1'}
    mods_l = [t.lower() for t in toks[:-1]]
    key = toks[-1]
    if len(key) == 1 and key.isupper():           # sxhkd: a capital letter implies Shift
        mods_l.append('shift'); key = key.lower()
    mods_l = ['super' if m == 'mod4' else 'alt' if m == 'mod1' else m for m in mods_l]
    order = ['super', 'ctrl', 'alt', 'shift']
    mods_l = sorted(set(mods_l), key=order.index)
    return '+'.join(mods_l + [key.lower() if len(key) > 1 and key[0] != 'X' else key])

def parse_sxhkd(path):
    keys = []
    for line in open(path):
        if not line.strip() or line[0] in ' \t#':
            continue
        for part in _expand(line.strip()):
            keys.append(_norm(part))
    return keys

def parse_tmux(path):
    keys = []
    for line in open(path):
        line = line.strip()
        m = re.match(r'bind(?:-key)?\s+(-n\s+)?(?:-T\s+(\S+)\s+)?(?:"([^"]+)"|\'([^\']+)\'|(\S+))', line)
        if not m or line.startswith('#'):
            continue
        root, table, a, b, c = m.groups()
        key = a or b or c
        if table:  # copy-mode-vi: not checked
            continue
        if root:
            key = re.sub(r'^M-(.)$', lambda mm: 'alt+' + (('shift+' + mm.group(1).lower()) if mm.group(1).isupper() and mm.group(1).isalpha() else mm.group(1)), key)
            key = key.replace('M-Left', 'alt+Left').replace('M-Right', 'alt+Right').replace('M-space', 'alt+space')
        else:
            key = 'prefix+' + key
        keys.append(key)
    return keys

def doc_sxhkd_keys():
    out = set()
    for _, rows in SXHKD:
        for k, _ in rows:
            if '..' in k:
                base = k.split('..')[0]
                pre = base[:-1]
                lo, hi = base[-1], k.split('..')[1].split(',')[0]
                if k.endswith(',0'):
                    out |= {pre + str(i) for i in range(int(lo), int(hi) + 1)} | {pre + '0'}
                else:
                    out |= {pre + str(i) for i in range(int(lo), int(hi) + 1)}
            else:
                out.add(k)
    return out
