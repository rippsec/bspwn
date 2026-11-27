#!/bin/bash
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
#
# Claude Code indicator for polybar (module/claude, custom/ipc).
#   claude-status.sh set busy|wait|done   called by Claude Code hooks (reads the hook JSON on stdin)
#   claude-status.sh end                  session ended: forget it
#   claude-status.sh bar [FRAME]          print the icon for polybar once (FRAME 0-9 = busy colour step)
#   claude-status.sh watch                loop for a tail=true module: prints on change, and animates the busy
#                                         icon from dark to light (a toaster 'toasting' progress) while working
#   claude-status.sh clear                drop finished sessions (click on the icon)
# One state file per session in $XDG_RUNTIME_DIR/bspwn-claude. The bar shows the most urgent state:
# wait (needs input) > busy (working) > done. Nothing is shown when no session is active.
# "done" plays a toaster ding; set BSPWN_CLAUDE_SOUND to another file, or to "none" to mute it.

DIR="${XDG_RUNTIME_DIR:-/tmp}/bspwn-claude"
SOUND="${BSPWN_CLAUDE_SOUND:-$HOME/.bspwn/assets/sounds/toaster.mp3}"

ICON_BUSY=$'\U000f0cd3'   # working
ICON_WAIT=$'\U000f009e'   # bell: waiting for an answer or a permission
ICON_DONE=$'\U000f1063'   # finished

refresh() { polybar-msg action "#claude.hook.0" >/dev/null 2>&1 & }

session_id() {
  local json id
  json=$(cat)
  id=$(jq -r '.session_id // empty' <<<"$json" 2>/dev/null)
  echo "${id:-default}" | tr -cd 'A-Za-z0-9_-'
}

chime() {
  [[ $SOUND == none || ! -f $SOUND ]] && return
  if command -v paplay >/dev/null; then paplay "$SOUND" &
  elif command -v pw-play >/dev/null; then pw-play "$SOUND" &
  fi
}

case "$1" in
  set)
    state=$2
    [[ $state =~ ^(busy|wait|done)$ ]] || exit 0
    mkdir -p "$DIR"
    file="$DIR/$(session_id)"
    [[ -f $file && $(<"$file") == "$state" ]] && exit 0   # unchanged: no bar update
    echo "$state" >"$file"
    [[ $state == done ]] && chime
    refresh
    ;;
  end)
    rm -f "$DIR/$(session_id)"
    refresh
    ;;
  clear)
    grep -lx done "$DIR"/* 2>/dev/null | xargs -r rm -f
    refresh
    ;;
  bar|watch)
    # busy colour ramp, dark -> light (monochrome palette); the last steps hold the lightest tone
    RAMP=(3a3b40 4b4d55 6f7178 8e9099 a2a3a7 b2b2b4 c0c0c1 c0c0c1 c0c0c1 c0c0c1)
    render() {   # render FRAME
      # sessions untouched for 12 h are treated as gone (crashed or killed terminal)
      find "$DIR" -type f -mmin +720 -delete 2>/dev/null
      local states n count=""
      states=$(cat "$DIR"/* 2>/dev/null)
      [[ -z $states ]] && { echo ""; return; }
      n=$(wc -l <<<"$states")
      (( n > 1 )) && count=" $n"
      if grep -qx wait <<<"$states"; then
        echo "%{F#e5383b}${ICON_WAIT}${count}%{F-}"
      elif grep -qx busy <<<"$states"; then
        echo "%{F#${RAMP[$1]}}${ICON_BUSY}${count}%{F-}"
      else
        echo "%{F#c0c0c1}%{u#c0c0c1}%{+u}${ICON_DONE}${count}%{-u}%{F-}"
      fi
    }
    if [[ $1 == bar ]]; then
      f=${2:-9}; [[ $f =~ ^[0-9]$ ]] || f=9
      render "$f"; exit 0
    fi
    f=0; last=
    while :; do
      out=$(render "$f")
      if [[ $out != "$last" ]]; then echo "$out"; last=$out; fi
      if grep -qx busy "$DIR"/* 2>/dev/null && ! grep -qx wait "$DIR"/* 2>/dev/null; then
        f=$(( (f + 1) % ${#RAMP[@]} )); sleep 0.12
      else
        f=0; sleep 0.5
      fi
    done
    ;;
esac
exit 0
