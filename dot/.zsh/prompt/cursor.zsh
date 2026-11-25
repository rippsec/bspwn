#!/usr/bin/env zsh
# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# cursor.zsh - cursor shape for the shell.
# DECSCUSR (\e[N q): 0 terminal default, 1/2 block, 3/4 underline, 5/6 vertical bar (odd = blinking, even = steady).
# Programs such as vim/nvim change the shape and may not restore it; resetting before every prompt
# means the shell always shows the steady bar again after they exit.

BSPWN_CURSOR=${BSPWN_CURSOR:-6}

_bspwn_cursor() { print -n "\e[${BSPWN_CURSOR} q"; }

autoload -Uz add-zsh-hook
add-zsh-hook precmd _bspwn_cursor
_bspwn_cursor
