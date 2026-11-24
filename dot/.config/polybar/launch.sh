#!/bin/bash
# Cockpit polybar: three floating islands (see config.ini)
killall -q polybar
# the bar holding the systray can ignore SIGTERM: give it 2 s, then force it
for _ in $(seq 20); do pgrep -x polybar >/dev/null || break; sleep 0.1; done
killall -q -9 polybar 2>/dev/null
for bar in launcher left center right power; do
  polybar -q -r "$bar" -c ~/.config/polybar/config.ini >/dev/null 2>&1 &
done
disown -a
