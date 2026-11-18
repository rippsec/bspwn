#!/bin/bash
# Event-driven power watcher (one process, no polling loop of its own):
#   AC plug/unplug  -> power-mode.sh (stop/start picom, conky, ...) + battery popups
#   BAT events      -> battery-notify.sh
#   every 60 s      -> battery-notify.sh (some ThinkPad batteries send no udev event per percent)
S="$HOME/.config/bspwm/scripts"
pkill -f 'udevadm monitor.*power_supply' 2>/dev/null
udevadm monitor -u -s power_supply 2>/dev/null | while true; do
  if read -r -t 60 _ _ _ dev _; then
    case $dev in
      */AC*|*/ADP*) sleep 1; "$S/power-mode.sh" auto; "$S/battery-notify.sh" ;;
      */BAT*)       "$S/battery-notify.sh" ;;
    esac
  else
    rc=$?
    (( rc > 128 )) && "$S/battery-notify.sh" || break      # timeout -> periodic check; EOF -> stop
  fi
done
