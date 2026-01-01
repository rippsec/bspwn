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
        echo "%{A1:$HOME/.config/polybar/scripts/micvol.sh --toggle:} 󰍭 %{A}"
    else
        echo "%{A1:$HOME/.config/polybar/scripts/micvol.sh --toggle:}%{F#FFFFFF}%{B#FF0000} 󰍬 %{B-}%{F-}%{A}"
    fi
}

if [ "$1" = "--toggle" ]; then
    toggle_mic
    exit
fi

get_mic_status
pactl subscribe | while read -r event; do
    if echo "$event" | grep -q "source"; then
        get_mic_status
    fi
done

