#!/bin/bash
# Volume control: one pactl call to change, one to read, one notification.
# Usage: volume_control.sh up|down|mute
SINK=@DEFAULT_SINK@

notify() {  # $1 = text, $2 = optional percent for the progress bar
    notify-send -u low -h string:x-canonical-private-synchronous:volume \
        ${2:+-h int:value:$2} -t 1000 "$1"
}
get_vol() { pactl get-sink-volume "$SINK" | grep -oE '[0-9]+%' | head -n1 | tr -d '%'; }

case "$1" in
    up|down)
        [ "$1" = up ] && d=+3% || d=-3%
        pactl set-sink-volume "$SINK" "$d"
        VOL=$(get_vol)
        if [ "${VOL:-0}" -gt 100 ]; then          # same 100% cap pamixer had
            pactl set-sink-volume "$SINK" 100%; VOL=100
        fi
        notify "Volume: $VOL%" "$VOL"
        ;;
    mute)
        pactl set-sink-mute "$SINK" toggle
        if [[ "$(pactl get-sink-mute "$SINK")" == *yes* ]]; then
            notify "Muted"
        else
            VOL=$(get_vol); notify "Volume: $VOL%" "$VOL"
        fi
        ;;
    *)
        echo "usage: ${0##*/} up|down|mute" >&2; exit 1
        ;;
esac
