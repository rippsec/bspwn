#!/bin/bash
# ~/.config/sxhkd/scripts/floating.sh

# Set window to floating
bspc node -t floating

# Get screen dimensions
screen_width=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f1)
screen_height=$(xdpyinfo | grep dimensions | awk '{print $2}' | cut -d'x' -f2)

# Calculate target size (50% of screen)
target_width=$((screen_width / 2))
target_height=$((screen_height / 2))

# Calculate position to center the window
pos_x=$(( (screen_width - target_width) / 2 ))
pos_y=$(( (screen_height - target_height) / 2 ))

# Use wid to get window id
wid=$(bspc query -N -n focused)

# Set size and position directly
xdotool windowsize $wid $target_width $target_height
xdotool windowmove $wid $pos_x $pos_y
