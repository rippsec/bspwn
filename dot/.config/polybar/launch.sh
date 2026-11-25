#!/bin/bash
# Cockpit polybar: three floating islands (see config.ini)
killall -q polybar
# the bar holding the systray can ignore SIGTERM: give it 2 s, then force it
for _ in $(seq 20); do pgrep -x polybar >/dev/null || break; sleep 0.1; done
killall -q -9 polybar 2>/dev/null
# the bars are gone: stop the module scripts they started (tail = true) before starting new ones
"$HOME/.config/bspwm/scripts/polybar-reap.sh" all
for bar in launcher left center right power tray; do
  polybar -q -r "$bar" -c ~/.config/polybar/config.ini >/dev/null 2>&1 &
done
disown -a
# the systray drawer starts closed
(sleep 3; ~/.config/polybar/scripts/traytoggle.sh hide; sleep 2; ~/.config/polybar/scripts/traytoggle.sh hide) >/dev/null 2>&1 &
disown -a
