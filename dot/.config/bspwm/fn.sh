watch_idle() {
  local idle blanked=0 i
  while :; do
    sleep 3
    idle=$(xssstate -i 2>/dev/null) || continue
    idle=$(( idle / 1000 ))
    if (( idle < 5 )); then blanked=0; continue; fi          # user is active again
    (( idle >= IDLE_LOCK )) || continue
    pgrep -u "$EUID" -x i3lock >/dev/null || { logger -t idle-lock "idle ${idle}s: locking"; xlock </dev/null >/dev/null 2>&1 & }
    (( blanked )) && continue
    for i in {1..20}; do pgrep -u "$EUID" -x i3lock >/dev/null && break; sleep 0.5; done
    if pgrep -u "$EUID" -x i3lock >/dev/null; then
      sleep 2                                                 # let the lock paint before the display goes off
      xset dpms force off; blanked=1
      logger -t idle-lock "locked, display off"
    fi
  done
}
