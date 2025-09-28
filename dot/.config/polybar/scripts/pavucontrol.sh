#!/bin/bash

# Check if tui-network is already running
if pgrep -f "/bin/pavucontrol" > /dev/null; then
  # If running, kill it
  pkill -f "/bin/pavucontrol"
else
  # If not running, start it
  /bin/pavucontrol &
fi
