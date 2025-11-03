#!/bin/bash

# Log execution
echo "[$(date)] Lid event triggered (lock + suspend)" >> /tmp/lid.log

# Function to find the active user
get_active_user() {
    # Try multiple methods to find the active user
    local user=""
    
    # 1. Try loginctl (systemd)
    user=$(loginctl list-sessions --no-legend | awk '($3 == "tty" || $3 == "x11") {print $2}' | head -n1)
    
    # 2. Fallback to who
    [ -z "$user" ] && user=$(who | grep -m1 "(:[0-9])" | awk '{print $1}')
    
    # 3. Fallback to last X11 user
    [ -z "$user" ] && user=$(ps -eo user,comm | awk '/Xorg/ {print $1}' | head -n1)
    
    echo "$user"
}

ACTIVE_USER=$(get_active_user)
[ -z "$ACTIVE_USER" ] && ACTIVE_USER=$(logname 2>/dev/null || echo "")

if [ -z "$ACTIVE_USER" ]; then
    echo "Error: Could not determine active user" >> /tmp/lid.log
    exit 1
fi

# Get user info
USER_HOME=$(getent passwd "$ACTIVE_USER" | cut -d: -f6)
USER_ID=$(id -u "$ACTIVE_USER")

# Find Xauthority
XAUTH=""
for loc in "$USER_HOME/.Xauthority" "/run/user/$USER_ID/gdm/Xauthority" "/run/user/$USER_ID/.Xauthority"; do
    if [ -f "$loc" ]; then
        XAUTH="$loc"
        break
    fi
done

# Get display
DISPLAY=":$(ls /tmp/.X11-unix/ | grep -oP 'X\d+' | sed 's/X//' | head -n1)"
[ -z "$DISPLAY" ] && DISPLAY=":0"

echo "Locking $ACTIVE_USER on $DISPLAY (Xauthority: ${XAUTH:-none})" >> /tmp/lid.log

# Lock screen
if command -v xlock >/dev/null; then
    # Run xlock as the active user
    if [ "$(id -u)" = "0" ]; then
        sudo -u "$ACTIVE_USER" env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTH" xlock &
    else
        env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTH" xlock &
    fi
    
    # Give xlock time to initialize
    sleep 1
    
    # Verify xlock is running
    if ! pgrep -u "$ACTIVE_USER" xlock >/dev/null; then
        echo "Error: xlock failed to start" >> /tmp/lid.log
        exit 1
    fi
else
    echo "Error: xlock not found" >> /tmp/lid.log
    exit 1
fi

# Extra safety delay
