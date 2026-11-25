#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Kill leftover polybar module scripts (and the `pactl subscribe` helpers they spawn).
#
# Why: modules with `tail = true` run a long-lived script. `killall polybar` stops only the bars,
# so every relaunch (mode.sh apply, launch.sh, bspc wm -r) used to leave the old scripts running,
# orphaned. They pile up over days of uptime or hibernation and each one keeps polling PipeWire.
#
#   polybar-reap.sh all       polybar was just stopped: every module script is stale, kill them all
#   polybar-reap.sh orphans   kill only those whose parent died (PPID 1); safe at any time
#
# The scripts to look for are read from the tail=true modules of the polybar config, so a new
# module is covered without editing this file.
mode=${1:-orphans}
case $mode in all|orphans) ;; *) echo "usage: ${0##*/} all|orphans" >&2; exit 2 ;; esac
CFG=${POLYBAR_CONFIG:-$HOME/.config/polybar/config.ini}
[[ -r $CFG ]] || exit 0

# last path component of every tail=true module's exec line, e.g. "micvol.sh", "servermode.py bar --follow"
PATS=$(awk '
  /^\[/          { if (tail && cmd != "") print cmd; tail = 0; cmd = "" }
  /^exec[ =]/    { sub(/^exec *= */, ""); n = split($0, a, "/"); cmd = a[n] }
  /^tail *= *true/ { tail = 1 }
  END            { if (tail && cmd != "") print cmd }' "$CFG")
[[ -n $PATS ]] || exit 0

# never touch ourselves or anything that started us (a caller whose command line merely mentions a module name)
ANC=" $$ "; p=$$
while (( p > 1 )); do p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' '); [[ -n $p ]] || break; ANC+="$p "; done

kill_tree() {                      # children first, so nothing is re-parented to PID 1 half-dead
  local c
  [[ $ANC == *" $1 "* ]] && return
  for c in $(pgrep -P "$1"); do kill_tree "$c"; done
  kill "$1" 2>/dev/null
}

# The pattern list goes in through the environment, not argv, so awk's own command line never matches it.
roots=$(ps -u "$USER" -o pid=,ppid=,args= | PATS=$PATS MODE=$mode ANC=$ANC awk '
  BEGIN { n = split(ENVIRON["PATS"], P, "\n") }
  { pid = $1; ppid = $2; $1 = $2 = ""; args = substr($0, 3)
    if (index(ENVIRON["ANC"], " " pid " ")) next
    for (i = 1; i <= n; i++)
      if (P[i] != "" && index(args, P[i])) {
        if (ENVIRON["MODE"] == "all" || ppid == 1) print pid
        break
      } }')

count=0
for pid in $roots; do kill_tree "$pid"; count=$((count + 1)); done

# `pactl subscribe` left behind with no parent
for pid in $(pgrep -u "$USER" -x -P 1 pactl); do
  [[ $(tr '\0' ' ' < "/proc/$pid/cmdline" 2>/dev/null) == "pactl subscribe"* ]] && { kill "$pid" 2>/dev/null; count=$((count + 1)); }
done

(( count > 0 )) && logger -t bspwn-reap "$mode: stopped $count stale polybar module process(es)"
exit 0
