#!/usr/bin/env python3
"""Shared helpers for the bspwn power tools (kbd-backlight.py, servermode.py).

Everything that touches the machine goes through small functions here so it can be faked in tests:
  BSPWN_PS_DIR / BSPWN_LED_DIR / BSPWN_THERMAL_DIR   alternative sysfs roots
  BSPWN_LID_FILE                                     file containing "open" or "closed"
  BSPWN_RUNTIME_DIR                                  where state files live (default $XDG_RUNTIME_DIR)
  BSPWN_POWER_CONF                                   alternative power.conf
  BSPWN_DRY_RUN=1                                    print side effects (xset, xlock, suspend, notify) instead of running them
"""
import ctypes
import glob
import os
import subprocess
import sys
from pathlib import Path

HOME = Path.home()
DRY = bool(os.environ.get("BSPWN_DRY_RUN"))
CONF = Path(os.environ.get("BSPWN_POWER_CONF", HOME / ".config/bspwm/power.conf"))
PS_DIR = Path(os.environ.get("BSPWN_PS_DIR", "/sys/class/power_supply"))
LED_DIR = Path(os.environ.get("BSPWN_LED_DIR", "/sys/class/leds"))
THERMAL_DIR = Path(os.environ.get("BSPWN_THERMAL_DIR", "/sys/class/thermal"))
LID_FILE = os.environ.get("BSPWN_LID_FILE")
RUN_DIR = Path(os.environ.get("BSPWN_RUNTIME_DIR") or os.environ.get("XDG_RUNTIME_DIR") or f"/run/user/{os.getuid()}")

DEFAULTS = {
    "KBD_AUTO": "1",              # keyboard backlight idle-off (0 disables the daemon)
    "KBD_IDLE_AC": "5",           # seconds after the last keypress before the backlight turns off, on AC
    "KBD_IDLE_BAT": "5",          # ... on battery
    "KBD_LEVEL": "1",             # level used when a key lights it (1 = minimal; 0 = the level it had before)
    "KBD_WAKE_POINTER": "0",      # 1 = touchpad/mouse input also lights it (default: keyboard only)
    "SERVER_BATTERY_MIN": "auto",  # server mode ends below this % on battery; auto = 20 (2+ batteries) or 55
    "SERVER_BATTERY": "total",     # which charge to watch: auto | total | lowest | a battery name (BAT0, BAT1, ...)
    "SERVER_TEMP_MAX": "0",       # >0: server mode ends (and the laptop suspends) at this temperature, degrees C; 0 = off
    "GUARD_ENABLED": "1",          # battery guard: warn, then shut down cleanly before the battery dies
    "GUARD_BATTERY": "auto",       # which battery it watches (same values as SERVER_BATTERY)
    "GUARD_WARN_PCT": "15",        # warn at or below this %
    "GUARD_WARN_MIN": "8",         # ... or when this many minutes are left at the current draw
    "GUARD_ACT_PCT": "7",          # act at or below this %
    "GUARD_ACT_MIN": "4",          # ... or with this many minutes left
    "GUARD_ACTION": "poweroff",    # poweroff | hibernate | none (notify only)
    "GUARD_GRACE": "30",           # seconds of countdown before acting; plugging in AC cancels
    "GUARD_NO_SUSPEND_BELOW": "30",  # on battery below this %, do not suspend (stay awake so the guard can act)
    "SERVER_LOCK": "1",           # lock the screen when the lid closes in server mode
    "SERVER_SCREEN_OFF": "1",     # turn the display off while the lid is closed in server mode
}


# ---------------------------------------------------------------- basics
def log(msg, tag="bspwn-power"):
    print(msg, file=sys.stderr)
    if not DRY:
        try:
            subprocess.run(["logger", "-t", tag, msg], timeout=3)
        except (OSError, subprocess.SubprocessError):
            pass


def act(cmd, **kw):
    """Run a side-effecting command (or print it in dry-run mode). Returns the exit status."""
    if DRY:
        print("DRY:", " ".join(map(str, cmd)), file=sys.stderr)
        return 0
    try:
        return subprocess.run(cmd, timeout=kw.pop("timeout", 10), **kw).returncode
    except (OSError, subprocess.SubprocessError):
        return 1


