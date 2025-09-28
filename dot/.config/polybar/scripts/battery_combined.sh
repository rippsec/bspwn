#!/bin/bash

# Paths to battery information
BAT0="/sys/class/power_supply/BAT0"
BAT1="/sys/class/power_supply/BAT1"
AC="/sys/class/power_supply/AC"

# Initialize variables
bat0_capacity=0
bat1_capacity=0
bat0_status="Unknown"
bat1_status="Unknown"
ac_status=0

# Read battery capacities and statuses
if [[ -f "$BAT0/capacity" ]]; then
    bat0_capacity=$(cat "$BAT0/capacity")
    bat0_status=$(cat "$BAT0/status")
fi
if [[ -f "$BAT1/capacity" ]]; then
    bat1_capacity=$(cat "$BAT1/capacity")
    bat1_status=$(cat "$BAT1/status")
fi
if [[ -f "$AC/online" ]]; then
    ac_status=$(cat "$AC/online")
fi

# Calculate average capacity
total_capacity=$(( (bat0_capacity + bat1_capacity) / 2 ))

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
if [[ $ac_status -eq 1 && ($bat0_status == "Charging" || $bat1_status == "Charging") ]]; then
    icon="$icon󱐋"
fi

# Output format: Icon + Average Capacity
#echo "$icon $total_capacity%"
echo "$icon" # $total_capacity%"

## Optional: Detailed status on click
#if [[ "$1" == "--details" ]]; then
#    echo "BAT0: $bat0_capacity% ($bat0_status)"
#    echo "BAT1: $bat1_capacity% ($bat1_status)"
#    [[ $ac_status -eq 1 ]] && echo "AC: Connected" || echo "AC: Disconnected"
#fi

if [[ "$1" == "--details" ]]; then
    message=$(printf "BAT0: %s%% (%s)\nBAT1: %s%% (%s)\nAC: %s" \
              "$bat0_capacity" "$bat0_status" \
              "$bat1_capacity" "$bat1_status" \
              "$([[ $ac_status -eq 1 ]] && echo "Connected" || echo "Disconnected")")
    notify-send "Battery Details" "$message"
fi


