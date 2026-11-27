#!/usr/bin/env python3
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
"""Double window borders for bspwm: a thin outer line plus an inner band that reads as an inner gap.

bspwm paints each border with one solid colour. X11 also accepts a border *pixmap*, so this helper
repaints the border of every visible window as two bands:

    outer  OUTER px          focused / unfocused colour (the frame)
    inner  border - OUTER    GAP colour (terminal background, looks like padding)

bspwm's border_width is the total (cockpit: 9 = 1 px line + 8 px gap). bspwm resets a border to a
plain colour whenever it redraws it (focus changes, layout), so the helper listens to
`bspc subscribe` and repaints after each burst of events.

Cheap by design:
  - idle = blocked on the event pipe (0 % CPU); no timers, no polling
  - no subprocess per event: the focused window comes from _NET_ACTIVE_WINDOW and bspwm's windows
    from _NET_CLIENT_LIST (one request each); then two small requests per managed window
  - bursts (a mouse resize sends dozens of node_geometry events) are coalesced: after an event it
    waits SETTLE seconds for more, then repaints once
  - windows whose border is <= OUTER (fullscreen, monocle, panels, undercover mode) are skipped

Started and stopped by mode.sh from the profile (INNER_GAP > 0); exits when bspwm or X goes away.
Usage: double-border.py            run
       double-border.py --once     paint once and exit
Env:   DB_FOCUSED (#808080) DB_NORMAL (#55575e) DB_GAP (#22242a) DB_OUTER (1) DB_SETTLE (0.03)
"""
import os
import select
import subprocess
import sys

from Xlib import X, Xatom, display, error

FOCUSED = os.environ.get("DB_FOCUSED", "#808080")
NORMAL = os.environ.get("DB_NORMAL", "#55575e")
GAP = os.environ.get("DB_GAP", "#22242a")
OUTER = int(os.environ.get("DB_OUTER", "1"))
SETTLE = float(os.environ.get("DB_SETTLE", "0.03"))
# events after which bspwm may have redrawn a border or changed a window's size/visibility
EVENTS = ["node_add", "node_remove", "node_focus", "node_activate", "node_geometry", "node_state",
          "node_flag", "node_layer", "node_transfer", "node_swap", "node_presel",
          "desktop_focus", "desktop_layout", "desktop_swap", "desktop_transfer"]

dpy = display.Display()
screen = dpy.screen()
root = screen.root
NET_ACTIVE = dpy.intern_atom("_NET_ACTIVE_WINDOW")
NET_CLIENTS = dpy.intern_atom("_NET_CLIENT_LIST")


def pixel(hexcol):
    rgb = (int(hexcol[i:i + 2], 16) * 257 for i in (1, 3, 5))
    return screen.default_colormap.alloc_color(*rgb).pixel


PX_FOCUSED, PX_NORMAL, PX_GAP = pixel(FOCUSED), pixel(NORMAL), pixel(GAP)


def root_windows(atom):
    p = root.get_full_property(atom, Xatom.WINDOW)
    return list(p.value) if p else []


def paint(win, g, outer_px):
    """The border pixmap is tiled from the window origin (inside the border). With a pixmap of
    (w+2b) x (h+2b): columns w..w+b-1 are the right border, w+b..w+2b-1 the left one (rows alike).
    The outer edges are column w+b-1 (right) and w+b (left), row h+b-1 (bottom) and h+b (top):
    one 2*OUTER px stripe per axis draws all four edges."""
    b, w, h = g.border_width, g.width, g.height
    W, H = w + 2 * b, h + 2 * b
    pm = win.create_pixmap(W, H, g.depth)
    gc = pm.create_gc(foreground=PX_GAP)
    pm.fill_rectangle(gc, 0, 0, W, H)
    gc.change(foreground=outer_px)
    pm.fill_rectangle(gc, w + b - OUTER, 0, 2 * OUTER, H)
    pm.fill_rectangle(gc, 0, h + b - OUTER, W, 2 * OUTER)
    win.change_attributes(border_pixmap=pm)  # the server keeps its own reference
    gc.free()
    pm.free()


def repaint():
    active = root_windows(NET_ACTIVE)
    focused = active[0] if active else 0
    for wid in root_windows(NET_CLIENTS):     # every window bspwm manages, mapped or not
        win = dpy.create_resource_object("window", wid)
        try:
            g = win.get_geometry()
            if g.border_width <= OUTER:          # fullscreen, monocle, undercover: skip
                continue
            if win.get_attributes().map_state != X.IsViewable:
                continue
            paint(win, g, PX_FOCUSED if wid == focused else PX_NORMAL)
        except error.XError:
            pass                                  # window vanished meanwhile
    dpy.flush()


def main():
    repaint()
    if "--once" in sys.argv:
        return
    proc = subprocess.Popen(["bspc", "subscribe", *EVENTS], stdout=subprocess.PIPE)
    fd = proc.stdout.fileno()
    while True:
        select.select([fd], [], [])                      # idle: block until bspwm reports something
        if not os.read(fd, 65536):
            break                                         # bspwm exited / restarted
        while select.select([fd], [], [], SETTLE)[0]:     # coalesce the rest of the burst
            if not os.read(fd, 65536):
                return
        repaint()


if __name__ == "__main__":
    try:
        main()
    except (error.ConnectionClosedError, BrokenPipeError, KeyboardInterrupt):
        pass