def notify(title, body="", urgency="normal"):
    act(["notify-send", "-u", urgency, "-a", "bspwn-power", title, body])


def read(path, default=None):
    try:
        return Path(path).read_text().strip()
    except OSError:
        return default


def conf():
    """power.conf is plain KEY=VALUE (shell-compatible); missing keys fall back to DEFAULTS."""
    c = dict(DEFAULTS)
    for line in (read(CONF, "") or "").splitlines():
        line = line.split("#", 1)[0].strip()
        if "=" in line:
            k, v = line.split("=", 1)
            c[k.strip()] = v.strip().strip("'\"")
    return c


# ---------------------------------------------------------------- power supply / lid / thermal
def _supplies(kind):
    return [d for d in sorted(PS_DIR.glob("*")) if read(d / "type") == kind]


def _battery_reading(d):
    """(now, full) for one battery dir, or None."""
    for now, full in (("energy_now", "energy_full"), ("charge_now", "charge_full")):
        n, f = read(d / now), read(d / full)
        if n and f and n.isdigit() and f.isdigit() and int(f) > 0:
            return int(n), int(f)
    cap = read(d / "capacity")
    if cap and cap.isdigit():
        return int(cap), 100
    return None


def battery_names():
    return [d.name for d in _supplies("Battery")]


def battery_pct_of(name):
    """Charge of ONE battery (e.g. "BAT1"), 0-100, or None if there is no such battery."""
    d = PS_DIR / name
    if read(d / "type") != "Battery":
        return None
    r = _battery_reading(d)
    return None if r is None else 100.0 * r[0] / r[1]


def battery_pct_lowest():
    vals = [p for p in (battery_pct_of(n) for n in battery_names()) if p is not None]
    return min(vals) if vals else None


def battery_minutes_left(name=None):
    """Minutes left at the current draw for one battery (or all discharging ones), None if not discharging/unknown."""
    dirs = [PS_DIR / name] if name else _supplies("Battery")
    e = p = 0
    for d in dirs:
        if read(d / "status") != "Discharging":
            continue
        for en_k, pw_k in (("energy_now", "power_now"), ("charge_now", "current_now")):
            en, pw = read(d / en_k), read(d / pw_k)
            if en and pw and en.isdigit() and pw.isdigit():
                e, p = e + int(en), p + int(pw)
                break
    return 60.0 * e / p if p > 0 else None


def pick_battery(spec):
    """spec: auto | total | lowest | <name>  ->  (percent or None, label, battery name or None for "all").
    auto: two or more batteries -> BAT1 (a ThinkPad's slice/external battery); one battery -> that battery."""
    spec = (spec or "total").strip() or "total"
    names = battery_names()
    if spec == "auto":
        spec = "BAT1" if len(names) >= 2 and "BAT1" in names else (names[0] if len(names) == 1 else "total")
    if spec == "lowest":
        vals = [(p, n) for n in names for p in [battery_pct_of(n)] if p is not None]
        if vals:
            p, n = min(vals)
            return p, "lowest battery", n
        return None, "lowest battery", None
    if spec != "total":
        p = battery_pct_of(spec)
        if p is not None:
            return p, spec, spec
    return battery_pct(), "battery", None


def batteries():
    """[(energy_now, energy_full)] per battery, in a common unit (uWh, or uAh where only charge_* exists)."""
    out = []
    for d in _supplies("Battery"):
        for now, full in (("energy_now", "energy_full"), ("charge_now", "charge_full")):
            n, f = read(d / now), read(d / full)
            if n and f and n.isdigit() and f.isdigit() and int(f) > 0:
                out.append((int(n), int(f)))
                break
        else:
            cap = read(d / "capacity")
            if cap and cap.isdigit():
                out.append((int(cap), 100))
    return out


def battery_count():
    return len(_supplies("Battery"))


def battery_pct():
    """Total charge across all batteries (energy-weighted), 0-100, or None without a battery."""
    b = batteries()
    if not b:
        return None
    return 100.0 * sum(n for n, _ in b) / sum(f for _, f in b)


