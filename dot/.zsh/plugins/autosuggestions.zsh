# SPDX-License-Identifier: GPL-2.0-only
# Copyright (c) 2025-2026 rippsec and contributors. See LICENSE and NOTICE.md.
# zsh-autosuggestions. (zsh-autocomplete is loaded earlier, in config/completion.zsh,
# because it has to come before compinit/compdef; syntax highlighting is plugins/syntax-highlighting.zsh.)
# Auto suggestions — async so a slow history/completion lookup never blocks typing
if [[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
    ZSH_AUTOSUGGEST_USE_ASYNC=1
    ZSH_AUTOSUGGEST_MANUAL_REBIND=1          # don't re-wrap widgets before every prompt
    ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=60       # don't suggest for huge pasted lines
    ZSH_AUTOSUGGEST_STRATEGY=(history)
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#999'
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi
