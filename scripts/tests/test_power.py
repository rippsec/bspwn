#!/usr/bin/env python3
"""Tests for the power tools (kbd-backlight.py, servermode.py, powerlib.py) against a fake sysfs.

    python3 scripts/tests/test_power.py

Nothing real is touched: power supply, lid, thermal zones, LED and runtime dir are temp files, side effects
(xset, xlock, suspend, notify) are recorded instead of run (BSPWN_DRY_RUN), and the inhibitor lock is a stub.
"""
import importlib.util
import sys
sys.dont_write_bytecode = True
import os
import tempfile
import unittest
from pathlib import Path

TMP = Path(tempfile.mkdtemp(prefix="bspwn-power-test-"))
for d in ("ps", "leds", "thermal", "run"):
    (TMP / d).mkdir()
os.environ.update(BSPWN_DRY_RUN="1", BSPWN_PS_DIR=str(TMP / "ps"), BSPWN_LED_DIR=str(TMP / "leds"),
                  BSPWN_THERMAL_DIR=str(TMP / "thermal"), BSPWN_LID_FILE=str(TMP / "lid"),
                  BSPWN_RUNTIME_DIR=str(TMP / "run"), BSPWN_POWER_CONF=str(TMP / "power.conf"))
SCRIPTS = Path(__file__).resolve().parents[2] / "dot/.config/bspwm/scripts"
sys.path.insert(0, str(SCRIPTS))
import powerlib as pl  # noqa: E402


def load(name, file):
    spec = importlib.util.spec_from_file_location(name, SCRIPTS / file)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


sm = load("servermode", "servermode.py")
kb = load("kbd_backlight", "kbd-backlight.py")


def w(path, text):
    Path(path).parent.mkdir(parents=True, exist_ok=True)
    Path(path).write_text(str(text))


def supply(name, kind, **kv):
    for k, v in dict(type=kind, **kv).items():
        w(TMP / "ps" / name / k, v)


def thinkpad(ac=True, b0=(15510000, 15670000), b1=(1820000, 2190000)):
    """Dual battery ThinkPad (energy in uWh), like the T450 with a slice."""
    supply("AC", "Mains", online=int(ac))
    supply("BAT0", "Battery", energy_now=b0[0], energy_full=b0[1], status="Discharging")
    supply("BAT1", "Battery", energy_now=b1[0], energy_full=b1[1], status="Discharging")


def set_total_pct(p):
    """Spread a total charge of p% over the two fake batteries (full = 15670000 + 2190000)."""
    thinkpad(ac=pl.ac_online(), b0=(int(15670000 * p / 100), 15670000), b1=(int(2190000 * p / 100), 2190000))


def remove_battery(name):
    """Take a battery away completely (move it out of the fake power_supply dir)."""
    import shutil
    shutil.rmtree(TMP / "ps" / name)


class FakeInhibitor:
    def __init__(self):
        self.held = False

    def acquire(self):
        self.held = True
        return True

    def release(self):
        self.held = False


class Recorder:
    """Collects the side effects the code would perform (act/notify/spawn)."""

    def __init__(self):
        self.calls = []
        self._act, self._spawn = pl.act, sm.spawn
        pl.act = lambda cmd, **kw: self.calls.append(" ".join(map(str, cmd))) or 0
        sm.spawn = lambda cmd: self.calls.append("spawn " + " ".join(cmd))

    def restore(self):
        pl.act, sm.spawn = self._act, self._spawn

    def has(self, text):
        return any(text in c for c in self.calls)


