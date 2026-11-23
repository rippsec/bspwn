#!/usr/bin/env python3
"""Keyboard backlight that follows your typing: any keypress lights it (minimal level), and it turns off
KBD_IDLE seconds after the last keypress (default 5). Stays off while the lid is closed.

Keypresses come from XInput raw events (`xinput test-xi2 --root`), so only the keyboard counts, they are seen even
while the lock screen holds the keyboard, and the reaction is immediate (no polling for idle time). Falls back to
X idle time (any input) if xinput is unavailable. Works with any /sys/class/leds/*kbd_backlight* (ThinkPad
tpacpi::kbd_backlight, Dell dell::kbd_backlight, ...); the LED is set through logind, no root needed.

Settings in power.conf: KBD_AUTO, KBD_IDLE_AC, KBD_IDLE_BAT, KBD_LEVEL, KBD_WAKE_POINTER.
If you change the level yourself (Fn+Space) it is respected and counts as activity.

  kbd-backlight.py          run the daemon (started from bspwm/start; single instance)
"""
import os
import select
import signal
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import powerlib as pl  # noqa: E402

WATCH_CMD = ["stdbuf", "-oL", "xinput", "test-xi2", "--root"]
FALLBACK_IDLE_MS = 700       # without xinput: input newer than this counts as typing


def is_activity(chunk, pointer=False):
    """True if an xinput output chunk contains a key press (or, optionally, pointer input)."""
    if "(RawKeyPress)" in chunk:
        return True
    return pointer and ("(RawButtonPress)" in chunk or "(RawMotion)" in chunk)


class Kbd:
    """Decision logic only (no I/O): feed it observations, it returns the LED level to set or None."""

    def __init__(self, now):
        self.last_key = now          # startup grace: the first timeout counts from the daemon start
        self.last_set = None         # level we last asked for (to notice changes made behind our back)
        self.prev = 0                # last non-zero level seen

    def key(self, now):
        self.last_key = now

    def step(self, now, cur, timeout, lid_closed, level):
        if self.last_set is not None and cur != self.last_set:
            self.last_key = now      # changed by someone else (Fn+Space): treat as activity, do not fight it
        if cur > 0:
            self.prev = cur
        if lid_closed:
            want = 0
        elif timeout <= 0 or now - self.last_key < timeout:
            want = cur if cur > 0 else (level or self.prev or 1)   # typing: light it, keep a level the user chose
        else:
            want = 0
        self.last_set = want
        return want if want != cur else None

    def wait(self, now, cur, timeout):
        """How long the loop may block before something needs re-checking (events interrupt it anyway)."""
        if cur > 0 and timeout > 0:
            return max(0.05, min(1.0, self.last_key + timeout - now))
        return 1.0


class KeyWatcher:
    """Persistent `xinput test-xi2 --root`; poll() blocks up to `timeout` and says whether a key was pressed."""

    def __init__(self):
        self.proc, self.retry_at, self.tail = None, 0.0, ""

    def poll(self, timeout, pointer=False):
        """True / False, or None when xinput is unavailable (caller falls back to idle time)."""
        if self.proc is None:
            if time.monotonic() < self.retry_at:
                time.sleep(timeout)
                return None
            try:
                self.proc = subprocess.Popen(WATCH_CMD, stdout=subprocess.PIPE, stderr=subprocess.DEVNULL)
            except OSError:
                self.retry_at = time.monotonic() + 30
                time.sleep(timeout)
                return None
        ready, _, _ = select.select([self.proc.stdout], [], [], timeout)
        if not ready:
            if self.proc.poll() is not None:
                self.proc, self.retry_at = None, time.monotonic() + 5
                return None
            return False
        data = os.read(self.proc.stdout.fileno(), 65536)
        if not data:                                           # xinput died (X restarted?): retry shortly
            self.proc.wait()
            self.proc, self.retry_at = None, time.monotonic() + 5
            return None
        text = self.tail + data.decode("utf-8", "replace")
        self.tail = text.rsplit("\n", 1)[-1]                    # keep only an unfinished last line (a marker may straddle two reads)
        return is_activity(text, pointer)

    def close(self):
        if self.proc is not None:
            self.proc.terminate()
            self.proc = None


def main():
    c = pl.conf()
    if c["KBD_AUTO"] == "0":
        return 0
    led = pl.kbd_led()
    if not led:
        return 0                                               # no keyboard backlight on this machine
    lock = pl.single_instance("bspwn-kbd-backlight")
    if lock is None:
        return 0
    watcher, idle = KeyWatcher(), pl.XIdle()
    kbd = Kbd(time.monotonic())
    kbd.prev = pl.led_get(led)
    timeout, level, pointer, refreshed = 5, 1, False, 0.0
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))      # so `finally` runs when the daemon is stopped
    try:
        while True:
            now = time.monotonic()
            if now - refreshed > 5:                            # config / AC state change rarely: read every 5 s
                c = pl.conf()
                timeout = int(c["KBD_IDLE_AC"] if pl.ac_online() else c["KBD_IDLE_BAT"])
                level = min(int(c["KBD_LEVEL"]), pl.led_max(led))
                pointer = c["KBD_WAKE_POINTER"] == "1"
                refreshed = now
            cur = pl.led_get(led)
            activity = watcher.poll(kbd.wait(now, cur, timeout), pointer)
            if activity is None:                               # no xinput: use X idle time instead
                ms = idle.ms()
                activity = ms is not None and ms < FALLBACK_IDLE_MS
            now = time.monotonic()
            if activity:
                kbd.key(now)
            new = kbd.step(now, pl.led_get(led), timeout, pl.lid_closed(), level)
            if new is not None:
                pl.led_set(led, min(new, pl.led_max(led)))
    finally:
        watcher.close()
        if pl.led_get(led) == 0 and kbd.prev > 0:              # stopping the daemon gives the keyboard its light back
            pl.led_set(led, kbd.prev)


if __name__ == "__main__":
    sys.exit(main())
