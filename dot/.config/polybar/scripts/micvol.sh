#!/bin/bash

toggle_mic() {
    local source
    source=$(pactl get-default-source)
    pactl set-source-mute "$source" toggle
}

get_mic_status() {
    local source muted
    source=$(pactl get-default-source)
    muted=$(pactl get-source-mute "$source" | grep -o "yes\|no")

    if [ "$muted" = "yes" ]; then
        echo "%{A1:$HOME/.config/polybar/scripts/micvol.sh --toggle:}%{F#52555e} 󰍭 %{F-}%{A}"
    else
        echo "%{A1:$HOME/.config/polybar/scripts/micvol.sh --toggle:}%{u#e5383b}%{o#e5383b}%{+u}%{+o}%{F#e5383b} 󰍬 %{F-}%{-o}%{-u}%{A}"
    fi
}

if [ "$1" = "--toggle" ]; then
    toggle_mic
    exit
fi

get_mic_status

# Run `pactl subscribe` as a coprocess and kill it whenever this script exits,
# so a polybar restart can no longer leave orphaned listeners behind.
coproc SUB { exec pactl subscribe; }
trap 'kill "$SUB_PID" 2>/dev/null' EXIT
trap 'exit 0' TERM INT HUP

while read -r event <&"${SUB[0]}"; do
    [[ $event == *source* ]] && get_mic_status
done