class PowerTest(unittest.TestCase):
    def setUp(self):
        for p in (TMP / "ps").glob("*"):
            for f in p.glob("*"):
                f.unlink()
            p.rmdir()
        thinkpad()
        w(TMP / "lid", "open")
        w(TMP / "power.conf", "")
        w(TMP / "thermal/thermal_zone0/temp", 45000)
        sm.STATE.unlink(missing_ok=True)
        self.rec = Recorder()
        self.inh = FakeInhibitor()
        self.d = sm.Daemon(self.inh)
        self.d.inh = self.inh
        sm.i3lock_running = lambda: False
        self._which = sm.shutil.which
        sm.shutil.which = lambda n: "/usr/local/bin/xlock"

    def tearDown(self):
        self.rec.restore()
        sm.shutil.which = self._which

    # --- measurements
    def test_battery_total_is_energy_weighted(self):
        self.assertAlmostEqual(pl.battery_pct(), 100 * (15510000 + 1820000) / (15670000 + 2190000), places=3)
        self.assertEqual(pl.battery_count(), 2)

    def test_ac_detection(self):
        thinkpad(ac=True); self.assertTrue(pl.ac_online())
        thinkpad(ac=False); self.assertFalse(pl.ac_online())

    def test_threshold_auto(self):
        self.assertEqual(sm.battery_min(pl.conf()), 20)                       # two batteries
        remove_battery("BAT1")
        self.assertEqual(sm.battery_min(pl.conf()), 55)                       # single battery laptop
        w(TMP / "power.conf", "SERVER_BATTERY_MIN=35  # custom\n")
        self.assertEqual(sm.battery_min(pl.conf()), 35)

    # --- policy
    def test_evaluate(self):
        ev = sm.evaluate
        self.assertEqual(ev(False, True, 90, 20, 40, 88), (False, "off"))
        self.assertEqual(ev(True, True, 5, 20, 40, 88), (True, "ac"))          # AC: battery level is irrelevant
        self.assertEqual(ev(True, False, 54, 20, 40, 88), (True, "battery"))
        self.assertEqual(ev(True, False, 19.9, 20, 40, 88), (False, "low-battery"))
        self.assertEqual(ev(True, False, 20, 20, 40, 88), (True, "battery"))   # boundary: still running at exactly min
        self.assertEqual(ev(True, True, 90, 20, 88, 88), (False, "overheat"))
        self.assertEqual(ev(True, True, None, 20, None, 88), (True, "ac"))     # no battery / no sensor

    # --- daemon behaviour
    def test_off_does_nothing(self):
        self.d.tick()
        self.assertFalse(self.inh.held)
        self.assertEqual(self.rec.calls, [])

    def test_on_holds_inhibitor_lid_open_no_side_effects(self):
        sm.STATE.write_text("on")
        info = self.d.tick()
        self.assertTrue(self.inh.held and info["effective"])
        self.assertFalse(self.rec.has("xset"))

    def test_lid_close_locks_and_blanks_then_reopen_wakes(self):
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed")
        t = [100.0]
        sm.time.monotonic = lambda: t[0]
        self.d.tick()
        self.assertTrue(self.rec.has("xset dpms force off"))
        self.assertFalse(self.rec.has("spawn xlock"))                          # not before 2 s (acpid usually locks first)
        t[0] = 103.0
        self.d.tick()
        self.assertTrue(self.rec.has("spawn xlock"))
        self.assertEqual(sum(c == "spawn xlock" for c in self.rec.calls), 1)   # only tried once per close
        self.assertTrue(self.inh.held)                                         # never suspended
        self.assertFalse(self.rec.has("suspend"))
        w(TMP / "lid", "open"); self.d.tick()
        self.assertTrue(self.rec.has("xset dpms force on"))

    def test_existing_lock_is_not_doubled(self):
        sm.i3lock_running = lambda: True
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); t = [0.0]; sm.time.monotonic = lambda: t[0]
        self.d.tick(); t[0] = 5; self.d.tick()
        self.assertFalse(self.rec.has("spawn xlock"))

    def test_unplug_continues_until_threshold_then_ends_and_suspends(self):
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed")
        thinkpad(ac=False); set_total_pct(54)
        info = self.d.tick()
        self.assertTrue(info["effective"] and self.inh.held)                   # 54% > 20%: keeps going on battery
        set_total_pct(20.5); self.assertTrue(self.d.tick()["effective"])
        self.rec.calls.clear()
        set_total_pct(19)
        info = self.d.tick()
        self.assertFalse(info["on"] or info["effective"])
        self.assertFalse(self.inh.held)                                        # lid works normally again
        self.assertFalse(sm.STATE.exists())                                    # server mode switched itself off
        self.assertTrue(self.rec.has("suspend"))                               # lid is shut -> normal behaviour = sleep
        self.assertEqual(sum("systemctl suspend" in c for c in self.rec.calls), 1)

    def test_low_battery_with_lid_open_does_not_suspend(self):
        sm.STATE.write_text("on"); self.d.tick()
        thinkpad(ac=False); set_total_pct(10)
        self.d.tick()
        self.assertFalse(self.inh.held)
        self.assertFalse(self.rec.has("suspend"))

    def test_single_battery_laptop_uses_55_percent(self):
        remove_battery("BAT1")
        supply("BAT0", "Battery", energy_now=int(0.58 * 50000000), energy_full=50000000, status="Discharging")
        supply("AC", "Mains", online=0)
        sm.STATE.write_text("on")
        self.assertTrue(self.d.tick()["effective"])                            # 58% >= 55%
        supply("BAT0", "Battery", energy_now=int(0.54 * 50000000), energy_full=50000000, status="Discharging")
        self.assertFalse(self.d.tick()["effective"])                           # 54% < 55%

    def test_manual_off_with_lid_closed_suspends(self):
        sm.STATE.write_text("on"); w(TMP / "lid", "closed"); self.d.tick()
        sm.STATE.unlink()
        self.rec.calls.clear()
        self.d.tick()
        self.assertFalse(self.inh.held)
        self.assertTrue(self.rec.has("systemctl suspend"))

    def test_overheat_ends_server_mode(self):
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "thermal/thermal_zone0/temp", 91000)
        info = self.d.tick()
        self.assertEqual(info["reason"], "overheat")
        self.assertFalse(self.inh.held)

    def test_ac_unplug_notifies_once(self):
        sm.STATE.write_text("on"); self.d.tick()
        thinkpad(ac=False); self.d.tick(); self.d.tick()
        self.assertEqual(sum("Server mode on battery" in c for c in self.rec.calls), 1)

    def test_screen_and_lock_options_can_be_disabled(self):
        w(TMP / "power.conf", "SERVER_LOCK=0\nSERVER_SCREEN_OFF=0\n")
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); t = [0.0]; sm.time.monotonic = lambda: t[0]
        self.d.tick(); t[0] = 9; self.d.tick()
        self.assertFalse(self.rec.has("xset")); self.assertFalse(self.rec.has("xlock"))

    def test_bar_text(self):
        self.assertIn(sm.DIM, sm.bar_text({"on": False, "ac": True, "pct": 90}))
        on_ac = sm.bar_text({"on": True, "ac": True, "pct": 90})
        self.assertIn(sm.BRIGHT, on_ac); self.assertNotIn("90", on_ac)
        self.assertIn("54%%", sm.bar_text({"on": True, "ac": False, "pct": 54.2}))


