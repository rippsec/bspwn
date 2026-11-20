#!/usr/bin/env python3
"""Server mode: keep the laptop running with the lid closed (remote control, ssh, ftp, ...).

While ON, closing the lid does NOT suspend. The screen locks and goes dark, the keyboard backlight turns
off, and everything else keeps running. It ends by itself (and the laptop then does the normal thing,
i.e. suspends if the lid is closed) when:
  * on battery and the charge drops below SERVER_BATTERY_MIN (power.conf; auto = 20% with a slice/second
    battery, 55% on a single-battery laptop), or
  * the machine gets hotter than SERVER_TEMP_MAX (a closed lid in a bag is a heat risk).
On AC it runs until you turn it off. State lives in $XDG_RUNTIME_DIR, so it is OFF again after a reboot/logout.

How: the daemon holds a logind "handle-lid-switch" inhibitor lock (an open file descriptor). If the daemon
ever dies the kernel closes it and the lid works normally again, so a crash can never keep a laptop awake.

  servermode.py on | off | toggle     change state (starts the daemon if needed)
  servermode.py status                human readable state
  servermode.py bar [--follow]        polybar output (--follow prints on every change, for `tail = true`)
  servermode.py daemon                the watcher (started from bspwm/start; single instance)
"""
import json
import os
import shutil
import signal
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import powerlib as pl  # noqa: E402

STATE = pl.RUN_DIR / "bspwn-servermode"          # exists  ->  server mode requested
INFO = pl.RUN_DIR / "bspwn-servermode.json"      # written by the daemon, read by the bar and `status`
PIDF = pl.RUN_DIR / "bspwn-servermode.pid"
ICON = "\U000F048B"                              # nf-md-server
DIM, BRIGHT = "#8e9099", "#f2efe9"


# ---------------------------------------------------------------- policy (pure)
def battery_min(c):
    v = c["SERVER_BATTERY_MIN"]
    if v == "auto":
        return 20 if pl.battery_count() >= 2 else 55
    try:
        return max(0, min(100, int(v)))
    except ValueError:
        return 20


def evaluate(on, ac, pct, min_pct, temp, temp_max):
    """-> (effective, reason). reason: off | ac | battery (still running) | low-battery | overheat (must end)."""
    if not on:
        return False, "off"
    if temp is not None and temp >= temp_max:
        return False, "overheat"
    if not ac and pct is not None and pct < min_pct:
        return False, "low-battery"
    return True, "ac" if ac else "battery"


# ---------------------------------------------------------------- the inhibitor lock
class Inhibitor:
    WHAT, WHO, WHY = "handle-lid-switch:idle", "bspwn-servermode", "Server mode: keep running with the lid closed"

    def __init__(self):
        self.fd = None
        self.proc = None

    @property
    def held(self):
        return self.fd is not None or self.proc is not None

    def acquire(self):
        if self.held:
            return True
        try:
            import gi
            gi.require_version("Gio", "2.0")
            from gi.repository import Gio, GLib
            bus = Gio.bus_get_sync(Gio.BusType.SYSTEM, None)
            res, fds = bus.call_with_unix_fd_list_sync(
                "org.freedesktop.login1", "/org/freedesktop/login1", "org.freedesktop.login1.Manager", "Inhibit",
                GLib.Variant("(ssss)", (self.WHAT, self.WHO, self.WHY, "block")), GLib.VariantType("(h)"),
                Gio.DBusCallFlags.NONE, -1, None, None)
            self.fd = fds.get(res.get_child_value(0).get_handle())
            return True
        except Exception as e:                                   # no PyGObject / no logind: fall back
            pl.log(f"servermode: D-Bus inhibit failed ({e}); using systemd-inhibit")
        try:
            import ctypes
            libc = ctypes.CDLL(None)
            die_with_parent = lambda: libc.prctl(1, signal.SIGTERM)   # PR_SET_PDEATHSIG
            self.proc = subprocess.Popen(
                ["systemd-inhibit", f"--what={self.WHAT}", f"--who={self.WHO}", f"--why={self.WHY}",
                 "--mode=block", "sleep", "infinity"], preexec_fn=die_with_parent)
            return True
        except OSError as e:
            pl.log(f"servermode: cannot take the inhibitor lock: {e}")
            return False

    def release(self):
        if self.fd is not None:
            try:
                os.close(self.fd)
            except OSError:
                pass
            self.fd = None
        if self.proc is not None:
            self.proc.terminate()
            self.proc = None


# ---------------------------------------------------------------- daemon
def spawn(cmd):
    if pl.DRY:
        print("DRY: spawn", " ".join(cmd), file=sys.stderr)
        return
    subprocess.Popen(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)


def i3lock_running():
    return subprocess.run(["pgrep", "-u", str(os.getuid()), "-x", "i3lock"], capture_output=True).returncode == 0


