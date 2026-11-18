#!/usr/bin/env bash
# Power menu (rofi/pwmenu.rasi): full-screen dim/blur overlay with big buttons,
# macOS / KDE style. Esc, Ctrl+g or a click on the empty area cancels.
# A second click on the polybar ⏻ button closes it again.

# toggle: close an already-open power menu
pid=$(pgrep -x rofi | while read -r p; do
  tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'pwmenu\.rasi' && echo "$p"
done)
if [[ -n $pid ]]; then
  kill $pid
  exit 0
fi

uptime=$(uptime -p | sed -e 's/up //g')

# one entry per button: big Nerd Font glyph over a label ('|' separates entries)
g() { printf "<span font_family='Symbols Nerd Font Mono' size='34pt'>%s</span>\n%s" "$1" "$2"; }
options="$(g $'\U000f033e' Lock)|$(g $'\U000f04b2' Sleep)|$(g $'\U000f0343' Logout)|$(g $'\U000f0709' Restart)|$(g $'\U000f0425' Shutdown)"

# -format i -> index of the chosen button (empty when cancelled)
chosen=$(printf '%s' "$options" | rofi -dmenu -sep '|' -markup-rows -eh 4 -format i \
  -no-custom -mesg "uptime · $uptime" -theme "$HOME/.config/rofi/pwmenu.rasi")

case "$chosen" in
  0) command -v xlock >/dev/null && xlock ;;
  1) mpc -q pause 2>/dev/null; amixer set Master mute >/dev/null 2>&1; systemctl suspend ;;
  2) bspc quit ;;
  3) shutdown -r now ;;
  4) shutdown -h now ;;
esac
