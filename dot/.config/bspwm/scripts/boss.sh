#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Spreadsheet key (super+ctrl+e): switch to undercover mode, minimise every other window to the taskbar and
# put a spreadsheet (OnlyOffice, new sheet; or the one already open) maximised on top.
# Under xfwm4 (session launcher) the windows are minimised; with bspwm they are hidden (bspc node -g hidden=on).
BASE="$HOME/.config/bspwm"
log() { logger -t bspwn-boss "$*"; }

if [[ $(cat "$HOME/.cache/bspwn-mode" 2>/dev/null) != undercover ]]; then
  "$BASE/scripts/mode.sh" undercover
  # under the launcher the WM restarts: wait for xfwm4 (mode.sh apply runs 1.5 s after it starts)
  if [[ -n $BSPWN_SESSION ]]; then
    for _ in $(seq 50); do [[ $("$BASE/scripts/session.sh" wm) == xfwm4 ]] && break; sleep 0.2; done
    sleep 2
  fi
fi
wm=$("$BASE/scripts/session.sh" wm)

is_office() { xprop -id "$1" WM_CLASS 2>/dev/null | grep -qi onlyoffice; }
normal_windows() {   # every normal (taskbar) window: no panels, docks, desktop, notifications
  local w
  for w in $(xprop -root _NET_CLIENT_LIST | grep -o '0x[0-9a-f]*'); do
    xprop -id "$w" _NET_WM_WINDOW_TYPE 2>/dev/null | grep -qE 'DOCK|DESKTOP|NOTIFICATION|TOOLBAR|SPLASH' && continue
    echo "$w"
  done
}

# 1. put away everything that is not the spreadsheet
office=
for w in $(normal_windows); do
  if is_office "$w"; then office=$w; continue; fi
  if [[ $wm == bspwm ]]; then bspc node "$w" -g hidden=on 2>/dev/null
  else xdotool windowminimize "$w" 2>/dev/null; fi
done

# 2. the spreadsheet: reuse the open OnlyOffice window, or start one with a new sheet
if [[ -z $office ]]; then
  log "starting OnlyOffice (new spreadsheet)"
  setsid onlyoffice-desktopeditors --new:cell >/dev/null 2>&1 &
  for _ in $(seq 60); do
    for w in $(normal_windows); do is_office "$w" && { office=$w; break 2; }; done
    sleep 0.25
  done
fi
[[ -n $office ]] || { log "no OnlyOffice window appeared"; exit 1; }
if [[ $wm == bspwm ]]; then
  bspc node "$office" -g hidden=off -d focused -t floating -f 2>/dev/null
  bspc node "$office" -t fullscreen 2>/dev/null
else
  wmctrl -i -r "$office" -b add,maximized_vert,maximized_horz 2>/dev/null
  wmctrl -i -a "$office" 2>/dev/null
fi
log "spreadsheet on top ($wm)"
