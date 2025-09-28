#!/bin/bash

# Check if one or three arguments are provided
if [ $# -ne 1 ] && [ $# -ne 3 ]; then
    echo -e "[+] Usage: autocolor <first_color> [<second_color> <background_color>]"
    echo -e "\tExample with one color: autocolor \"#FF0000\""
    echo -e "\tExample with three colors: autocolor \"#FF0000\" \"#00FF00\" \"#0000FF\""
    exit 1
fi

# Validate hex color format for provided arguments
if [ $# -eq 1 ]; then
    if ! [[ $1 =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        echo "Error: Color must be in #RRGGBB format (e.g., #FF0000)"
        exit 1
    fi
elif [ $# -eq 3 ]; then
    if ! [[ $1 =~ ^#[0-9A-Fa-f]{6}$ ]] || ! [[ $2 =~ ^#[0-9A-Fa-f]{6}$ ]] || ! [[ $3 =~ ^#[0-9A-Fa-f]{6}$ ]]; then
        echo "Error: Colors must be in #RRGGBB format (e.g., #FF0000)"
        exit 1
    fi
fi

CONFIG_DIR="$HOME/.config"

# Function to generate darker color using Python
generate_darker_color() {
    python3 -c "import sys; h=sys.argv[1].lstrip('#'); f=float(sys.argv[2]); \
    print('#' + ''.join([f'{max(0, min(255, round(int(h[i:i+2],16)*f))):02x}' for i in range(0,6,2)]))" "$1" "$2"
}

# Assign colors based on arguments
if [ $# -eq 1 ]; then
    FIRST_COLOR=$1
    SECOND_COLOR=$(generate_darker_color "$FIRST_COLOR" 0.75)
    THIRD_COLOR=$(generate_darker_color "$FIRST_COLOR" 0.55)
else
    FIRST_COLOR=$1
    SECOND_COLOR=$2
    THIRD_COLOR=$3
fi

# Replace first color lines
sed -i "s|^primary = #\([0-9A-Fa-f]\{6\}\)$|primary = $FIRST_COLOR|" "$CONFIG_DIR/polybar/config.ini"
sed -i "s|label-mounted = %{F#\([0-9A-Fa-f]\{6\}\)}|label-mounted = %{F$FIRST_COLOR}|" "$CONFIG_DIR/polybar/config.ini"
sed -i "s|date = %d/%m/%y %{F#\([0-9A-Fa-f]\{6\}\)} %a %{F-} %I:%M:%S|date = %d/%m/%y %{F$FIRST_COLOR} %a %{F-} %I:%M:%S|" "$CONFIG_DIR/polybar/config.ini"
sed -i "s|label = %{F#\([0-9A-Fa-f]\{6\}\)}|label = %{F$FIRST_COLOR}|" "$CONFIG_DIR/polybar/config.ini"
sed -i "s|^active_tab_foreground   #\([0-9A-Fa-f]\{6\}\)$|active_tab_foreground   $FIRST_COLOR|" "$CONFIG_DIR/kitty/colors.conf"
sed -i "s|hsetroot -solid \"#\([0-9A-Fa-f]\{6\}\)\" -center \"\$default_bg\"|hsetroot -solid \"$FIRST_COLOR\" -center \"\$default_bg\"|" "$CONFIG_DIR/bspwm/start"
sed -i "s|bspc config focused_border_color \"#\([0-9A-Fa-f]\{6\}\)\"|bspc config focused_border_color \"$FIRST_COLOR\"|" "$CONFIG_DIR/bspwm/bspwmrc"

# Replace second color lines
sed -i "s|^occupied = #\([0-9A-Fa-f]\{6\}\)$|occupied = $SECOND_COLOR|" "$CONFIG_DIR/polybar/config.ini"
sed -i "s|^active_border_color #\([0-9A-Fa-f]\{6\}\)$|active_border_color $SECOND_COLOR|" "$CONFIG_DIR/kitty/colors.conf"
sed -i "s|^inactive_border_color #\([0-9A-Fa-f]\{6\}\)$|inactive_border_color $SECOND_COLOR|" "$CONFIG_DIR/kitty/colors.conf"
sed -i "s|^cursor #\([0-9A-Fa-f]\{6\}\)$|cursor $SECOND_COLOR|" "$CONFIG_DIR/kitty/colors.conf"


# Replace third color lines
sed -i "s|bg_color='%{%K{#\([0-9A-Fa-f]\{6\}\)}%}'|bg_color='%{%K{$THIRD_COLOR}%}'|" "$HOME/.zshrc"


# Completed message
echo "Colors updated successfully!"
echo "First color ($FIRST_COLOR), Second color ($SECOND_COLOR), and Third color ($THIRD_COLOR) applied."

# Reload bspwm colors and settings
bspc wm -r

# Update kitty colors if running inside kitty
if [ -n "$KITTY_PID" ] || [ "$TERM" = "xterm-kitty" ]; then
    # If using a kitty color scheme file (e.g., ~/.config/kitty/current-theme.conf)
    if [ -f ~/.config/kitty/current-theme.conf ]; then
        kitty @ set-colors --all --configured ~/.config/kitty/current-theme.conf
    else
        # Alternatively, reload the entire config
        kitty @ load-config
    fi
fi