def ac_online():
    mains = [d for k in ("Mains", "USB_PD", "USB_C") for d in _supplies(k)]
    if mains:
        return any(read(d / "online") == "1" for d in mains)
    bats = _supplies("Battery")
    if not bats:
        return True                      # no battery at all: a desktop
    return any(read(d / "status") in ("Charging", "Full", "Not charging") for d in bats)


def lid_closed():
    if LID_FILE:
        return read(LID_FILE, "open") == "closed"
    for f in glob.glob("/proc/acpi/button/lid/*/state"):
        return "closed" in (read(f, "") or "")
    return False


def max_temp():
    best = None
    for f in glob.glob(str(THERMAL_DIR / "thermal_zone*/temp")):
        v = read(f)
        if v and v.lstrip("-").isdigit() and 0 < int(v) / 1000 < 130:
            best = max(best or 0, int(v) / 1000)
    return best


# ---------------------------------------------------------------- X idle time (libXss, no process spawn)
class XIdle:
    class _Info(ctypes.Structure):
        _fields_ = [("window", ctypes.c_ulong), ("state", ctypes.c_int), ("kind", ctypes.c_int),
                    ("til_or_since", ctypes.c_ulong), ("idle", ctypes.c_ulong), ("event_mask", ctypes.c_ulong)]

    def __init__(self):
        self.x = self.xss = self.dpy = self.info = None
        try:
            self.x = ctypes.CDLL("libX11.so.6")
            self.xss = ctypes.CDLL("libXss.so.1")
            self.x.XOpenDisplay.restype = ctypes.c_void_p
            self.x.XDefaultRootWindow.argtypes = [ctypes.c_void_p]
            self.x.XDefaultRootWindow.restype = ctypes.c_ulong
            self.xss.XScreenSaverAllocInfo.restype = ctypes.POINTER(self._Info)
            self.xss.XScreenSaverQueryInfo.argtypes = [ctypes.c_void_p, ctypes.c_ulong, ctypes.POINTER(self._Info)]
        except OSError:
            self.x = None

    def ms(self):
        """Milliseconds since the last keyboard/pointer input, or None if X is unavailable."""
        if self.x is None:
            return None
        if self.dpy is None:
            self.dpy = self.x.XOpenDisplay(None)
            if not self.dpy:
                self.dpy = None
                return None
            self.info = self.xss.XScreenSaverAllocInfo()
        ok = self.xss.XScreenSaverQueryInfo(self.dpy, self.x.XDefaultRootWindow(self.dpy), self.info)
        return int(self.info.contents.idle) if ok else None


# ---------------------------------------------------------------- keyboard backlight LED
def kbd_led():
    """Name of the keyboard backlight LED (tpacpi::kbd_backlight, dell::kbd_backlight, ...) or None."""
    for d in sorted(LED_DIR.glob("*kbd_backlight*")):
        if (d / "brightness").exists() and (d / "max_brightness").exists():
            return d.name
    return None


def led_get(name):
    v = read(LED_DIR / name / "brightness")
    return int(v) if v and v.isdigit() else 0


def led_max(name):
    v = read(LED_DIR / name / "max_brightness")
    return int(v) if v and v.isdigit() else 1


def led_set(name, value):
    """Set the LED through logind (works unprivileged for the active session); falls back to sysfs."""
    if LED_DIR != Path("/sys/class/leds"):          # fake sysfs (tests): write the file directly
        try:
            (LED_DIR / name / "brightness").write_text(str(value))
        except OSError:
            pass
        return
    if DRY:
        print(f"DRY: led {name} -> {value}", file=sys.stderr)
        return
    rc = act(["gdbus", "call", "--system", "--dest", "org.freedesktop.login1",
              "--object-path", "/org/freedesktop/login1/session/auto",
              "--method", "org.freedesktop.login1.Session.SetBrightness", "leds", name, str(int(value))],
             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    if rc != 0:
        try:
            (LED_DIR / name / "brightness").write_text(str(value))
        except OSError:
            pass


def single_instance(name):
    """Hold an exclusive lock for the life of the process; returns the open file, or None if already running."""
    import fcntl
    RUN_DIR.mkdir(parents=True, exist_ok=True)
    f = open(RUN_DIR / f"{name}.lock", "w")
    try:
        fcntl.flock(f, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        return None
    return f
