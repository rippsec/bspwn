#!/bin/bash
# Battery popups (replaces the cbatticon tray icon): low / critical / charged, for every BAT*.
# Called by power-watch.sh on power events and once a minute. Each state is announced once.
#   PS_DIR=/path  overrides /sys/class/power_supply (testing)
PS=${PS_DIR:-/sys/class/power_supply}
STATE="${XDG_RUNTIME_DIR:-/tmp}/battery-notify.state"
LOW=20 CRIT=7

declare -A seen
[[ -r $STATE ]] && while read -r k v; do seen[$k]=$v; done < "$STATE"

for bat in "$PS"/BAT*; do
  [[ -r $bat/capacity ]] || continue
  name=${bat##*/}
  cap=$(<"$bat/capacity"); st=$(<"$bat/status")
  if [[ $st == Discharging ]]; then
    if (( cap <= CRIT )); then level=crit; elif (( cap <= LOW )); then level=low; else level=ok; fi
    if [[ $level != "${seen[$name]}" ]]; then
      case $level in
        crit) notify-send -u critical -t 0 "Battery critical" "$name at ${cap}% — plug in now" ;;
        low)  notify-send -u normal "Battery low" "$name at ${cap}%" ;;
      esac
      seen[$name]=$level
    fi
  elif [[ $st == Full || ( $st == Charging && $cap -ge 100 ) ]]; then
    if [[ ${seen[$name]} != full ]]; then
      notify-send -u low "Battery charged" "$name is full"
      seen[$name]=full
    fi
  else
    seen[$name]=ok                       # charging / not charging: re-arm the warnings
  fi
done

: > "$STATE"
for k in "${!seen[@]}"; do echo "$k ${seen[$k]}" >> "$STATE"; done
