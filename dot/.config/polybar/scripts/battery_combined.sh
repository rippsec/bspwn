#!/bin/bash

# Combines every BAT* under /sys/class/power_supply (one on the Dell, two on a ThinkPad)
AC="/sys/class/power_supply/AC"

ac_status=0
[[ -f "$AC/online" ]] && ac_status=$(cat "$AC/online")

count=0
sum=0
charging=0
details=""
for bat in /sys/class/power_supply/BAT*; do
    [[ -f "$bat/capacity" ]] || continue
    cap=$(cat "$bat/capacity")
    status=$(cat "$bat/status")
    sum=$(( sum + cap ))
    count=$(( count + 1 ))
    [[ $status == "Charging" ]] && charging=1
    details+=$(printf '%s: %s%% (%s)\n' "$(basename "$bat")" "$cap" "$status")$'\n'
done

total_capacity=0
[[ $count -gt 0 ]] && total_capacity=$(( sum / count ))

# Determine icon based on average capacity
if [[ $total_capacity -ge 95 ]]; then
    icon="󰁹"
elif [[ $total_capacity -ge 75 ]]; then
    icon="󰂁"
elif [[ $total_capacity -ge 50 ]]; then
    icon="󰁿"
elif [[ $total_capacity -ge 25 ]]; then
    icon="󰁽"
else
    icon="󰁻"
fi

# Determine charging status
if [[ $ac_status -eq 1 && $charging -eq 1 ]]; then
    icon="$icon󱐋"
fi

echo "$icon"

# Detailed status on click
if [[ "$1" == "--details" ]]; then
    notify-send "Battery Details" "${details}AC: $([[ $ac_status -eq 1 ]] && echo Connected || echo Disconnected)"
fi
