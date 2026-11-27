#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Idle lock supervisor (started by bspwm/start).
# LOCK FIRST, THEN SCREEN OFF: a watcher in this script reads the idle time (xssstate) and after IDLE_LOCK seconds runs
# xlock; only once the lock is really on screen (i3lock running) and IDLE_SCREEN_OFF s passed does it turn the display off. So waking the
# screen shows the lock, never the desktop. (Before, X's screensaver/DPMS timers and xss-lock raced: the display went
# off but the lock came late, so a key press showed the unlocked desktop for a moment.) bspwm/start therefore disables
# X's own timers (`xset s off`, `xset dpms 0 0 0`). xss-lock stays for locking before suspend
# (--transfer-sleep-lock: suspend waits until the lock is on screen) and keeps being supervised here.
# Running this again replaces the previous supervisor. Log: journalctl -t idle-lock
rundir=${XDG_RUNTIME_DIR:-/run/user/$EUID}; [[ -d $rundir && -w $rundir ]] || rundir=/tmp
pidf="$rundir/bspwn-idle-lock-${DISPLAY//[^0-9A-Za-z]/_}.pid"

if [[ -f $pidf ]]; then
  old=$(<"$pidf")
  [[ $old =~ ^[0-9]+$ && $old != "$$" ]] && kill "$old" 2>/dev/null && sleep 0.3
fi
echo $$ >"$pidf"

# xss-lock must run INSIDE the login session (bspwm/start is): started from elsewhere (a tmux/Claude shell lives in its
# own systemd scope) logind answers NoSessionForPID and xss-lock aborts at the first blank, right after starting xlock.
if [[ $(</proc/self/cgroup) != *"/session-"* ]]; then
  logger -t idle-lock "WARNING: not inside a login session, xss-lock will crash after each lock; restart it with super+Esc"
fi
pkill -x -U "$EUID" xss-lock 2>/dev/null   # strays started outside this supervisor

# IDLE_LOCK / IDLE_SCREEN_OFF come from power.conf (read again every cycle, so edits apply live); 0 = never lock.
CONF="$HOME/.config/bspwm/power.conf"
conf_get() { sed -n "s/^$1=\([0-9]*\).*/\1/p" "$CONF" 2>/dev/null | head -1; }
child=; watcher=
locked() { pgrep -u "$EUID" -x i3lock >/dev/null; }
# State machine, one step every 2 s, never a long sleep (a sleep here once outlived an unlock and blanked the
# unlocked screen; xss-lock then saw the blank and locked a second time):
# - locked (any way: super+x, power menu, lid, idle): the idle-lock timer is not used. The display goes off once the
#   lock has been up and there was no input for IDLE_SCREEN_OFF s; checked again right before `xset dpms force off`.
# - unlocked: lock after IDLE_LOCK s without input AND IDLE_LOCK s since the last unlock (idle time that piled up
#   while the screen was locked never counts).
watch_idle() {
  local idle off blanked=0 locked_at=0 unlocked_at=$SECONDS
  while :; do
    sleep 2
    IDLE_LOCK=$(conf_get IDLE_LOCK); IDLE_LOCK=${IDLE_LOCK:-300}
    IDLE_SCREEN_OFF=$(conf_get IDLE_SCREEN_OFF); IDLE_SCREEN_OFF=${IDLE_SCREEN_OFF:-10}
    off=$(( IDLE_SCREEN_OFF < 5 ? 5 : IDLE_SCREEN_OFF ))        # >= the "active again" threshold below
    idle=$(xssstate -i 2>/dev/null) || continue
    idle=$(( idle / 1000 ))
    if locked; then
      (( locked_at )) || locked_at=$SECONDS
      unlocked_at=$SECONDS
      (( idle < 5 )) && blanked=0                                # woken up: may go dark again later
      if (( !blanked && SECONDS - locked_at >= off && idle >= off )) && locked; then
        xset dpms force off; blanked=1
        logger -t idle-lock "locked, display off"
      fi
      continue
    fi
    if (( locked_at )); then logger -t idle-lock "unlocked, idle timer restarts"; fi
    locked_at=0; blanked=0
    (( IDLE_LOCK > 0 )) || continue
    (( idle >= IDLE_LOCK && SECONDS - unlocked_at >= IDLE_LOCK )) || continue
    logger -t idle-lock "idle ${idle}s: locking"
    xlock </dev/null >/dev/null 2>&1 &
    unlocked_at=$(( SECONDS - IDLE_LOCK + 10 ))                  # no lock on screen in 10 s: try again
  done
}
watch_idle &
watcher=$!
trap '[[ -n $child ]] && kill "$child" 2>/dev/null; kill "$watcher" 2>/dev/null; [[ $(cat "$pidf" 2>/dev/null) == "$$" ]] && rm -f "$pidf"; exit 0' TERM INT HUP

fails=0
while :; do
  xset q >/dev/null 2>&1 || { logger -t idle-lock "X display $DISPLAY is gone, stopping"; exit 0; }
  start=$SECONDS
  xss-lock --transfer-sleep-lock -- xlock </dev/null >/dev/null 2>&1 &
  child=$!
  wait "$child"; rc=$?
  child=
  (( SECONDS - start < 10 )) && fails=$((fails + 1)) || fails=0
  logger -t idle-lock "xss-lock exited rc=$rc, restarting (quick fails: $fails)"
  sleep $(( fails > 5 ? 30 : 2 ))
done
