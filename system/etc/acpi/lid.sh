#!/bin/bash
# acpid handler for lid close: lock the graphical session as its OWNER.
# (Suspend itself is handled by systemd-logind.)

log() { echo "[$(date)] $*" >> /var/log/lid.log; }
log "Lid closed"

# Owner of the active graphical session on seat0. Never root: an i3lock started
# as root only accepts the root password, which made unlocking impossible.
ACTIVE_USER=""
while read -r sid _; do
  [[ $(loginctl show-session "$sid" -p Seat --value) == seat0 ]] || continue
  [[ $(loginctl show-session "$sid" -p Active --value) == yes ]] || continue
  ACTIVE_USER=$(loginctl show-session "$sid" -p Name --value)
  break
done < <(loginctl list-sessions --no-legend)

# Fallback: owner of a non-root process that has DISPLAY set (e.g. bspwm)
if [[ -z $ACTIVE_USER || $ACTIVE_USER == root ]]; then
  ACTIVE_USER=$(ps -o user= -C bspwm | grep -v '^root$' | head -n1)
fi

if [[ -z $ACTIVE_USER || $ACTIVE_USER == root ]]; then
  log "Error: no non-root graphical user found, not locking"
  exit 1
fi

USER_ID=$(id -u "$ACTIVE_USER")
USER_HOME=$(getent passwd "$ACTIVE_USER" | cut -d: -f6)

# Take DISPLAY/XAUTHORITY from the user's running window manager
WM_PID=$(pgrep -u "$USER_ID" -x bspwm | head -n1)
if [[ -n $WM_PID ]]; then
  DISPLAY=$(tr '\0' '\n' < /proc/$WM_PID/environ | sed -n 's/^DISPLAY=//p')
  XAUTH=$(tr '\0' '\n' < /proc/$WM_PID/environ | sed -n 's/^XAUTHORITY=//p')
fi
DISPLAY=${DISPLAY:-:0}
XAUTH=${XAUTH:-$USER_HOME/.Xauthority}

if pgrep -u "$USER_ID" -x i3lock >/dev/null; then
  log "Already locked"
  exit 0
fi

log "Locking $ACTIVE_USER on $DISPLAY"
runuser -u "$ACTIVE_USER" -- env DISPLAY="$DISPLAY" XAUTHORITY="$XAUTH" \
  DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/$USER_ID/bus" \
  XDG_RUNTIME_DIR="/run/user/$USER_ID" /usr/local/bin/xlock >/dev/null 2>&1 &

# Give i3lock time to grab the screen before logind suspends
sleep 1
