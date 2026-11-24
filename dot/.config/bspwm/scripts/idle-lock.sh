#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rip (rippsec) and contributors. See LICENSE and NOTICE.md.
# Idle lock supervisor (started by bspwm/start).
# LOCK FIRST, THEN SCREEN OFF: a watcher in this script reads the idle time (xssstate) and after IDLE_LOCK seconds runs
# xlock; only once the lock is really on screen (i3lock running) plus 2 s does it turn the display off. So waking the
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

IDLE_LOCK=${IDLE_LOCK:-300}   # seconds of inactivity before the lock
child=; watcher=
watch_idle() {
  local idle blanked=0 i
  while :; do
    sleep 3
    idle=$(xssstate -i 2>/dev/null) || continue
    idle=$(( idle / 1000 ))
    if (( idle < 5 )); then blanked=0; continue; fi          # user is active again
    (( idle >= IDLE_LOCK )) || continue
    pgrep -u "$EUID" -x i3lock >/dev/null || { logger -t idle-lock "idle ${idle}s: locking"; xlock </dev/null >/dev/null 2>&1 & }
    (( blanked )) && continue
    for i in {1..20}; do pgrep -u "$EUID" -x i3lock >/dev/null && break; sleep 0.5; done
    if pgrep -u "$EUID" -x i3lock >/dev/null; then
      sleep 2                                                 # let the lock paint before the display goes off
      xset dpms force off; blanked=1
      logger -t idle-lock "locked, display off"
    fi
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
