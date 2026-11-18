#!/bin/bash
# ThinkPad touchpad helper:  touchpad.sh apply | toggle | reset
# Finds the touchpad by name whichever bus it uses: "Synaptics TM3053-003" (RMI4/SMBus,
# psmouse.synaptics_intertouch=1) or the legacy "SynPS/2 Synaptics TouchPad" (PS/2).
tp_name() { xinput list --name-only 2>/dev/null | grep -m1 'Synaptics'; }

apply() {
  local tp; tp=$(tp_name) || return 1
  [[ -n $tp ]] || return 1
  xinput set-prop "$tp" 'libinput Accel Speed' -0.1
  xinput set-prop "$tp" 'libinput Scroll Method Enabled' 0 1 0
  xinput set-prop "$tp" 'libinput Horizontal Scroll Enabled' 1
  xinput set-prop "$tp" 'libinput Tapping Enabled' 1
  xinput set-prop "$tp" 'libinput Natural Scrolling Enabled' 1
  xinput set-prop "$tp" 'libinput Disable While Typing Enabled' 1
  xinput set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Speed' -0.7 2>/dev/null
}

case ${1:-apply} in
  apply) apply ;;
  toggle)
    tp=$(tp_name); [[ -n $tp ]] || { notify-send -u low "Touchpad: not found"; exit 1; }
    en=$(xinput list-props "$tp" | awk -F: '/Device Enabled/{gsub(/[ \t]/,"",$2);print $2}')
    if [[ $en == 1 ]]; then xinput disable "$tp"; notify-send -u low "Touchpad: DISABLED"
    else xinput enable "$tp"; notify-send -u low "Touchpad: ENABLED"; fi ;;
  reset)
    # what a reboot would do for the touchpad: reload the driver, then re-apply settings
    sudo modprobe -r psmouse && sudo modprobe psmouse
    for _ in $(seq 20); do [[ -n $(tp_name) ]] && break; sleep 0.25; done
    xinput enable "$(tp_name)" 2>/dev/null
    apply
    notify-send -u low "Touchpad: reset" ;;
  *) echo "usage: touchpad.sh [apply|toggle|reset]" >&2; exit 2 ;;
esac
