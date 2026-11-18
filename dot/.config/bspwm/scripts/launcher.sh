#!/bin/bash
# Super+R / start button: rofi launcher styled for the current mode (toggle if open).
pid=$(pgrep -x rofi | while read -r p; do
  tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -qE 'launch\.rasi|start-menu\.rasi' && echo "$p"
done)
[[ -n $pid ]] && { kill $pid; exit 0; }
case $(cat "$HOME/.cache/bspwn-mode" 2>/dev/null) in
  undercover) exec rofi -show drun -theme "$HOME/.config/rofi/start-menu.rasi" ;;
  *)          exec rofi -show drun -theme "$HOME/.config/rofi/launch.rasi" ;;
esac
