#!/usr/bin/env python3
"""Server mode: keep the laptop running with the lid closed (remote control, ssh, ftp, ...).

While ON, closing the lid does NOT suspend. The screen locks and goes dark, the keyboard backlight turns
off, and everything else keeps running. It ends by itself (and the laptop then does the normal thing,
i.e. suspends if the lid is closed) when:
  * on battery and the watched charge drops below SERVER_BATTERY_MIN (power.conf; auto = 20% with a slice/second
    battery, 55% on a single-battery laptop). SERVER_BATTERY picks the charge: total, lowest or one battery (BAT1), or
  * (optional, off by default) the machine gets hotter than SERVER_TEMP_MAX.
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


def watched_battery(c):
    """-> (percent or None, label). SERVER_BATTERY = auto | total | lowest | <battery name>; unknown name -> total."""
    pct, label, _ = pl.pick_battery(c.get("SERVER_BATTERY", "total"))
    return pct, label


def num(c, key, default=0.0):
    try:
        return float(c[key])
    except (KeyError, ValueError):
        return default


def temp_limit(c):
    """SERVER_TEMP_MAX in degrees C, 0 = disabled (the default)."""
    try:
        return max(0.0, float(c["SERVER_TEMP_MAX"]))
    except ValueError:
        return 0.0


def evaluate(on, ac, pct, min_pct, temp, temp_max):
    """-> (effective, reason). reason: off | ac | battery (still running) | low-battery | overheat (must end)."""
    if not on:
        return False, "off"
    if temp_max > 0 and temp is not None and temp >= temp_max:     # temp_max 0 = guard disabled
        return False, "overheat"
    if not ac and pct is not None and pct < min_pct:
        return False, "low-battery"
    return True, "ac" if ac else "battery"


# ---------------------------------------------------------------- the inhibitor lock
class Inhibitor:
    WHAT, WHO, WHY = "handle-lid-switch:idle", "bspwn-servermode", "Server mode: keep running with the lid closed"

    def __init__(self, what=None, who=None, why=None):
        self.WHAT, self.WHO, self.WHY = what or self.WHAT, who or self.WHO, why or self.WHY
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
    def __init__(self, inhibitor=None, guard_inhibitor=None):
        self.inh = inhibitor or Inhibitor()
        # battery guard: keeps the laptop awake (no lid/idle/manual suspend) while the battery is low on battery power,
        # so it can shut down cleanly instead of dying inside suspend
        self.ginh = guard_inhibitor or Inhibitor("handle-lid-switch:sleep", "bspwn-battery-guard",
                                                 "Battery guard: low battery, staying awake to shut down cleanly")
        self.countdown_at = None
        self.warned = False
        self.acted = False
        self.min_ema = None
        self.switch_warned = False     # told the user once that the battery switch cannot write (no udev rule)
        self.lid_prev = False
        self.ac_prev = None
        self.closed_at = None
        self.lock_tried = False
        self.lock_seen_at = None       # when a running locker was first seen after the lid closed
        self.refresh_at = None         # second repaint after the lid reopened

    def switch(self, c, ac):
        """Battery switch (two-battery laptops). The firmware drains SWITCH_FROM (a ThinkPad's external battery) first; when
        it runs DRY the hand-over to the internal one can fail and cut the power. So switch early, while it still has charge,
        by forcing the firmware to discharge SWITCH_TO. On AC everything goes back to the firmware's own order (auto)."""
        names = pl.battery_names()
        if c.get("SWITCH_ENABLED", "1") != "1":
            return {"switch": "off"}
        frm = c.get("SWITCH_FROM", "auto"); frm = "BAT1" if frm == "auto" else frm
        to = c.get("SWITCH_TO", "auto"); to = "BAT0" if to == "auto" else to
        if len(names) < 2 or frm not in names or to not in names or "force-discharge" not in pl.charge_options(to):
            return {"switch": "n/a"}
        forced = [n for n in names if pl.charge_mode(n) == "force-discharge"]
        if ac:
            if forced:
                for n in forced:
                    pl.set_charge_behaviour(n, "auto")
                pl.log("battery switch: AC connected, batteries back to the firmware's order")
            return {"switch": "ac"}
        if to in forced:
            return {"switch": f"on {to}"}
        pf, pt = pl.battery_pct_of(frm), pl.battery_pct_of(to)
        mins = pl.battery_minutes_left(frm)
        low = pf is not None and (pf <= num(c, "SWITCH_AT_PCT", 15) or (mins is not None and mins <= num(c, "SWITCH_AT_MIN", 10)))
        if low and pt is not None and pt > num(c, "SWITCH_TO_MIN", 10):
            if pl.set_charge_behaviour(to, "force-discharge"):
                left = "" if mins is None else f", ~{mins:.0f} min left"
                pl.log(f"battery switch: {frm} at {pf:.0f}%{left}, switched to {to} ({pt:.0f}%) before it runs dry")
                pl.notify("Battery switch", f"{frm} at {pf:.0f}%: now running on {to} ({pt:.0f}%) so the hand-over "
                          "happens while it still has charge.", "normal")
                return {"switch": f"on {to}"}
            if not self.switch_warned:
                self.switch_warned = True
                pl.log(f"battery switch: cannot write {to}/charge_behaviour (install system/etc/udev/rules.d/90-bspwn-battery.rules)")
                pl.notify("Battery switch unavailable", "Cannot choose the battery: the udev rule 90-bspwn-battery.rules is not installed.", "critical")
        return {"switch": f"watching {frm}"}

    def _guard_reset(self):
        if self.ginh.held:
            self.ginh.release()
            pl.log("battery guard: released")
        self.countdown_at, self.warned, self.acted, self.min_ema = None, False, False, None

    def guard(self, c, ac, now):
        """Battery guard: warn when the watched battery is low, then shut down cleanly (after a countdown that
        plugging in AC cancels). Below GUARD_NO_SUSPEND_BELOW it keeps the laptop awake, because on this kind of
        hardware a battery that runs out *inside suspend* cuts the power with no shutdown at all."""
        if c.get("GUARD_ENABLED", "1") != "1":
            self._guard_reset()
            return {"guard": "off"}
        pct, label, name = pl.pick_battery(c.get("GUARD_BATTERY", "auto"))
        if ac or pct is None:
            if self.countdown_at is not None and not self.acted:
                pl.notify("Battery guard", "Power connected: shutdown cancelled.", "normal")
                pl.log("battery guard: AC connected, countdown cancelled")
            self._guard_reset()
            return {"guard": "ac" if ac else "no battery"}
        m = pl.battery_minutes_left(name)
        if m is not None:
            self.min_ema = m if self.min_ema is None else 0.7 * self.min_ema + 0.3 * m
        mins = self.min_ema

        if pct < num(c, "GUARD_NO_SUSPEND_BELOW", 30):
            if not self.ginh.held and self.ginh.acquire():
                pl.log(f"battery guard: {label} at {pct:.0f}%, suspend blocked until AC")
        elif self.ginh.held:
            self.ginh.release()

        def low(pct_key, min_key):
            return pct <= num(c, pct_key) or (mins is not None and mins <= num(c, min_key))

        state = "armed"
        left = "" if mins is None else f", about {mins:.0f} min left"
        if low("GUARD_ACT_PCT", "GUARD_ACT_MIN"):
            state = "countdown"
            action = c.get("GUARD_ACTION", "poweroff")
            if self.countdown_at is None:
                grace = num(c, "GUARD_GRACE", 30)
                self.countdown_at = now + grace
                verb = {"poweroff": "Shutting down", "hibernate": "Hibernating"}.get(action)
                pl.log(f"battery guard: {label} at {pct:.0f}%{left}; action {action} in {grace:.0f} s")
                pl.notify("Battery critical", f"{label} at {pct:.0f}%{left}. "
                          + (f"{verb} in {grace:.0f} s. Plug in power to cancel." if verb else "Plug in power now."), "critical")
            elif not self.acted and now >= self.countdown_at and action in ("poweroff", "hibernate"):
                self.acted = True
                pl.log(f"battery guard: {action} now ({label} at {pct:.0f}%{left})")
                if action == "hibernate":
                    self.ginh.release()                           # our own sleep block would refuse it
                pl.act(["systemctl", action])
        else:
            if self.countdown_at is not None and not self.acted:   # reading recovered: stand down
                self.countdown_at = None
                pl.log("battery guard: level recovered, countdown cancelled")
            if low("GUARD_WARN_PCT", "GUARD_WARN_MIN"):
                state = "warned"
                if not self.warned:
                    self.warned = True
                    pl.log(f"battery guard: low, {label} at {pct:.0f}%{left}")
                    pl.notify("Battery low", f"{label} at {pct:.0f}%{left}. Plug in power; the laptop shuts down "
                              f"cleanly at {num(c, 'GUARD_ACT_PCT'):.0f}%.", "critical")
        return {"guard": state, "guard_battery": label, "guard_pct": round(pct, 1),
                "guard_min": None if mins is None else round(mins, 1)}

    def tick(self):
        c = pl.conf()
        on = STATE.exists()
        ac, lid, temp = pl.ac_online(), pl.lid_closed(), pl.max_temp()
        pct, bat_label = watched_battery(c)
        min_pct = battery_min(c)
        temp_max = temp_limit(c)
        eff, why = evaluate(on, ac, pct, min_pct, temp, temp_max)
        sinfo = self.switch(c, ac)                                # before the guard: it follows the active battery
        ginfo = self.guard(c, ac, time.monotonic())
        guarding = self.ginh.held                                 # the guard is keeping the laptop awake

        if on and why in ("low-battery", "overheat"):            # must end: fall back to normal power behaviour
            STATE.unlink(missing_ok=True)
            on = False
            msg = (f"{bat_label} at {pct:.0f}% (minimum {min_pct}%)" if why == "low-battery"
                   else f"temperature {temp:.0f} C (limit {temp_max:.0f} C)")
            pl.log(f"servermode: ended, {msg}")
            pl.notify("Server mode ended", msg + ". Back to normal power behaviour.", "critical")
        want = on and eff

        if on and self.ac_prev is True and not ac and want:
            pl.notify("Server mode on battery", f"Keeps running until {bat_label} drops below {min_pct}%.")
        self.ac_prev = ac

        if want and not self.inh.held:
            if not self.inh.acquire():
                pl.notify("Server mode failed", "Could not take the lid-switch inhibitor; the lid will suspend.", "critical")
            pl.log("servermode: on (lid close will not suspend)")
        elif not want and self.inh.held:
            self.inh.release()
            pl.log("servermode: off")
            if lid and guarding:                                  # low battery: suspending could end in a power cut
                pl.log("servermode: lid closed but not suspending, the battery guard keeps the laptop awake")
            elif lid:                                             # lid already shut: do what a closed lid normally does
                pl.act(["systemctl", "suspend"])

        lid_mode = want or guarding                               # someone is keeping the laptop awake: handle the lid
        if lid_mode and lid:                                      # lid closed and staying awake: lock + dark
            now = time.monotonic()
            if not self.lid_prev:
                self.closed_at, self.lock_tried, self.lock_seen_at = now, False, None
                pl.log("servermode: lid closed, staying awake" + ("" if want else " (battery guard)"))
            locked = i3lock_running()                             # acpid's lid.sh usually locked already
            if (c["SERVER_LOCK"] == "1" and not locked and not self.lock_tried and now - self.closed_at >= 2):
                self.lock_tried = True
                if shutil.which("xlock"):
                    spawn(["xlock"])
            if locked and self.lock_seen_at is None:
                self.lock_seen_at = now
            # Blank only once the lock has been up for 2 s, so the compositor has painted it. Blanking in the same
            # instant as the lock maps can leave picom showing its last frame (the unlocked desktop) on wake.
            # Without any locker, still blank after 10 s rather than leave the desktop showing.
            lock_painted = c["SERVER_LOCK"] != "1" or (self.lock_seen_at is not None and now - self.lock_seen_at >= 2)
            if c["SERVER_SCREEN_OFF"] == "1" and (lock_painted or now - self.closed_at >= 10):
                pl.act(["xset", "dpms", "force", "off"])
        elif lid_mode and self.lid_prev:                          # lid reopened: wake the (locked) screen
            # Reset X's idle timer first: after a long closed-lid period X still counts the machine as idle past
            # the DPMS timeout and would blank the panel again right after "force on" (a black, frozen-looking screen).
            pl.act(["xset", "s", "reset"])
            pl.act(["xset", "dpms", "force", "on"])
            # Force every window (the lock included) to repaint: a compositor that idled while the panel was off can
            # otherwise keep showing a stale frame. Repeat once shortly after, when the panel is surely up.
            pl.act(["xrefresh"])
            self.refresh_at = time.monotonic() + 1.5
            pl.log("servermode: lid opened, screen woken and repainted")
        if self.refresh_at is not None and not lid and time.monotonic() >= self.refresh_at:
            pl.act(["xrefresh"])
            self.refresh_at = None
        self.lid_prev = lid

        info = {"on": on, "effective": want, "reason": why, "ac": ac, "pct": None if pct is None else round(pct, 1), "battery": bat_label,
                "min": min_pct, "lid": lid, "temp": temp, **sinfo, **ginfo}
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
            wait = 2 if (info["on"] or not info["ac"]) else 5     # on battery: the guard needs a close eye
            if d.refresh_at is not None:
                wait = max(0.2, min(wait, d.refresh_at - time.monotonic()))
            signal.sigtimedwait({signal.SIGUSR1}, wait)
    finally:
        d.inh.release()
        d.ginh.release()
        if pl.ac_online():                                        # never leave a forced discharge behind on AC
            for n in pl.battery_names():
                if pl.charge_mode(n) == "force-discharge":
                    pl.set_charge_behaviour(n, "auto")
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
          f"{i.get('battery', 'battery')}: {i['pct']}% (ends below {i['min']}% on battery)   lid: {'closed' if i['lid'] else 'open'}   "
          f"temp: {i['temp']}")
    if i.get("switch"):
        print(f"battery switch: {i['switch']}")
    g = i.get("guard")
    if g:
        extra = ""
        if i.get("guard_pct") is not None:
            extra = f" ({i['guard_battery']} {i['guard_pct']}%" + (f", ~{i['guard_min']:.0f} min" if i.get("guard_min") else "") + ")"
        print(f"battery guard: {g}{extra}")


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
