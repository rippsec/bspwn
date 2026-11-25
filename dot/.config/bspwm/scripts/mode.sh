#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Desktop mode switcher: cockpit (monochrome rice) <-> undercover (Windows 10 look).
#   mode.sh cockpit | undercover | toggle | apply
# Everything is applied LIVE (no logout): GTK via xsettingsd + gsettings, geometry via
# explicit bspc paddings (not panel struts), panels/compositor restarted, wallpaper set.
# The chosen mode is stored in ~/.cache/bspwn-mode; "apply" re-applies it (login, bspc wm -r).
# Cockpit is the default and is restored by re-applying its profile, nothing is undone.
BASE="$HOME/.config/bspwm"
STATE="$HOME/.cache/bspwn-mode"
FLOATED="$HOME/.cache/bspwn-mode-floated"
mkdir -p "$HOME/.cache"

# PID lock (not flock: a flock fd would leak into the panels/daemons started below and stay held)
LOCK="${XDG_RUNTIME_DIR:-/tmp}/bspwn-mode.pid"
for _ in $(seq 50); do
  if [[ -r $LOCK ]] && kill -0 "$(cat "$LOCK" 2>/dev/null)" 2>/dev/null; then sleep 0.2; else break; fi
done
echo $$ > "$LOCK"
trap 'rm -f "$LOCK"' EXIT

cur=$(cat "$STATE" 2>/dev/null)
[[ -f $BASE/modes/$cur.conf ]] || cur=cockpit
case ${1:-toggle} in
  toggle)    [[ $cur == cockpit ]] && new=undercover || new=cockpit ;;
  apply)     new=$cur ;;
  cockpit|undercover) new=$1 ;;
  *) echo "usage: mode.sh [cockpit|undercover|toggle|apply]" >&2; exit 2 ;;
esac
# shellcheck disable=SC1090
source "$BASE/modes/$new.conf"
echo "$new" > "$STATE"

# ---- snapshot tiled rectangles BEFORE any geometry changes (used to float windows in place)
declare -A RECT
if [[ $FLOATING == 1 ]]; then
  for n in $(bspc query -N -n .tiled.window); do
    RECT[$n]=$(bspc query -T -n "$n" | python3 -c \
      'import json,sys;r=json.load(sys.stdin)["client"]["tiledRectangle"];print(r["x"],r["y"],r["width"],r["height"])')
  done
  read -r SCR_H < <(bspc query -T -m | python3 -c 'import json,sys;print(json.load(sys.stdin)["rectangle"]["height"])')
fi

# ---- GTK / icons / cursor / font: live via XSETTINGS (xsettingsd) + gsettings (GTK4)
mkdir -p "$HOME/.config/xsettingsd"
cat > "$HOME/.config/xsettingsd/xsettingsd.conf" <<XS
Net/ThemeName "$GTK_THEME_NAME"
Net/IconThemeName "$ICON_THEME"
Gtk/CursorThemeName "$CURSOR_THEME"
Gtk/CursorThemeSize $CURSOR_SIZE
Gtk/FontName "$UI_FONT"
Xft/DPI 98304
Xft/Antialias 1
Xft/Hinting 1
Xft/HintStyle "hintmedium"
XS
if pgrep -x xsettingsd >/dev/null; then pkill -HUP -x xsettingsd; else setsid xsettingsd >/dev/null 2>&1 & fi
gsettings set org.gnome.desktop.interface gtk-theme "$GTK_THEME_NAME" 2>/dev/null
gsettings set org.gnome.desktop.interface icon-theme "$ICON_THEME" 2>/dev/null
gsettings set org.gnome.desktop.interface cursor-theme "$CURSOR_THEME" 2>/dev/null
gsettings set org.gnome.desktop.interface font-name "$UI_FONT" 2>/dev/null
gsettings set org.gnome.desktop.interface color-scheme "$COLOR_SCHEME" 2>/dev/null
printf 'Xcursor.theme: %s\nXcursor.size: %s\n' "$CURSOR_THEME" "$CURSOR_SIZE" | xrdb -merge 2>/dev/null
xsetroot -cursor_name left_ptr 2>/dev/null

