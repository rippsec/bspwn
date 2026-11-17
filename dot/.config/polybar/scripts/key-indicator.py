#!/usr/bin/env python3
"""Polybar keyboard indicator — a fixed strip of 'key caps'.

  ⇪ ⇧ ⌃ ⌥ ❖   (Caps Lock, Shift, Ctrl, Alt, Super)

All five are always there in a barely-visible grey, so the bar never shifts.
  * a held modifier lights up white with an underline (like a lit key)
  * Caps Lock (latched) lights up with a line above AND below ("engaged")
  * combos show every key involved (e.g. Super+Shift lights both)

Caps Lock state comes from the keyboard LED in sysfs (no `xset` per keypress),
and a line is printed only when the state actually changes.
"""
import glob
import sys

from pynput import keyboard

OFF = "#2e3036"        # resting key: almost invisible on the bar background
ON = "#f2efe9"         # lit key
LINE = "#f2efe9"       # underline / overline colour

SLOTS = [  # (name, glyph)
    ("caps", "\U000f030e"),   # 󰌎
    ("shift", "\U000f0636"),  # 󰘶
    ("ctrl", "\U000f0634"),   # 󰘴
    ("alt", "\U000f0635"),    # 󰘵
    ("super", "\U000f0633"),  # 󰘳
]

KEYMAP = {
    keyboard.Key.shift: "shift", keyboard.Key.shift_l: "shift", keyboard.Key.shift_r: "shift",
    keyboard.Key.ctrl: "ctrl", keyboard.Key.ctrl_l: "ctrl", keyboard.Key.ctrl_r: "ctrl",
    keyboard.Key.alt: "alt", keyboard.Key.alt_l: "alt", keyboard.Key.alt_r: "alt", keyboard.Key.alt_gr: "alt",
    keyboard.Key.cmd: "super", keyboard.Key.cmd_l: "super", keyboard.Key.cmd_r: "super",
}

CAPS_LEDS = glob.glob("/sys/class/leds/*capslock*/brightness")
held = set()
last = None


def caps_on():
    for path in CAPS_LEDS:
        try:
            with open(path) as f:
                if f.read().strip() not in ("", "0"):
                    return True
        except OSError:
            pass
    return False


def render():
    global last
    state = set(held)
    if caps_on():
        state.add("caps")
    key = frozenset(state)
    if key == last:
        return
    last = key
    parts = []
    for name, glyph in SLOTS:
        if name in state:
            deco = "%{+o}%{+u}" if name == "caps" else "%{+u}"
            undeco = "%{-o}%{-u}" if name == "caps" else "%{-u}"
            parts.append(f"%{{u{LINE}}}%{{o{LINE}}}{deco}%{{F{ON}}} {glyph} %{{F-}}{undeco}")
        else:
            parts.append(f"%{{F{OFF}}} {glyph} %{{F-}}")
    sys.stdout.write("".join(parts) + "\n")
    sys.stdout.flush()


def on_press(k):
    name = KEYMAP.get(k)
    if name:
        held.add(name)
    render()           # also re-checks Caps Lock (LED toggles on press)


def on_release(k):
    held.discard(KEYMAP.get(k))
    render()


render()
with keyboard.Listener(on_press=on_press, on_release=on_release) as listener:
    listener.join()
