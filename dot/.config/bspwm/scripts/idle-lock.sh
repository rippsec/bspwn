#!/usr/bin/env bash
# Idle lock supervisor (started by bspwm/start).
# X blanks the screen after `xset s 300` idle (bspwm/start); xss-lock gets that same event and runs xlock, so the
# lock comes up the moment the screen goes dark (DPMS then cuts the backlight at 310 s). xss-lock also locks before
# suspend (--transfer-sleep-lock: suspend waits until the lock is on screen).
# If xss-lock is not running the screen just goes dark UNLOCKED, so this keeps it alive and restarts it if it exits.
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

child=
trap '[[ -n $child ]] && kill "$child" 2>/dev/null; [[ $(cat "$pidf" 2>/dev/null) == "$$" ]] && rm -f "$pidf"; exit 0' TERM INT HUP

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
