#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-only
# Wi-Fi menu for the polybar icon (like the NetworkManager applet menu):
#   wifimenu.sh --icon   print the bar icon (on / connected / off)
#   wifimenu.sh          open (or close) the dropdown: list networks, connect, disconnect, Wi-Fi on/off
theme="$HOME/.config/rofi/wifi.rasi"
I_ON=$'\U000f05a9'; I_OFF=$'\U000f092e'; I_LOCK=$'\U000f033e'

if [[ $1 == --icon ]]; then
  if [[ $(nmcli radio wifi) != enabled ]]; then echo "$I_OFF"
  elif nmcli -t -f TYPE,STATE device | grep -q '^wifi:connected'; then echo "$I_ON"
  else echo "$I_OFF"; fi
  exit 0
fi

# toggle: a second click closes the open menu
pid=$(pgrep -x rofi | while read -r p; do
  tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'wifi\.rasi' && echo "$p"
done)
[[ -n $pid ]] && { kill $pid; exit 0; }

menu() { rofi -dmenu -i -p "$1" -theme "$theme" "${@:2}"; }

radio=$(nmcli radio wifi)
if [[ $radio != enabled ]]; then
  [[ $(printf '%s\n' "Turn Wi-Fi on" | menu "wifi") ]] && nmcli radio wifi on
  exit 0
fi

# list the cached scan (instant); `wifi list` alone waits up to ~4 s for a fresh scan. Rescan afterwards for the next open.
known=$(nmcli -t -f NAME connection show)
# fields: IN-USE:SSID:SIGNAL:SECURITY ('\:' inside a value is protected)
mapfile -t nets < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list --rescan no | sed 's/\\:/\x01/g' \
  | awk -F: '$2!="" { gsub(/\x01/,":"); s=$2
      if (!(s in sig)) { order[++n]=s; sig[s]=$3; sec[s]=$4 }   # strongest access point first
      if ($1=="*") use[s]=1 }                                   # the active one may not be the strongest
    END { for (i=1;i<=n;i++) { s=order[i]; printf "%s\t%s\t%s\t%s\n", (use[s]?"●":" "), s, sig[s], sec[s] } }')

lines=()
for n in "${nets[@]}"; do
  IFS=$'\t' read -r use ssid sig sec <<<"$n"
  lock=" "; [[ -n $sec && $sec != -- ]] && lock=$I_LOCK
  lines+=("$use $lock $(printf '%3s%%' "$sig")  $ssid")
done
lines+=("── Turn Wi-Fi off" "── Advanced settings…")

(nmcli device wifi rescan >/dev/null 2>&1 &)
sel=$(printf '%s\n' "${lines[@]}" | menu "wifi" -format i)
[[ -z $sel ]] && exit 0
if (( sel >= ${#nets[@]} )); then
  case $((sel - ${#nets[@]})) in
    0) nmcli radio wifi off ;;
    1) nm-connection-editor & ;;
  esac
  exit 0
fi

IFS=$'\t' read -r use ssid sig sec <<<"${nets[$sel]}"
if [[ $use == "●" ]]; then
  nmcli connection down id "$ssid" >/dev/null 2>&1 && notify-send -t 3000 "Wi-Fi" "Disconnected from $ssid"
  exit 0
fi
if grep -qxF -- "$ssid" <<<"$known"; then
  out=$(nmcli connection up id "$ssid" 2>&1)
elif [[ -n $sec && $sec != -- ]]; then
  pw=$(menu "password" -password -lines 0 -mesg "$ssid") || exit 0
  [[ -z $pw ]] && exit 0
  out=$(nmcli device wifi connect "$ssid" password "$pw" 2>&1)
else
  out=$(nmcli device wifi connect "$ssid" 2>&1)
fi
if (( $? == 0 )); then notify-send -t 3000 "Wi-Fi" "Connected to $ssid"
else notify-send -u critical "Wi-Fi" "${out:0:200}"; fi
