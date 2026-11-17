#!/usr/bin/env python3
"""Calendar dropdown under the polybar clock (cockpit style).

- current month with ISO week numbers; days of the neighbouring months dimmed
- today shown inverted (white square, dark bold number)
- mouse wheel or the ‹ › arrows change month; click the title to jump back
  to today; keys: ←/→ (or h/l) month, ↑/↓ year, t/Home today, Esc close
- click anywhere outside (or on the clock again) closes it

Runs as a single instance: launching it while open closes it (toggle).
"""
import calendar
import datetime as dt
import os
import signal
import sys

import gi

gi.require_version("Gtk", "3.0")
gi.require_version("Gdk", "3.0")
from gi.repository import Gdk, GLib, Gtk  # noqa: E402

PIDFILE = os.path.join(os.environ.get("XDG_RUNTIME_DIR", "/tmp"), "polybar-calendar.pid")
BAR_BOTTOM = 34          # polybar islands: offset 6 + height 28
GAP = 4

CSS = b"""
* { font-family: "Atkinson Hyperlegible Mono"; font-size: 12pt; }
window { background-color: #111214; border-bottom: 2px solid #f2efe9; }
.header { padding: 10px 10px 6px 10px; }
.title { color: #f2efe9; font-weight: bold; letter-spacing: 2px; }
.arrow { color: #8e9099; padding: 0 8px; }
.arrow:hover, .title:hover { color: #ffffff; }
.head { color: #6f7178; font-size: 9pt; font-weight: bold; }
.wk   { color: #4b4d55; font-size: 9pt; }
.day  { color: #e6e3dd; }
.weekend { color: #8e9099; }
.other { color: #34363c; }
.today { background-color: #f2efe9; color: #111214; font-weight: bold; }
.cell { min-width: 34px; min-height: 26px; }
.grid { padding: 0 10px 12px 10px; }
"""


def toggle_existing():
    """If another instance is open, close it and report True."""
    try:
        with open(PIDFILE) as f:
            pid = int(f.read().strip())
        os.kill(pid, signal.SIGTERM)
        return True
    except (OSError, ValueError):
        return False


