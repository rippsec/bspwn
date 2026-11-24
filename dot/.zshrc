# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
#
# ~/.zshrc: kept short on purpose. Everything lives in ~/.zsh/ and is loaded by ~/.zsh/init.zsh
# (load order and layout are documented there). Machine-specific extras go in ~/.zshrc.local (not in git).
[[ -r ~/.zsh/init.zsh ]] && source ~/.zsh/init.zsh

PROMPT_EOL_MARK=''

# Debian chroot name for the prompt
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# LHOST is kept up to date by the polybar LHOST widget (it rewrites this line); RHOST lines are added by the RHOST widget.
export lhost="$(get_ipaddr)"

# fnm (Node version manager), if installed
FNM_PATH="$HOME/.local/share/fnm"
if [ -d "$FNM_PATH" ]; then
  export PATH="$FNM_PATH:$PATH"
  eval "$(fnm env --shell zsh)"
fi

# readable world-writable dirs (default 34;42 blue-on-green is unreadable in this palette)
export LS_COLORS="${LS_COLORS}:ow=01;34:tw=01;34"
