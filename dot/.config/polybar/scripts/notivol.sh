#!/bin/bash

# Function to display volume notification
show_volume_notification() {
  if [ "$(pamixer --get-mute)" = "true" ]; then
    notify-send -u low -h string:x-canonical-private-synchronous:volume "Muted" -t 1000
  else
    VOL=$(pamixer --get-volume)
    notify-send -u low -h string:x-canonical-private-synchronous:volume "Volume: $VOL%" -h int:value:$VOL -t 1000
  fi
}

# Handle different actions
case "$1" in
  up)
    pamixer -i 5
    show_volume_notification
    ;;
  down)
    pamixer -d 5
    show_volume_notification
    ;;
  mute)
    pamixer -t
    show_volume_notification
    ;;
  *)
    # Just show notification without changing volume
    show_volume_notification
    ;;
esac
