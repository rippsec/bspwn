TERMINAL=qterminal
terminal=${TERMINAL:-xterm}  # Default terminal, fallback to xterm if not set

# Check if tui-network is already running
if pgrep -f "$terminal -e tui-network" > /dev/null; then
  # If running, kill it
  pkill -f "$terminal -e tui-network"
else
  # If not running, start it with a specific title
  $terminal -e tui-network &
fi
