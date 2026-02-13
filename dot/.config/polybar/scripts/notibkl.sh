#!/bin/bash

# Function to display brightness notification
show_brightness_notification() {
  BRIGHT=$(brightnessctl g)
  MAX=$(brightnessctl m)
  PERCENT=$((BRIGHT * 100 / MAX))
  notify-send -u low -h string:x-canonical-private-synchronous:brightness "Brightness: $PERCENT%" -h int:value:$PERCENT -t 1000
}

# Handle different actions
case "$1" in
  up)
    brightnessctl s +1%
    show_brightness_notification
    ;;
  down)
    brightnessctl s 1%-
    show_brightness_notification
    ;;
  *)
    # Just show notification without changing brightness
    show_brightness_notification
    ;;
esac
