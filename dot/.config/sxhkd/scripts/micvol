#!/bin/bash

# Get the default source index using shell parameter expansion
DEFAULT_SOURCE_INDEX=0
display_volume() {
    if [ -z "$volume" ]; then
        echo "No Mic Found"
    else
        volume="${volume//[[:blank:]]/}"
        if [[ "$mute" == *"yes"* ]]; then
            echo "    "
        else
            echo "%{B#c30505}    %{B-}"
        fi
    fi
}

# Use pactl once to get volume and mute status
pactl_output=$(pactl list sources)
volume=$(awk -v idx=$DEFAULT_SOURCE_INDEX '/#'${idx}'/{found=1;next} /#/ && found{exit} found{print $5}' <<< "$pactl_output")
mute=$(awk -v idx=$DEFAULT_SOURCE_INDEX '/#'${idx}'/{found=1;next} /#/ && found{exit} found{print $2}' <<< "$pactl_output")

case $1 in
    "show-vol")
        display_volume
        ;;
    "inc-vol")
        pactl set-source-volume $DEFAULT_SOURCE_INDEX +7%
        ;;
    "dec-vol")
        pactl set-source-volume $DEFAULT_SOURCE_INDEX -7%
        ;;
    "toggle")
        pactl set-source-mute $DEFAULT_SOURCE_INDEX toggle
        ;;
    *)
        echo -e "Invalid script option\n usage: micvol.sh [ inc-vol| dec-vol| toggle| show-vol ]"
        ;;
esac