# ---- wallpaper
[[ -f $WALLPAPER ]] && feh --no-fehbg --bg-fill "$WALLPAPER" 2>/dev/null

# ---- bspwm geometry: explicit, so it never depends on a panel's struts (no stale sizes)
bspc config ignore_ewmh_struts true
for m in $(bspc query -M); do
  bspc config -m "$m" top_padding "$TOP_PAD"
  bspc config -m "$m" bottom_padding "$BOTTOM_PAD"
done
bspc config window_gap "$GAP"
bspc config border_width "$BORDER"
bspc config focused_border_color "$FOCUSED_COLOR"
bspc config active_border_color  "$ACTIVE_COLOR"
bspc config normal_border_color  "$NORMAL_COLOR"

# ---- window behaviour: floating (Windows-like) vs tiling
# remove ONLY our wildcard rule, by index (bspc rule -r PATTERN treats '*' as a wildcard and would
# delete every rule, including the ones from bspwmrc)
for _ in $(seq 20); do                      # bounded: never loop forever
  idx=$(bspc rule -l | grep -n -x '\*:\*:\* => state=floating' | head -1 | cut -d: -f1)
  [[ -n $idx ]] || break
  bspc rule -r "^$idx" || break             # ^N is 1-based and follows the `bspc rule -l` order
done
if [[ $FLOATING == 1 ]]; then
  bspc rule -a '*:*:*' state=floating
  : > "$FLOATED"
  for n in "${!RECT[@]}"; do
    read -r x y w h <<<"${RECT[$n]}"
    # clamp into the work area (below TOP_PAD, above the taskbar)
    (( y < TOP_PAD )) && y=$TOP_PAD
    (( y + h > SCR_H - BOTTOM_PAD )) && h=$(( SCR_H - BOTTOM_PAD - y ))
    bspc node "$n" -t floating && echo "$n" >> "$FLOATED"
    xdotool windowsize "$n" "$w" "$h" windowmove "$n" "$x" "$y" 2>/dev/null
  done
elif [[ -s $FLOATED ]]; then
  while read -r n; do                       # re-tile only the windows WE floated
    bspc node "$n" -t tiled 2>/dev/null
  done < "$FLOATED"
  : > "$FLOATED"
fi

# ---- panels
kill_polybar() {
  killall -q polybar
  for _ in $(seq 20); do pgrep -x polybar >/dev/null || return 0; sleep 0.1; done
  killall -q -9 polybar 2>/dev/null
  "$HOME/.config/bspwm/scripts/polybar-reap.sh" all
}
mkdir -p "$HOME/.cache/bspwn"
cat > "$HOME/.cache/bspwn/start-menu.desktop" <<DT
[Desktop Entry]
Type=Application
Name=Start
Icon=start-here
Exec=$BASE/scripts/launcher.sh
DT
case $PANEL in
  polybar)
    killall -q tint2
    "$HOME/.config/polybar/launch.sh" ;;
  tint2)
    kill_polybar
    killall -q tint2; sleep 0.2
    setsid tint2 -c "$HOME/.config/tint2/undercover.tint2rc" >/dev/null 2>&1 & ;;
esac

# ---- compositor + HUD (power-mode.sh starts picom/conky from the profile, honouring battery)
pkill -x picom
for _ in $(seq 30); do pgrep -x picom >/dev/null || break; sleep 0.1; done   # wait: power-mode.sh checks pgrep
[[ $CONKY == 1 ]] || pkill -x conky
"$BASE/scripts/power-mode.sh" auto --force

[[ $1 == apply ]] || notify-send -u low "Mode: $new (switched live)" 2>/dev/null
exit 0
