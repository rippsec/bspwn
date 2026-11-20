#!/usr/bin/env python3
"""Keyboard backlight idle-off, like a modern laptop: the light turns off after a while without
typing / touchpad use and comes back on the first key or touch. Stays off while the lid is closed.

Works on any laptop that exposes /sys/class/leds/*kbd_backlight* (ThinkPad tpacpi::kbd_backlight,
Dell dell::kbd_backlight, ...). Silent no-op elsewhere. Timeouts are in power.conf
(KBD_IDLE_AC / KBD_IDLE_BAT seconds, KBD_AUTO=0 disables). No root needed: the LED is set through logind.

  kbd-backlight.py          run the daemon (started from bspwm/start; single instance)
"""
import signal
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import powerlib as pl  # noqa: E402

WAKE_MS = 700            # input newer than this counts as "someone is typing"
POLL_LIT = 1.0           # seconds between checks while the light is on
POLL_DIM = 0.2           # ... while it is off (so the first keypress lights it quickly)


class Kbd:
    """Decision logic only (no I/O): feed it observations, it returns the LED level to set or None."""

    def __init__(self):
        self.dimmed = False
        self.saved = 0

    def step(self, cur, idle_ms, timeout_s, lid_closed):
        if not self.dimmed:
            if cur > 0 and (lid_closed or (idle_ms is not None and idle_ms >= timeout_s * 1000)):
                self.saved, self.dimmed = cur, True
                return 0
            return None
        # dimmed by us
        if cur > 0:                       # the user changed it (e.g. Fn+Space): that is their choice now
            self.dimmed = False
            return None
        if not lid_closed and idle_ms is not None and idle_ms < WAKE_MS:
            self.dimmed = False
            return self.saved
        return None


def main():
    c = pl.conf()
    if c["KBD_AUTO"] == "0":
        return 0
    led = pl.kbd_led()
    if not led:
        return 0                          # no keyboard backlight on this machine
    lock = pl.single_instance("bspwn-kbd-backlight")
    if lock is None:
        return 0
    idle, kbd = pl.XIdle(), Kbd()
    timeout, refreshed = 30, 0.0
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))      # so `finally` runs when the daemon is stopped
    try:
        while True:
            if time.monotonic() - refreshed > 5:          # config / AC state change rarely: read them every 5 s
                c = pl.conf()
                timeout = int(c["KBD_IDLE_AC"] if pl.ac_online() else c["KBD_IDLE_BAT"])
                refreshed = time.monotonic()
            level = kbd.step(pl.led_get(led), idle.ms(), timeout, pl.lid_closed())
            if level is not None:
                pl.led_set(led, min(level, pl.led_max(led)))
            time.sleep(POLL_DIM if kbd.dimmed else POLL_LIT)
    finally:
        if kbd.dimmed and pl.led_get(led) == 0:           # never leave the keyboard dark because we stopped
            pl.led_set(led, kbd.saved)


if __name__ == "__main__":
    sys.exit(main())
