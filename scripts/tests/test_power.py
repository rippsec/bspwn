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
        self.ginh = FakeInhibitor()                       # battery guard lock: never take a real logind lock in tests
        self.d = sm.Daemon(self.inh, self.ginh)
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
        self.assertEqual(ev(True, True, 90, 20, 99, 0), (True, "ac"))          # temp_max 0 = guard disabled
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

    def test_lid_close_blanks_only_after_the_lock_is_painted(self):
        """Regression (2026-11-20): blanking in the same instant the lock mapped left picom showing the old,
        unlocked desktop on wake. Now: lock first, blank only once the lock has been up for 2 s."""
        running = [False]
        sm.i3lock_running = lambda: running[0]
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); t = [100.0]; sm.time.monotonic = lambda: t[0]
        self.d.tick()                                                          # t=100: no lock yet
        self.assertFalse(self.rec.has("xset dpms force off"))                  # never blank before the lock exists
        self.assertFalse(self.rec.has("spawn xlock"))                          # give acpid's lid.sh 2 s to lock first
        t[0] = 102.5; self.d.tick()                                            # still no lock: fallback locker
        self.assertTrue(self.rec.has("spawn xlock")); self.assertFalse(self.rec.has("xset dpms force off"))
        running[0] = True
        t[0] = 103.0; self.d.tick()                                            # lock seen now
        self.assertFalse(self.rec.has("xset dpms force off"))                  # ... but not painted long enough
        t[0] = 105.1; self.d.tick()
        self.assertTrue(self.rec.has("xset dpms force off"))                   # 2 s after the lock appeared: dark
        self.assertEqual(sum(c == "spawn xlock" for c in self.rec.calls), 1)   # fallback tried once per close
        self.assertTrue(self.inh.held); self.assertFalse(self.rec.has("suspend"))

    def test_lid_open_wakes_and_forces_a_full_repaint_twice(self):
        sm.i3lock_running = lambda: True
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); t = [0.0]; sm.time.monotonic = lambda: t[0]
        self.d.tick(); t[0] = 3; self.d.tick()
        self.rec.calls.clear()
        w(TMP / "lid", "open"); t[0] = 2000; self.d.tick()
        self.assertEqual(self.rec.calls[:3], ["xset s reset", "xset dpms force on", "xrefresh"])
        self.rec.calls.clear()
        t[0] = 2000.5; self.d.tick(); self.assertFalse(self.rec.has("xrefresh"))   # not yet
        t[0] = 2001.6; self.d.tick(); self.assertEqual(self.rec.calls.count("xrefresh"), 1)
        t[0] = 2010; self.d.tick(); self.assertEqual(self.rec.calls.count("xrefresh"), 1)  # only one extra repaint

    def test_no_locker_still_blanks_after_ten_seconds(self):
        sm.i3lock_running = lambda: False
        sm.shutil.which = lambda n: None                                       # no xlock installed
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); t = [0.0]; sm.time.monotonic = lambda: t[0]
        self.d.tick(); t[0] = 9; self.d.tick()
        self.assertFalse(self.rec.has("xset dpms force off"))
        t[0] = 10.1; self.d.tick()
        self.assertTrue(self.rec.has("xset dpms force off"))                   # better dark than showing the desktop

    def test_lock_disabled_blanks_immediately(self):
        w(TMP / "power.conf", "SERVER_LOCK=0\n")
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); t = [0.0]; sm.time.monotonic = lambda: t[0]
        self.d.tick()
        self.assertTrue(self.rec.has("xset dpms force off")); self.assertFalse(self.rec.has("xlock"))

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
        self.assertFalse(self.inh.held)                                        # server mode released its lock
        self.assertFalse(sm.STATE.exists())                                    # server mode switched itself off
        self.assertTrue(self.ginh.held)                                        # ... but the battery guard keeps it awake
        self.assertFalse(self.rec.has("systemctl suspend"))                    # no sleep on a low battery (power-cut risk)

    def test_without_guard_server_mode_end_suspends(self):
        w(TMP / "power.conf", "GUARD_ENABLED=0\n")
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "lid", "closed"); thinkpad(ac=False); set_total_pct(19)
        self.d.tick()
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

    def test_heat_is_ignored_by_default(self):
        sm.STATE.write_text("on"); self.d.tick()
        w(TMP / "thermal/thermal_zone0/temp", 99000)                           # this ThinkPad often runs this hot
        info = self.d.tick()
        self.assertTrue(info["effective"] and self.inh.held)
        self.assertEqual(info["reason"], "ac")

    def test_overheat_guard_when_enabled(self):
        w(TMP / "power.conf", "SERVER_TEMP_MAX=88\n")
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

    def test_watch_one_battery_by_name(self):
        w(TMP / "power.conf", "SERVER_BATTERY=BAT1\n")
        supply("AC", "Mains", online=0)
        supply("BAT0", "Battery", energy_now=15000000, energy_full=15670000, status="Discharging")   # internal ~96%
        supply("BAT1", "Battery", energy_now=500000, energy_full=2190000, status="Discharging")      # slice ~23%
        sm.STATE.write_text("on")
        info = self.d.tick()
        self.assertTrue(info["effective"]); self.assertEqual(info["battery"], "BAT1"); self.assertAlmostEqual(info["pct"], 22.8, places=1)
        supply("BAT1", "Battery", energy_now=400000, energy_full=2190000, status="Discharging")      # slice ~18% < 20
        info = self.d.tick()
        self.assertFalse(info["effective"]); self.assertEqual(info["reason"], "low-battery")       # ends although the total is ~86%
        self.assertTrue(any("BAT1 at 18%" in c for c in self.rec.calls))

    def test_missing_battery_name_falls_back_to_total(self):
        w(TMP / "power.conf", "SERVER_BATTERY=BAT7\n")
        pct, label = sm.watched_battery(pl.conf())
        self.assertEqual(label, "battery"); self.assertAlmostEqual(pct, pl.battery_pct())

    def test_lowest_battery(self):
        w(TMP / "power.conf", "SERVER_BATTERY=lowest\n")
        pct, label = sm.watched_battery(pl.conf())
        self.assertAlmostEqual(pct, 100 * 1820000 / 2190000, places=3); self.assertEqual(label, "lowest battery")

    def test_auto_picks_slice_on_thinkpad_and_the_only_battery_elsewhere(self):
        w(TMP / "power.conf", "SERVER_BATTERY=auto\n")
        pct, label = sm.watched_battery(pl.conf())
        self.assertEqual(label, "BAT1")                                        # two batteries: the slice
        remove_battery("BAT1")
        pct, label = sm.watched_battery(pl.conf())
        self.assertEqual(label, "BAT0")                                        # one battery (Dell-like): that one
        remove_battery("BAT0"); supply("BAT1", "Battery", energy_now=30, energy_full=60, status="Discharging")
        pct, label = sm.watched_battery(pl.conf())
        self.assertEqual(label, "BAT1"); self.assertAlmostEqual(pct, 50.0)    # single battery named BAT1 (some Dells)

    def test_default_is_total(self):
        pct, label = sm.watched_battery(pl.conf())
        self.assertAlmostEqual(pct, pl.battery_pct()); self.assertEqual(label, "battery")

    # --- battery guard (watches BAT1 on the fake two-battery ThinkPad)
    def slice_at(self, pct, power_uw=8000000, status="Discharging"):
        full = 2190000
        supply("BAT1", "Battery", energy_now=int(full * pct / 100), energy_full=full, power_now=power_uw, status=status)

    def guard_tick(self, t):
        sm.time.monotonic = lambda: t
        return self.d.tick()

    def test_guard_idle_on_ac_and_healthy_battery(self):
        self.slice_at(5); self.guard_tick(0)                                   # AC (default): nothing at all
        self.assertFalse(self.ginh.held); self.assertFalse(self.rec.has("Battery"))
        thinkpad(ac=False); self.slice_at(80, power_uw=1000000)                # 80%, ~105 min: armed, silent
        self.assertEqual(self.guard_tick(1)["guard"], "armed")
        self.assertFalse(self.ginh.held); self.assertFalse(self.rec.has("Battery"))

    def test_guard_blocks_suspend_below_threshold(self):
        thinkpad(ac=False); self.slice_at(29, power_uw=500000)
        self.guard_tick(0)
        self.assertTrue(self.ginh.held)

    def test_guard_warns_once(self):
        thinkpad(ac=False); self.slice_at(14, power_uw=500000)                 # 14% but plenty of minutes
        self.assertEqual(self.guard_tick(0)["guard"], "warned"); self.guard_tick(2)
        self.assertEqual(sum("Battery low" in c for c in self.rec.calls), 1)

    def test_guard_countdown_then_poweroff(self):
        thinkpad(ac=False); self.slice_at(6, power_uw=500000)
        self.assertEqual(self.guard_tick(100)["guard"], "countdown")
        self.assertTrue(self.rec.has("Shutting down in 30 s"))
        self.guard_tick(120); self.assertFalse(self.rec.has("systemctl poweroff"))
        self.guard_tick(130.5); self.assertEqual(self.rec.calls.count("systemctl poweroff"), 1)
        self.guard_tick(140); self.assertEqual(self.rec.calls.count("systemctl poweroff"), 1)   # only once

    def test_guard_ac_cancels_countdown(self):
        thinkpad(ac=False); self.slice_at(6, power_uw=500000); self.guard_tick(100)
        supply("AC", "Mains", online=1)
        self.guard_tick(110)
        self.assertTrue(self.rec.has("shutdown cancelled")); self.assertFalse(self.ginh.held)
        self.guard_tick(200); self.assertFalse(self.rec.has("systemctl poweroff"))

    def test_guard_acts_on_minutes_left_for_a_small_worn_battery(self):
        thinkpad(ac=False); self.slice_at(40, power_uw=15000000)               # 40% of 2.19 Wh at 15 W = ~3.5 min
        info = self.guard_tick(0)
        self.assertEqual(info["guard"], "countdown"); self.assertLess(info["guard_min"], 4)

    def test_guard_hibernate_releases_its_sleep_block_first(self):
        w(TMP / "power.conf", "GUARD_ACTION=hibernate\nGUARD_GRACE=0\n")
        thinkpad(ac=False); self.slice_at(5, power_uw=500000)
        self.guard_tick(0); self.guard_tick(1)
        self.assertTrue(self.rec.has("systemctl hibernate")); self.assertFalse(self.ginh.held)

    def test_guard_notify_only(self):
        w(TMP / "power.conf", "GUARD_ACTION=none\n")
        thinkpad(ac=False); self.slice_at(5, power_uw=500000)
        self.guard_tick(0); self.guard_tick(100)
        self.assertTrue(self.rec.has("Plug in power now")); self.assertFalse(self.rec.has("systemctl"))

    def test_guard_disabled(self):
        w(TMP / "power.conf", "GUARD_ENABLED=0\n")
        thinkpad(ac=False); self.slice_at(3, power_uw=500000)
        self.assertEqual(self.guard_tick(0)["guard"], "off")
        self.assertFalse(self.ginh.held); self.assertFalse(self.rec.has("Battery"))

    def test_guard_handles_the_lid_like_server_mode(self):
        sm.i3lock_running = lambda: True
        thinkpad(ac=False); self.slice_at(20, power_uw=500000)                 # guard awake, server mode OFF
        w(TMP / "lid", "closed")
        self.guard_tick(0); self.guard_tick(2.5)
        self.assertTrue(self.rec.has("xset dpms force off")); self.assertFalse(self.rec.has("systemctl suspend"))
        w(TMP / "lid", "open"); self.guard_tick(10)
        self.assertTrue(self.rec.has("xrefresh"))

    def test_guard_uses_the_only_battery_on_a_single_battery_laptop(self):
        remove_battery("BAT1"); supply("AC", "Mains", online=0)
        supply("BAT0", "Battery", energy_now=int(50000000 * 0.05), energy_full=50000000, power_now=9000000, status="Discharging")
        info = self.guard_tick(0)
        self.assertEqual(info["guard_battery"], "BAT0"); self.assertEqual(info["guard"], "countdown")

    # --- battery switch (fake ThinkPad with charge_behaviour on both batteries)
    def with_switch(self, ac=False, ext=(50, 8000000), internal=95):
        thinkpad(ac=ac)
        full1, full0 = 2190000, 15670000
        supply("BAT1", "Battery", energy_now=int(full1 * ext[0] / 100), energy_full=full1, power_now=ext[1],
               status="Discharging" if not ac else "Not charging", charge_behaviour="[auto] inhibit-charge force-discharge")
        supply("BAT0", "Battery", energy_now=int(full0 * internal / 100), energy_full=full0, power_now=0,
               status="Not charging", charge_behaviour="[auto] inhibit-charge force-discharge")

    def test_switch_waits_while_external_has_charge(self):
        self.with_switch(ext=(50, 1000000))                                    # 50%, ~66 min
        self.assertEqual(self.d.tick()["switch"], "watching BAT1")
        self.assertEqual(pl.charge_mode("BAT0"), "auto")

    def test_switch_to_internal_before_external_runs_dry(self):
        self.with_switch(ext=(14, 1000000))
        info = self.d.tick()
        self.assertEqual(info["switch"], "on BAT0"); self.assertEqual(pl.charge_mode("BAT0"), "force-discharge")
        self.assertTrue(self.rec.has("now running on BAT0"))
        self.assertEqual(info["guard_battery"], "BAT0")                        # the guard follows the battery in use
        self.assertEqual(info["guard"], "armed"); self.assertFalse(self.ginh.held)   # internal at 95%: all fine
        self.d.tick(); self.assertEqual(sum("now running on BAT0" in c for c in self.rec.calls), 1)   # once

    def test_switch_on_minutes_left(self):
        self.with_switch(ext=(30, 4000000))                                    # 30% of 2.19 Wh at 4 W = ~10 min
        self.assertEqual(self.d.tick()["switch"], "on BAT0")

    def test_no_switch_when_internal_is_low_too(self):
        self.with_switch(ext=(12, 1000000), internal=8)
        self.assertEqual(self.d.tick()["switch"], "watching BAT1"); self.assertEqual(pl.charge_mode("BAT0"), "auto")

    def test_ac_gives_batteries_back_to_the_firmware(self):
        self.with_switch(ext=(14, 1000000)); self.d.tick()
        self.assertEqual(pl.charge_mode("BAT0"), "force-discharge")
        supply("AC", "Mains", online=1)
        self.assertEqual(self.d.tick()["switch"], "ac"); self.assertEqual(pl.charge_mode("BAT0"), "auto")

    def test_switch_cannot_write_warns_once(self):
        self.with_switch(ext=(14, 1000000))
        orig = pl.set_charge_behaviour
        pl.set_charge_behaviour = lambda n, v: False
        try:
            self.d.tick(); self.d.tick()
        finally:
            pl.set_charge_behaviour = orig
        self.assertEqual(sum("Battery switch unavailable" in c for c in self.rec.calls), 1)

    def test_switch_disabled_and_single_battery(self):
        w(TMP / "power.conf", "SWITCH_ENABLED=0\n")
        self.with_switch(ext=(5, 1000000)); self.assertEqual(self.d.tick()["switch"], "off")
        w(TMP / "power.conf", "")
        remove_battery("BAT1"); self.assertEqual(self.d.tick()["switch"], "n/a")

    def test_already_forced_stays(self):
        self.with_switch(ext=(60, 1000000))
        pl.set_charge_behaviour("BAT0", "force-discharge")
        self.assertEqual(self.d.tick()["switch"], "on BAT0"); self.assertEqual(pl.charge_mode("BAT0"), "force-discharge")

    def test_active_battery_pick(self):
        self.with_switch(ext=(60, 1000000))
        self.assertEqual(pl.pick_battery("active")[1], "BAT1")                 # the discharging one
        pl.set_charge_behaviour("BAT0", "force-discharge")
        self.assertEqual(pl.pick_battery("active")[1], "BAT0")                 # the forced one wins

    def test_bar_text(self):
        self.assertIn(sm.DIM, sm.bar_text({"on": False, "ac": True, "pct": 90}))
        on_ac = sm.bar_text({"on": True, "ac": True, "pct": 90})
        self.assertIn(sm.BRIGHT, on_ac); self.assertNotIn("90", on_ac)
        self.assertIn("54%%", sm.bar_text({"on": True, "ac": False, "pct": 54.2}))


