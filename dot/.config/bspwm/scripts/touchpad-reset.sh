#!/bin/bash
# Un-freeze the ThinkPad touchpad: reconnect the PS/2 port (what a reboot would do),
# then re-apply the libinput settings that a re-created device loses.
# Bound to super+shift+e. Needs sudo (drvctl is root-only).
TP='SynPS/2 Synaptics TouchPad'
for s in /sys/bus/serio/devices/serio*; do
  [[ $(cat "$s/description" 2>/dev/null) == *i8042*AUX* ]] || continue
  [[ -w $s/drvctl || -e $s/drvctl ]] || continue
  echo -n reconnect | sudo tee "$s/drvctl" >/dev/null && break
done
for _ in $(seq 20); do xinput list --id-only "$TP" >/dev/null 2>&1 && break; sleep 0.25; done
xinput enable "$TP" 2>/dev/null
xinput set-prop "$TP" 'libinput Accel Speed' -0.1
xinput set-prop "$TP" 'libinput Scroll Method Enabled' 0 1 0
xinput set-prop "$TP" 'libinput Horizontal Scroll Enabled' 1
xinput set-prop "$TP" 'libinput Tapping Enabled' 1
xinput set-prop "$TP" 'libinput Natural Scrolling Enabled' 1
xinput set-prop "$TP" 'libinput Disable While Typing Enabled' 1
xinput set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Speed' -0.7 2>/dev/null
notify-send -u low "Touchpad: reset"