class CalendarPopup(Gtk.Window):
    def __init__(self):
        super().__init__(type=Gtk.WindowType.POPUP)   # override-redirect: not tiled by bspwm
        self.set_wmclass("cockpit-calendar", "Cockpit-calendar")
        today = dt.date.today()
        self.today = today
        self.year, self.month = today.year, today.month

        provider = Gtk.CssProvider()
        provider.load_from_data(CSS)
        Gtk.StyleContext.add_provider_for_screen(Gdk.Screen.get_default(), provider,
                                                 Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION)

        self.box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL)
        self.add(self.box)

        header = Gtk.Box(spacing=0)
        header.get_style_context().add_class("header")
        self.prev_btn = self._clickable("‹", "arrow", lambda *_: self.shift(-1))
        self.next_btn = self._clickable("›", "arrow", lambda *_: self.shift(+1))
        self.title = self._clickable("", "title", lambda *_: self.go_today())
        header.pack_start(self.prev_btn, False, False, 0)
        header.set_center_widget(self.title)
        header.pack_end(self.next_btn, False, False, 0)
        self.box.pack_start(header, False, False, 0)

        self.grid = Gtk.Grid(column_homogeneous=True, row_spacing=2, column_spacing=2)
        self.grid.get_style_context().add_class("grid")
        self.box.pack_start(self.grid, False, False, 0)

        self.add_events(Gdk.EventMask.SCROLL_MASK | Gdk.EventMask.SMOOTH_SCROLL_MASK |
                        Gdk.EventMask.BUTTON_PRESS_MASK | Gdk.EventMask.KEY_PRESS_MASK)
        self.connect("scroll-event", self.on_scroll)
        self.connect("button-press-event", self.on_button)
        self.connect("key-press-event", self.on_key)
        self.connect("map-event", self.on_map)
        self.connect("destroy", self.quit)

        self.render()

    # ---------------------------------------------------------------- widgets
    def _clickable(self, text, cls, cb):
        ev = Gtk.EventBox()
        lbl = Gtk.Label(label=text)
        lbl.get_style_context().add_class(cls)
        ev.add(lbl)
        ev.connect("button-press-event", cb)
        ev.label = lbl
        return ev

    def _cell(self, text, *classes):
        lbl = Gtk.Label(label=text)
        ctx = lbl.get_style_context()
        ctx.add_class("cell")
        for c in classes:
            ctx.add_class(c)
        return lbl

    def render(self):
        for child in self.grid.get_children():
            self.grid.remove(child)
        self.title.label.set_text(f"{calendar.month_name[self.month].upper()}  {self.year}")

        for col, name in enumerate(["WK", "MO", "TU", "WE", "TH", "FR", "SA", "SU"]):
            self.grid.attach(self._cell(name, "head"), col, 0, 1, 1)

        cal = calendar.Calendar(firstweekday=0)
        weeks = cal.monthdatescalendar(self.year, self.month)
        while len(weeks) < 6:                       # constant height: always 6 rows
            last = weeks[-1][-1]
            weeks.append([last + dt.timedelta(days=i) for i in range(1, 8)])
        for row, week in enumerate(weeks, start=1):
            self.grid.attach(self._cell(f"{week[0].isocalendar()[1]:02d}", "wk"), 0, row, 1, 1)
            for col, day in enumerate(week, start=1):
                classes = ["day"]
                if day.month != self.month:
                    classes = ["other"]
                elif day == self.today:
                    classes = ["today"]
                elif col >= 6:
                    classes = ["day", "weekend"]
                self.grid.attach(self._cell(str(day.day), *classes), col, row, 1, 1)
        self.grid.show_all()

    # ---------------------------------------------------------------- navigation
    def shift(self, months):
        m = self.month - 1 + months
        self.year += m // 12
        self.month = m % 12 + 1
        self.render()
        return True

    def go_today(self):
        self.year, self.month = self.today.year, self.today.month
        self.render()
        return True

    def on_scroll(self, _w, ev):
        if ev.direction == Gdk.ScrollDirection.UP:
            self.shift(-1)
        elif ev.direction == Gdk.ScrollDirection.DOWN:
            self.shift(+1)
        elif ev.direction == Gdk.ScrollDirection.SMOOTH:
            ok, _dx, dy = ev.get_scroll_deltas()
            if ok and abs(dy) >= 0.5:
                self.shift(+1 if dy > 0 else -1)
        return True

    def on_key(self, _w, ev):
        k = Gdk.keyval_name(ev.keyval)
        if k in ("Escape", "q"):
            self.destroy()
        elif k in ("Left", "h", "Page_Up"):
            self.shift(-1)
        elif k in ("Right", "l", "Page_Down"):
            self.shift(+1)
        elif k in ("Up", "k"):
            self.shift(-12)
        elif k in ("Down", "j"):
            self.shift(+12)
        elif k in ("t", "Home"):
            self.go_today()
        return True

    def on_button(self, _w, ev):
        # with the grab, clicks outside the popup arrive here too: close
        alloc = self.get_allocation()
        if not (0 <= ev.x <= alloc.width and 0 <= ev.y <= alloc.height):
            self.destroy()
        return False

    # ---------------------------------------------------------------- window
    def on_map(self, *_):
        # position: centred under the clock (centre of the screen), below the bar
        w, _h = self.get_size()
        mon = Gdk.Display.get_default().get_primary_monitor() or \
            Gdk.Display.get_default().get_monitor(0)
        geo = mon.get_geometry()
        self.move(geo.x + geo.width // 2 - w // 2, geo.y + BAR_BOTTOM + GAP)
        # grab pointer + keyboard like a menu (click outside closes, keys work)
        GLib.timeout_add(30, self.grab)
        return False

    def grab(self):
        seat = Gdk.Display.get_default().get_default_seat()
        status = seat.grab(self.get_window(), Gdk.SeatCapabilities.ALL, True, None, None, None, None)
        if status != Gdk.GrabStatus.SUCCESS:
            GLib.timeout_add(50, self.grab)       # bar still holds the click: retry
        return False

    def quit(self, *_):
        try:
            os.remove(PIDFILE)
        except OSError:
            pass
        Gtk.main_quit()


def main():
    if toggle_existing():
        return
    with open(PIDFILE, "w") as f:
        f.write(str(os.getpid()))
    win = CalendarPopup()
    GLib.unix_signal_add(GLib.PRIORITY_DEFAULT, signal.SIGTERM, lambda *_: (win.destroy(), False)[1])
    win.show_all()
    Gtk.main()


if __name__ == "__main__":
    sys.exit(main())
