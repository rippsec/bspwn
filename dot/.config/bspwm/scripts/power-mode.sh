#!/bin/bash
# Apply the userspace half of the power profile (TLP handles CPU/disk/wifi/PCIe).
#   battery: stop picom, conky HUD, kdeconnect, cap brightness  -> least drain
#   AC:      start them again, restore brightness               -> full eye candy
# usage: power-mode.sh [auto|battery|ac]   (auto = read /sys/class/power_supply/AC)
STATE="${XDG_RUNTIME_DIR:-/run/user/$UID}/power-mode.state"
BAT_BRIGHT=40          # % brightness cap on battery

# desktop mode (cockpit | undercover) decides which picom config runs and whether conky starts
DESK=$(cat "$HOME/.cache/bspwn-mode" 2>/dev/null)
[[ -f $HOME/.config/bspwm/modes/$DESK.conf ]] && source "$HOME/.config/bspwm/modes/$DESK.conf"
PICOM_CONF=${PICOM_CONF:-$HOME/.config/picom/picom.conf}
CONKY=${CONKY:-1}
# power.conf PICOM=0 turns the compositor off on this machine (AC and battery); default 1 = picom on AC only
PICOM=$(sed -n 's/^PICOM=\([01]\).*/\1/p' "$HOME/.config/bspwm/power.conf" 2>/dev/null | tail -1)
PICOM=${PICOM:-1}

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
  pkill -x kdeconnectd
  systemctl --user stop jarvis 2>/dev/null
  printf 'battery\n' > "$STATE"; [[ -n $saved ]] && echo "brightness=$saved" >> "$STATE"
  [[ $2 != --force ]] && notify-send -u low "Power saver" "On battery: picom, conky and kdeconnect stopped" 2>/dev/null
else
  prev=$(sed -n 's/^brightness=//p' "$STATE" 2>/dev/null)
  [[ -n $prev ]] && brightnessctl -q set "${prev}%"
  if [[ $PICOM == 1 ]]; then
    pgrep -x picom >/dev/null || picom -b --config "$PICOM_CONF"
  else
    pkill -x picom
  fi
  [[ $CONKY == 1 ]] && { pgrep -x conky >/dev/null || setsid conky -q -c "$HOME/.config/conky/hud.conf" >/dev/null 2>&1 & }
  pgrep -x kdeconnectd >/dev/null || { setsid kdeconnectd >/dev/null 2>&1 & }
  [[ -f ~/.config/jarvis/config.toml ]] && systemctl --user start jarvis 2>/dev/null
  printf 'ac\n' > "$STATE"
  [[ $2 != --force ]] && notify-send -u low "Full power" "AC connected: picom, conky and kdeconnect started" 2>/dev/null
fi
