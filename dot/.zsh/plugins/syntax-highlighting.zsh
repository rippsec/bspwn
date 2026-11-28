# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# zsh-syntax-highlighting: sourced ONCE, with the palette-friendly styles below.
if [[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    ZSH_HIGHLIGHT_MAXLENGTH=300              # skip highlighting very long buffers
    ZSH_HIGHLIGHT_HIGHLIGHTERS=(main brackets pattern line regexp)
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
    ZSH_HIGHLIGHT_STYLES[default]=none
    ZSH_HIGHLIGHT_STYLES[line]=bold
    ZSH_HIGHLIGHT_STYLES[unknown-token]=fg=red
    ZSH_HIGHLIGHT_STYLES[reserved-word]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[suffix-alias]=fg=green
    ZSH_HIGHLIGHT_STYLES[global-alias]=fg=green
    ZSH_HIGHLIGHT_STYLES[precommand]=fg=green
    ZSH_HIGHLIGHT_STYLES[commandseparator]=fg=blue
    ZSH_HIGHLIGHT_STYLES[autodirectory]=fg=green
    ZSH_HIGHLIGHT_STYLES[path]=bold,fg=blue
    ZSH_HIGHLIGHT_STYLES[path_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[path_prefix_pathseparator]=
    ZSH_HIGHLIGHT_STYLES[globbing]=fg=blue
    ZSH_HIGHLIGHT_STYLES[history-expansion]=fg=blue
    ZSH_HIGHLIGHT_STYLES[command-substitution]=none
    ZSH_HIGHLIGHT_STYLES[command-substitution-delimiter]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[process-substitution]=none
    ZSH_HIGHLIGHT_STYLES[process-substitution-delimiter]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[single-hyphen-option]=fg=green
    ZSH_HIGHLIGHT_STYLES[double-hyphen-option]=fg=green
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument]=none
    ZSH_HIGHLIGHT_STYLES[back-quoted-argument-delimiter]=fg=blue
    ZSH_HIGHLIGHT_STYLES[single-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[double-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[rc-quote]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[dollar-double-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-double-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[back-dollar-quoted-argument]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[assign]=none
    ZSH_HIGHLIGHT_STYLES[redirection]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[comment]=fg=gray
    ZSH_HIGHLIGHT_STYLES[named-fd]=none
    ZSH_HIGHLIGHT_STYLES[numeric-fd]=none
    ZSH_HIGHLIGHT_STYLES[arg0]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[bracket-error]=fg=red
    ZSH_HIGHLIGHT_STYLES[bracket-level-1]=fg=blue
    ZSH_HIGHLIGHT_STYLES[bracket-level-2]=fg=green
    ZSH_HIGHLIGHT_STYLES[bracket-level-3]=fg=magenta
    ZSH_HIGHLIGHT_STYLES[bracket-level-4]=fg=yellow
    ZSH_HIGHLIGHT_STYLES[bracket-level-5]=fg=cyan
    ZSH_HIGHLIGHT_STYLES[cursor-matchingbracket]=standout
    ZSH_HIGHLIGHT_STYLES[alias]=fg=cyan
    # Warning blocks for sudo and rm: bg "red" / fg "black" are the terminal palette colours (alacritty and
    # kitty red #d78a7b, black #2e3135), so the block follows the theme. \<...\> matches whole words only
    # (not sudoedit, format, rmdir); [[:space:]] because \s is not valid inside a bracket expression.
    ZSH_HIGHLIGHT_REGEXP+=(
        '\<sudo\>'                                      bg=red,fg=black,bold
        '\<rm\>([[:space:]]+-[^[:space:]]+)*'           bg=red,fg=black,bold   # rm plus its options
        '\$\([^)]*\<rm\>[^)]*\)|`[^`]*\<rm\>[^`]*`'     bg=red,fg=black,bold   # rm inside $( ) or ` `
    )
fi
