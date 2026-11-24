# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# X display auto-adapt (runs once at start and before every prompt).
# Long-lived shells (tmux servers, old terminals) keep the DISPLAY of a previous login
# (e.g. :0 from lightdm while Ly's session is on :1). If a local DISPLAY points at an X
# server that isn't running, switch to the one that is. Skipped over SSH/forwarded displays.
_adapt_display() {
  [[ -n $SSH_CONNECTION ]] && return
  [[ -n $DISPLAY && $DISPLAY != :<->* ]] && return
  # running X servers = their sockets in /tmp/.X11-unix (no subprocess: this
  # runs before every prompt)
  local -a active=(/tmp/.X11-unix/X<->(N:t))
  active=(${active/#X/:})
  (( ${#active} )) || return
  [[ -n ${active[(r)${DISPLAY%%.*}]} ]] || export DISPLAY=${active[1]}
}
_adapt_display
autoload -Uz add-zsh-hook
add-zsh-hook precmd _adapt_display

