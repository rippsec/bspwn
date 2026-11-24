# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# Environment. `typeset -U path` keeps every PATH entry once (first occurrence wins).
typeset -U path PATH
export PATH=$PATH:$HOME:/opt/bin:$HOME/.local/bin:/usr/bin/ruby3.0:$HOME/.go/bin:$HOME/.cargo/bin
export PATH=$PATH:$HOME/.rvm/bin
export DEBIAN_FRONTEND=noninteractive
export GOPATH=$HOME/.go
export GEM_HOME="$HOME/.gems"
export PATH="$HOME/.gems/bin:$PATH"
export _JAVA_AWT_WM_NONREPARENTING=1
export TERM=xterm-256color
export PATH="$PATH:/usr/local/zig"
export PATH="$PATH:/snap/bin"
export PATH="$PATH:$HOME/go/bin:$HOME/.pdtm/go/bin:/usr/local/bin:/opt/pentest/bin/linux"



# default terminal for scripts/launchers that honour $TERMINAL
export TERMINAL=alacritty
