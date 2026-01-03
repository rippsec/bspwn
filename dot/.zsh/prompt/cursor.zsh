#!/usr/bin/env zsh

# cursor.zsh - A module to manage terminal cursor styles
# Usage: source ~/path/to/cursor.zsh

# --- Available Styles Reference ---
# 0 or 1 -> Blinking Block
# 2      -> Steady Block
# 3      -> Blinking Underline
# 4      -> Steady Underline
# 5      -> Blinking Vertical Line (Bar)
# 6      -> Steady Vertical Line (Bar)

set_terminal_cursor() {
    local style=${1:-5} # Defaults to 5 (Blinking Vertical Line) if no arg provided
    
    # Check if 'tput' supports the 'Ps' capability for the current terminal
    if tput Ps $style >/dev/null 2>&1; then
        tput Ps $style
    else
        # Fallback to raw escape sequence if tput capability is missing
        echo -ne "\e[$style q"
    fi
}

# Execute immediately upon sourcing
set_terminal_cursor 2
