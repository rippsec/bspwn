#!/bin/bash
# Un-freeze the Dell Precision 7780 I2C-HID touchpad: rebind the HID driver
# (what a reboot would do), then re-apply the libinput settings that a re-created
# device loses. Bound to super+shift+e. Needs sudo for the rebind.
TP='VEN_0488:00 0488:1064 Touchpad'
for d in /sys/bus/i2c/drivers/i2c_hid_acpi/i2c-*; do
  [[ -e $d ]] || continue
  dev=${d##*/}
  echo -n "$dev" | sudo tee /sys/bus/i2c/drivers/i2c_hid_acpi/unbind >/dev/null
  sleep 0.5
  echo -n "$dev" | sudo tee /sys/bus/i2c/drivers/i2c_hid_acpi/bind >/dev/null
done
for _ in $(seq 20); do xinput list --id-only "$TP" >/dev/null 2>&1 && break; sleep 0.25; done
xinput enable "$TP" 2>/dev/null
xinput set-prop "$TP" 'libinput Accel Speed' -0.1
xinput set-prop "$TP" 'libinput Scroll Method Enabled' 0 1 0
xinput set-prop "$TP" 'libinput Horizontal Scroll Enabled' 1
xinput set-prop "$TP" 'libinput Tapping Enabled' 1
xinput set-prop "$TP" 'libinput Natural Scrolling Enabled' 1
xinput set-prop "$TP" 'libinput Disable While Typing Enabled' 1
notify-send -u low "Touchpad: reset"
