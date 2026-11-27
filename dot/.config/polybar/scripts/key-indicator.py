#!/usr/bin/env python3
"""Polybar keyboard indicator: ONE key-cap slot, one icon at a time.

  idle:               a dim keyboard glyph
  modifier(s) held:   ONE glyph, lit, with a line above AND below. With several keys held at
                      once only the highest-priority one shows: super > ctrl > alt > shift > caps
  Caps Lock latched:  shows the caps glyph (same lit + over/underline) when nothing else is held

Caps Lock state comes from the keyboard LED in sysfs (no `xset` per keypress),
and a line is printed only when what is shown actually changes.
"""
import glob
import sys

from pynput import keyboard

OFF = "#4b4d55"        # idle keyboard glyph (dim)
IDLE = "\U000f030c"    # 󰌌 keyboard
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
last = "?"            # sentinel: forces the first render


def caps_on():
    for path in CAPS_LEDS:
        try:
            with open(path) as f:
                if f.read().strip() not in ("", "0"):
                    return True
        except OSError:
            pass
    return False


PRIORITY = ["super", "ctrl", "alt", "shift", "caps"]
GLYPH = dict(SLOTS)


def render():
    global last
    state = set(held)
    if caps_on():
        state.add("caps")
    top = next((n for n in PRIORITY if n in state), None)   # the single key we show
    if top == last:
        return
    last = top
    if top is None:
        out = f"%{{F{OFF}}} {IDLE} %{{F-}}"
    else:
        out = f"%{{u{LINE}}}%{{o{LINE}}}%{{+o}}%{{+u}}%{{F{ON}}} {GLYPH[top]} %{{F-}}%{{-o}}%{{-u}}"
    sys.stdout.write(out + "\n")
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
