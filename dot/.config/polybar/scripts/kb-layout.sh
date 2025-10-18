#!/bin/bash

# Keyboard Layout Switcher for Polybar
# Save this as ~/.config/polybar/scripts/kb-layout.sh
# Make it executable: chmod +x ~/.config/polybar/scripts/kb-layout.sh

LAYOUT_FILE="/tmp/polybar_kb_layout"

# Initialize layout file if it doesn't exist
if [ ! -f "$LAYOUT_FILE" ]; then
    echo "latam" > "$LAYOUT_FILE"
fi

get_current_layout() {
    cat "$LAYOUT_FILE"
}

switch_layout() {
    current=$(get_current_layout)
    
    if [ "$current" == "latam" ]; then
        setxkbmap ru
        echo "ru" > "$LAYOUT_FILE"
    else
        setxkbmap latam
        echo "latam" > "$LAYOUT_FILE"
    fi
}

display_layout() {
    layout=$(get_current_layout)
    
    case $layout in
        latam)
            echo "LA"
            ;;
        ru)
            echo "RU"
            ;;
        *)
            echo "?"
            ;;
    esac
}

case "$1" in
    switch)
        switch_layout
        display_layout
        ;;
    *)
        display_layout
        ;;
esac
