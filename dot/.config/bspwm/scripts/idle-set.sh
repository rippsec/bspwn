#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Idle lock + screen off, from power.conf:
#   IDLE_LOCK=300        seconds without input before the screen locks (xss-lock runs xlock); 0 = never
#   IDLE_SCREEN_OFF=10   seconds after the lock before the display powers off
# Run it again after editing power.conf (it is also run at session start).
CONF="$HOME/.config/bspwm/power.conf"
get() { sed -n "s/^$1=\([0-9]*\).*/\1/p" "$CONF" 2>/dev/null | head -1; }
lock=$(get IDLE_LOCK); off=$(get IDLE_SCREEN_OFF)
lock=${lock:-300}; off=${off:-10}
if (( lock <= 0 )); then
  xset s off; xset dpms 0 0 0
else
  xset s "$lock" 0                              # blank (and so lock, via xss-lock) after $lock s
  xset dpms "$((lock + off))" "$((lock + off))" "$((lock + off))"
fi