class KbdTest(unittest.TestCase):
    """New behaviour: a keypress lights the keyboard (minimal level), 5 s after the last keypress it turns off."""

    def run_steps(self, k, steps, timeout=5, level=1, lid=False):
        """steps: [(time, cur_level, key_pressed_now)] -> list of returned levels."""
        out = []
        for t, cur, pressed in steps:
            if pressed:
                k.key(t)
            out.append(k.step(t, cur, timeout, lid, level))
        return out

    def test_keypress_lights_minimal_then_off_after_five_seconds(self):
        k = kb.Kbd(0.0)
        # long idle, light already off: stays off
        self.assertEqual(self.run_steps(k, [(100, 0, False)]), [None])
        # key pressed: lit at the minimal level
        self.assertEqual(self.run_steps(k, [(101, 0, True)]), [1])
        # still within 5 s of the last key: stays lit
        self.assertEqual(self.run_steps(k, [(103, 1, False), (105.9, 1, False)]), [None, None])
        # more typing extends it
        self.assertEqual(self.run_steps(k, [(106, 1, True), (110, 1, False)]), [None, None])
        # 5 s after the last keypress: off
        self.assertEqual(self.run_steps(k, [(111.0, 1, False)]), [0])

    def test_off_exactly_at_timeout_boundary(self):
        k = kb.Kbd(0.0); k.key(10.0)
        self.assertIsNone(k.step(14.99, 1, 5, False, 1))
        self.assertEqual(k.step(15.0, 1, 5, False, 1), 0)

    def test_startup_grace_then_off(self):
        k = kb.Kbd(50.0)                                                       # daemon starts with the light on
        self.assertIsNone(k.step(52, 1, 5, False, 1))
        self.assertEqual(k.step(55.1, 1, 5, False, 1), 0)

    def test_lid_closed_keeps_it_off_even_when_typing(self):
        k = kb.Kbd(0.0); k.key(1.0)
        self.assertEqual(k.step(1.5, 1, 5, True, 1), 0)
        k.key(2.0)
        self.assertIsNone(k.step(2.1, 0, 5, True, 1))
        k.key(3.0)
        self.assertEqual(k.step(3.1, 0, 5, False, 1), 1)                       # lid open again: typing lights it

    def test_user_chosen_brighter_level_is_kept_while_typing(self):
        k = kb.Kbd(0.0); k.key(1.0)
        self.assertIsNone(k.step(1.0, 2, 5, False, 1))                         # user has level 2 (Fn+Space): no lowering to 1
        self.assertEqual(k.step(7.0, 2, 5, False, 1), 0)                       # still turns off when typing stops

    def test_manual_toggle_counts_as_activity(self):
        k = kb.Kbd(0.0)
        self.assertEqual(k.step(100, 1, 5, False, 1), 0)                       # idle: turned off, we asked for 0
        self.assertIsNone(k.step(101, 0, 5, False, 1))
        self.assertIsNone(k.step(102, 2, 5, False, 1))                         # Fn+Space changed it behind our back: leave it
        self.assertIsNone(k.step(106, 2, 5, False, 1))                         # ... for the timeout
        self.assertEqual(k.step(107.1, 2, 5, False, 1), 0)

    def test_level_zero_restores_the_previous_level(self):
        k = kb.Kbd(0.0); k.step(1.0, 2, 5, False, 0)                           # saw level 2 earlier
        self.assertEqual(k.step(20, 2, 5, False, 0), 0)
        k.key(30.0)
        self.assertEqual(k.step(30.0, 0, 5, False, 0), 2)

    def test_timeout_zero_never_turns_off(self):
        k = kb.Kbd(0.0)
        self.assertIsNone(k.step(9999, 1, 0, False, 1))

    def test_wait_is_short_only_while_lit(self):
        k = kb.Kbd(0.0); k.key(10.0)
        self.assertAlmostEqual(k.wait(12.0, 1, 5), 1.0)
        self.assertAlmostEqual(k.wait(14.5, 1, 5), 0.5)
        self.assertEqual(k.wait(20.0, 0, 5), 1.0)

    def test_only_keyboard_events_count_by_default(self):
        key = "EVENT type 13 (RawKeyPress)\n    device: 12"
        self.assertTrue(kb.is_activity(key))
        self.assertFalse(kb.is_activity("EVENT type 14 (RawKeyRelease)\nEVENT type 17 (RawMotion)\nEVENT type 15 (RawButtonPress)"))
        self.assertTrue(kb.is_activity("EVENT type 17 (RawMotion)", pointer=True))
        self.assertFalse(kb.is_activity("EVENT type 17 (RawMotion)", pointer=False))

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
