#!/bin/bash
# Event-driven (no polling): react to AC plug/unplug via udev and run power-mode.sh.
pkill -f 'udevadm monitor.*power_supply' 2>/dev/null
udevadm monitor -u -s power_supply 2>/dev/null | while read -r _ _ _ dev _; do
  [[ $dev == */AC* || $dev == */ADP* ]] || continue
  sleep 1
  "$HOME/.config/bspwm/scripts/power-mode.sh" auto
done
