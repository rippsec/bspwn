#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Session launcher (run by /usr/local/bin/bspwn-session, the LightDM "bspwn" session; also ~/.xsession). One login session, two window managers:
#   bspwm  (cockpit mode: tiling)
#   xfwm4  (undercover mode: floating windows with Windows-10 frames, title bars and buttons)
# Usage:
#   session.sh            run the session loop (from ~/.xsession)
#   session.sh switch WM  replace the running WM with WM (bspwm|xfwm4); used by mode.sh
#   session.sh quit       end the session (log out), whatever the WM
#   session.sh wm         print the running WM: bspwm | xfwm4 | none
# The loop starts bspwm (bspwmrc -> start -> mode.sh apply); mode.sh asks for xfwm4 when the mode is undercover.
# A WM that exits without a switch request ends the session (logout); one that dies within 5 s falls back to bspwm.
# xfwm4 runs on a private D-Bus with its own xfconf (~/.cache/bspwn/xfwm4, copied from bspwm/xfwm4/xfwm4.xml),
# so XFCE's own settings are never changed. Log: journalctl -t bspwn-session
RUN=${XDG_RUNTIME_DIR:-/tmp}
REQ="$RUN/bspwn-wm-switch"
QUIT="$RUN/bspwn-wm-quit"
XPID="$RUN/bspwn-xfwm4.pid"
XCFG="$HOME/.cache/bspwn/xfwm4"
BASE="$HOME/.config/bspwm"
log() { logger -t bspwn-session "$*"; }

running_wm() {
  if [[ -f $XPID ]] && kill -0 "$(<"$XPID")" 2>/dev/null; then echo xfwm4
  elif bspc query -D >/dev/null 2>&1; then echo bspwm
  else echo none; fi
}
stop_wm() {
  case $(running_wm) in
    bspwm) bspc quit ;;
    xfwm4) kill "$(<"$XPID")" ;;
  esac
}

case $1 in
  wm) running_wm; exit 0 ;;
  switch)
    [[ $2 == bspwm || $2 == xfwm4 ]] || { echo "usage: session.sh switch bspwm|xfwm4" >&2; exit 2; }
    [[ -n $BSPWN_SESSION ]] || { echo "not running under session.sh (~/.xsession)" >&2; exit 1; }
    [[ $(running_wm) == "$2" ]] && exit 0
    echo "$2" >"$REQ"
    log "switch to $2 requested"
    stop_wm
    exit 0 ;;
  quit)
    rm -f "$REQ"
    : >"$QUIT"
    [[ $(running_wm) == none ]] && exit 1
    stop_wm
    exit 0 ;;
  "") ;;
  *) echo "usage: session.sh [switch bspwm|xfwm4 | quit | wm]" >&2; exit 2 ;;
esac

# ---------------------------------------------------------------- session loop
export BSPWN_SESSION=1
rm -f "$REQ" "$QUIT" "$XPID"
wm=bspwm
quick=0
while :; do
  start=$SECONDS
  case $wm in
    xfwm4)
      mkdir -p "$XCFG/xfce4/xfconf/xfce-perchannel-xml"
      cp -f "$BASE/xfwm4/xfwm4.xml" "$XCFG/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml"
      log "starting xfwm4"
      XDG_CONFIG_HOME=$XCFG dbus-run-session -- sh -c 'echo $$ >"$1"; exec xfwm4 --compositor=off' sh "$XPID" &
      p=$!
      ( sleep 1.5; "$BASE/scripts/mode.sh" apply ) >/dev/null 2>&1 &
      wait "$p"
      rm -f "$XPID" ;;
    *)
      log "starting bspwm"
      bspwm ;;
  esac
  if [[ -f $REQ ]]; then
    wm=$(<"$REQ"); rm -f "$REQ"; quick=0
    log "switching to $wm"
    continue
  fi
  if [[ -f $QUIT ]]; then rm -f "$QUIT"; log "logout requested"; break; fi
  if (( SECONDS - start < 5 )) && (( ++quick <= 3 )); then
    log "$wm died after $((SECONDS - start)) s, falling back to bspwm (cockpit)"
    echo cockpit >"$HOME/.cache/bspwn-mode"
    wm=bspwm
    continue
  fi
  log "$wm exited, ending the session"
  break
done
