#!/bin/bash
# Full-screen app launcher (rofi/launchpad.rasi). Toggle: if it's already open,
# a second click on the button closes it. Only real rofi processes count
# (an editor with launchpad.rasi open must not match).
pid=$(pgrep -x rofi | while read -r p; do
  tr '\0' ' ' < "/proc/$p/cmdline" 2>/dev/null | grep -q 'launchpad\.rasi' && echo "$p"
done)
if [[ -n $pid ]]; then
  kill $pid
  exit 0
fi
exec rofi -show drun -theme "$HOME/.config/rofi/launchpad.rasi"