class KbdTest(unittest.TestCase):
    def test_dims_after_timeout_and_wakes_on_input(self):
        k = kb.Kbd()
        self.assertIsNone(k.step(2, 5000, 30, False))                          # active enough: stays lit
        self.assertEqual(k.step(2, 31000, 30, False), 0)                       # idle >= 30 s: off
        self.assertIsNone(k.step(0, 40000, 30, False))                         # still idle: stays off
        self.assertEqual(k.step(0, 100, 30, False), 2)                         # key pressed: back to the previous level

    def test_lid_closed_keeps_it_off_even_with_input(self):
        k = kb.Kbd()
        self.assertEqual(k.step(1, 0, 30, True), 0)
        self.assertIsNone(k.step(0, 50, 30, True))
        self.assertEqual(k.step(0, 50, 30, False), 1)

    def test_user_change_while_dimmed_is_respected(self):
        k = kb.Kbd()
        k.step(1, 99999, 30, False)
        self.assertIsNone(k.step(2, 99999, 30, False))                         # Fn+Space raised it: adopt, do not fight
        self.assertFalse(k.dimmed)

    def test_already_off_is_left_alone(self):
        k = kb.Kbd()
        self.assertIsNone(k.step(0, 99999, 30, False))
        self.assertFalse(k.dimmed)

    def test_no_x_idle_never_dims(self):
        self.assertIsNone(kb.Kbd().step(2, None, 30, False))

    def test_led_discovery_and_set(self):
        w(TMP / "leds/dell::kbd_backlight/brightness", 1); w(TMP / "leds/dell::kbd_backlight/max_brightness", 3)
        self.assertEqual(pl.kbd_led(), "dell::kbd_backlight")
        pl.led_set("dell::kbd_backlight", 0)
        self.assertEqual(pl.led_get("dell::kbd_backlight"), 0)
        self.assertEqual(pl.led_max("dell::kbd_backlight"), 3)


if __name__ == "__main__":
    pl.log = lambda msg, tag="": None          # keep the output readable
    sm.pl.log = pl.log
    sys.dont_write_bytecode = True
    result = unittest.main(exit=False, verbosity=2).result
    sys.exit(0 if result.wasSuccessful() else 1)
