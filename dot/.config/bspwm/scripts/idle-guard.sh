#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Keeps the idle lock / screen-off from firing while a video is playing (IDLE_VIDEO_INHIBIT=1 in power.conf).
# Every 30 s: if the focused desktop has a fullscreen window, or a video player (mpv, vlc, celluloid, totem)
# reports "Playing" over MPRIS, reset the X idle timer (`xset s reset`). Single instance.
CONF="$HOME/.config/bspwm/power.conf"
exec 9>"${XDG_RUNTIME_DIR:-/tmp}/idle-guard.lock"; flock -n 9 || exit 0
while sleep 30 9>&-; do   # 9>&-: the sleep must not keep the lock if the script is killed
  [[ $(sed -n 's/^IDLE_VIDEO_INHIBIT=\([0-9]*\).*/\1/p' "$CONF" 2>/dev/null | head -1) == 0 ]] && continue
  video=0
  [[ -n $(bspc query -N -n .fullscreen -d focused 2>/dev/null) ]] && video=1
  (( video )) || { playerctl -p mpv,vlc,celluloid,totem status 2>/dev/null | grep -qx Playing && video=1; }
  if (( video )); then
    xset s reset
  fi
done
