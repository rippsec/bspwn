#!/bin/bash
# Apply the userspace half of the power profile (TLP handles CPU/disk/wifi/PCIe).
#   battery: stop picom, conky HUD, kdeconnect, cap brightness  -> least drain
#   AC:      start them again, restore brightness               -> full eye candy
# usage: power-mode.sh [auto|battery|ac]   (auto = read /sys/class/power_supply/AC)
STATE="${XDG_RUNTIME_DIR:-/run/user/$UID}/power-mode.state"
BAT_BRIGHT=40          # % brightness cap on battery

mode=${1:-auto}
if [[ $mode == auto ]]; then
  [[ $(cat /sys/class/power_supply/AC*/online 2>/dev/null | head -1) == 1 ]] && mode=ac || mode=battery
fi
[[ $(cat "$STATE" 2>/dev/null | head -1) == "$mode" && $2 != --force ]] && exit 0

if [[ $mode == battery ]]; then
  # remember brightness once, then cap it
  cur=$(brightnessctl -m 2>/dev/null | cut -d, -f4 | tr -d %)
  if [[ -n $cur ]]; then
    prev=$(sed -n 's/^brightness=//p' "$STATE" 2>/dev/null)
    [[ -z $prev && $cur -gt $BAT_BRIGHT ]] && saved=$cur || saved=$prev
    [[ $cur -gt $BAT_BRIGHT ]] && brightnessctl -q set "${BAT_BRIGHT}%"
  fi
  pkill -x picom
  pkill -x conky
  pkill -f '^kdeconnect-indicator'; pkill -x kdeconnectd
  systemctl --user stop jarvis 2>/dev/null
  printf 'battery\n' > "$STATE"; [[ -n $saved ]] && echo "brightness=$saved" >> "$STATE"
  [[ $2 != --force ]] && notify-send -u low "Power saver" "On battery: picom, conky and kdeconnect stopped" 2>/dev/null
else
  prev=$(sed -n 's/^brightness=//p' "$STATE" 2>/dev/null)
  [[ -n $prev ]] && brightnessctl -q set "${prev}%"
  pgrep -x picom >/dev/null || picom -b --config "$HOME/.config/picom/picom.conf"
  pgrep -x conky >/dev/null || setsid conky -q -c "$HOME/.config/conky/hud.conf" >/dev/null 2>&1 &
  pgrep -x kdeconnectd >/dev/null || { setsid kdeconnectd >/dev/null 2>&1 & }
  pgrep -f '^kdeconnect-indicator' >/dev/null || { setsid kdeconnect-indicator >/dev/null 2>&1 & }
  [[ -f ~/.config/jarvis/config.toml ]] && systemctl --user start jarvis 2>/dev/null
  printf 'ac\n' > "$STATE"
  [[ $2 != --force ]] && notify-send -u low "Full power" "AC connected: picom, conky and kdeconnect started" 2>/dev/null
fi