class Daemon:
    def __init__(self, inhibitor=None):
        self.inh = inhibitor or Inhibitor()
        self.lid_prev = False
        self.ac_prev = None
        self.closed_at = None
        self.lock_tried = False

    def tick(self):
        c = pl.conf()
        on = STATE.exists()
        ac, pct, lid, temp = pl.ac_online(), pl.battery_pct(), pl.lid_closed(), pl.max_temp()
        min_pct = battery_min(c)
        eff, why = evaluate(on, ac, pct, min_pct, temp, float(c["SERVER_TEMP_MAX"]))

        if on and why in ("low-battery", "overheat"):            # must end: fall back to normal power behaviour
            STATE.unlink(missing_ok=True)
            on = False
            msg = (f"battery at {pct:.0f}% (minimum {min_pct}%)" if why == "low-battery"
                   else f"temperature {temp:.0f} C (limit {float(c['SERVER_TEMP_MAX']):.0f} C)")
            pl.log(f"servermode: ended, {msg}")
            pl.notify("Server mode ended", msg + ". Back to normal power behaviour.", "critical")
        want = on and eff

        if on and self.ac_prev is True and not ac and want:
            pl.notify("Server mode on battery", f"Keeps running until the battery drops below {min_pct}%.")
        self.ac_prev = ac

        if want and not self.inh.held:
            if not self.inh.acquire():
                pl.notify("Server mode failed", "Could not take the lid-switch inhibitor; the lid will suspend.", "critical")
            pl.log("servermode: on (lid close will not suspend)")
        elif not want and self.inh.held:
            self.inh.release()
            pl.log("servermode: off")
            if lid:                                               # lid already shut: do what a closed lid normally does
                pl.act(["systemctl", "suspend"])

        if want and lid:                                          # lid closed in server mode: lock + dark
            now = time.monotonic()
            if not self.lid_prev:
                self.closed_at, self.lock_tried = now, False
                pl.log("servermode: lid closed, staying awake")
            if (c["SERVER_LOCK"] == "1" and not self.lock_tried and now - self.closed_at >= 2):
                self.lock_tried = True                            # acpid's lid.sh usually locked already
                if not i3lock_running() and shutil.which("xlock"):
                    spawn(["xlock"])
            if c["SERVER_SCREEN_OFF"] == "1":
                pl.act(["xset", "dpms", "force", "off"])
        elif want and self.lid_prev:                              # lid reopened: wake the (locked) screen
            pl.act(["xset", "dpms", "force", "on"])
        self.lid_prev = lid

        info = {"on": on, "effective": want, "reason": why, "ac": ac, "pct": None if pct is None else round(pct, 1),
                "min": min_pct, "lid": lid, "temp": temp}
        try:
            tmp = INFO.with_suffix(".tmp")
            tmp.write_text(json.dumps(info))
            tmp.replace(INFO)
        except OSError:
            pass
        return info


def run_daemon():
    lock = pl.single_instance("bspwn-servermode")
    if lock is None:
        return 0
    PIDF.write_text(str(os.getpid()))
    signal.pthread_sigmask(signal.SIG_BLOCK, {signal.SIGUSR1})   # SIGUSR1 = "state changed, re-check now"
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(0))
    d = Daemon()
    try:
        while True:
            info = d.tick()
            signal.sigtimedwait({signal.SIGUSR1}, 2 if info["on"] else 5)
    finally:
        d.inh.release()
        INFO.unlink(missing_ok=True)
        PIDF.unlink(missing_ok=True)


# ---------------------------------------------------------------- commands
def daemon_running():
    lock = pl.single_instance("bspwn-servermode")
    if lock is None:
        return True
    lock.close()
    return False


def ping_daemon():
    try:
        os.kill(int(PIDF.read_text()), signal.SIGUSR1)
    except (OSError, ValueError):
        pass


def set_state(on):
    pl.RUN_DIR.mkdir(parents=True, exist_ok=True)
    was = STATE.exists()
    if on:
        STATE.write_text("on\n")
    else:
        STATE.unlink(missing_ok=True)
    if not daemon_running():
        spawn([sys.executable, str(Path(__file__).resolve()), "daemon"])
        time.sleep(0.5)
    ping_daemon()
    if on != was:
        c = pl.conf()
        if on:
            pl.notify("Server mode ON", f"Closing the lid keeps everything running (screen locks and goes dark). "
                      f"On battery it ends below {battery_min(c)}%.")
        else:
            pl.notify("Server mode OFF", "Closing the lid suspends again.", "low")


def load_info(max_age=20):
    """The daemon's last status, or None if it is missing/stale (daemon not running)."""
    try:
        if time.time() - INFO.stat().st_mtime > max_age:
            return None
        return json.loads(INFO.read_text())
    except (OSError, ValueError):
        return None


def bar_text(info=None):
    info = info or load_info() or {"on": False}         # no fresh daemon status: do not claim server mode is active
    if not info["on"]:
        return f"%{{F{DIM}}}%{{T6}}{ICON}%{{T-}}%{{F-}}"
    extra = ""
    if not info.get("ac") and info.get("pct") is not None:
        extra = f" %{{T2}}{info['pct']:.0f}%%{{T-}}"
    return f"%{{F{BRIGHT}}}%{{u{BRIGHT}}}%{{+u}}%{{T6}}{ICON}%{{T-}}{extra}%{{-u}}%{{F-}}"


def status():
    i = load_info()
    if not i:
        print("server mode: " + ("requested but the daemon is NOT running (lid will suspend)" if STATE.exists() else "OFF"))
        return
    print(f"server mode: {'ON' if i['on'] else 'OFF'}   power: {'AC' if i['ac'] else 'battery'}   "
          f"battery: {i['pct']}% (ends below {i['min']}% on battery)   lid: {'closed' if i['lid'] else 'open'}   "
          f"temp: {i['temp']}")


def main(argv):
    cmd = argv[1] if len(argv) > 1 else "status"
    if cmd == "daemon":
        return run_daemon()
    if cmd in ("on", "off"):
        set_state(cmd == "on")
    elif cmd == "toggle":
        set_state(not STATE.exists())
    elif cmd == "status":
        status()
    elif cmd == "bar":
        if "--follow" in argv:
            last = None
            while True:
                t = bar_text()
                if t != last:
                    print(t, flush=True)
                    last = t
                time.sleep(1)
        print(bar_text())
    else:
        print(__doc__)
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
