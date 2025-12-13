# Initialize prompt style
PROMPT_STYLE=ipdir

# Control variable for detailed prompt
ENABLE_DETAILED_PROMPT=false

# Set color prompt (from lines 114-143)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes ;;
esac

force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
        color_prompt=yes
    else
        color_prompt=
    fi
fi
