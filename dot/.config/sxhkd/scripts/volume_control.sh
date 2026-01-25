#!/bin/bash
# Volume control script that ensures audio system is awake

ACTION="$1"  # up, down, or mute

# Debug logging
echo "$(date '+%Y-%m-%d %H:%M:%S') - Action: $ACTION, Volume before: $(pamixer --get-volume 2>/dev/null)%" >> /tmp/volume-control-debug.log

# Wake up PipeWire/PulseAudio if suspended
pactl set-sink-volume @DEFAULT_SINK@ +0% 2>/dev/null &

case "$ACTION" in
    up)
        pamixer -i 3 && \
        VOL=$(pamixer --get-volume) && \
        notify-send -u low -h string:x-canonical-private-synchronous:volume "Volume: $VOL%" -h int:value:$VOL -t 1000
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Action: $ACTION, Volume after: $VOL%" >> /tmp/volume-control-debug.log
        ;;
    down)
        pamixer -d 3 && \
        VOL=$(pamixer --get-volume) && \
        notify-send -u low -h string:x-canonical-private-synchronous:volume "Volume: $VOL%" -h int:value:$VOL -t 1000
        echo "$(date '+%Y-%m-%d %H:%M:%S') - Action: $ACTION, Volume after: $VOL%" >> /tmp/volume-control-debug.log
        ;;
    mute)
        pamixer -t && \
        if [ $(pamixer --get-mute) = "true" ]; then \
            notify-send -u low -h string:x-canonical-private-synchronous:volume "Muted" -t 1000; \
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Action: $ACTION, Result: MUTED" >> /tmp/volume-control-debug.log
        else \
            VOL=$(pamixer --get-volume) && \
            notify-send -u low -h string:x-canonical-private-synchronous:volume "Volume: $VOL%" -h int:value:$VOL -t 1000; \
            echo "$(date '+%Y-%m-%d %H:%M:%S') - Action: $ACTION, Volume after: $VOL%" >> /tmp/volume-control-debug.log
        fi
        ;;
esac
