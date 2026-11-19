#!/bin/bash
# Touchpad helper:  touchpad.sh apply | toggle | reset
# Finds the touchpad by name whichever bus it uses:
#   ThinkPad: "Synaptics TM3053-003" (RMI4/SMBus, psmouse.synaptics_intertouch=1)
#             or the legacy "SynPS/2 Synaptics TouchPad" (PS/2)
#   Dell Precision 7780: "VEN_0488:00 0488:1064 Touchpad" (I2C-HID)
# a disabled (floating) device is listed as "∼ Name": strip any leading non-letters
tp_name() { xinput list --name-only 2>/dev/null | grep -m1 -E 'Synaptics|Touchpad' | sed 's/^[^A-Za-z]*//'; }

apply() {
  local tp; tp=$(tp_name) || return 1
  [[ -n $tp ]] || return 1
  xinput set-prop "$tp" 'libinput Accel Speed' -0.1
  xinput set-prop "$tp" 'libinput Scroll Method Enabled' 0 1 0
  xinput set-prop "$tp" 'libinput Horizontal Scroll Enabled' 1
  xinput set-prop "$tp" 'libinput Tapping Enabled' 1
  xinput set-prop "$tp" 'libinput Natural Scrolling Enabled' 1
  xinput set-prop "$tp" 'libinput Disable While Typing Enabled' 1
  xinput set-prop 'TPPS/2 IBM TrackPoint' 'libinput Accel Speed' -0.7 2>/dev/null || true   # ThinkPad only
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
    hid=/sys/bus/i2c/drivers/i2c_hid_acpi
    if compgen -G "$hid/i2c-*" >/dev/null; then      # I2C-HID pad (Dell): rebind
      for d in "$hid"/i2c-*; do
        echo -n "${d##*/}" | sudo tee "$hid/unbind" >/dev/null
        sleep 0.5
        echo -n "${d##*/}" | sudo tee "$hid/bind" >/dev/null
      done
    else                                              # PS/2 / RMI4 pad (ThinkPad)
      sudo modprobe -r psmouse && sudo modprobe psmouse
    fi
    for _ in $(seq 20); do [[ -n $(tp_name) ]] && break; sleep 0.25; done
    xinput enable "$(tp_name)" 2>/dev/null
    apply
    notify-send -u low "Touchpad: reset" ;;
  *) echo "usage: touchpad.sh [apply|toggle|reset]" >&2; exit 2 ;;
esac
